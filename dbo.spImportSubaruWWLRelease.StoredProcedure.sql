USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportSubaruWWLRelease]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportSubaruWWLRelease] (@BatchID int,
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	@SubaruWWLReleaseImportID	int,
	@VIN				varchar(20),
	@Destination			varchar(15),
	@CarrierCode			varchar(5),
	@ReleaseDate			datetime,
	@Origin				varchar(10),
	@BayLocation			varchar(6),
	@SoldOrderIndicator		varchar(1),
	@ImportedInd			int,
	@VINCOUNT			int,
	@DestinationID			int,
	@OriginID			int,
	@ChargeRate			decimal(19,2),
	@CustomerID			int,
	@OrderID			int,
	@CustomerCode			varchar(70),
	@PreviousOrigin			int,
	@PreviousDestination		int,
	@OrderNumber			int,
	@RecordStatus			varchar(100),
	@Status				varchar(100),
	@OrderNumberPlusOne		int,
	@VehicleID			int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@TotalOrderUnits		int,
	@TotalOrderChargeRate		decimal(19,2),
	@LegsCount			int,
	@SOADiversifiedLocationID	int,
	@SOADiversifiedLocationCode	varchar(20),
	@ShopWorkStartedInd		int,
	@ShopWorkCompleteInd		int,
	@PriorityInd			int,
	@DecodedColor			varchar(20),
	@VehicleYear			varchar(6), 
	@Make				varchar(50), 
	@Model				varchar(50),
	@Bodystyle			varchar(50),
	@VehicleLength			varchar(10),
	@VehicleWidth			varchar(10),
	@VehicleHeight			varchar(10),
	@VINDecodedInd			int,
	@ImportError			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@VehicleOriginID		int,
	@CreationDate			datetime,
	@VehicleDestinationID		int,
	@VehicleBayLocation		varchar(20),
	@PoolRecordCount		int,
	@PoolID				int

	/************************************************************************
	*	spImportSubaruWWLRelease					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the SubaruWWLRelease import	*
	*	table and creates the new orders and vehicle records.		*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	05/30/2008 CMK    Initial version				*
	*	01/27/2016 CMK    WidenedBayLocation, Added SoldOrderIndicator	*
	*									*
	************************************************************************/
	SELECT @PreviousOrigin = 0
	SELECT @PreviousDestination = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP

	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SOACustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting CustomerID'
		GOTO Error_Encountered2
	END
	IF @CustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'CustomerID Not Found'
		GOTO Error_Encountered2
	END

	SELECT @SOADiversifiedLocationID = CONVERT(int,Value1),
	@SOADiversifiedLocationCode = Code
	FROM Code
	WHERE CodeType = 'SOALocationCode'
	AND Value2 = 'DAI'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting SOADiversifiedLocationID'
		GOTO Error_Encountered2
	END
	IF @CustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'CustomerID Not Found'
		GOTO Error_Encountered2
	END

	DECLARE SubaruWWLReleaseImportCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT SubaruWWLReleaseImportID, VIN, Destination, CarrierCode,
		ReleaseDate, OriginLocation, BayLocation,
		VehicleYear, Make, Model, Bodystyle, VehicleLength, VehicleWidth,
		VehicleHeight, VINDecodedInd
		FROM SubaruWWLReleaseImport
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY OriginLocation, Destination, SubaruWWLReleaseImportID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN SubaruWWLReleaseImportCursor

	BEGIN TRAN

	FETCH SubaruWWLReleaseImportCursor into @SubaruWWLReleaseImportID, @VIN, @Destination,
		@CarrierCode, @ReleaseDate, @Origin, @BayLocation,
		@VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength, @VehicleWidth,
		@VehicleHeight, @VINDecodedInd

	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @ImportedInd = 0
		SELECT @DestinationID = NULL
		SELECT @ImportError = 0
		--get the destination
		IF @Destination = @SOADiversifiedLocationCode
		BEGIN
			SELECT @DestinationID = @SOADiversifiedLocationID
			SELECT @ShopWorkStartedInd = 0
			SELECT @ShopWorkCompleteInd = 0
		END
		ELSE
		BEGIN
			--courtesy delivery
			SELECT @ShopWorkStartedInd = 1
			SELECT @ShopWorkCompleteInd = 1
			
			SELECT @DestinationID = LocationID
			FROM Location
			WHERE ParentRecordID = @CustomerID
			AND ParentRecordTable = 'Customer'
			AND CustomerLocationCode = @Destination
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
					@Destination,
					0,
					0,
					0,
					0,
					0,
					0,
					'Active',
					GetDate(),
					'IMPORT',
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
		--get the Origin.
		SELECT @OriginID = NULL
		SELECT @OriginID = CONVERT(int,Value1)
		FROM Code
		WHERE CodeType = 'SOALocationCode'
		AND Code = @Origin
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR GETTING ORIGIN LOCATION'
			GOTO Error_Encountered
		END

		IF @OriginID IS NULL
		BEGIN
			SELECT @ImportError = 0
			SELECT @RecordStatus = 'Orig Cd '+@Origin+' Not Found'
			GOTO Update_Import_Record
		END

		SELECT @ChargeRate = NULL
		--From these values we can get the financial information.
		--Need to add logic to check size class. not in this particular file.
		SELECT @ChargeRate = Rate
		FROM ChargeRate
		WHERE StartLocationID = @OriginID
		AND EndLocationID = @DestinationID
		AND CustomerID = @CustomerID
		AND RateType = 'Size A Rate' -- for now
		AND @CreationDate >= StartDate
		AND @CreationDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
		
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM Vehicle
		WHERE VIN = @VIN
		AND CustomerID = @CustomerID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error getting vin count'
			GOTO Error_Encountered
		END

		IF @VINCOUNT > 0
		BEGIN
			--see if there are any changes to the origin/destination
			SELECT TOP 1 @VehicleID = V.VehicleID,
			@VehicleOriginID = V.PickupLocationID,
			@VehicleDestinationID = V.DropoffLocationID,
			@VehicleBayLocation = ISNULL(V.BayLocation,'')
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			WHERE V.VIN = @VIN
			AND V.CustomerID = @CustomerID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING VEHICLE STATUS'
				GOTO Error_Encountered
			END
			
			-- check the origin/destination
			IF @OriginID <> @VehicleOriginID
			BEGIN
				SELECT @RecordStatus = 'ORIGIN MISMATCH'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
			END
			ELSE IF @DestinationID <> @VehicleDestinationID
			BEGIN
				SELECT @RecordStatus = 'DESTINATION MISMATCH'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
			END
			ELSE IF @BayLocation <> @VehicleBayLocation
			BEGIN
				UPDATE Vehicle
				SET BayLocation = @BayLocation
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING BAY LOCATION'
					GOTO Error_Encountered
				END
				SELECT @RecordStatus = 'Bay Location Updated'
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = @CreationDate
				SELECT @ImportedBy = @UserCode
			END
			ELSE
			BEGIN
				SELECT @RecordStatus = 'VIN ALREADY EXISTS'
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
			END
		END
		ELSE
		BEGIN
			--only insert an order record for the ones with different origin and destination values
			IF @OriginID <> @PreviousOrigin OR @DestinationID <> @PreviousDestination
			BEGIN

				--if @orderid is not null, then save the totals off to the order before creating the new one
				IF @OrderID IS NOT NULL
				BEGIN
					UPDATE Orders
					SET Units = @TotalOrderUnits,
					OrderChargeRate = @TotalOrderChargeRate
					WHERE OrdersID = @OrderID
				END
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
					@CreationDate,	--CreationDate,
					'IMPORT',	--CreatedBy,
					NULL,		--UpdatedDate,
					NULL		--UpdatedBy
				)

				--need to get the orderId key here, to insert into the vehicle record.			
				SELECT @OrderID = @@identity
			END

			--and now do the vehicle
			IF @SOADiversifiedLocationID = @DestinationID
			BEGIN
				SELECT @PriorityInd = 0
			END
			ELSE
			BEGIN
				SELECT @PriorityInd = 1
			END
				
			IF @VehicleYear IS NULL OR DATALENGTH(@VehicleYear)<1
			BEGIN
				SELECT @VehicleYear = ''
			END
			SELECT @DecodedColor = ''
			IF @Make IS NULL OR DATALENGTH(@Make)<1
			BEGIN
				SELECT @Make = 'Subaru'
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
				FinalShipawayInspectionDoneInd
			)
			VALUES(
				@CustomerID,			--CustomerID,
				@OrderID,			--OrderID,
				@VehicleYear,			--VehicleYear,
				@Make,				--Make,
				@Model,				--Model,
				@Bodystyle,			--Bodystyle,
				@VIN,				--VIN,
				@DecodedColor,			--Color,
				@VehicleLength,			--VehicleLength
				@VehicleWidth,			--VehicleWidth
				@VehicleHeight,			--VehicleHeight
				@OriginID,			--PickupLocationID,
				@DestinationID,			--DropoffLocationID,
				'Available',			--VehicleStatus,
				'Pickup Point',			--VehicleLocation,
				NULL,				--CustomerIdentification,
				'A',				--SizeClass,
				@BayLocation,			--BayLocation,
				'',				--RailCarNumber,
				@PriorityInd,			--PriorityInd
				NULL,				--HaulType,
				@ReleaseDate,			--AvailableForPickupDate,
				@ShopWorkStartedInd,		--ShopWorkStartedInd,
				NULL,				--ShopWorkStartedDate,
				@ShopWorkCompleteInd,		--ShopWorkCompleteInd,
				NULL,				--ShopWorkCompleteDate,
				NULL,				--PaperworkReceivedDate,
				NULL,				--ICLAuditCode,
				@ChargeRate,			--ChargeRate
				0,				--ChargeRateOverrideInd
				0,				--BilledInd
				NULL,				--DateBilled
				@VINDecodedInd,			--VINDecodedInd
				'Active',			--RecordStatus,
				@CreationDate,			--CreationDate
				'IMPORT',			--CreatedBy
				NULL,				--UpdatedDate,
				NULL,				--UpdatedBy
				0,				--CreditHoldInd
				0,				--PickupNotificationSentInd
				0,				--STIDeliveryNotificationSentInd
				0,				--BillOfLadingSentInd
				0,				--DealerHoldOverrideInd
				0,				--MiscellaneousAdditive
				0,				--FuelSurcharge
				0,				--AccessoriesCompleteInd,
				0,				--PDICompleteInd
				0				--FinalShipawayInspectionDoneInd
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

			--need to save off the previous destination and orign.
			--get the destination.
			Select @PreviousDestination = @DestinationID

			--get the Origin.
			Select @PreviousOrigin = @OriginID

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
					'RAIL IMPORT'	--CreatedBy
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
				@VehicleID,
				@PoolID,
				@ReleaseDate,
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
				'Available',
				0,
				@CreationDate, 	--CreationDate
				'IMPORT', 	--CreatedBy
				0		--OutsideCarrierFuelSurchargeType
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR CREATING DEFAULT LEG'
				GOTO Error_Encountered
			END
			SELECT @RecordStatus = 'Imported'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = GetDate()
			SELECT @ImportedBy = @UserCode
		END

		--update logic here.
		Update_Import_Record:
		UPDATE SubaruWWLReleaseImport
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE SubaruWWLReleaseImportID = @SubaruWWLReleaseImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END
		
		FETCH SubaruWWLReleaseImportCursor into @SubaruWWLReleaseImportID, @VIN, @Destination, 
			@CarrierCode, @ReleaseDate, @Origin, @BayLocation,
			@VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength, @VehicleWidth,
			@VehicleHeight, @VINDecodedInd

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
		CLOSE SubaruWWLReleaseImportCursor
		DEALLOCATE SubaruWWLReleaseImportCursor
		PRINT 'Subaru WWL Release Import Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE SubaruWWLReleaseImportCursor
		DEALLOCATE SubaruWWLReleaseImportCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			PRINT 'Subaru WWL Release Import Error_Encountered =' + STR(@ErrorID)
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
