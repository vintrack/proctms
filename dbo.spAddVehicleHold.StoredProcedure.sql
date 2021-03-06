USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spAddVehicleHold]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[spAddVehicleHold](
	@VehicleID		int,
	@HoldReason		varchar(100),
	@HoldEffectiveDate	datetime,
	@CreatedBy		varchar(20),
	@rReturnCode	int = 0 OUTPUT -- 0 = return result set, otherwise don't
	)
AS
BEGIN
	/************************************************************************
	*	spAddVehicleHold						*
	*									*
	*	Description							*
	*	-----------							*
	*	Creates a VehicleHold record and puts the vehicle on hold. 	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	05/17/2010 CMK    Initial version				*
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	@ChryslerCustomerID	int,
		@FordCustomerID		int,
		@SDCCustomerID		int,
		@VehicleCustomerID	int,
		@LegID			int,
		@LegStatus		varchar(20),
		@PoolID			int,
		@DateAvailable		datetime,
		@LoadID			int,
		@DateEntered		datetime,
		@EnteredBy		varchar(20),
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
	--print 'begin tran'
	--set the default values
	SELECT @DateEntered = CURRENT_TIMESTAMP
	SELECT @EnteredBy = @CreatedBy
	SELECT @RecordStatus = 'Open'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	--get the poolid and date available
	SELECT TOP 1 @VehicleCustomerID = V.CustomerID,@VIN=V.VIN,
	@LegID = L.LegsID,
	@LegStatus = L.LegStatus,
	@PoolID = L.PoolID,
	@DateAvailable = L.DateAvailable,
	@LoadID = L.LoadID
	FROM Legs L
	LEFT JOIN Vehicle V ON L.VehicleID = V.VehicleID
	WHERE L.VehicleID = @VehicleID
	AND L.LegNumber = 1
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting Pool ID'
		GOTO Error_Encountered
	END
	--print 'CustomerID = '+convert(varchar(20),@VehicleCustomerID)
	--print 'LegsID = '+convert(varchar(20),@LegID)
	--print 'LegStatus = '+@LegStatus
	--print 'PoolID = '+convert(varchar(20),@PoolID)
	--print 'DateAvailable = '+convert(varchar(10),@DateAvailable,101)
	--print 'LoadID = '+convert(varchar(20),@LoadID)
	
	--Chryslers must use VISTA Delay Transaction, make sure vehicle is not a Chrysler
	SELECT @ChryslerCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ChryslerCustomerID'
	IF @@ERROR <> 0
	BEGIN
		--print 'in get chrysler customer id error'
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting Chrysler Customer ID'
		GOTO Error_Encountered
	END
	
	IF @ChryslerCustomerID IS NULL
	BEGIN
		--print 'chrysler customer id is null'
		SELECT @ErrorID = 100000
		SELECT @Msg = 'Error Getting Chrysler Customer ID'
		GOTO Error_Encountered
	END
	
	IF @VehicleCustomerID = @ChryslerCustomerID
	BEGIN
		--print 'chrysler customer id = vehicle customer id'
		SELECT @ErrorID = 100001
		SELECT @Msg = 'Chrysler Holds MUST be entered through VISTA Delay Transactions!'
		GOTO Error_Encountered
	END
	
	--Fords must use Ford Delay Transaction, make sure vehicle is not a Ford
	SELECT @FordCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'FordCustomerID'
	IF @@ERROR <> 0
	BEGIN
		--print 'in get ford customer id error'
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting Ford Customer ID'
		GOTO Error_Encountered
	END
	
	IF @FordCustomerID IS NULL
	BEGIN
		--print 'ford customer id is null'
		SELECT @ErrorID = 100000
		SELECT @Msg = 'Error Getting Ford Customer ID'
		GOTO Error_Encountered
	END
	
	--Get the SDCCustomerID for VPC Vehicles
	SELECT @SDCCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SDCCustomerID'
	IF @@ERROR <> 0
	BEGIN
		--print 'in get sdc customer id error'
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting SDC Customer ID'
		GOTO Error_Encountered
	END
	
	IF @SDCCustomerID IS NULL
	BEGIN
		--print 'sdc customer id is null'
		SELECT @ErrorID = 100000
		SELECT @Msg = 'Error Getting SDC Customer ID'
		GOTO Error_Encountered
	END
	/*
	IF @VehicleCustomerID = @FordCustomerID
	BEGIN
		print 'ford customer id = vehicle customer id'
		SELECT @ErrorID = 100001
		SELECT @Msg = 'Ford Holds MUST be entered through Ford Delay Transactions!'
		GOTO Error_Encountered
	END
	*/
	
	IF @LegStatus IN ('EnRoute','Delivered')
	BEGIN
		--print 'in leg status in enroute/delivered'
		SELECT @ErrorID = 100002
		SELECT @Msg = 'Vehicle is '+@LegStatus+'. It cannot be put on hold at this time!'
		GOTO Error_Encountered
	END
	
	IF @LegStatus = 'Complete'
	BEGIN
		--print 'in leg status = complete'
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
			SELECT @ErrorID = 100003
			SELECT @Msg = 'Vehicle is not in the correct status. It cannot be put on hold at this time!'
			GOTO Error_Encountered
		END
	END
	
	--make sure that there is not already an open hold for the vehicle/Modified to accomodate multiple holds
	SELECT @Count = COUNT(*)
	FROM VehicleHolds
	WHERE VehicleID = @VehicleID
	AND RecordStatus = 'Open'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Getting Open Hold Count'
		GOTO Error_Encountered
	END
	--print 'hold count = '+convert(varchar(20),@count)
	IF @Count > 0
	BEGIN
		--SELECT @ErrorID = 100004
		--SELECT @Msg 'Open Hold already exists for vehicle!'
		--GOTO Error_Encountered
		SELECT TOP 1 @PoolID = PoolID,@DateAvailable=DateAvailable
		FROM VehicleHolds
		WHERE VehicleID = @VehicleID
		AND RecordStatus = 'Open'
		GOTO Do_Insert_VehicleHolds
	END
	
	--if we have a load id, remove the vehicle from the load
	IF ISNULL(@LoadID,0) > 0
	BEGIN
		--print 'in loadid > 0, about to remove vehicle from load'
		--remove the vehicle from the load
		SELECT @ReturnCode = 1
		EXEC spRemoveVehicleFromLoad @LegID, @LoadID, @DateEntered,
		@CreatedBy, @rReturnCode = @ReturnCode OUTPUT
		print 'after remove vehicle from load, return code = '+convert(varchar(20),@returncode)
		IF @ReturnCode <> 0
		BEGIN
			SELECT @ErrorID = @ReturnCode
			SELECT @Msg = 'Error Removing Vehicle From Load'
			GOTO Error_Encountered
		END
		--print 'about to get pool id'
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
		--print 'poolid = '+convert(varchar(20),@poolid)
	END
	
	--print 'updating vehicle'
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
	
	--if we have a pool id, reduce the pool size
	IF @PoolID IS NOT NULL
	BEGIN
		--print 'in poolid is not null'
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
	--print 'updating legs'
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
	
	--update the vpcvehicle record, if necessary
	IF @VehicleCustomerID = @SDCCustomerID
	BEGIN
		UPDATE VPCVehicle
		SET VehicleStatus = 'OnHold'
		WHERE SDCVehicleID = @VehicleID
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating VPCVehicle'
			GOTO Error_Encountered
		END
	END 
	--print 'inserting the vehicle hold record'
	--insert the hold record
	Do_Insert_VehicleHolds:
	INSERT INTO VehicleHolds(
		VehicleID,
		PoolID,
		DateAvailable,
		HoldReason,
		HoldEffectiveDate,
		DateEntered,
		EnteredBy,
		RecordStatus,
		CreationDate,
		CreatedBy
	)
	VALUES(
		@VehicleID,
		@PoolID,
		@DateAvailable,
		@HoldReason,
		@HoldEffectiveDate,
		@DateEntered,
		@EnteredBy,
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

	INSERT INTO ActionHistory (
		RecordID,
		RecordTableName,
		ActionType,
		Comments,
		CreationDate,
		CreatedBy
	)
	VALUES(
		@VehicleID,
		'Vehicle',
		'Vehicle Delay Transaction Added',
		'Vehicle DelayReason  ('+@HoldReason+ ')' + 'Added For VIN '+@VIN ,
		@CreationDate,
		@CreatedBy
	)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered creating Hold Record'
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
		SELECT @ReturnMessage = 'Vehicle Hold Record Created Successfully'
	END

	IF @rReturnCode = 0
	BEGIN
		SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM'
	END
		
	SET @rReturnCode = @ReturnCode
		
	RETURN @ReturnCode
END

GO
