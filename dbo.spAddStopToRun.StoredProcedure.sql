USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spAddStopToRun]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spAddStopToRun](
	@DriverID		int,
	@RunID			int,
	@LocationID		int,
	@NumberLoaded		int,
	@NumberUnloaded		int,
	@NumberOfReloads	int,
	@StopCreationDate	datetime,
	@WhoCreated		varchar(20)	-- Can be either user name or application name
	)
AS
BEGIN
	/************************************************************************
	*	spAddStopToRun							*
	*									*
	*	Description							*
	*	-----------							*
	*	Adds a new stop to a run.				 	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/03/2005 CMK    Initial version				*
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	@UnitsOnTruck		int,
		@MaxUnitsOnTruck	int,
		@TotalStops		int,
		@CreationDate		datetime,
		@CreatedBy		varchar(20),
		@UpdatedDate		datetime,
		@UpdatedBy		varchar(20),
		@RunStopsID		int,
		@RunStopNumber		int,
		@NextStopNumber		int,
		@StopType		varchar(20),
		@UnitsLoaded		int,
		@UnitsUnloaded		int,
		@Miles			decimal(19,2),
		@AuctionPay		decimal(19,2),
		@StopDate		datetime,
		@TruckID		int,
		@ReturnCode		int,
		@ReturnMessage		varchar(50),
		@ErrorID		int,
		@Msg			varchar(50),
		@Count			int

	SELECT @Count = 0
	SELECT @ErrorID = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @UpdatedDate = CURRENT_TIMESTAMP
	
	BEGIN TRAN
	--query for values needed from the run
	SELECT @NextStopNumber = TotalStops + 1,
	@UnitsOnTruck = UnitsOnTruck,
	@MaxUnitsOnTruck = MaxUnitsOnTruck
	FROM Run
	WHERE RunID = @RunID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered creating the RunsStops Record'
		GOTO Error_Encountered
	END
	
	SELECT @TruckID = CurrentTruckID
	FROM Driver
	WHERE DriverID = @DriverID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the truck id'
		GOTO Error_Encountered
	END
	
	--create the stop
	SELECT @RunStopNumber = @NextStopNumber
	IF @NumberLoaded>0 AND @NumberUnloaded > 0
	BEGIN
		SELECT @StopType = 'Pickup & Dropoff'
	END
	ELSE IF @NumberLoaded > 0
	BEGIN
		SELECT @StopType = 'Pickup'
	END
	ELSE IF @NumberUnloaded > 0
	BEGIN
		SELECT @StopType = 'Dropoff'
	END
	ELSE IF @NumberLoaded = 0 AND @NumberUnloaded = 0 AND @NextStopNumber = 1
	BEGIN
		SELECT @StopType = 'StartEmptyPoint'
	END
	ELSE
	BEGIN
		SELECT @ErrorID = 100000
		SELECT @Msg = 'Unable to determine stop type'
		GOTO Error_Encountered
	END
	
	SELECT @UnitsLoaded = @NumberLoaded
	SELECT @UnitsUnloaded = @NumberUnloaded
	SELECT @Miles = 0			--will be calculated when the payroll record is created
	SELECT @AuctionPay = 0			--will be calcualted when the payroll record is created
	SELECT @StopDate = @StopCreationDate
	--SELECT @CreationDate = @StopCreationDate
	--SELECT @CreatedBy = @WhoCreated
	--SELECT @UpdatedDate = NULL
	--SELECT @UpdatedBy = NULL
	
	INSERT INTO RunStops(
		RunID,
		LocationID,
		RunStopNumber,
		StopType,
		UnitsLoaded,
		UnitsUnloaded,
		Miles,
		AuctionPay,
		NumberOfReloads,
		StopDate,
		CreationDate,
		CreatedBy,
		UpdatedDate,
		UpdatedBy
	)
	VALUES(
		@RunID,
		@LocationID,
		@RunStopNumber,
		@StopType,
		@UnitsLoaded,
		@UnitsUnloaded,
		@Miles,
		@AuctionPay,
		@NumberOfReloads,
		@StopDate,
		@CreationDate,
		@WhoCreated,
		NULL,
		NULL
	)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered creating the RunsStops Record'
		GOTO Error_Encountered
	END
	
	--update the run with the new number of stops, units on truck and max units on truck
	SELECT @UnitsOnTruck = @UnitsOnTruck + @NumberLoaded - @NumberUnLoaded
	IF @NumberLoaded > @NumberUnloaded
	BEGIN
		SELECT @MaxUnitsOnTruck = @MaxUnitsOnTruck + @NumberLoaded - @NumberUnloaded
	END
	
	UPDATE Run
	SET TotalStops = @NextStopNumber,
	UnitsOnTruck = @UnitsOnTruck,
	MaxUnitsOnTruck = @MaxUnitsOnTruck,
	UpdatedDate = @UpdatedDate,
	UpdatedBy = @WhoCreated
	WHERE RunID = @RunID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating the Run Record'
		GOTO Error_Encountered
	END
	--update the driver record
	UPDATE Driver
	SET LastLocationID = @LocationID,
	LastLocationDate = @StopCreationDate,
	UpdatedDate = @UpdatedDate,
	UpdatedBy = @WhoCreated
	WHERE DriverID = @DriverID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating the Driver Record'
		GOTO Error_Encountered
	END

	--update the truck record
	UPDATE Truck
	SET LastDriverID = @DriverID, 
	LastLocationID = @LocationID,
	LastLocationDateTime = @StopCreationDate,
	UpdatedDate = @UpdatedDate,
	UpdatedBy = @WhoCreated
	WHERE TruckID = @TruckID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating the Truck Record'
		GOTO Error_Encountered
	END
	
	Error_Encountered:
	IF @ErrorID <> 0
	BEGIN
		ROLLBACK TRAN
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Msg
	END
	ELSE
	BEGIN
		COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Stop Created Successfully'
	END

	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM'

	RETURN @ReturnCode
END

GO
