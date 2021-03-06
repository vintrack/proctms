USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenericVehicleImport]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenericVehicleImport] (@BatchID int,
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	@GenericVehicleImportID		int,
	@OrderNumber			varchar(20),
	@VIN				varchar(17),
	@CustomerIdentification		varchar(20),
	@BayLocation			varchar(20),
	@CustomerID			int,
	@FromLocationID			int,
	@FromCustomerLocationCode	varchar(20),
	@ToLocationID			int,
	@ToCustomerLocationCode		varchar(20),
	@SizeClass			varchar(1),
	@PONumber			varchar(20),
	@SpotBuyUnitInd			varchar(10),
	@ImportedInd			int,
	@VINCOUNT			int,
	@DestinationID			int,
	@OriginID			int,
	@ChargeRate			decimal(19,2),
	@MiscellaneousAdditive		decimal(19,2),
	@OrderID			int,
	@CustomerCode			varchar(70),
	@RecordStatus			varchar(100),
	@Status				varchar(100),
	@VehicleID			int,
	@VehicleDestinationID		int,
	@VehiclePoolID			int,
	@VehicleLoadID			int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@PoolRecordCount		int,
	@PoolID				int,
	@TotalOrderUnits		int,
	@TotalOrderChargeRate		decimal(19,2),
	@LegsCount			int,
	@DecodedColor			varchar(20),
	@VehicleYear			varchar(6), 
	@Make				varchar(50), 
	@Model				varchar(50),
	@Bodystyle			varchar(50),
	@VehicleLength			varchar(10),
	@VehicleWidth			varchar(10),
	@VehicleHeight			varchar(10),
	@VINDecodedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@LegID				int,
	@Result				int,
	@CreationDate			datetime,
	@VehicleOriginID		int,
	@OrderCount			int,
	@DateAvailable			datetime,
	@PreviousCustomerID		int,
	@PreviousOriginID		int,
	@PreviousDestinationID		int,
	@PreviousPONumber		varchar(20),
	@Count				int,
	@OrderNumberPlusOne		int
			
	
	/************************************************************************
	*	spGenericVehicleImport						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the Generic Vehicle Import	*
	*	table, creates the vehicle records and adds them to the		*
	*	specified order.						*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	02/21/2008 CMK    Initial version				*
	*									*
	************************************************************************/
	
	SELECT @CreationDate = CURRENT_TIMESTAMP
	--SELECT @DateAvailable = CONVERT(varchar(10),CURRENT_TIMESTAMP,101)

	DECLARE GenericVehicleImport CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT GenericVehicleImportID, OrderNumber, VIN, CustomerID, FromLocationID,
		FromCustomerLocationCode, ToLocationID, ToCustomerLocationCode, CustomerIdentification,
		BayLocation, SizeClass, PONumber, ISNULL(SpotBuyUnitInd,''), ImportedInd, VehicleYear, Make, Model, Bodystyle,
		VehicleLength, VehicleWidth, VehicleHeight, VINDecodedInd
		FROM GenericVehicleImport
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY OrderNumber, CustomerID, FromLocationID, FromCustomerLocationCode, ToLocationID, ToCustomerLocationCode

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN GenericVehicleImport

	BEGIN TRAN
	
	SELECT @PreviousCustomerID = 0
	SELECT @PreviousOriginID = 0
	SELECT @PreviousDestinationID = 0
	SELECT @PreviousPONumber = ''

	FETCH GenericVehicleImport INTO @GenericVehicleImportID, @OrderNumber, @VIN, @CustomerID, @FromLocationID,
		@FromCustomerLocationCode, @ToLocationID, @ToCustomerLocationCode, @CustomerIdentification,
		@BayLocation, @SizeClass, @PONumber, @SpotBuyUnitInd, @ImportedInd, @VehicleYear, @Make, @Model, @Bodystyle,
		@VehicleLength, @VehicleWidth, @VehicleHeight, @VINDecodedInd

	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF DATALENGTH(@OrderNumber) > 0
		BEGIN
			SELECT @OrderCount = COUNT(*)
			FROM Orders
			WHERE OrderNumber = @OrderNumber
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING ORDER COUNT'
				GOTO Error_Encountered
			END
			IF @OrderCount = 0
			BEGIN
				SELECT @RecordStatus = 'ORDER NOT FOUND'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Import_Record
			END
		
		
			SELECT @CustomerID = O.CustomerID, @OrderID = O.OrdersID,
			@OriginID = O.PickupLocation, @DestinationID = O.DropoffLocation,
			@DateAvailable = ISNULL(RequestedPickupDate,CONVERT(varchar(10),CURRENT_TIMESTAMP,101))
			FROM Orders O
			WHERE O.OrderNumber = @OrderNumber
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING ORDER DETAIL'
				GOTO Error_Encountered
			END
		END
		ELSE
		BEGIN
			SELECT @OriginID = NULL
			SELECT @DestinationID = NULL
			
			--get the origin
			IF @FromLocationID > 0
			BEGIN
				--validate that the origin is valid for the customer
				SELECT @Count = 0
				
				SELECT @Count = COUNT(*)
				FROM Location
				WHERE LocationID = @FromLocationID
				AND (ParentRecordID = @CustomerID
				OR ParentRecordTable = 'Common')
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR VALIDATING ORIGIN'
					GOTO Error_Encountered
				END
				IF @Count > 0
				BEGIN
					SELECT @OriginID = @FromLocationID
				END
				
				
			END
			ELSE IF DATALENGTH(@FromCustomerLocationCode) > 0
			BEGIN
				SELECT @OriginID = LocationID
				FROM Location
				WHERE ParentRecordID = @CustomerID
				AND ParentRecordTable = 'Customer'
				AND CustomerLocationCode = @FromCustomerLocationCode
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING ORIGIN LOCATION'
					GOTO Error_Encountered
				END
			END
			IF @OriginID IS NULL
			BEGIN
				SELECT @RecordStatus = 'ORIGIN NOT FOUND'
				GOTO Update_Import_Record
			END
			
			--get the destination
			IF @ToLocationID > 0
			BEGIN
				--validate that the origin is valid for the customer
				SELECT @Count = 0
				
				SELECT @Count = COUNT(*)
				FROM Location
				WHERE LocationID = @ToLocationID
				AND (ParentRecordID = @CustomerID
				OR ParentRecordTable = 'Common')
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR VALIDATING DESTINATION'
					GOTO Error_Encountered
				END
				IF @Count > 0
				BEGIN
					SELECT @DestinationID = @ToLocationID
				END
			END
			ELSE IF DATALENGTH(@ToCustomerLocationCode) > 0
			BEGIN
				--get the destination
				SELECT TOP 1 @DestinationID = LocationID
				FROM Location
				WHERE ParentRecordID = @CustomerID
				AND ParentRecordTable = 'Customer'
				AND CustomerLocationCode = @ToCustomerLocationCode
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
						@ToCustomerLocationCode,
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
			IF @DestinationID IS NULL
			BEGIN
				SELECT @RecordStatus = 'DESTINATION NOT FOUND'
				GOTO Update_Import_Record
			END
						
			
			SELECT @DateAvailable = CONVERT(varchar(10),CURRENT_TIMESTAMP,101)
			
			IF @CustomerID <> @PreviousCustomerID OR @OriginID <> @PreviousOriginID OR @DestinationID <> @PreviousDestinationID OR @PONumber <> @PreviousPONumber
			BEGIN
				--create the order
				
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
					@PONumber,	--PONumber,
					'Pending',	--OrderStatus,
					GetDate(),	--CreationDate,
					'CSX IMPORT',	--CreatedBy,
					NULL,		--UpdatedDate,
					NULL		--UpdatedBy
				)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error creating order'
					GOTO Error_Encountered
				END	
				--need to get the orderId key here, to insert into the vehicle record.			
				SELECT @OrderID = @@identity
			END
		END
		
		IF ISNULL(@SizeClass,'') = ''
		BEGIN
			SELECT @SizeClass = 'A'
		END
		
		SELECT @ChargeRate = NULL
		--From these values we can get the financial information.
		--Need to add logic to check size class. not in this particular file.
		SELECT @ChargeRate = Rate, @MiscellaneousAdditive = MiscellaneousAdditive
		FROM ChargeRate
		WHERE StartLocationID = @OriginID
		AND EndLocationID = @DestinationID
		AND CustomerID = @CustomerID
		AND RateType = 'Size '+@SizeClass+' Rate'
		AND @CreationDate >= StartDate
		AND @CreationDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
		
		IF @VehicleYear IS NULL OR DATALENGTH(@VehicleYear)<1
		BEGIN
			SELECT @VehicleYear = ''
		END
		IF @Make IS NULL OR DATALENGTH(@Make)<1
		BEGIN
			SELECT @Make = ''
		END
		IF @Model IS NULL OR DATALENGTH(@Model)<1
		BEGIN
			SELECT @Model = ''
		END
		IF @Bodystyle IS NULL OR DATALENGTH(@Bodystyle)<1
		BEGIN
			SELECT @Bodystyle = ''
		END
		IF @VehicleLength IS NULL OR DATALENGTH(@VehicleLength)<1
		BEGIN
			SELECT @VehicleLength = ''
		END
		IF @VehicleWidth IS NULL OR DATALENGTH(@VehicleWidth)<1
		BEGIN
			SELECT @VehicleWidth = ''
		END
		IF @VehicleHeight IS NULL OR DATALENGTH(@VehicleHeight)<1
		BEGIN
			SELECT @VehicleHeight = ''
		END
		IF @VINDecodedInd IS NULL OR DATALENGTH(@VINDecodedInd)<1
		BEGIN
			SELECT @VINDecodedInd = 0
		END
			
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
			IntoInventoryDate,
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
			PickupNotificationSentInd,
			STIDeliveryNotificationSentInd,
			BillOfLadingSentInd,
			DealerHoldOverrideInd,
			MiscellaneousAdditive,
			FuelSurcharge,
			AccessoriesCompleteInd,
			PDICompleteInd,
			FinalShipawayInspectionDoneInd,
			DateMadeAvailable,
			SpotBuyUnitInd
		)
		VALUES(
			@CustomerID,				--CustomerID,
			@OrderID,				--OrderID,
			@VehicleYear,				--VehicleYear,	
			@Make,					--Make,
			@Model,					--Model,
			@Bodystyle,				--Bodystyle,
			@VIN,					--VIN,
			'',					--Color,
			@VehicleLength,				--VehicleLength,
			@VehicleWidth,				--VehicleWidth,
			@VehicleHeight,				--VehicleHeight,
			@OriginID,				--PickupLocationID,
			@DestinationID,				--DropoffLocationID,
			'Available',				--VehicleStatus,
			'Pickup Point',				--VehicleLocation,
			@CustomerIdentification,		--CustomerIdentification,
			@SizeClass,				--SizeClass,
			@BayLocation,				--BayLocation,
			'',					--RailCarNumber,
			0,					--PriorityInd
			NULL,					--HaulType,
			@DateAvailable,				--AvailableForPickupDate,
			0,					--ShopWorkStartedInd,
			NULL,					--ShopWorkStartedDate,
			0,					--ShopWorkCompleteInd,
			NULL,					--ShopWorkCompleteDate,
			NULL,					--PaperworkReceivedDate,
			NULL,					--ICLAuditCode,
			NULL,	--IntoInventoryDate
			@ChargeRate,
			0,					--ChargeRateOverrideInd
			0,					--BilledInd,
			NULL,					--BilledDate,
			@VINDecodedInd,				--VINDecodedInd,
			'Active',				--RecordStatus,
			@CreationDate,				--CreationDate
			'IMPORT',				--CreatedBy
			NULL,					--UpdatedDate,
			NULL,					--UpdatedBy
			0,					--CreditHoldInd
			0,					--PickupNotificationSentInd
			0,					--STIDeliveryNotificationSentInd
			0,					--BillOfLadingSentInd
			0,					--DealerHoldOverrideInd
			@MiscellaneousAdditive,			--MiscellaneousAdditive
			0,					--FuelSurcharge
			0,					--AccessoriesCompleteInd,
			0,					--PDICompleteInd
			0,					--FinalShipawayInspectionDoneInd
			CURRENT_TIMESTAMP,			--DateMadeAvailable
			CASE WHEN @SpotBuyUnitInd IN ('1','Y','Yes') THEN 1 ELSE 0 END	--SpotBuyUnitInd
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR CREATING VEHICLE RECORD'
			GOTO Error_Encountered
		END

		SELECT @VehicleID = @@Identity
						
		--update the VehiclePool
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
				1,		--PoolSize
				0,		--Reserved
				1,		--Available
				@CreationDate,	--CreationDate
				'IMPORT'	--CreatedBy
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR CREATING POOL RECORD'
				GOTO Error_Encountered
			END
			SELECT @PoolID = @@Identity
		END
		ELSE
		BEGIN
			SELECT @PoolID = VehiclePoolID
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
			@VehicleID,	--VehicleID
			@PoolID,
			@DateAvailable,
			@OriginID,	--PickupLocationID
			@DestinationID,	--DropoffLocationID
			0,		--OutsideCarrierLegInd
			0,		--OutsideCarrierPaymentMethod
			0,		--OutsideCarrierPercentage
			0,		--OutsideCarrierPay
			0,		--OutsideCarrierFuelSurchargePercentage
			0,		--OCFSPEstablishedInd
			1,		--LegNumber
			1,		--FinalLegInd
			'Available',	--LegStatus
			0,		--ShagUnitInd
			@CreationDate,	--CreationDate
			'IMPORT',	--CreatedBy
			0		--OutsideCarrierFuelSurchargeType
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR CREATING DEFAULT LEG'
			GOTO Error_Encountered
		END
			
		--update the order
		UPDATE Orders
		SET Units = ISNULL(Units,0) + 1,
		OrderChargeRate = ISNULL(OrderChargeRate,0) + @ChargeRate
		WHERE OrdersID = @OrderID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR UPDATING ORDER TOTALS'
			GOTO Error_Encountered
		END
		
		print 'about to set record status'
		SELECT @RecordStatus = 'Imported'
		SELECT @ImportedInd = 1
		SELECT @ImportedDate = GetDate()
		SELECT @ImportedBy = @UserCode
		
		print 'at update import record'
		--update logic here.
		Update_Import_Record:
		UPDATE GenericVehicleImport
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE GenericVehicleImportID = @GenericVehicleImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END
		
		SELECT @PreviousCustomerID = @CustomerID
		SELECT @PreviousOriginID = @OriginID
		SELECT @PreviousDestinationID = @DestinationID
		SELECT @PreviousPONumber = @PONumber

		FETCH GenericVehicleImport INTO @GenericVehicleImportID, @OrderNumber, @VIN, @CustomerID, @FromLocationID,
		@FromCustomerLocationCode, @ToLocationID, @ToCustomerLocationCode, @CustomerIdentification,
		@BayLocation, @SizeClass, @PONumber, @SpotBuyUnitInd, @ImportedInd, @VehicleYear, @Make, @Model, @Bodystyle,
		@VehicleLength, @VehicleWidth, @VehicleHeight, @VINDecodedInd

	END --end of loop

	--save off the totals for the last order
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
		CLOSE GenericVehicleImport
		DEALLOCATE GenericVehicleImport
		PRINT 'GenericVehicleImport Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE GenericVehicleImport
		DEALLOCATE GenericVehicleImport
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			PRINT 'GenericVehicleImport Error_Encountered =' + STR(@ErrorID)
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
