USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportSubaruASN]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportSubaruASN] (@BatchID int,
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	@SubaruASNID			int,
	@OriginLocation			varchar(10),
	@RailLoadDate			datetime,
	@LoadNumber			varchar(15),
	@CarrierCode			varchar(5),
	@Region				varchar(5),
	@Dealer				varchar(5),
	@VIN				varchar(20),
	@SOAModelYear			varchar(6),
	@DescriptionCategory		varchar(10),
	@DescriptionSubCategory		varchar(10),
	@SOAExteriorColor		varchar(5),
	@DestinationRailheadCode	varchar(6),
	@RailCarNumber			varchar(10),
	@SoldOrder			varchar(5),
	@Destination			varchar(15),
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
	@NeedsReviewInd			int,
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
	@Count				int,
	@EstimatedReleaseDate		datetime

	/************************************************************************
	*	spImportSubaruASN						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the SubaruASN table and 	*
	*	creates the new orders and vehicle records.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	07/01/2004 CMK    Initial version				*
	*	11/10/2004 CMK    Moved ShagUnitInd from Vehicle to Leg		*
	*	08/19/2005 CMK    Reject record status when origin not found	*
	*	12/02/2005 CMK    Changed VIN found code to update status and 	*
	*	                  not update any vehicle, leg or pool records	*
	*									*
	************************************************************************/
	SELECT @PreviousOrigin = 0
	SELECT @PreviousDestination = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @EstimatedReleaseDate = CONVERT(varchar(10),DATEADD(day,4,@CreationDate),101)
	SELECT @NeedsReviewInd = 0
	
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

	DECLARE SubaruASN CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT SubaruASNID, OriginLocation, RailLoadDate, LoadNumber, CarrierCode, Region, Dealer, 
		VIN, SOAModelYear, DescriptionCategory, DescriptionSubCategory, SOAExteriorColor,
		DestinationRailheadCode, RailcarNumber, SoldOrder, Destination,
		VehicleYear, Make, Model, Bodystyle, VehicleLength, VehicleWidth,
		VehicleHeight, VINDecodedInd
		FROM SubaruASN
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY OriginLocation, Destination, SubaruASNID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN SubaruASN

	BEGIN TRAN

	FETCH SubaruASN into @SubaruASNID, @OriginLocation, @RailLoadDate, @LoadNumber, @CarrierCode, @Region, @Dealer, 
		@VIN, @SOAModelYear, @DescriptionCategory, @DescriptionSubCategory, @SOAExteriorColor,
		@DestinationRailheadCode, @RailcarNumber, @SoldOrder, @Destination,
		@VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength, @VehicleWidth,
		@VehicleHeight, @VINDecodedInd

	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @ImportedInd = 0
		SELECT @ImportedDate = NULL
		SELECT @ImportedBy = NULL
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
		AND Code = @DestinationRailheadCode
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR GETTING ORIGIN LOCATION'
			GOTO Error_Encountered
		END

		IF @OriginID IS NULL
		BEGIN
			SELECT @NeedsReviewInd = 1
			SELECT @ImportError = 0
			SELECT @RecordStatus = 'Orig Cd '+@DestinationRailheadCode+' Not Found'
			GOTO Update_Import_Record
			/*
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
				@DestinationRailheadCode,
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
			*/
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
		--AND VehicleStatus <> 'Delivered'
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error getting vin count'
			GOTO Error_Encountered
		END

		IF @SoldOrder = 'Y'
		BEGIN
			SELECT @PriorityInd = 1
		END
		ELSE
		BEGIN
			SELECT @PriorityInd = 0
		END
		
		IF @VINCOUNT > 0
		BEGIN
			--see if there are any changes to the origin/destination
			SELECT TOP 1 @VehicleID = V.VehicleID,
			@VehicleOriginID = V.PickupLocationID,
			@VehicleDestinationID = V.DropoffLocationID
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
				SELECT @NeedsReviewInd = 1
				SELECT @RecordStatus = 'ORIGIN MISMATCH'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
			END
			ELSE IF @DestinationID <> @VehicleDestinationID
			BEGIN
				SELECT @NeedsReviewInd = 1
				SELECT @RecordStatus = 'DESTINATION MISMATCH'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
			END
			ELSE
			BEGIN
				SELECT @NeedsReviewInd = 1
				SELECT @RecordStatus = 'VIN ALREADY EXISTS'
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
			END
			/*
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
			SET Color = @SOAExteriorColor,
			PickupLocationID = @OriginID,
			DropoffLocationID = @DestinationID,
			RailcarNumber = @RailcarNumber,
			ChargeRate = @ChargeRate,
			EstimatedReleaseDate = @EstimatedReleaseDate
			WHERE VIN = @VIN
			AND CustomerID = @CustomerID
			AND VehicleStatus <> 'Delivered'
			--AvailableForPickupDate = @PortReleaseDate
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
				GOTO Error_Encountered
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
				SET PickupLocationID = @OriginID
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
			END
			ELSE
			BEGIN
				--have to create the legs record
				INSERT INTO Legs(
					VehicleID,
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
					'Pending',
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
			*/
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
				SELECT @OrderID = @@identity
			END

			--and now do the vehicle
			/* --NOW COMING FROM ASN FILE
			IF @SOADiversifiedLocationID = @DestinationID
			BEGIN
				SELECT @PriorityInd = 0
			END
			ELSE
			BEGIN
				SELECT @PriorityInd = 1
			END
			*/	
			--try to decode the color
			SET @DecodedColor = NULL
			
			SELECT @DecodedColor = CodeDescription
			FROM Code
			WHERE CodeType = 'SubaruColorCode'
			AND Code = @SOAExteriorColor
			
			IF @DecodedColor IS NULL OR DATALENGTH(@DecodedColor)<1
			BEGIN
				SELECT @DecodedColor = @SOAExteriorColor
			END
			IF @VehicleYear IS NULL OR DATALENGTH(@VehicleYear)<1
			BEGIN
				SELECT @VehicleYear = @SOAModelYear
			END
			IF @Make IS NULL OR DATALENGTH(@Make)<1
			BEGIN
				SELECT @Make = 'Subaru'
			END
			IF @Model IS NULL OR DATALENGTH(@Model)<1
			BEGIN
				SELECT @Model = @DescriptionCategory
			END
			IF @Bodystyle IS NULL OR DATALENGTH(@Bodystyle)<1
			BEGIN
				SELECT @Bodystyle = @DescriptionSubCategory
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
				FinalShipawayInspectionDoneInd,
				EstimatedReleaseDate
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
				'Pending',			--VehicleStatus,
				'Pickup Point',			--VehicleLocation,
				NULL,				--CustomerIdentification,
				'A',				--SizeClass,
				NULL,				--BayLocation,
				@RailcarNumber,			--RailCarNumber,
				@PriorityInd,			--PriorityInd
				NULL,				--HaulType,
				NULL,				--AvailableForPickupDate,-----------for now.
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
				GetDate(),			--CreationDate
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
				0,				--FinalShipawayInspectionDoneInd
				@EstimatedReleaseDate		--EstimtatedReleaseDate
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

			-- now create the Legs record for the vehicle
			INSERT INTO Legs(
				VehicleID,
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
				'Pending',
				0,
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
			SELECT @RecordStatus = 'Imported'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = GetDate()
			SELECT @ImportedBy = @UserCode
		END
		
		SELECT @Count = NULL
		
		SELECT @Count = COUNT(*)
		FROM VPCVehicle
		WHERE FullVIN = @VIN
		AND SOAVehicleID IS NULL
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error getting VIN Count'
			GOTO Error_Encountered
		END
		
		IF @COUNT IS NOT NULL
		BEGIN
			UPDATE VPCVehicle
			SET SOAVehicleID = @VehicleID
			WHERE FullVIN = @VIN
			AND SOAVehicleID IS NULL
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error updating VPCVehicle'
				GOTO Error_Encountered
			END
		END
			
		--update logic here.
		Update_Import_Record:
		UPDATE SubaruASN
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE SubaruASNID = @SubaruASNID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END
		
		FETCH SubaruASN into @SubaruASNID, @OriginLocation, @RailLoadDate, @LoadNumber, @CarrierCode, @Region, @Dealer, 
		@VIN, @SOAModelYear, @DescriptionCategory, @DescriptionSubCategory, @SOAExteriorColor,
		@DestinationRailheadCode, @RailcarNumber, @SoldOrder, @Destination,
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
		CLOSE SubaruASN
		DEALLOCATE SubaruASN
		PRINT 'SubaruASN Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE SubaruASN
		DEALLOCATE SubaruASN
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			PRINT 'SubaruASN Error_Encountered =' + STR(@ErrorID)
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
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage, @NeedsReviewInd AS NeedsReviewInd
	
	RETURN
END
GO
