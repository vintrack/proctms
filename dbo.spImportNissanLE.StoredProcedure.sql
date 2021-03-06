USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportNissanLE]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROC [dbo].[spImportNissanLE] (@BatchID int,
	@UserCode varchar(20)) 
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	@ErrorEncountered	varchar(5000),
	@loopcounter		int,
	@NissanImportLEID	int,
	@Status			varchar(100),
	@VIN			varchar(20),
	@D6			varchar(15),
	@ModelLine		varchar(5),
	@ColorCode		varchar(5),
	@ShipDealer		varchar(5),
	@SellDealer		varchar(20),
	@PriorityCode		varchar(6),
	@MustShip		varchar(10),
	@DealerMemo		varchar(10),
	@LoadEligible		varchar(5),
	@RailcarNumber		varchar(6),
	@RailcarLoadDate	varchar(10),
	@ModelCode		varchar(5),
	@RateClass		varchar(15),
	@ImportedInd		int,
	@Header			varchar(50),
	@VINCOUNT		int,
	@DestinationLocation	varchar(20),
	@OriginID		int,
	@DestinationID		int,
	@ChargeRate		decimal(19,2),
	@CustomerID		int,
	@OrderID		int,
	@CustomerCode		varchar(70),
	@PreviousOrigin		int,
	@PreviousDestination	int,
	@OrderNumber		int,
	@RecordStatus		varchar (50),
	@OrderNumberPlusOne	int,
	@OriginLocation		varchar(20),
	@VehicleStatus		varchar(20),
	@DropDealer		varchar(100),
	@DropAddress		varchar(30),
	@DropCity		varchar(20),
	@DropState		varchar(2),
	@DropZip		varchar(15),
	@VehicleID		int,
	@ReturnCode		int,
	@ReturnMessage		varchar(100),
	@PoolRecordCount	int,
	@PoolID			int,
	@TotalOrderUnits	int,
	@TotalOrderChargeRate	decimal(19,2),
	@LegsCount		int,
	@VehicleYear		varchar(6), 
	@Make			varchar(50), 
	@Model			varchar(50),
	@Bodystyle		varchar(50),
	@VehicleLength		varchar(10),
	@VehicleWidth		varchar(10),
	@VehicleHeight		varchar(10),
	@VINDecodedInd		int

	/************************************************************************
	*	spImportNissanLE						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the NissanLE table and 	*
	*	creates the new orders and vehicle records.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	07/19/2004 CMK    Initial version				*
	*	11/10/2004 CMK    Moved ShagUnitInd from Vehicle to Leg		*
	*									*
	************************************************************************/

	SELECT @PreviousOrigin = 0
	SELECT @PreviousDestination = 0
	SELECT @VehicleStatus = 'Pending'
	SELECT @CustomerID = NULL
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NissanCustomerID'
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

	DECLARE NissanLE CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT NissanImportLEID, Status, VIN, D6, ModelLine, ColorCode, ShipDealer, 
 		SellDealer, PriorityCode, MustShip, DealerMemo, LoadEligible,
		RailcarNumber, RailcarLoadDate, ModelCode, RateClass, Header,
		VehicleYear, Make, Model, Bodystyle, VehicleLength, VehicleWidth,
		VehicleHeight, VINDecodedInd
		FROM NissanImportLE
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY Header, ShipDealer, NissanImportLEID

	SELECT @ErrorID = 0
	SELECT @ErrorEncountered = 0
	SELECT @loopcounter = 0

	OPEN NissanLE

	BEGIN TRAN

	FETCH NEXT FROM NissanLE INTO @NissanImportLEID, @Status, @VIN, @D6, @ModelLine, @ColorCode, @ShipDealer, 
		@SellDealer, @PriorityCode, @MustShip, @DealerMemo, @LoadEligible,
		@RailcarNumber, @RailcarLoadDate, @ModelCode, @RateClass, @Header,
		@VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength, @VehicleWidth,
		@VehicleHeight, @VINDecodedInd
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		SELECT @DestinationID = NULL
		SELECT @OriginID = NULL
		--if the ship dealer is a drop, then lookup the location id, if its not found, then
		-- update the vehicle status that its not found in the location table.
		--Print 'whats the ship dealer ' + @ShipDealer
		IF @ShipDealer = 'Drop'
		BEGIN
			SELECT @DropDealer = Dealer,
			@DropAddress = Address,
			@DropCity = City,
			@DropState = State,
			@DropZip = ZipCode
			FROM NissanImportDrops
			WHERE VIN = @VIN
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Drop Location Not Found'
				GOTO Error_Encountered
			END

			SELECT TOP 1 @DestinationID = LocationID
			FROM Location 
			WHERE AddressLine1 = @DropAddress
			AND City = @DropCity
			AND State = @DropState
			AND Zip = @DropZip 
			AND ParentRecordID = @CustomerID
			AND ParentRecordTable = 'Customer'
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Getting Drop Location'
				GOTO Error_Encountered
			END

			IF @DestinationID IS NULL
			BEGIN
				--Create the destination location
				INSERT INTO Location(
					ParentRecordID,
					ParentRecordTable,
					LocationType,
					LocationName,
					AddressLine1,
					City,
					State,
					Zip,
					Country,
					AuctionPayOverrideInd,
					AuctionPayRate,
					FlatDeliveryPayInd,
					FlatDeliveryPayRate,
					MileagePayBoostOverrideInd,
					MileagePayBoost,
					SortOrder,
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
					@DropDealer,
					@DropAddress,
					@DropCity,
					@DropState,
					@DropZip,
					'U.S.A.',
					0,
					0,
					0,
					0,
					0,
					0,
					0,
					'Active',
					getDate(),
					'Import',
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
				IF @@ERROR <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Creating Drop Location'
					GOTO Error_Encountered
				END
				ELSE
				BEGIN
					SELECT @DestinationID = @@IDENTITY
				END
			END
		END
		ELSE
		BEGIN
			--PRINT 'Inside the else, whats the ship dealer ' + @ShipDealer
			--get the destination.
			SELECT @DestinationID = LocationID
			FROM Location
			WHERE ParentRecordID = @CustomerID
			AND ParentRecordTable = 'Customer'
			AND (CustomerLocationCode = @ShipDealer
			OR CustomerLocationCode = '0'+@ShipDealer)
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Getting Destination Location ID'
				GOTO Error_Encountered
			END

			IF @DestinationID IS NULL
			BEGIN
				--Create the destination location
				INSERT INTO Location(
					ParentRecordID,
					ParentRecordTable,
					LocationType,
					LocationName,
					Country,
					CustomerLocationCode,
					AuctionPayOverrideInd,
					AuctionPayRate,
					FlatDeliveryPayInd,
					FlatDeliveryPayRate,
					MileagePayBoostOverrideInd,
					MileagePayBoost,
					SortOrder,
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
					'U.S.A.',
					@ShipDealer,
					0,
					0,
					0,
					0,
					0,
					0,
					0,
					'Active',
					getDate(),
					'Import',
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
				IF @@ERROR <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Creating Drop Location'
					GOTO Error_Encountered
				END
				ELSE
				BEGIN
					SELECT @DestinationID = @@IDENTITY
				END
			END
		END

		--PRINT 'header ' + @Header
		--get the Origin location
		SELECT @OriginLocation = @Header

		--get the Origin
		/*
		SELECT @OriginID = LocationID
		FROM Location
		WHERE ParentRecordID = @CustomerID
		AND ParentRecordTable = 'Customer'
		AND CustomerLocationCode = @OriginLocation
		*/
		SELECT @OriginID = CONVERT(int,Value1)
		FROM Code
		WHERE CodeType = 'NissanRailheadCode'
		AND Code = @OriginLocation
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error origin id'
			GOTO Error_Encountered
		END

		IF @OriginID IS NULL
		BEGIN
			--NEW ORIGIN, SO CREATE A NEW LOCATION RECORD
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
				'PickupLocation',
				'NEED LOCATION NAME',
				@OriginLocation,
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
			SELECT @OriginID = @@Identity
		END

		SELECT @ChargeRate = NULL
		--From these values we can get the financial information.
		--Need to add logic to check size class. not in this particular file.
		SELECT @ChargeRate = Rate
		FROM ChargeRate
		WHERE StartLocationID = @OriginID
		AND EndLocationID = @DestinationID
		AND CustomerID = @CustomerID
		AND RateType = 'Size '+@RateClass+' Rate'

		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM Vehicle
		WHERE VIN = @VIN
		AND CustomerID = @CustomerID
		AND VehicleStatus <> 'Delivered'
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error getting vin count'
			GOTO Error_Encountered
		END

		IF @VINCOUNT > 0
		BEGIN
			--get the vehicle id
			SELECT @VehicleID = VehicleID
			FROM Vehicle
			WHERE VIN = @VIN
			AND CustomerID = @CustomerID
			AND VehicleStatus <> 'Delivered'
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting vin count'
				GOTO Error_Encountered
			END

			--update logic here.
			UPDATE Vehicle
			SET Color = @ColorCode,
			PickupLocationID = @OriginID,
			DropoffLocationID = @DestinationID,
			ChargeRate = @ChargeRate
			WHERE VehicleID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
				GOTO Error_Encountered
			END

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
					GetDate(),	--CreationDate
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
			
			--update any legs records
			SELECT @LegsCount = 0
			SELECT @LegsCount = COUNT(*)
			FROM Legs
			WHERE VehicleID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting Legs count'
				GOTO Error_Encountered
			END

			IF @LegsCount > 0
			BEGIN
				--have legs, so update them
				UPDATE Legs
				SET PickupLocationID = @OriginID,
				DateAvailable = GetDate(),
				LegStatus = 'Available',
				PoolID = @PoolID
				WHERE VehicleID = @VehicleID
				AND LegNumber = 1
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error updating starting leg'
					GOTO Error_Encountered
				END

				UPDATE Legs
				SET DropoffLocationID = @DestinationID
				WHERE VehicleID = @VehicleID
				AND FinalLegInd = 1
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error updating ending leg'
					GOTO Error_Encountered
				END
				
				IF @LegsCount > 1
				BEGIN
					UPDATE Legs
					SET LegStatus = 'Pending Prev. Leg'
					WHERE VehicleID = @VehicleID
					AND LegNumber > 1
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'Error updating ending leg'
						GOTO Error_Encountered
					END
				END
			END
			ELSE
			BEGIN
				--have to create the legs record
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
					GetDate(),
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
					0,		--ShagUnitInd
					GetDate(), 	--CreationDate
					'IMPORT', 	--CreatedBy
					0		--OutsideCarrierFuelSurchargeType
				)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR CREATING DEFAULT LEG'
					GOTO Error_Encountered
				END
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
					GetDate(),	--CreationDate,
					'IMPORT',	--CreatedBy,
					NULL,		--UpdatedDate,
					NULL		--UpdatedBy
				)
			
				--need to get the orderId key here, to insert into the vehicle record.			
				select @OrderID = @@identity
			END

			--and now do the vehicle
			IF @VehicleYear IS NULL OR DATALENGTH(@VehicleYear)<1
			BEGIN
				SELECT @VehicleYear = ''
			END
			IF @Make IS NULL OR DATALENGTH(@Make)<1
			BEGIN
				SELECT @Make = 'Nissan'
			END
			IF @Model IS NULL OR DATALENGTH(@Model)<1
			BEGIN
				SELECT @Model = @ModelLine
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
				
			INSERT INTO Vehicle(
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
				@CustomerID,	--CustomerID,
				@OrderID,	--OrderID,
				@VehicleYear,	--VehicleYear,
				@Make,		--Make,
				@Model,		--Model,
				@Bodystyle,	--Bodystyle,
				@VIN,		--VIN,
				@ColorCode,	--Color,  --decode from the codes table.
				@VehicleLength,	--VehicleLength
				@VehicleWidth,	--VehicleWidth
				@VehicleHeight,	--VehicleHeight
				@OriginID,	--PickupLocationID,
				@DestinationID,	--DropoffLocationID,
				'Pending',	--VehicleStatus,
				'Pickup Point', --VehicleLocation,
				@D6,		--CustomerIdentification,
				@RateClass,	--SizeClass, 
				NULL,		--BayLocation,
				@RailCarNumber, --RailCarNumber,
				0,		--PriorityInd,
				NULL,		--HaulType,
				GetDate(),	--AvailableForPickupDate,
				0,		--ShopWorkStartedInd,
				NULL,		--ShopWorkStartedDate,
				0,		--ShopWorkCompleteInd
				NULL,		--ShopWorkCompleteDate
				NULL,		--PaperworkReceivedDate,
				NULL,		--ICLAuditCode,
				@ChargeRate,	--ChargeRate,
				0,		--ChargeRateOverrideInd
				0,		--BilledInd
				NULL,		--DateBilled
				@VINDecodedInd,	--VINDecodedInd
				'Active',	--RecordStatus,
				GetDate(),	--CreationDate,-- getDate
				'IMPORT',	--CreatedBy, -- SYSTEM
				NULL,		--UpdatedDate,
				NULL,		--UpdatedBy
				0,		--CreditHoldInd
				0,		--PickupNotificationSentInd
				0,		--STIDeliveryNotificationSentInd
				0,		--BillOfLadingSentInd
				0,		--DealerHoldOverrideInd
				0,		--MiscellaneousAdditive
				0,		--FuelSurcharge
				0,		--AccessoriesCompleteInd,
				0,		--PDICompleteInd
				0		--FinalShipawayInspectionDoneInd
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
					GetDate(),	--CreationDate
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
				@VehicleID,	--VehicleID
				@PoolID,
				GetDate(),
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
				GetDate(),	--CreationDate
				'IMPORT',	--CreatedBy
				0		--OutsideCarrierFuelSurchargeType
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR CREATING DEFAULT LEG'
				GOTO Error_Encountered
			END

		END

		--update logic here.
		UPDATE NissanImportLE
		SET RecordStatus = 'Imported',
		ImportedInd = 1,
		ImportedDate = GetDate(),
		ImportedBy = @UserCode
		WHERE NissanImportLEID = @NissanImportLEID
	
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH NissanLE into @NissanImportLEID, @Status, @VIN, @D6, @ModelLine, @ColorCode, @ShipDealer, 
			@SellDealer, @PriorityCode, @MustShip, @DealerMemo, @LoadEligible,
			@RailcarNumber, @RailcarLoadDate, @ModelCode, @RateClass, @Header,
			@VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength, @VehicleWidth,
			@VehicleHeight, @VINDecodedInd

	END

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
		CLOSE NissanLE
		DEALLOCATE NissanLE
		--PRINT 'NissanLE Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE NissanLE
		DEALLOCATE NissanLE
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
	BEGIN
		--PRINT 'NissanLE Error_Encountered =' + STR(@ErrorID)
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
