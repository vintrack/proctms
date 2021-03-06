USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spAddVISTADelayTransaction]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[spAddVISTADelayTransaction](
	@VehicleID		int,
	@DelayCode		varchar(20),
	@DelayEffectiveDate	datetime,
	@CreatedBy		varchar(20)
	)
AS
BEGIN
	/************************************************************************
	*	spAddVISTADelayTransaction					*
	*									*
	*	Description							*
	*	-----------							*
	*	Creates a VISTADelayTransaction and puts the vehicle on hold. 	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/27/2007 CMK    Initial version				*
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	@LegID			int,
		@LegStatus		varchar(20),
		@PoolID			int,
		@DateAvailable		datetime,
		@LoadID			int,
		@DateEntered		datetime,
		@EnteredBy		varchar(20),
		@DelayReportedInd	int,
		@DateDelayReported	datetime,
		@DateReleased		datetime,
		@ReleasedBy		varchar(20),
		@ReleaseReportedInd	int,
		@DateReleaseReported	datetime,
		@RecordStatus		varchar(20),
		@CreationDate		datetime,
		@ReturnCode		int,
		@ReturnMessage		varchar(100),
		@ErrorID		int,
		@Msg			varchar(100),
		@Count			int,
		@VIN			varchar(17)

	SELECT @ErrorID = 0
			
	BEGIN TRAN
	
	--set the default values
	SELECT @DateEntered = CURRENT_TIMESTAMP
	SELECT @EnteredBy = @CreatedBy
	SELECT @DelayReportedInd = 0
	SELECT @DateDelayReported = NULL
	SELECT @DateReleased = NULL
	SELECT @ReleasedBy = NULL
	SELECT @ReleaseReportedInd = 0
	SELECT @DateReleaseReported = NULL
	SELECT @RecordStatus = 'Open'
	SELECT @CreationDate = CURRENT_TIMESTAMP

	--get the poolid and date available
	SELECT TOP 1 @LegID = LegsID,@VIN=V.VIN,
	@LegStatus = LegStatus,
	@PoolID = PoolID,
	@DateAvailable = DateAvailable,
	@LoadID = LoadID
	FROM Legs L
	LEFT JOIN Vehicle V ON L.VehicleID = V.VehicleID
	WHERE L.VehicleID = @VehicleID
	AND LegNumber = 1
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting Pool ID'
		GOTO Error_Encountered
	END
	
	IF @LegStatus IN ('EnRoute','Delivered')
	BEGIN
		SELECT @ErrorID = 100000
		SELECT @Msg = 'Vehicle is '+@LegStatus+'. It cannot be put on hold at this time!'
		GOTO Error_Encountered
	END
	
	IF @LegStatus = 'Complete'
	BEGIN
		SELECT @LegID = NULL
		
		--see if there is another leg for this vehicle that is in the correct status
		SELECT TOP 1 @LegID = LegsID,
		@LegStatus = LegStatus,
		@PoolID = PoolID,
		@DateAvailable = DateAvailable,
		@LoadID = LoadID
		FROM Legs
		WHERE VehicleID = @VehicleID
		AND LegNumber <> 1
		AND LegStatus NOT IN ('Complete','EnRoute','Delivered')
		ORDER BY LegNumber
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting Pool ID'
			GOTO Error_Encountered
		END
		
		IF @LegID IS NULL
		BEGIN
			SELECT @ErrorID = 100001
			SELECT @Msg = 'Vehicle is not in the correct status. It cannot be put on hold at this time!'
			GOTO Error_Encountered
		END
	END

	--make sure that there is not already an open hold for the vehicle/Modified this to get multiple holds

	SELECT @Count = COUNT(*)
	FROM VistaDelayTransactions
	WHERE VehicleID = @VehicleID
	AND RecordStatus = 'Open'
	AND DelayCode = @DelayCode
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Getting Open Delay Transaction Count'
		GOTO Error_Encountered
	END
	print 'hold count = '+convert(varchar(20),@count)
	IF @Count > 0
	BEGIN
		SELECT @ErrorID = 100004
		SELECT @Msg 'Open Delay Transaction already exists for the vehicle!'
		GOTO Error_Encountered
		
	END
	
	SELECT @Count = COUNT(*)
	FROM VistaDelayTransactions
	WHERE VehicleID = @VehicleID
	AND RecordStatus = 'Open'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Getting Open Delay Transaction Count'
		GOTO Error_Encountered
	END
	print 'hold count = '+convert(varchar(20),@count)
	IF @Count > 0
	BEGIN
		--SELECT @ErrorID = 100004
		--SELECT @Msg 'Open Delay Transaction already exists for vehicle!'
		--GOTO Error_Encountered
		SELECT TOP 1 @PoolID = PoolID,
		@DateAvailable = DateAvailable
		FROM VistaDelayTransactions
		WHERE VehicleID = @VehicleID
		AND RecordStatus = 'Open'
		GOTO Do_Insert_VistaDelayTransactions
	END
	
	--update the vehicle status
	UPDATE Vehicle
	SET VehicleStatus = 'OnHold',
	AvailableForPickupDate = NULL
	WHERE VehicleID = @VehicleID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating Vehicle'
		GOTO Error_Encountered
	END
	
	--if we have a load id, remove the vehicle from the load
	IF @LoadID > 0
	BEGIN
		--remove the vehicle from the load
		SELECT @ReturnCode = 1
		EXEC spRemoveVehicleFromLoad @LegID, @LoadID, @DateEntered,
		@CreatedBy, @rReturnCode = @ReturnCode OUTPUT
		IF @ReturnCode <> 0
		BEGIN
			SELECT @ErrorID = @ReturnCode
			GOTO Error_Encountered
		END
		
		--removing the vehicle from the load will give the leg a poolid, so get that value
		SELECT TOP 1 @PoolID = PoolID
		FROM Legs
		WHERE LegsID = @LegID
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting Pool ID'
			GOTO Error_Encountered
		END
	END
	
	--if we have a pool id, reduce the pool size
	IF @PoolID IS NOT NULL
	BEGIN
		UPDATE VehiclePool
		SET PoolSize = PoolSize - 1,
		Available = Available - 1
		WHERE VehiclePoolID = @PoolID
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating Pool'
			GOTO Error_Encountered
		END
	END
	
	--update the leg status
	UPDATE Legs
	SET LegStatus = 'OnHold',
	DateAvailable = NULL,
	PoolID = NULL
	WHERE LegsID = @LegID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating Leg'
		GOTO Error_Encountered
	END
	--insert the delay record
	Do_Insert_VistaDelayTransactions:
	INSERT INTO VISTADelayTransactions(
		VehicleID,
		PoolID,
		DateAvailable,
		DelayCode,
		DelayEffectiveDate,
		DateEntered,
		EnteredBy,
		DelayReportedInd,
		DateDelayReported,
		DateReleased,
		ReleasedBy,
		ReleaseReportedInd,
		DateReleaseReported,
		RecordStatus,
		CreationDate,
		CreatedBy
	)
	VALUES(
		@VehicleID,
		@PoolID,
		@DateAvailable,
		@DelayCode,
		@DelayEffectiveDate,
		@DateEntered,
		@EnteredBy,
		@DelayReportedInd,
		@DateDelayReported,
		@DateReleased,
		@ReleasedBy,
		@ReleaseReportedInd,
		@DateReleaseReported,
		@RecordStatus,
		@CreationDate,
		@CreatedBy
	)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered creating Delay Record'
		GOTO Error_Encountered
	END
	
	INSERT INTO ActionHistory(
		RecordID,
		RecordTableName,
		ActionType,
		Comments,
		CreationDate,
		CreatedBy
	)
	VALUES
	(
		@VehicleID,
		'Vehicle',
		'Vista Vehicle Delay Transaction Added',
		'Vista Vehicle Delay ('+@DelayCode +')' + 'Added For VIN '+@VIN ,
		@CreationDate,
		@CreatedBy
	)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered creating Delay Record'
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
		SELECT @ReturnMessage = 'VISTA Delay Record Created Successfully'
	END

	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM'

	RETURN @ReturnCode
END

GO
