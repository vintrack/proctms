USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportACESG95]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROC [dbo].[spImportACESG95] (@BatchID int, @CustomerCode varchar(20),
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@ErrorEncountered		varchar(5000),
	@loopcounter			int,
	@ACESImportG95ID		int,
	@VIN				varchar(17),
	@ShipmentAuthorizationCode	varchar(12),
	@ModelCode			varchar(20),
	@ExteriorColorCode		varchar(4),
	@TransactionCode		varchar(12),
	@PrevVehicleOwnerName		varchar(20),
	@DateAvailable			datetime,
	@RequiredShipDate		datetime,
	@RequiredDelvDate		datetime,
	@Rate				varchar(8),
	@Comments			varchar(40),
	@ACESAssignedTruckAccountNumber	varchar(4),
	@OriginCode			varchar(7),
	@ContactNameAtOrigin		varchar(20),
	@OriginAddress1			varchar(50),
	@OriginAddress2			varchar(50),
	@OriginCity			varchar(28),
	@OriginState			varchar(2),
	@OriginZipCode			varchar(10),
	@OriginPhoneNumber		varchar(20),
	@OriginFaxNumber		varchar(20),
	@DestinationCode		varchar(7),
	@ContactNameAtDestination	varchar(20),
	@ShipToAddress1			varchar(50),
	@ShipToAddress2			varchar(50),
	@ShipToCity			varchar(28),
	@ShipToState			varchar(2),
	@ShipToZipCode			varchar(10),
	@ShipToPhoneNumber		varchar(20),
	@ShipToFaxNumber		varchar(20),
	@RecordStatus			varchar(100),
	@VINCOUNT			int,
	@DestinationID			int,
	@OriginID			int,
	@ChargeRate			decimal(19,2),
	@CustomerID			int,
	@OrderID			int,
	@PreviousOrigin			int,
	@PreviousDestination		int,
	@OrderNumber			int,
	@Status				varchar(50),
	@OrderNumberPlusOne		int,
	@VehicleID			int,
	@VehicleDestinationID		int,
	@VehicleOriginID		int,
	@VehiclePoolID			int,
	@VehicleLoadID			int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@PoolRecordCount		int,
	@PoolID				int,
	@TotalOrderUnits		int,
	@TotalOrderChargeRate		decimal(19,2),
	@LegsCount			int,
	@VehicleYear			varchar(6), 
	@Make				varchar(50), 
	@Model				varchar(50),
	@Bodystyle			varchar(50),
	@VehicleLength			varchar(10),
	@VehicleWidth			varchar(10),
	@VehicleHeight			varchar(10),
	@VINDecodedInd			int,
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@SizeClass			varchar(10)
	
	/************************************************************************
	*	spImportACESG95							*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the ACESImportG95 table and 	*
	*	creates the new orders and vehicle records.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	02/05/2009 CMK    Initial version				*
	*									*
	************************************************************************/
	SELECT @PreviousOrigin = 0
	SELECT @PreviousDestination = 0

	--get the customer id from the setting table
	SELECT @CustomerID = Value1
	FROM Code
	WHERE CodeType = 'ACESCustomerCode'
	AND Code = @CustomerCode
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

	DECLARE ImportG95 CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT ACESImportG95ID, VIN, ShipmentAuthorizationCode, ModelCode,
		ExteriorColorCode, TransactionCode, PrevVehicleOwnerName, DateAvailable,
		RequiredShipDate, RequiredDelvDate, Rate, Comments, ACESAssignedTruckAccountNumber,
		OriginCode, ContactNameAtOrigin, OriginAddress1, OriginAddress2, OriginCity,
		OriginState, OriginZipCode, OriginPhoneNumber, OriginFaxNumber, DestinationCode,
		ContactNameAtDestination, ShipToAddress1, ShipToAddress2, ShipToCity, ShipToState,
		ShipToZipCode, ShipToPhoneNumber, ShipToFaxNumber,
		VehicleYear, Make, Model, Bodystyle, VehicleLength, VehicleWidth,
		VehicleHeight, VINDecodedInd
		FROM ACESImportG95
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		AND Header = @CustomerCode
		ORDER BY OriginCode, DestinationCode

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN ImportG95

	BEGIN TRAN

	FETCH ImportG95 into @ACESImportG95ID, @VIN, @ShipmentAuthorizationCode, @ModelCode,
		@ExteriorColorCode, @TransactionCode, @PrevVehicleOwnerName, @DateAvailable,
		@RequiredShipDate, @RequiredDelvDate, @Rate, @Comments, @ACESAssignedTruckAccountNumber,
		@OriginCode, @ContactNameAtOrigin, @OriginAddress1, @OriginAddress2, @OriginCity,
		@OriginState, @OriginZipCode, @OriginPhoneNumber, @OriginFaxNumber, @DestinationCode,
		@ContactNameAtDestination, @ShipToAddress1, @ShipToAddress2, @ShipToCity, @ShipToState,
		@ShipToZipCode, @ShipToPhoneNumber, @ShipToFaxNumber,
		@VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength, @VehicleWidth,
		@VehicleHeight, @VINDecodedInd
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		PRINT 'Inside the while loop first time through'

		SELECT @DestinationID = NULL
		SELECT @OriginID = NULL

		--get the destination.
		IF DATALENGTH(ISNULL(@DestinationCode,'')) > 0
		BEGIN
			--try the customers locations
			SELECT TOP 1 @DestinationID = LocationID
			FROM Location
			WHERE ParentRecordID = @CustomerID
			AND ParentRecordTable = 'Customer'
			AND CustomerLocationCode = @DestinationCode
			ORDER BY LocationSubType
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING DESTINATION LOCATION'
				GOTO Error_Encountered
			END
	
			--try the aces location codes
			IF @DestinationID IS NULL
			BEGIN
				SELECT TOP 1 @DestinationID = CONVERT(int,Value1)
				FROM Code
				WHERE CodeType = 'ACES'+@CustomerCode+'LocationCode'
				AND Code = @DestinationCode
				ORDER BY Code
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING DESTINATION LOCATION'
					GOTO Error_Encountered
				END
			END
		END
		ELSE
		BEGIN
			--try to find using the address
			SELECT TOP 1 @DestinationID = LocationID
			FROM Location
			WHERE AddressLine1 = @ShipToAddress1
			AND City = @ShipToCity
			AND State = @ShipToState
			AND Zip = @ShipToZipCode
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING DESTINATION LOCATION'
				GOTO Error_Encountered
			END
		END

		IF @DestinationID IS NULL
		BEGIN
			--NEW DESTINATION, SO CREATE A NEW LOCATION RECORD
			INSERT INTO Location(
				ParentRecordID,
				ParentRecordTable,
				LocationType,
				LocationName,
				AddressLine1,
				AddressLine2,
				City,
				State,
				Zip,
				Country,
				CustomerLocationCode,
				MainPhone,
				FaxNumber,
				PrimaryContactFirstName,
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
				@ShipToAddress1,
				@ShipToAddress2,
				@ShipToCity,
				@ShipToState,
				@ShipToZipCode,
				'U.S.A.',
				@DestinationCode,
				REPLACE(@ShipToPhoneNumber,' ',''),
				REPLACE(@ShipToFaxNumber,' ',''),
				@ContactNameAtDestination,
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

		--get the Origin.
		IF DATALENGTH(ISNULL(@OriginCode,'')) > 0
		BEGIN
			--try the customers locations
			SELECT TOP 1 @OriginID = LocationID
			FROM Location
			WHERE ParentRecordID = @CustomerID
			AND ParentRecordTable = 'Customer'
			AND CustomerLocationCode = @OriginCode
			ORDER BY LocationSubType
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING ORIGIN LOCATION'
				GOTO Error_Encountered
			END
		
			--try the aces location codes
			IF @OriginID IS NULL
			BEGIN
				SELECT TOP 1 @OriginID = CONVERT(int,Value1)
				FROM Code
				WHERE CodeType = 'ACES'+@CustomerCode+'LocationCode'
				AND Code = @OriginCode
				ORDER BY Code
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING ORIGIN LOCATION'
					GOTO Error_Encountered
				END
			END
		END
		ELSE
		BEGIN
			--try to find using the address
			SELECT TOP 1 @OriginID = LocationID
			FROM Location
			WHERE AddressLine1 = @OriginAddress1
			AND City = @OriginCity
			AND State = @OriginState
			AND Zip = @OriginZipCode
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING ORIGIN LOCATION'
				GOTO Error_Encountered
			END
		END
		
		--try using the 
		IF @OriginID IS NULL
		BEGIN
			--NEW ORIGIN, SO CREATE A NEW LOCATION RECORD
			INSERT INTO Location(
				ParentRecordID,
				ParentRecordTable,
				LocationType,
				LocationName,
				AddressLine1,
				AddressLine2,
				City,
				State,
				Zip,
				Country,
				CustomerLocationCode,
				MainPhone,
				FaxNumber,
				PrimaryContactFirstName,
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
				@OriginAddress1,
				@OriginAddress2,
				@OriginCity,
				@OriginState,
				@OriginZipCode,
				'U.S.A.',
				@OriginCode,
				REPLACE(@OriginPhoneNumber,' ',''),
				REPLACE(@OriginFaxNumber,' ',''),
				@ContactNameAtOrigin,
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

		SELECT @SizeClass = 'A'
		
		/* For G95 ChargeRate is in the file
		SELECT @ChargeRate = NULL
		--From these values we can get the financial information.
		--Need to add logic to check size class. not in this particular file.
		SELECT @ChargeRate = Rate
		FROM ChargeRate
		WHERE StartLocationID = @OriginID
		AND EndLocationID = @DestinationID
		AND CustomerID = @CustomerID
		AND RateType = 'Size A Rate'
		*/
		SELECT @ChargeRate = CONVERT(Decimal(19,2),@Rate)
		
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
			SELECT @VehicleID = V.VehicleID,
			@VehicleOriginID = V.PickupLocationID,
			@VehicleDestinationID = V.DropoffLocationID,
			@VehicleLoadID = L.LoadID,
			@VehiclePoolID = L.PoolID
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			AND L.LegNumber = 1
			WHERE V.VIN = @VIN
			AND V.CustomerID = @CustomerID
			AND V.VehicleStatus <> 'Delivered'
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting vehicle id'
				GOTO Error_Encountered
			END

			-- check the origin/destination
			IF @OriginID <> @VehicleOriginID
			BEGIN
				SELECT @RecordStatus = 'ORIGIN MISMATCH'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Record_Status
			END
			ELSE IF @DestinationID <> @VehicleDestinationID
			BEGIN
				SELECT @RecordStatus = 'DESTINATION MISMATCH'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Record_Status
			END
						
			--update logic here.
			UPDATE Vehicle
			SET Color = @ExteriorColorCode,
			PickupLocationID = @OriginID,
			DropoffLocationID = @DestinationID,
			CustomerIdentification = @ShipmentAuthorizationCode,
			ChargeRate = @ChargeRate,
			ChargeRateOverrideInd = 1,
			AvailableForPickupDate = @DateAvailable
			WHERE VehicleID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
				GOTO Error_Encountered
			END

			IF @VehicleLoadID IS NULL
			BEGIN
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
						'G95 IMPORT'	--CreatedBy
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
					
					IF ISNULL(@VehiclePoolID,0) <> @PoolID
					BEGIN
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
				END
				IF @VehiclePoolID IS NOT NULL AND @PoolID <> @VehiclePoolID
				BEGIN
					--decrease the old pool
					UPDATE VehiclePool
					SET PoolSize = PoolSize - 1,
					Available = Available - 1
					WHERE VehiclePoolID = @VehiclePoolID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING OLD POOL RECORD'
						GOTO Error_Encountered
					END
				END
			END
			ELSE
			BEGIN
				SELECT @PoolID = NULL
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
				IF @VehicleLoadID IS NULL
				BEGIN
					--have legs, so update them
					UPDATE Legs
					SET PickupLocationID = @OriginID,
					DateAvailable = @DateAvailable,
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
					@DateAvailable,
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
					'G95 IMPORT', 	--CreatedBy
					0		--OutsideCarrierFuelSurchargeType
				)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR CREATING DEFAULT LEG'
					GOTO Error_Encountered
				END
			END
			SELECT @RecordStatus = 'Imported'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = GetDate()
			SELECT @ImportedBy = @UserCode
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
					0,			--LoadType,
					0,			--CustomerChargeType,
					0,			--CarrierType,
					NULL,			--OutsideCarrierID,
					0,			--PricingInd,
					0,			--FixedChargeRateOverrideInd,
					0,			--FixedChargeRate,
					0,			--MileageChargeRateOverrideInd,
					0,			--MileageChargeRate,
					0,			--PerUnitChargeRate,
					0,			--OrderChargeRate,
					@RequiredShipDate,	--RequestedPickupDate,
					@RequiredDelvDate,	--RequestedDeliveryDate,
					@OriginID,		--PickupLocation,
					@DestinationID,		--DropoffLocation,
					0,			--Units,
					0,			--Mileage,
					NULL,			--SalespersonID,
					0,			--OutsideCarrierPaymentMethod,
					0,			--OutsideCarrierPercentage,
					0,			--OutsideCarrierPctOverrideInd,
					0,			--OutsideCarrierPay,
					'Bill To Customer',	--PaymentMethod,
					NULL,			--InternalComment,
					NULL,			--DriverComment,
					NULL,			--PONumber,
					'Pending',		--OrderStatus,
					GetDate(),		--CreationDate,
					'G95 IMPORT',		--CreatedBy,
					NULL,			--UpdatedDate,
					NULL			--UpdatedBy
				)

				--need to get the orderId key here, to insert into the vehicle record.			
				SELECT @OrderID = @@identity
			END

			--and now do the vehicle
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
				@CustomerID,		--CustomerID,
				@OrderID,		--OrderID,
				@VehicleYear,		--VehicleYear,
				@Make,			--Make,
				@Model,			--Model,
				@Bodystyle,		--Bodystyle,
				@VIN,			--VIN,
				@ExteriorColorCode,	--Color,
				@VehicleLength,		--VehicleLength
				@VehicleWidth,		--VehicleWidth
				@VehicleHeight,		--VehicleHeight
				@OriginID,		--PickupLocationID,
				@DestinationID,		--DropoffLocationID,
				'Pending',		--VehicleStatus,
				'Pickup Point',		--VehicleLocation,
				@ShipmentAuthorizationCode,	--CustomerIdentification,
				@SizeClass,		--SizeClass,  --decode sizeclass.  might come up with logic for determining the size class.
				NULL,			--BayLocation,
				NULL,			--RailCarNumber,
				0,			--PriorityInd
				NULL,			--HaulType,
				@DateAvailable,		--AvailableForPickupDate,
				0,			--ShopWorkStartedInd,
				NULL,			--ShopWorkStartedDate,
				0,			--ShopWorkCompleteInd,
				NULL,			--ShopWorkCompleteDate
				NULL,			--PaperworkReceivedDate,
				NULL,			--ICLAuditCode,
				@ChargeRate,		--ChargeRate
				1,			--ChargeRateOverrideInd
				0,			--BilledInd
				NULL,			--DateBilled
				@VINDecodedInd,		--VINDecodedInd
				'Active',		--RecordStatus,
				GetDate(),		--CreationDate,
				'G95 IMPORT',		--CreatedBy,
				NULL,			--UpdatedDate,
				NULL,			--UpdatedBy
				0,			--CreditHoldInd
				0,			--PickupNotificationSentInd
				0,			--STIDeliveryNotificationSentInd
				0,			--BillOfLadingSentInd
				0,			--DealerHoldOverrideInd
				0,			--MiscellaneousAdditive
				0,			--FuelSurcharge
				0,			--AccessoriesCompleteInd,
				0,			--PDICompleteInd
				0			--FinalShipawayInspectionDoneInd
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
					'G95 IMPORT'	--CreatedBy
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
				GetDate(),	--CreationDate
				'G95 IMPORT',	--CreatedBy
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
		Update_Record_Status:
		UPDATE ACESImportG95
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE ACESImportG95ID = @ACESImportG95ID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH ImportG95 into @ACESImportG95ID, @VIN, @ShipmentAuthorizationCode, @ModelCode,
			@ExteriorColorCode, @TransactionCode, @PrevVehicleOwnerName, @DateAvailable,
			@RequiredShipDate, @RequiredDelvDate, @Rate, @Comments, @ACESAssignedTruckAccountNumber,
			@OriginCode, @ContactNameAtOrigin, @OriginAddress1, @OriginAddress2, @OriginCity,
			@OriginState, @OriginZipCode, @OriginPhoneNumber, @OriginFaxNumber, @DestinationCode,
			@ContactNameAtDestination, @ShipToAddress1, @ShipToAddress2, @ShipToCity, @ShipToState,
			@ShipToZipCode, @ShipToPhoneNumber, @ShipToFaxNumber,
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
		CLOSE ImportG95
		DEALLOCATE ImportG95
		PRINT 'ImportG95 Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ImportG95
		DEALLOCATE ImportG95
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			PRINT 'ImportG95 Error_Encountered =' + STR(@ErrorID)
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
