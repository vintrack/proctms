USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spCreateRun]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spCreateRun](
	@DriverID		int,
	@TruckID		int,
	@PayPeriod		int,		-- -1 = Check for current run, -2 = new run current period, -3 = new run next period
	@StartedEmptyFromID	int,		-- LocationID for the started empty point
	@StartedLoadedFromID	int,		-- LocationID for where the first units were loaded
	@RunCreationDate	datetime,
	@WhoCreated		varchar(20),	-- Can be either user name or application name
	@DriverRunNumber	int,		-- The Driver Run Number or Zero to Calculate Automatically
	@StartingMileage	decimal(19,2) = NULL
	)
AS
BEGIN
	/************************************************************************
	*	spCreateRun							*
	*									*
	*	Description							*
	*	-----------							*
	*	Creates a new run either in the current or next pay period. 	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/03/2005 CMK    Initial version				*
	*	09/22/2005 CMK    Added Code to automatically calculate driver	*
	*                         run number, if a zero run number passed in	*
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	@RunID			int,
		@UnitsOnTruck		int,
		@CurrentPayPeriod	int,
		@PayPeriodID		int,
		@PeriodNumber		int,
		@PeriodClosedInd	int,
		@CalendarYear		int,
		@LastRunNumber		int,
		--@DriverRunNumber	int,
		@DriverCurrentPayPeriod	int,
		@RunPayPeriod		int,
		@RunPayPeriodYear	int,
		@RunStartDate		datetime,
		@RunEndDate		datetime,
		@MaxUnitsOnTruck	int,
		@TotalStops		int,
		@InPayrollInd		int,
		@PaidInd		int,
		@PaidDate		datetime,
		@RunStatus		varchar(20),
		@CreationDate		datetime,
		@CreatedBy		varchar(20),
		@UpdatedDate		datetime,
		@UpdatedBy		varchar(20),
		@RunStopsID		int,
		@LocationID		int,
		@RunStopNumber		int,
		@StopType		varchar(20),
		@UnitsLoaded		int,
		@UnitsUnloaded		int,
		@Miles			decimal(19,2),
		@AuctionPay		decimal(19,2),
		@NumberOfReloads	int,
		@StopDate		datetime,
		@ReturnCode		int,
		@ReturnMessage		varchar(50),
		@ReturnRunID		int,
		@ErrorID		int,
		@Msg			varchar(50),
		@Count			int

	SELECT @Count = 0
	SELECT @ErrorID = 0
	SELECT @RunID = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @UpdatedDate = CURRENT_TIMESTAMP
	
	BEGIN TRAN
	-- see if there is an existing open run
	SELECT @Count = COUNT(*)
	FROM Run
	WHERE DriverID = @DriverID
	AND RunStatus = 'Open'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the Run Count'
		GOTO Error_Encountered
	END
	
	IF @Count = 1
	BEGIN
		-- Need to get the run id and check the status of the run and if possible close it
		SELECT @RunID = RunID, @UnitsOnTruck = UnitsOnTruck
		FROM Run
		WHERE DriverID = @DriverID
		AND RunStatus = 'Open'
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the Open Run ID'
			GOTO Error_Encountered
		END
		
		IF @PayPeriod = -1 --we were only looking for the current runid and found it
		BEGIN
			SELECT @ErrorID = 0
			GOTO Error_Encountered
		END
		
		IF @UnitsOnTruck = 0
		BEGIN
			--No units left on the truck, so it should be safe to close the run now
			UPDATE Run
			SET RunStatus = 'Closed',
			UpdatedDate = @UpdatedDate,
			UpdatedBy = @WhoCreated
			WHERE RunID = @RunID
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered closing the Old Run'
				GOTO Error_Encountered
			END
		END
	END
	ELSE IF @Count > 1
	BEGIN
		-- THIS SHOULD NOT HAPPEN, HOW DO WE WANT TO ACCOUNT FOR THIS
		IF @PayPeriod = -1 --we were only looking for the current runid and found it
		BEGIN
			SELECT @ErrorID = 100000
			SELECT @Msg = 'Multiple Open Runs Found'
			GOTO Error_Encountered
		END
	END

	--SHOULD NOW BE SAFE TO CREATE THE NEW RUN
	
	--get the pay period information and run number information
	--SELECT @CurrentPayPeriod = CurrentPayPeriod,	-- cmk are always going to use the current pay period
	SELECT @LastRunNumber = ISNULL(LastRunNumber,0),
	@DriverCurrentPayPeriod = CurrentPayPeriod
	FROM Driver
	WHERE DriverID = @DriverID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting data from the Driver Table'
		GOTO Error_Encountered
	END
	
	IF @CurrentPayPeriod IS NULL --just in case the driver does not have a current pay period
	BEGIN
		/*
		SELECT TOP 1 @CurrentPayPeriod = PayPeriodID
		FROM PayPeriod
		WHERE (PeriodClosedInd IS NULL
		OR PeriodClosedInd = 0)
		ORDER BY PeriodEndDate
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the Current Pay Period'
			GOTO Error_Encountered
		END
		*/
		SELECT TOP 1 @CurrentPayPeriod = PayPeriodID
		FROM PayPeriod
		WHERE PeriodEndDate >= CONVERT(varchar(10),CURRENT_TIMESTAMP,101)
		AND PeriodClosedInd = 0
		ORDER BY PeriodEndDate
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the Current Pay Period'
			GOTO Error_Encountered
		END
	END
	
	--get the pay period detail
	SELECT @PayPeriodID = P.PayPeriodID,
	@PeriodNumber = P.PeriodNumber,
	@CalendarYear = P.CalendarYear,
	@PeriodClosedInd = P.PeriodClosedInd
	FROM PayPeriod P
	WHERE P.PayPeriodID = @CurrentPayPeriod
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting data for the Current Pay Period'
		GOTO Error_Encountered
	END
		
	IF @PayPeriod = -2
	BEGIN
		IF @DriverRunNumber = 0
		BEGIN
			IF @DriverCurrentPayPeriod = @CurrentPayPeriod
			BEGIN
				SELECT @DriverRunNumber = @LastRunNumber+1
			END
			ELSE
			BEGIN
				SELECT @DriverRunNumber = 1
			END
		END
	END
	ELSE
	BEGIN
		IF @DriverRunNumber = 0
		BEGIN
			SELECT @DriverRunNumber = 1
		END
		
		--get the pay period detail
		SELECT @PayPeriodID = P.PayPeriodID,
		@PeriodNumber = P.PeriodNumber,
		@CalendarYear = P.CalendarYear,
		@PeriodClosedInd = P.PeriodClosedInd
		FROM PayPeriod P
		WHERE P.PeriodNumber = CASE WHEN @PeriodNumber = 26 THEN 1 ELSE @PeriodNumber+1 END
		AND P.CalendarYear = CASE WHEN @PeriodNumber = 26 THEN @CalendarYear+1 ELSE @CalendarYear END
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting data for the Next Pay Period'
			GOTO Error_Encountered
		END
		
	END
	
	IF @PeriodClosedInd = 1
	BEGIN
		--the pay period is closed by payroll so we have to go to the next open period
		SELECT @DriverRunNumber = 1 --COMMENTED OUT UNTIL DRIVERS ARE USING THE PHONES FOR ALL RUNS
		
		--get the pay period detail
		SELECT @PayPeriodID = P.PayPeriodID,
		@PeriodNumber = P.PeriodNumber,
		@CalendarYear = P.CalendarYear,
		@PeriodClosedInd = P.PeriodClosedInd
		FROM PayPeriod P
		WHERE P.PeriodEndDate = (SELECT MIN(P2.PeriodEndDate)
			FROM PayPeriod P2
			WHERE PeriodClosedInd IS NULL
			OR PeriodClosedInd = 0)
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting data for the Next Open Pay Period'
			GOTO Error_Encountered
		END
		
	END
	--load the variables
	SELECT @RunPayPeriod = @PeriodNumber
	SELECT @RunPayPeriodYear = @CalendarYear
	SELECT @RunStartDate = @RunCreationDate
	SELECT @RunEndDate = NULL
	SELECT @StartedEmptyFromID = @StartedEmptyFromID
	SELECT @StartedLoadedFromID = @StartedLoadedFromID
	SELECT @UnitsOnTruck = 0
	SELECT @MaxUnitsOnTruck = 0
	SELECT @TotalStops = 1		--for the started empty stop being created below
	SELECT @InPayrollInd = 0
	SELECT @PaidInd = 0
	SELECT @PaidDate = NULL
	SELECT @RunStatus = 'Open'
	--SELECT @CreationDate = @RunCreationDate
	--SELECT @CreatedBy = @WhoCreated
	--SELECT @UpdatedDate = NULL
	--SELECT @UpdatedBy = NULL
	
	--create the run
	INSERT INTO Run(
		DriverID,
		TruckID,
		DriverRunNumber,
		RunPayPeriod,
		RunPayPeriodYear,
		RunStartDate,
		RunEndDate,
		StartedEmptyFromID,
		StartedLoadedFromID,
		UnitsOnTruck,
		MaxUnitsOnTruck,
		TotalStops,
		InPayrollInd,
		PaidInd,
		PaidDate,
		RunStatus,
		CreationDate,
		CreatedBy,
		UpdatedDate,
		UpdatedBy,
		StartingMileage
	)
	VALUES(
		@DriverID,
		@TruckID,
		@DriverRunNumber,
		@RunPayPeriod,
		@RunPayPeriodYear,
		@RunStartDate,
		@RunEndDate,
		@StartedEmptyFromID,
		@StartedLoadedFromID,
		@UnitsOnTruck,
		@MaxUnitsOnTruck,
		@TotalStops,
		@InPayrollInd,
		@PaidInd,
		@PaidDate,
		@RunStatus,
		@CreationDate,
		@CreatedBy,
		NULL,
		NULL,
		@StartingMileage
	)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered inserting New Run Record'
		GOTO Error_Encountered
	END
	
	--get the runid
	SELECT @RunID = @@Identity
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the New Run ID'
		GOTO Error_Encountered
	END
	
	--create the started empty stop
	SELECT @LocationID = @StartedEmptyFromID
	SELECT @RunStopNumber = 1
	SELECT @StopType = 'StartEmptyPoint'
	SELECT @UnitsLoaded = 0
	SELECT @UnitsUnloaded = 0
	SELECT @Miles = 0
	SELECT @AuctionPay = 0
	SELECT @NumberOfReloads = 0
	SELECT @StopDate = @RunCreationDate
	--SELECT @CreationDate = @RunCreationDate
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
		@CreatedBy,
		NULL,
		NULL
	)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered creating the RunsStops Record'
		GOTO Error_Encountered
	END
	
	--update the driver record
	UPDATE Driver
	SET LastRunNumber = @DriverRunNumber,
	CurrentPayPeriod = @PayPeriodID,
	LastLocationID = @StartedEmptyFromID,
	LastLocationDate = @RunCreationDate,
	UpdatedDate = @UpdatedDate,
	UpdatedBy = @WhoCreated
	WHERE DriverID = @DriverID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating the Driver Record'
		GOTO Error_Encountered
	END
	
	--update the truck with the current driver id
	UPDATE Truck
	SET LastDriverID = @DriverID,
	LastLocationID = @StartedLoadedFromID,
	LastLocationDateTime = @RunCreationDate,
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
		SELECT @ReturnRunID = 0
	END
	ELSE
	BEGIN
		COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Run Created Successfully'
		SELECT @ReturnRunID = @RunID
	END

	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM', @ReturnRunID AS 'RR'

	RETURN @ReturnCode
END

GO
