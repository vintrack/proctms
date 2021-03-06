USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spCreateOrderForCSXRailheadFeedRecord]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spCreateOrderForCSXRailheadFeedRecord] (@CSXRailheadFeedImportID int,
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--CSXRailheadFeedImport table variables
	--@CSXRailheadFeedImportID	int,
	@ActionCode			varchar(10),
	@Railyard			varchar(6),
	@Railcar			varchar(10),
	@VIN				varchar(17),
	@Dealer				varchar(6),
	@Area1				varchar(6),
	@Area2				varchar(4),
	@BayLocation			varchar(7),
	@Manufacturer			varchar(10),
	@UnloadDate			datetime,
	@UnloadTime			varchar(6),
	@ImportedInd			int,
	@VehicleYear			varchar(6),
	@Make				varchar(50),
	@Model				varchar(50),
	@Bodystyle			varchar(50),
	@VehicleLength			varchar(10),
	@VehicleWidth			varchar(10),
	@VehicleHeight			varchar(10),
	@VINDecodedInd			int,
	@NewImportedInd			int,
	@VINCOUNT			int,
	@CustomerID			int,
	@AvailableInd			int,
	@ReleaseCode			varchar(10),
	@VehicleOriginID		int,
	@VehicleDestinationID		int,
	@VehiclePoolID			int,
	@OriginID			int,
	@DestinationID			int,
	@OrderID			int,
	@PoolID				int,
	@PlantCode			varchar(1),
	@VINSquish			varchar(10),
	@SizeClass			varchar(1),
	@CustomerCode			varchar(70),
	@TotalOrderUnits		int,
	@TotalOrderChargeRate		int,
	@PreviousOrigin			int,
	@PreviousDestination		int,
	@OrderNumber			int,
	@OrderNumberPlusOne		int,
	@Reserved			int,
	@Available			int,
	@PoolSize			int,
	@RecordStatus			varchar(100),
	@Status				varchar(100),
	@VehicleID			int,
	@Count				int,
	@ReturnCode			int,
	@PoolRecordCount		int,
	@CurrentLegStatus		varchar(20),
	@ChryslerCustomerID		int,
	@ReturnMessage			varchar(100),
	@DestinationCode		varchar(20),
	@ChargeRate			decimal(19,2),
	@CreationDate			datetime
	
	/************************************************************************
	*	spCreateOrderForCSXRailheadFeedRecord				*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the CSXRailheadFeedImport	*
	*	for the requested record id and creates an order for the	*
	*	vehicle.							*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/01/2011 CMK    Initial version				*
	*									*
	************************************************************************/
	
	
	SELECT @CreationDate = CURRENT_TIMESTAMP

	SELECT @ActionCode = ActionCode,
		@Railyard = Railyard,
		@Railcar = Railcar,
		@VIN = VIN,
		@Dealer = Dealer,
		@Area1 = Area1,
		@Area2 = Area2,
		@BayLocation = BayLocation,
		@Manufacturer = Manufacturer,
		@UnloadDate = UnloadDate,
		@UnloadTime = UnloadTime,
		@ImportedInd = ImportedInd,
		@VehicleYear = VehicleYear,
		@Make = Make,
		@Model = Model,
		@Bodystyle = Bodystyle,
		@VehicleLength = VehicleLength,
		@VehicleWidth = VehicleWidth,
		@VehicleHeight = VehicleHeight,
		@VINDecodedInd = VINDecodedInd
	FROM CSXRailheadFeedImport
	WHERE CSXRailheadFeedImportID = @CSXRailheadFeedImportID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'ERROR GETTING CHRYSLER CUSTOMERID'
		GOTO Error_Encountered2
	END
	
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	IF @ImportedInd = 1
	BEGIN
		SELECT @ErrorID = 100000
		SELECT @Status = 'RECORD ALREADY IMPORTED'
		GOTO Error_Encountered2
	END

	SELECT @ChryslerCustomerID = convert(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ChryslerCustomerID'
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'ERROR GETTING CHRYSLER CUSTOMERID'
		GOTO Error_Encountered2
	END
	
	SELECT @NewImportedInd = 0
	SELECT @RecordStatus = 'Import Pending'
		
	SELECT @CustomerID = NULL
		
	BEGIN TRAN

	SELECT @CustomerID = CONVERT(int,Value1),
	@AvailableInd = CONVERT(int,Value2)
	FROM Code
	WHERE CodeType = 'CSXRailCustomerCode'
	AND Code = @Manufacturer
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Customer ID From Code Table'
		GOTO Update_Record_Status
	END
	IF @CustomerID IS NULL
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Customer ID Not Found In Code Table'
		GOTO Update_Record_Status
	END
		
	SELECT @OriginID = NULL
	SELECT @DestinationID = NULL
		
	--get the Origin.
	SELECT @OriginID = CONVERT(int,Value1)
	FROM Code
	WHERE CodeType = 'CSXRailyardCode'
	AND Code = @Railyard
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'ERROR GETTING ORIGIN LOCATION'
		GOTO Error_Encountered
	END
	IF @OriginID IS NULL
	BEGIN
		SELECT @RecordStatus = 'Orig Cd '+@Railyard+' Not Found'
		GOTO Update_Record_Status
	END
			
	IF DATALENGTH(@Dealer) > 0
	BEGIN
		--get the destination
		SELECT TOP 1 @DestinationID = LocationID
		FROM Location
		WHERE ParentRecordID = @CustomerID
		AND ParentRecordTable = 'Customer'
		AND CustomerLocationCode = @Dealer
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR GETTING DESTINATION LOCATION'
			GOTO Error_Encountered
		END
			
		IF @DestinationID IS NULL
		BEGIN
			--NEW DESTINATION, SO CREATE A NEW LOCATION RECORD
			INSERT INTO Location(
				ParentRecordID,
				ParentRecordTable,
				LocationType,
				LocationName,
				CustomerLocationCode,
				AuctionPayOverrideInd,
				AuctionPayRate,
				FlatDeliveryPayInd,
				FlatDeliveryPayRate,
				MileagePayBoostOverrideInd,
				MileagePayBoost,
				RecordStatus,
				CreationDate,
				CreatedBy,
				DeliveryHoldInd,
				NightDropAllowedInd,
				STIAllowedInd,
				AssignedDealerInd,
				ShagPayAllowedInd,
				ShortHaulPaySchedule,
				NYBridgeAdditiveEligibleInd,
				HotDealerInd,
				DisableLoadBuildingInd,
				LocationHasInspectorsInd
			)
			VALUES(
				@CustomerID,
				'Customer',
				'DropoffLocation',
				'NEED LOCATION NAME',
				@Dealer,
				0,
				0,
				0,
				0,
				0,
				0,
				'Active',
				GetDate(),
				'CSX IMPORT',
				0,
				0,
				0,
				0,
				0,
				'A',			--ShortHaulPaySchedule,
				0,			--NYBridgeAdditiveEligibleInd
				0,			--HotDealerInd
				0,			--DisableLoadBuildingInd
				0			--LocationHasInspectorsInd
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR CREATING DESTINATION LOCATION'
				GOTO Error_Encountered
			END
			SELECT @DestinationID = @@Identity
		END
	END
	ELSE
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'DEALER CODE MISSING'
		GOTO Error_Encountered
	END
					
	IF @Manufacturer <> 'CHRYSLER'
	BEGIN
		SELECT @SizeClass = 'A'
		SELECT @ReleaseCode = ''
	END
	ELSE
	BEGIN			
		SELECT @PlantCode = SUBSTRING(@VIN,11,1)
		SELECT @VINSquish = SUBSTRING(@VIN,1,8)+SUBSTRING(@VIN,10,2)
		
		IF @PlantCode IN ('D','H','T','P','M','Z','0','7')
		BEGIN
			IF SUBSTRING(@Model,1,7) IN ('Journey', 'Cheroke', 'Stelvio') OR @VINSquish = '3C4PDDAGET'
			BEGIN
				SELECT @SizeClass = 'B'
			END
			ELSE
			BEGIN
				SELECT @SizeClass = 'A'
			END
		END
		ELSE IF @PlantCode IN ('B','C','R','W','L','6')
		BEGIN
			SELECT @SizeClass = 'B'
		END
		ELSE IF @PlantCode IN ('F','G','J','N','S','E')
		BEGIN
			SELECT @SizeClass = 'C'
		END
		ELSE
		BEGIN
			SELECT @SizeClass = NULL
		END
		SELECT @ReleaseCode = ''
	END		
		
	SELECT @ChargeRate = NULL
	--From these values we can get the financial information.
	SELECT @ChargeRate = Rate
	FROM ChargeRate
	WHERE StartLocationID = @OriginID
	AND EndLocationID = @DestinationID
	AND CustomerID = @CustomerID
	AND RateType = 'Size '+@SizeClass+' Rate'
	AND @UnloadDate >= StartDate
	AND @UnloadDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
			
	--create an order
	SELECT @TotalOrderUnits = 0
	SELECT @TotalOrderChargeRate = 0
	--get the next available order number from the app constants table.
	Select @OrderNumber = NextOrderNumber from ApplicationConstants
	
	--add one to it, so it can be updated.
	Select @OrderNumberPlusOne = @OrderNumber + 1			
		
	--now update the app constants table with the number + 1
	UPDATE ApplicationConstants
	Set NextOrderNumber = @OrderNumberPlusOne
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'ERROR UPDATING Application Constants'
		GOTO Error_Encountered
	END
	--logic for the insert of orders and vehicle
	INSERT ORDERS(
		CustomerID,
		OrderNumber,
		LoadType,
		CustomerChargeType,
		CarrierType,
		OutsideCarrierID,
		PricingInd,
		FixedChargeRateOverrideInd,
		FixedChargeRate,
		MileageChargeRateOverrideInd,
		MileageChargeRate,
		PerUnitChargeRate,
		OrderChargeRate,
		RequestedPickupDate,
		RequestedDeliveryDate,
		PickupLocation,
		DropoffLocation,
		Units,
		Mileage,
		SalespersonID,
		OutsideCarrierPaymentMethod,
		OutsideCarrierPercentage,
		OutsideCarrierPctOverrideInd,
		OutsideCarrierPay,
		PaymentMethod,
		InternalComment,
		DriverComment,
		PONumber,
		OrderStatus,
		CreationDate,
		CreatedBy,
		UpdatedDate,
		UpdatedBy
	)
	VALUES(
		@CustomerID,
		@OrderNumber,
		0,		--LoadType,
		0,		--CustomerChargeType,
		0,		--CarrierType,
		NULL,		--OutsideCarrierID,
		0,		--PricingInd,
		0,		--FixedChargeRateOverrideInd,
		0,		--FixedChargeRate,
		0,		--MileageChargeRateOverrideInd,
		0,		--MileageChargeRate,
		0,		--PerUnitChargeRate,
		0,		--OrderChargeRate,
		NULL,		--RequestedPickupDate,
		NULL,		--RequestedDeliveryDate,
		@OriginID,	--PickupLocation,
		@DestinationID,	--DropoffLocation,
		0,		--Units,
		0,		--Mileage,
		NULL,		--SalespersonID,
		0,		--OutsideCarrierPaymentMethod,
		0,		--OutsideCarrierPercentage,
		0,		--OutsideCarrierPctOverrideInd,
		0,		--OutsideCarrierPay,
		'Bill To Customer',	--PaymentMethod,
		NULL,		--InternalComment,
		NULL,		--DriverComment,
		NULL,		--PONumber,
		'Pending',	--OrderStatus,
		GetDate(),	--CreationDate,
		'CSX IMPORT',	--CreatedBy,
		NULL,		--UpdatedDate,
		NULL		--UpdatedBy
	)
		
	--need to get the orderId key here, to insert into the vehicle record.			
	SELECT @OrderID = @@identity
				
	--and now do the vehicle
	INSERT VEHICLE(
		CustomerID,
		OrderID,
		VehicleYear,
		Make,
		Model,
		Bodystyle,
		VIN,
		Color,
		VehicleLength,
		VehicleWidth,
		VehicleHeight,
		PickupLocationID,
		DropoffLocationID,
		VehicleStatus,
		VehicleLocation,
		CustomerIdentification,
		SizeClass,
		BayLocation,
		RailCarNumber,
		PriorityInd,
		HaulType,
		AvailableForPickupDate,
		ShopWorkStartedInd,
		ShopWorkStartedDate,
		ShopWorkCompleteInd,
		ShopWorkCompleteDate,
		PaperworkReceivedDate,
		ICLAuditCode,
		ChargeRate,
		ChargeRateOverrideInd,
		BilledInd,
		DateBilled,
		VINDecodedInd,
		RecordStatus,
		CreationDate,
		CreatedBy,
		UpdatedDate,
		UpdatedBy,
		CreditHoldInd,
		ReleaseCode,
		PickupNotificationSentInd,
		STIDeliveryNotificationSentInd,
		BillOfLadingSentInd,
		DealerHoldOverrideInd,
		MiscellaneousAdditive,
		FuelSurcharge,
		AccessoriesCompleteInd,
		PDICompleteInd,
		FinalShipawayInspectionDoneInd,
		DateMadeAvailable
	)
	VALUES(
		@CustomerID,			--CustomerID,
		@OrderID,			--OrderID,
		@VehicleYear,			--VehicleYear,
		@Make,				--Make,
		@Model,				--Model,
		@Bodystyle,			--Bodystyle,
		@VIN,				--VIN,
		NULL,				--Color,
		@VehicleLength,			--VehicleLength
		@VehicleWidth,			--VehicleWidth
		@VehicleHeight,			--VehicleHeight
		@OriginID,			--PickupLocationID,
		@DestinationID,			--DropoffLocationID,
		'Available',			--VehicleStatus,
		'Pickup Point',			--VehicleLocation,
		NULL,				--CustomerIdentification,
		@SizeClass,			--SizeClass,
		@BayLocation,			--BayLocation,
		@Railcar,			--RailCarNumber,
		0,				--PriorityInd
		NULL,				--HaulType,
		@UnloadDate,			--AvailableForPickupDate,
		0,				--ShopWorkStartedInd,
		NULL,				--ShopWorkStartedDate,
		0,				--ShopWorkCompleteInd,
		NULL,				--ShopWorkCompleteDate,
		NULL,				--PaperworkReceivedDate,
		NULL,				--ICLAuditCode,
		@ChargeRate,			--ChargeRate
		0,				--ChargeRateOverrideInd
		0,				--BilledInd
		NULL,				--DateBilled
		@VINDecodedInd,			--VINDecodedInd
		'Active',			--RecordStatus,
		GetDate(),			--CreationDate
		'CSX IMPORT',			--CreatedBy
		NULL,				--UpdatedDate,
		NULL,				--UpdatedBy
		0,				--CreditHoldInd
		@ReleaseCode,			--ReleaseCode
		0,				--PickupNotificationSentInd
		0,				--STIDeliveryNotificationSentInd
		0,				--BillOfLadingSentInd
		0,				--DealerHoldOverrideInd
		0,				--MiscellaneousAdditive
		0,				--FuelSurcharge,
		0,				--AccessoriesCompleteInd,
		0,				--PDICompleteInd
		0,				--FinalShipawayInspectionDoneInd
		CONVERT(varchar(10),@UnloadDate,101)+' '+LEFT(@UnloadTime,2)+':'+SUBSTRING(@UnloadTime,3,2)	--DateMadeAvailable
	)
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'ERROR CREATING VEHICLE RECORD'
		GOTO Error_Encountered
	END
			
	SELECT @VehicleID = @@Identity
	SELECT @TotalOrderUnits = @TotalOrderUnits + 1
	SELECT @TotalOrderChargeRate = @TotalOrderChargeRate + @ChargeRate
			
	--get the poolid
	SELECT @PoolRecordCount = 0
	SELECT @PoolRecordCount = Count(*)
	FROM VehiclePool
	WHERE CustomerID = @CustomerID
	AND OriginID = @OriginID
	AND DestinationID = @DestinationID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'ERROR GETTING POOL RECORD COUNT'
		GOTO Error_Encountered
	END
	IF @PoolRecordCount = 0	
	BEGIN
		--don't have pool, so add one
		INSERT INTO VehiclePool(
			OriginID,
			DestinationID,
			CustomerID,
			PoolSize,
			Reserved,
			Available,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@OriginID,
			@DestinationID,
			@CustomerID,
			0,		--PoolSize
			0,		--Reserved
			0,		--Available
			GetDate(),	--CreationDate
			'CSX IMPORT'	--CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR CREATING POOL RECORD'
			GOTO Error_Encountered
		END
		SELECT @PoolID = @@Identity
		SELECT @Reserved = 0
		SELECT @Available = 0
		SELECT @PoolSize = 0
	END
	ELSE
	BEGIN
		SELECT @PoolID = VehiclePoolID,
		@PoolSize = PoolSize,
		@Reserved = Reserved,
		@Available = Available
		FROM VehiclePool
		WHERE CustomerID = @CustomerID
		AND OriginID = @OriginID
		AND DestinationID = @DestinationID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR GETTING POOL ID'
			GOTO Error_Encountered
		END
	END
	--add one to the pool
	UPDATE VehiclePool
	SET PoolSize = PoolSize + 1,
	Available = Available + 1
	WHERE VehiclePoolID = @PoolID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'ERROR UPDATING POOL RECORD'
		GOTO Error_Encountered
	END
						
	-- now create the Legs record for the vehicle
	INSERT INTO Legs(
		VehicleID,
		PoolID,
		DateAvailable,
		PickupLocationID,
		DropoffLocationID,
		OutsideCarrierLegInd,
		OutsideCarrierPaymentMethod,
		OutsideCarrierPercentage,
		OutsideCarrierPay,
		OutsideCarrierFuelSurchargePercentage,
		OCFSPEstablishedInd,
		LegNumber,
		FinalLegInd,
		LegStatus,
		ShagUnitInd,
		CreationDate,
		CreatedBy,
		OutsideCarrierFuelSurchargeType
	)
	VALUES(
		@VehicleID,
		@PoolID,
		@UnloadDate,
		@OriginID,
		@DestinationID,
		0, 		--OutsideCarrierLegInd
		0, 		--OutsideCarrierPaymentMethod
		0, 		--OutsideCarrierPercentage
		0, 		--OutsideCarrierPay
		0,		--OutsideCarrierFuelSurchargePercentage
		0,		--OCFSPEstablishedInd
		1, 		--LegNumber
		1, 		--FinalLegInd
		'Available',	--LegStatus
		0,
		GetDate(), 	--CreationDate
		'CSX IMPORT', 	--CreatedBy
		0		--OutsideCarrierFuelSurchargeType
	)
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'ERROR CREATING DEFAULT LEG'
		GOTO Error_Encountered
	END
	SELECT @RecordStatus = 'VEHICLE CREATED'
	SELECT @NewImportedInd = 1
	
	--update logic here.
	Update_Record_Status:
	UPDATE CSXRailheadFeedImport
	SET RecordStatus = @RecordStatus,
	ImportedInd = @NewImportedind,
	ImportedDate = CASE WHEN @NewImportedInd = 1 THEN GetDate() ELSE NULL END,
	ImportedBy = CASE WHEN @NewImportedInd = 1 THEN @UserCode ELSE NULL END
	WHERE CSXRailheadFeedImportID = @CSXRailheadFeedImportID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error setting Imported status'
		GOTO Error_Encountered
	END
		
	IF @OrderID IS NOT NULL
	BEGIN
		UPDATE Orders
		SET Units = @TotalOrderUnits,
		OrderChargeRate = @TotalOrderChargeRate
		WHERE OrdersID = @OrderID
	END
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		PRINT 'ImportRailheadFeed Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
	BEGIN
		PRINT 'ImportRailheadFeed Error_Encountered =' + STR(@ErrorID)
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
