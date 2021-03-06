USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportMercedesVehicles]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportMercedesVehicles] (@BatchID int,
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--NissanImportTE table variables
	@MercedesImportID		int,
	@RecordType			varchar(2),
	@MIStatus			varchar(1),
	@LoadNumber			varchar(10),
	@AvailableDate			varchar(10),
	@VIN				varchar(17),
	@VPC				varchar(2),
	@HotCarFlag			varchar(1),
	@OriginDealerCode		varchar(5),
	@DestinationDealer		varchar(5),
	@ParkingBayLocation		varchar(4),
	@EquipmentType			varchar(1),
	@MessageFlag			varchar(1),
	@ColorCode			varchar(3),
	@ModelDescription		varchar(7),
	@ShopTag			varchar(5),
	@Railcar			varchar(10),
	@RetailerCode			varchar(5),
	@Filler				varchar(1),
	@ImportedInd			int,
	@SpecialHandlingFlag		varchar(1),
	--processing variables
	@VINCOUNT			int,
	@OldLegStatus			varchar(20),
	@DestinationID			int,
	@OriginID			int,
	@ChargeRate			decimal(19,2),
	@RateClass			varchar(1),
	@AvailableForPickupDate		datetime,
	@LegStatus			varchar(20),
	@CustomerID			int,
	@OrderID			int,
	@CustomerCode			varchar(70),
	@PreviousOrigin			int,
	@PreviousDestination		int,
	@OrderNumber			int,
	@RecordStatus			varchar(100),
	@Status				varchar(100),
	@OrderNumberPlusOne		int,
	@LoadID				int,
	@PoolID				int,
	@VehicleID			int,
	@PoolRecordCount		int,
	@Available			int,
	@PoolSize			int,
	@Reserved			int,
	@VehicleReservationsID		int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@NeedsReviewInd			int,
	@TotalOrderUnits		int,
	@TotalOrderChargeRate		decimal(19,2),
	@LegsCount			int,
	@DateAvailable			datetime,
	@PriorityInd			int,
	@VehicleYear			varchar(6), 
	@Make				varchar(50), 
	@Model				varchar(50),
	@Bodystyle			varchar(50),
	@VehicleLength			varchar(10),
	@VehicleWidth			varchar(10),
	@VehicleHeight			varchar(10),
	@VINDecodedInd			int,
	@AvailableInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@VehicleOriginID		int,
	@CreationDate			datetime,
	@VehicleDestinationID		int,
	@DealerETADate			datetime,
	@BayLocation			varchar(20),
	@DateMadeAvailable		datetime
					
	/************************************************************************
	*	spImportMercedesVehicles					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the MercedesImport table and *
	*	creates the new orders and vehicle records.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	04/04/2005 CMK    Initial version				*
	*	12/02/2005 CMK    Changed VIN found code to update status and 	*
	*	                  not update any vehicle, leg or pool records	*
	*									*
	************************************************************************/
	Select @PreviousOrigin = 0
	Select @PreviousDestination = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @NeedsReviewInd = 0
	
	--get the customer id from the setting table
	Select @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'MercedesCustomerID'
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

	DECLARE MercedesImportCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT MercedesImportID, RecordType, Status, LoadNumber,
		AvailableDate, VIN, VPC, HotCarFlag, OriginDealerCode,
		DestinationDealer, ParkingBayLocation, EquipmentType,
		MessageFlag, ColorCode, ModelDescription, ShopTag,
		Railcar, RetailerCode, Filler, ImportedInd, VehicleYear, 
		Make, Model, Bodystyle, VehicleLength, VehicleWidth,
		VehicleHeight, VINDecodedInd, SpecialHandlingFlag
		FROM MercedesImport
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY OriginDealerCode, DestinationDealer, MercedesImportID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN MercedesImportCursor

	BEGIN TRAN

	FETCH MercedesImportCursor INTO @MercedesImportID, @RecordType, @MIStatus, @LoadNumber,
		@AvailableDate, @VIN, @VPC, @HotCarFlag, @OriginDealerCode,
		@DestinationDealer, @ParkingBayLocation, @EquipmentType,
		@MessageFlag, @ColorCode, @ModelDescription, @ShopTag,
		@Railcar, @RetailerCode, @Filler, @ImportedInd, @VehicleYear, 
		@Make, @Model, @Bodystyle, @VehicleLength, @VehicleWidth,
		@VehicleHeight, @VINDecodedInd, @SpecialHandlingFlag

	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		SELECT @OriginID = NULL
		SELECT @DestinationID = NULL

		--get the destination.
		SELECT @DestinationID = LocationID
		FROM Location
		WHERE ParentRecordID = @CustomerID
		AND ParentRecordTable = 'Customer'
		AND CustomerLocationCode = @DestinationDealer
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
				@DestinationDealer,
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
				SELECT @Status = 'Error Creating Destination Location'
				GOTO Error_Encountered
			END
			ELSE
			BEGIN
				SELECT @DestinationID = @@IDENTITY
			END
		END
		
		--get the Origin
		/*
		SELECT @OriginID = LocationID
		FROM Location
		WHERE ParentRecordID = @CustomerID
		AND ParentRecordTable = 'Customer'
		AND CustomerLocationCode = @OriginRampCode
		*/
		SELECT @OriginID = CONVERT(int,Value1),
		@AvailableInd = CONVERT(int,Value2)
		FROM Code
		WHERE CodeType = 'MercedesLocationCode'
		AND Code = @OriginDealerCode
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
				@OriginDealerCode,
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
			SELECT @AvailableInd = 1
		END

		SELECT @ChargeRate = NULL
		--Need to add logic to check size class. not in this particular file.
		IF LEFT(@ModelDescription,1) = 'G'
		BEGIN
			SELECT @RateClass = 'C'
		END
		ELSE IF LEFT(@ModelDescription,1) IN ('M','R')
		BEGIN
			IF @ModelDescription IN ('M1CA126', 'M1PV126')
			BEGIN
				SELECT @RateClass = 'D'
			END
			ELSE
			BEGIN
				SELECT @RateClass = 'B'
			END
		END
		ELSE
		BEGIN
			SELECT @RateClass = 'A'
		END
		
		--From these values we can get the financial information.
		SELECT @ChargeRate = Rate
		FROM ChargeRate
		WHERE StartLocationID = @OriginID
		AND EndLocationID = @DestinationID
		AND CustomerID = @CustomerID
		AND RateType = 'Size '+@RateClass+' Rate' -- for now
		AND @CreationDate >= StartDate
		AND @CreationDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
		
		IF ISNULL(@SpecialHandlingFlag,'') = 'Y'
		BEGIN
			SELECT @BayLocation = 'A-'+@ParkingBayLocation+'-'+@ShopTag
		END
		ELSE
		BEGIN
			SELECT @BayLocation = @ParkingBayLocation+'-'+@ShopTag
		END
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM Vehicle
		WHERE VIN = @VIN
		AND CustomerID = @CustomerID
		--AND VehicleStatus <> 'Delivered' -- don't need this since any match on the vin will always be for the first move
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
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting vin count'
				GOTO Error_Encountered
			END

			IF @AvailableInd = 1
			BEGIN
				SELECT @AvailableForPickupDate = SUBSTRING(@AvailableDate,5,2)+'/'+SUBSTRING(@AvailableDate,7,2)+'/'+SUBSTRING(@AvailableDate,1,4)
				SELECT @LegStatus = 'Available'
				
				SELECT @DealerETADate = DATEADD(hh,MercdsETA.ETAHOURS,CURRENT_TIMESTAMP)   
				FROM MercedesETA MercdsETA
				WHERE MercdsETA.OriginID = @OriginID AND MercdsETA.DestinationID = @DestinationID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error getting ETA Date'
					GOTO Error_Encountered
				END
			END
			ELSE
			BEGIN
				SELECT @AvailableForPickupDate = NULL
				SELECT @LegStatus = 'Pending'
				SELECT @DealerETADate = NULL
			END
			
			IF @HotCarFlag = '1'
			BEGIN
				SELECT @PriorityInd = 1
			END
			ELSE
			BEGIN
				SELECT @PriorityInd = 0
			END
			--update logic here.
			UPDATE Vehicle
			SET Color = @ColorCode,
			PickupLocationID = @OriginID,
			DropoffLocationID = @DestinationID,
			RailcarNumber = @Railcar,
			CustomerIdentification = @LoadNumber,
			BayLocation = @BayLocation,
			ChargeRate = @ChargeRate,
			AvailableForPickupDate = @AvailableForPickupDate,
			PriorityInd = @PriorityInd,
			DealerETADate = @DealerETADate
			WHERE VehicleID = @VehicleID
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
				--need to find out if the leg status is changing
				SELECT @OldLegStatus = LegStatus,
				@LoadID = LoadID,
				@PoolID = PoolID
				FROM Legs
				WHERE VehicleID = @VehicleID
				AND LegNumber = 1
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error getting old leg status'
					GOTO Error_Encountered
				END
				
				--have legs, so update them
				UPDATE Legs
				SET PickupLocationID = @OriginID,
				LegStatus = @LegStatus,
				DateAvailable = @AvailableForPickupDate
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
				
				--if the leg status has changed, update the pools
				IF @LegStatus <> @OldLegStatus
				BEGIN
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
							'IMPORT'	--CreatedBy
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
					IF @LegStatus = 'Available' AND @OldLegStatus = 'Pending'
					BEGIN
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
						
						UPDATE Legs
						SET PoolID = @PoolID
						WHERE VehicleID = @VehicleID
						AND LegNumber = 1
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @Status = 'Error updating starting leg'
							GOTO Error_Encountered
						END
					END
				END
			END
			ELSE
			BEGIN
				--have to create the legs record
				IF @LegStatus = 'Available'
				BEGIN
					SELECT @DateAvailable = @AvailableForPickupDate
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
				END
				ELSE
				BEGIN
					SELECT @PoolID = NULL
					SELECT @DateAvailable = NULL
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
					@LegStatus,
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
					@LoadNumber,	--PONumber,
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
			IF @HotCarFlag = '1'
			BEGIN
				SELECT @PriorityInd = 1
			END
			ELSE
			BEGIN
				SELECT @PriorityInd = 0
			END
				
			IF @VehicleYear IS NULL OR DATALENGTH(@VehicleYear)<1
			BEGIN
				SELECT @VehicleYear = ''
			END
			IF @Make IS NULL OR DATALENGTH(@Make)<1
			BEGIN
				SELECT @Make = 'Mercedes'
			END
			IF @Model IS NULL OR DATALENGTH(@Model)<1
			BEGIN
				SELECT @Model = @ModelDescription
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
			
			IF @AvailableInd = 1
			BEGIN
				SELECT @AvailableForPickupDate = SUBSTRING(@AvailableDate,5,2)+'/'+SUBSTRING(@AvailableDate,7,2)+'/'+SUBSTRING(@AvailableDate,1,4)
				SELECT @LegStatus = 'Available'
				SELECT @DateMadeAvailable = CURRENT_TIMESTAMP
		
				--SELECT @DealerETADate = CURRENT_TIMESTAMP
				SELECT @DealerETADate = DATEADD(hh,MercdsETA.ETAHOURS,CURRENT_TIMESTAMP)   
				FROM MercedesETA MercdsETA
				WHERE MercdsETA.OriginID = @OriginID AND MercdsETA.DestinationID = @DestinationID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error getting ETA Date'
					GOTO Error_Encountered
				END
			END
			ELSE
			BEGIN
				SELECT @AvailableForPickupDate = NULL
				SELECT @LegStatus = 'Pending'
				SELECT @DealerETADate= NULL
				SELECT @DateMadeAvailable = NULL
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
				DealerETADate,
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
				@ColorCode,			--Color,
				@VehicleLength,			--VehicleLength
				@VehicleWidth,			--VehicleWidth
				@VehicleHeight,			--VehicleHeight
				@OriginID,			--PickupLocationID,
				@DestinationID,			--DropoffLocationID,
				'Pending',			--VehicleStatus,
				'Pickup Point',			--VehicleLocation,
				@LoadNumber,			--CustomerIdentification,
				@RateClass,			--SizeClass,
				@BayLocation,			--BayLocation,
				@Railcar,			--RailCarNumber,
				@PriorityInd,			--PriorityInd
				NULL,				--HaulType,
				@AvailableForPickupDate,	--AvailableForPickupDate,
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
				@DealerETADate,			--DealerETADate
				@DateMadeAvailable		--DateMadeAvailable
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
			IF @LegStatus = 'Available'
			BEGIN
				SELECT @DateAvailable = @AvailableForPickupDate
				
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
			END
			ELSE
			BEGIN
				SELECT @DateAvailable = NULL
				SELECT @PoolID = NULL
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
				@LegStatus,	--LegStatus
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
			SELECT @RecordStatus = 'Imported'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = GetDate()
			SELECT @ImportedBy = @UserCode
		END

		--update logic here.
		UPDATE MercedesImport
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE MercedesImportID = @MercedesImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH MercedesImportCursor INTO @MercedesImportID, @RecordType, @MIStatus, @LoadNumber,
			@AvailableDate, @VIN, @VPC, @HotCarFlag, @OriginDealerCode,
			@DestinationDealer, @ParkingBayLocation, @EquipmentType,
			@MessageFlag, @ColorCode, @ModelDescription, @ShopTag,
			@Railcar, @RetailerCode, @Filler, @ImportedInd, @VehicleYear, 
			@Make, @Model, @Bodystyle, @VehicleLength, @VehicleWidth,
			@VehicleHeight, @VINDecodedInd, @SpecialHandlingFlag

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
		CLOSE MercedesImportCursor
		DEALLOCATE MercedesImportCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE MercedesImportCursor
		DEALLOCATE MercedesImportCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
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
