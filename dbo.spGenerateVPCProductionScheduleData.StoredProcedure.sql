USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateVPCProductionScheduleData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateVPCProductionScheduleData] (@ScheduleDate datetime)
AS
BEGIN
	set nocount on

	DECLARE
	@VPCProductionScheduleID	int,
	@TotalUnits			int,
	@Unprocessed			int,
	@ThroughThrowInToday		int,
	@InProcess			int,
	@PDIStage			int,
	@AccessoryStage			int,
	@PDIScheduler			int,
	@CompleteToday			int,
	@Complete			int,
	@Shipped			int,
	@SDCInventory			int,
	@SOAInventory			int,
	@InboundedNotReceived		int,
	@DealerStorage			int,
	@CompleteDealerStorage		int,
	@CompleteDealerStorageToday	int,
	@CreationDate			datetime,
	@CreatedBy			int,
	@UpdatedDate			datetime,
	@UpdatedBy			varchar(20),
	@SOACustomerID			int,
	@SDCCustomerID			int,
	@ErrorID			int,
	@ErrorEncountered		varchar(5000),
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@Status				varchar(100)
	
	/************************************************************************
	*	spGenerateVPCProductionScheduleData				*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the ImportI73 table and 	*
	*	creates the new orders and vehicle records.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	07/20/2004 CMK    Initial version				*
	*	11/10/2004 CMK    Moved ShagUnitInd from Vehicle to Leg		*
	*	08/19/2005 CMK    Added lookup for vehicle record added by phone*
	*	12/02/2005 CMK    Changed VIN found code to update status and 	*
	*	                  not update any vehicle, leg or pool records	*
	*  11/19/2017  SS	  AND Loadnumber NOT LIKE ('D%')
		
	************************************************************************/
	
	--get the SOA customer id from the setting table
	SELECT @SOACustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE Valuekey = 'SOACustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting SOA CustomerID'
		GOTO Error_Encountered
	END
	IF @SOACustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'SOA CustomerID Not Found'
		GOTO Error_Encountered
	END

	--get the SDC customer id from the setting table
	SELECT @SDCCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE Valuekey = 'SDCCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting SDC CustomerID'
		GOTO Error_Encountered
	END
	IF @SDCCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Status = 'SDC CustomerID Not Found'
		GOTO Error_Encountered
	END

	--see if we already have a VPC Production Schedule record to update
	SELECT TOP 1 @VPCProductionScheduleID = VPCProductionScheduleID
	FROM VPCProductionSchedule
	WHERE ScheduleDate = @ScheduleDate
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Schedule Record'
		GOTO Error_Encountered
	END
	
	-- get the total unit count
	/*
	SELECT @TotalUnits = COUNT(*)
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	WHERE V.CustomerID = @SDCCustomerID
	AND L.LegStatus NOT IN ('Complete','EnRoute', 'Delivered')
	AND V.PickupLocationID = (SELECT CONVERT(int,ValueDescription) FROM SettingTable WHERE ValueKey = 'SDCDiversifiedLocationID')
	*/
	SELECT @TotalUnits = COUNT(*)
	FROM VPCVehicle V
	WHERE V.ReleaseDate IS NOT NULL
	AND V.DateOut IS NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Total Units'
		GOTO Error_Encountered
	END
	
	-- get the in unprocessed count
	/*SELECT @Unprocessed = COUNT(*)
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	WHERE V.CustomerID = @SDCCustomerID
	AND V.ShopWorkStartedInd = 0
	AND V.ShopWorkCompleteInd = 0
	AND L.LegStatus NOT IN ('Complete','EnRoute', 'Delivered')
	AND V.PickupLocationID = (SELECT CONVERT(int,ValueDescription) FROM SettingTable WHERE ValueKey = 'SDCDiversifiedLocationID')
	*/
	SELECT @Unprocessed = COUNT(*)
	FROM VPCVehicle V
	WHERE V.ShopWorkStartedInd = 0
	AND V.ShopWorkCompleteInd = 0
	AND V.ReleaseDate IS NOT NULL
	AND V.DateOut IS NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Unprocessed Units'
		GOTO Error_Encountered
	END
	
	-- get the throw in today count
	/*
	SELECT @ThroughThrowInToday = COUNT(*)
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	WHERE V.CustomerID = @SDCCustomerID
	AND V.ShopWorkStartedInd = 1
	AND CONVERT(varchar(10),V.ShopWorkStartedDate,101) = CONVERT(varchar(10),@ScheduleDate,101)
	*/
	SELECT @ThroughThrowInToday = COUNT(*)
	FROM VPCVehicle V
	WHERE V.ShopWorkStartedInd = 1
	AND V.ShopWorkStartedDate >= CONVERT(varchar(10),@ScheduleDate,101)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Throw In Today Units'
		GOTO Error_Encountered
	END
	
	-- get the in process count
	/*SELECT @InProcess = COUNT(*)
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	WHERE V.CustomerID = @SDCCustomerID
	AND V.ShopWorkStartedInd = 1
	AND V.ShopWorkCompleteInd = 0
	AND L.LegStatus NOT IN ('Complete','EnRoute', 'Delivered')
	*/
	SELECT @InProcess = COUNT(*)
	FROM VPCVehicle V
	WHERE V.ShopWorkStartedInd = 1
	AND V.ShopWorkCompleteInd = 0
	AND V.DateOut IS NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting In Process Units'
		GOTO Error_Encountered
	END
	
	-- get the pdi stage count
	SELECT @PDIStage = 0
	
	-- get the accessory stage count
	SELECT @AccessoryStage = 0
	
	-- get the pdi scheduler count
	SELECT @PDIScheduler = COUNT(*)
	FROM VPCVehicle V
	WHERE V.PDICompleteInd = 1
	AND CONVERT(varchar(10),V.PDICompleteDate,101) = CONVERT(varchar(10),@ScheduleDate,101)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Complete Today Units'
		GOTO Error_Encountered
	END
		
	-- get the complete today count
	/*
	SELECT @CompleteToday = COUNT(*)
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	WHERE V.CustomerID = @SDCCustomerID
	AND V.ShopWorkCompleteInd = 1
	AND CONVERT(varchar(10),V.ShopWorkCompleteDate,101) = CONVERT(varchar(10),@ScheduleDate,101)
	*/
	SELECT @CompleteToday = COUNT(*)
	FROM VPCVehicle V
	WHERE V.ShopWorkCompleteInd = 1
	AND V.ShopWorkCompleteDate >= CONVERT(varchar(10),@ScheduleDate,101)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Complete Today Units'
		GOTO Error_Encountered
	END
	
	-- get the complete count
	/*
	SELECT @Complete = COUNT(*)
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	WHERE V.CustomerID = @SDCCustomerID
	AND V.ShopWorkCompleteInd = 1
	AND L.LegStatus NOT IN ('Complete','EnRoute', 'Delivered')
	*/
	
	/**  Modified  on 11/19/2017*/

	SELECT @Complete = COUNT(*)
	FROM VPCVehicle V
	WHERE V.ShopWorkCompleteInd = 1
	AND V.DateOut IS NULL
	AND Loadnumber NOT LIKE ('D%')

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Complete Units'
		GOTO Error_Encountered
	END
	
	-- get the shipped today count
	/*
	SELECT @Shipped = COUNT(*)
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	WHERE V.CustomerID = @SDCCustomerID
	AND V.ShopWorkCompleteInd = 1
	AND CONVERT(varchar(10),L.PickupDate,101) = CONVERT(varchar(10),@ScheduleDate,101)
	AND L.LegStatus IN ('Complete','EnRoute', 'Delivered')
	*/
	SELECT @Shipped = COUNT(*)
	FROM VPCVehicle V
	WHERE V.ShopWorkCompleteInd = 1
	AND V.DateOut >= CONVERT(varchar(10),@ScheduleDate,101)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Shipped Units'
		GOTO Error_Encountered
	END
	
	-- get the sdc inventory count
	SELECT @SDCInventory = COUNT(*)
	FROM VPCVehicle V
	WHERE V.DateIn IS NOT NULL
	AND V.ReleaseDate IS NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting SDC Inventory Count'
		GOTO Error_Encountered
	END
	
	--  get the soa inventory count
	/*
	SELECT @SOAInventory = COUNT(*)
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	WHERE V.CustomerID = @SOACustomerID
	AND L.LegStatus NOT IN ('Complete','EnRoute', 'Delivered')
	AND L.DateAvailable IS NOT NULL
	AND L.LegNumber = 1
	AND L.dropofflocationid = 11776
	*/
	SELECT @SOAInventory = COUNT(*)
	FROM Vehicle V
	WHERE V.CustomerID = 3495
	AND V.DropoffLocationID = 11776
	AND V.VehicleStatus NOT IN ('Pending','EnRoute','Delivered')
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting SOA Inventory Units'
		GOTO Error_Encountered
	END
	
	-- get the inbounded not received count
	SELECT @InboundedNotReceived = COUNT(*)
	FROM VPCVehicle VV
	LEFT JOIN Vehicle V ON VV.SOAVehicleID = V.VehicleID
	WHERE V.VehicleStatus = 'Delivered'
	AND VV.DateIn IS NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Inbounded Not Received Count'
		GOTO Error_Encountered
	END
	
	-- get the Dealer Storage, Complete Dealer Storage Count and DealerStorageCompleteToday Count
	/*
	SELECT @DealerStorage = COUNT(*), @CompleteDealerStorage = SUM(ShopWorkCompleteInd),
	CASE WHEN 
	FROM Loads L
	LEFT JOIN Legs L2 ON L.LoadsID = L2.LoadID
	LEFT JOIN Vehicle V ON L2.VehicleID = V.VehicleID
	WHERE L.CustomerLoadNumber LIKE 'D%'
	AND V.VehicleID IS NOT NULL
	*/
	SELECT @DealerStorage = COUNT(*), @CompleteDealerStorage = SUM(ShopWorkCompleteInd),
	@CompleteDealerStorageToday = SUM(CASE WHEN ShopWorkCompleteInd = 1 AND CONVERT(varchar(10),ShopWorkCompleteDate,101) = CONVERT(varchar(10),@ScheduleDate,101) THEN 1 ELSE 0 END)
	FROM VPCVehicle
	WHERE LoadNumber LIKE 'D%'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting SOA Inventory Units'
		GOTO Error_Encountered
	END
	
	IF @VPCProductionScheduleID IS NOT NULL
	BEGIN	
		--update the VPCProductionSchedule record
		UPDATE VPCProductionSchedule
		SET TotalUnits = @TotalUnits,
		Unprocessed = @Unprocessed,
		ThroughThrowInToday = @ThroughThrowInToday,
		InProcess = @InProcess,
		PDIScheduler = @PDIScheduler,
		CompleteToday = @CompleteToday,
		Complete = @Complete,
		Shipped = @Shipped,
		SOAInventory = @SOAInventory,
		UpdatedDate = GetDate(),
		UpdatedBy = 'Nightly',
		DealerStorage = @DealerStorage,
		CompleteDealerStorage = @CompleteDealerStorage,
		SDCInventory = @SDCInventory,
		InboundedNotReceived = @InboundedNotReceived
		WHERE VPCProductionScheduleID = @VPCProductionScheduleID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
			GOTO Error_Encountered
		END
	END
	ELSE
	BEGIN
		--create the VPCProductionSchedule record
		INSERT VPCProductionSchedule(
			ScheduleDate,
			TotalUnits,
			Unprocessed,
			ThroughThrowInToday,
			InProcess,
			PDIStage,
			AccessoryStage,
			PDIScheduler,
			CompleteToday,
			Complete,
			Shipped,
			SOAInventory,
			CreationDate,
			CreatedBy,
			DealerStorage,
			CompleteDealerStorage,
			CompleteDealerStorageToday,
			SDCInventory,
			InboundedNotReceived
		)
		VALUES(
			@ScheduleDate,
			@TotalUnits,
			@Unprocessed,
			@ThroughThrowInToday,
			@InProcess,
			@PDIStage,
			@AccessoryStage,
			@PDIScheduler,
			@CompleteToday,
			@Complete,
			@Shipped,
			@SOAInventory,
			GetDate(),		--@CreationDate,
			'Nightly',		--@CreatedBy
			@DealerStorage,
			@CompleteDealerStorage,
			@CompleteDealerStorageToday,
			@SDCInventory,
			@InboundedNotReceived
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR CREATING VEHICLE RECORD'
			GOTO Error_Encountered
		END
	END
	
	SELECT @ErrorID = 0

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		PRINT 'GenerateVPCProductionScheduleData Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Do_Return:
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage

	RETURN
END
GO
