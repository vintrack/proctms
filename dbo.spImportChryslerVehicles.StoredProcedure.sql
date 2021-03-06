USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportChryslerVehicles]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportChryslerVehicles] (@BatchID int,
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--ChryslerVehicleImport table variables
	@ChryslerVehicleImportID	int,
	@VIN				varchar(17),
	@VehicleDescription		varchar(50),
	@Status				varchar(20),
	@ReceivedDate			datetime,
	@Days				varchar(10),
	@Location			varchar(20),
	@Damage				varchar(20),
	@HoldFlag			varchar(20),
	@Owner				varchar(20),
	@DealerCode			varchar(5),
	@LanguageCode			varchar(20),
	@RailcarNumber			varchar(20),
	@DestinationRamp		varchar(20),
	@Comments			varchar(100),
	@ImportedInd			int,
	--processing variables
	@PlantCode			varchar(1),
	@VINSquish			varchar(10),
	@VINCOUNT			int,
	@OldLegStatus			varchar(20),
	@OldVehicleStatus		varchar(20),
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
	@ImportStatus			varchar(100),
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
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@CreationDate			datetime,
	@VehicleOriginID		int,
	@VehicleDestinationID		int,
	@ColorCode			varchar(20),
	@ReleaseCode			varchar(20)

	/************************************************************************
	*	spImportChryslerVehicles					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the ChryslerVehicleImport	*
	*	table and creates the new orders and vehicle records.		*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/01/2005 CMK    Initial version				*
	*									*
	************************************************************************/
	SELECT @PreviousOrigin = 0
	SELECT @PreviousDestination = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP

	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ChryslerCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @ImportStatus = 'Error Getting CustomerID'
		GOTO Error_Encountered2
	END
	IF @CustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @ImportStatus = 'CustomerID Not Found'
		GOTO Error_Encountered2
	END

	DECLARE ChryslerVehicleImportCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT ChryslerVehicleImportID,VIN,VehicleDescription,Status,
		CONVERT(varchar(10),ReceivedDate,101),Days,Location,Damage,HoldFlag,Owner,DealerCode,LanguageCode,
		RailcarNumber,DestinationRamp,Comments,ImportedInd,ImportedDate,ImportedBy,
		RecordStatus,VehicleYear,Make,Model,Bodystyle,VehicleLength,VehicleWidth,
		VehicleHeight,VINDecodedInd
		FROM ChryslerVehicleImport
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY DestinationRamp, DealerCode, ChryslerVehicleImportID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	SELECT @ReleaseCode = 'SA'

	OPEN ChryslerVehicleImportCursor

	BEGIN TRAN

	FETCH ChryslerVehicleImportCursor INTO @ChryslerVehicleImportID,@VIN,@VehicleDescription,@Status,
		@ReceivedDate,@Days,@Location,@Damage,@HoldFlag,@Owner,@DealerCode,@LanguageCode,
		@RailcarNumber,@DestinationRamp,@Comments,@ImportedInd,@ImportedDate,@ImportedBy,
		@RecordStatus,@VehicleYear,@Make,@Model,@Bodystyle,@VehicleLength,@VehicleWidth,
		@VehicleHeight,@VINDecodedInd

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
		AND (CustomerLocationCode = @DealerCode
		OR CustomerLocationCode = '0'+@DealerCode)
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @ImportStatus = 'Error Getting Destination Location ID'
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
				@DealerCode,
				0,
				0,
				0,
				0,
				0,
				0,
				0,
				'Active',
				@CreationDate,
				'ChryslerImport',
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
				SELECT @ImportStatus = 'Error Creating Drop Location'
				GOTO Error_Encountered
			END
			ELSE
			BEGIN
				SELECT @DestinationID = @@IDENTITY
			END
		END
				
		--get the Origin
		SELECT @OriginID = CONVERT(int,Value1)
		FROM Code
		WHERE CodeType = 'ChryslerRailheadCode'
		AND Code = @DestinationRamp
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @ImportStatus = 'Error origin id'
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
				@DestinationRamp,
				0,
				0,
				0,
				0,
				0,
				0,
				'Active',
				@CreationDate,
				'ChryslerImport',
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
				SELECT @ImportStatus = 'ERROR CREATING DESTINATION LOCATION'
				GOTO Error_Encountered
			END
			SELECT @OriginID = @@Identity
		END

		SELECT @ChargeRate = NULL
		SELECT @PlantCode = SUBSTRING(@VIN,11,1)
		SELECT @VINSquish = SUBSTRING(@VIN,1,8)+SUBSTRING(@VIN,10,2)
		
		IF @PlantCode IN ('D','H','T','P','M','Z','0','7')
		BEGIN
			IF SUBSTRING(@Model,1,7) IN ('Journey', 'Cheroke', 'Stelvio') OR @VINSquish = '3C4PDDAGET'
			BEGIN
				SELECT @RateClass = 'B'
			END
			ELSE
			BEGIN
				SELECT @RateClass = 'A'
			END
		END
		ELSE IF @PlantCode IN ('B','C','R','W','L','6')
		BEGIN
			SELECT @RateClass = 'B'
		END
		ELSE IF @PlantCode IN ('F','G','J','N','S','E')
		BEGIN
			SELECT @RateClass = 'C'
		END
		ELSE
		BEGIN
			SELECT @RateClass = NULL
		END
		--From these values we can get the financial information.
		--Need to add logic to check size class. not in this particular file.
		SELECT @ChargeRate = Rate
		FROM ChargeRate
		WHERE StartLocationID = @OriginID
		AND EndLocationID = @DestinationID
		AND CustomerID = @CustomerID
		AND RateType = 'Size '+@RateClass+' Rate' -- for now
		AND @CreationDate >= StartDate
		AND @CreationDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
		
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM Vehicle
		WHERE VIN = @VIN
		AND CustomerID = @CustomerID
		--AND CustomerIdentification = @D6Number
		--AND VehicleStatus <> 'Delivered' -- don't need this since any match on the vin will always be for the first move
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @ImportStatus = 'Error getting vin count'
			GOTO Error_Encountered
		END

		IF @VINCOUNT > 0
		BEGIN
			--get the vehicle id
			SELECT TOP 1 @VehicleID = V.VehicleID,
			@VehicleOriginID = V.PickupLocationID,
			@VehicleDestinationID = V.DropoffLocationID,
			@OldLegStatus = L.LegStatus
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			WHERE V.VIN = @VIN
			AND V.CustomerID = @CustomerID
			--AND CustomerIdentification = @D6Number
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @ImportStatus = 'Error getting vin count'
				GOTO Error_Encountered
			END

			IF @OldLegStatus = 'OnHold'
			BEGIN
				SELECT @AvailableForPickupDate = NULL
				SELECT @LegStatus = 'OnHold'
			END
			ELSE
			BEGIN
				SELECT @AvailableForPickupDate = @ReceivedDate
				SELECT @LegStatus = 'Available'
			END
			
			IF @OldLegStatus <> 'Pending'
			BEGIN
				SELECT @RecordStatus = 'VEHICLE IS NOT PENDING'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Do_Update
			END
			ELSE IF @OriginID <> @VehicleOriginID
			BEGIN
				SELECT @RecordStatus = 'ORIGIN MISMATCH'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Do_Update
			END
			ELSE IF @DestinationID <> @VehicleDestinationID
			BEGIN
				SELECT @RecordStatus = 'DESTINATION MISMATCH'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Do_Update
			END
			
			
			--update logic here.
			UPDATE Vehicle
			SET --Color = @ColorCode,
			PickupLocationID = @OriginID,
			DropoffLocationID = @DestinationID,
			RailcarNumber = @RailcarNumber,
			--BayLocation = @BayLocation,
			--CustomerIdentification = @D6Number,
			ChargeRate = @ChargeRate,
			AvailableForPickupDate = @AvailableForPickupDate
			WHERE VehicleID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @ImportStatus = 'ERROR UPDATING VEHICLE RECORD'
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
				SELECT @ImportStatus = 'Error getting Legs count'
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
					SELECT @ImportStatus = 'Error getting old leg status'
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
					SELECT @ImportStatus = 'Error updating starting leg'
					GOTO Error_Encountered
				END

				UPDATE Legs
				SET DropoffLocationID = @DestinationID
				WHERE VehicleID = @VehicleID
				AND FinalLegInd = 1
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @ImportStatus = 'Error updating ending leg'
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
						SELECT @ImportStatus = 'ERROR GETTING POOL RECORD COUNT'
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
							0,			--PoolSize
							0,			--Reserved
							0,			--Available
							@CreationDate,		--CreationDate
							'ChryslerImport'	--CreatedBy
						)
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @ImportStatus = 'ERROR CREATING POOL RECORD'
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
							SELECT @ImportStatus = 'ERROR GETTING POOL ID'
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
							SELECT @ImportStatus = 'ERROR UPDATING POOL RECORD'
							GOTO Error_Encountered
						END
						
						UPDATE Legs
						SET PoolID = @PoolID
						WHERE VehicleID = @VehicleID
						AND LegNumber = 1
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @ImportStatus = 'Error updating starting leg'
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
						SELECT @ImportStatus = 'ERROR GETTING POOL RECORD COUNT'
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
							1,			--PoolSize
							0,			--Reserved
							1,			--Available
							@CreationDate,		--CreationDate
							'ChryslerImport'	--CreatedBy
						)
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @ImportStatus = 'ERROR CREATING POOL RECORD'
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
							SELECT @ImportStatus = 'ERROR GETTING POOL ID'
							GOTO Error_Encountered
						END
						
						UPDATE VehiclePool
						SET PoolSize = PoolSize + 1,
						Available = Available + 1
						WHERE VehiclePoolID = @PoolID
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @ImportStatus = 'ERROR UPDATING POOL RECORD'
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
					0, 			--OutsideCarrierLegInd
					0, 			--OutsideCarrierPaymentMethod
					0, 			--OutsideCarrierPercentage
					0, 			--OutsideCarrierPay
					0,			--OutsideCarrierFuelSurchargePercentage
					0,			--OCFSPEstablishedInd
					1, 			--LegNumber
					1, 			--FinalLegInd
					@LegStatus,
					0,			--ShagUnitInd
					@CreationDate, 		--CreationDate
					'ChryslerImport', 	--CreatedBy
					0			--OutsideCarrierFuelSurchargeType
				)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @ImportStatus = 'ERROR CREATING DEFAULT LEG'
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
					SELECT @ImportStatus = 'ERROR UPDATING Application Constants'
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
					'ChryslerImport',	--CreatedBy,
					NULL,		--UpdatedDate,
					NULL		--UpdatedBy
				)

				--need to get the orderId key here, to insert into the vehicle record.			
				SELECT @OrderID = @@identity
			END

			--and now do the vehicle
			/*
			IF @CommitFlag = 'Y'
			BEGIN
				SELECT @PriorityInd = 1
			END
			ELSE
			BEGIN
			*/
			
			SELECT @PriorityInd = 0
			
			--END
				
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
				SELECT @Model = @VehicleDescription
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
			SELECT @ColorCode = ''
			SELECT @AvailableForPickupDate = @ReceivedDate
			SELECT @LegStatus = 'Available'
						
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
				@ColorCode,			--Color,
				@VehicleLength,			--VehicleLength
				@VehicleWidth,			--VehicleWidth
				@VehicleHeight,			--VehicleHeight
				@OriginID,			--PickupLocationID,
				@DestinationID,			--DropoffLocationID,
				'Pending',			--VehicleStatus,
				'Pickup Point',			--VehicleLocation,
				'',				--CustomerIdentification,
				@RateClass,			--SizeClass,
				@Location,			--BayLocation,
				@RailcarNumber,			--RailCarNumber,
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
				@CreationDate,			--CreationDate
				'ChryslerImport',		--CreatedBy
				NULL,				--UpdatedDate,
				NULL,				--UpdatedBy
				0,				--CreditHoldInd
				@ReleaseCode,			--ReleaseCode
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
				SELECT @ImportStatus = 'ERROR CREATING VEHICLE RECORD'
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
					SELECT @ImportStatus = 'ERROR GETTING POOL RECORD COUNT'
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
						'ChryslerImport'	--CreatedBy
					)
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @ImportStatus = 'ERROR CREATING POOL RECORD'
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
						SELECT @ImportStatus = 'ERROR GETTING POOL ID'
						GOTO Error_Encountered
					END
					
					UPDATE VehiclePool
					SET PoolSize = PoolSize + 1,
					Available = Available + 1
					WHERE VehiclePoolID = @PoolID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @ImportStatus = 'ERROR UPDATING POOL RECORD'
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
				@VehicleID,		--VehicleID
				@PoolID,
				@DateAvailable,
				@OriginID,		--PickupLocationID
				@DestinationID,		--DropoffLocationID
				0,			--OutsideCarrierLegInd
				0,			--OutsideCarrierPaymentMethod
				0,			--OutsideCarrierPercentage
				0,			--OutsideCarrierPay
				0,			--OutsideCarrierFuelSurchargePercentage
				0,			--OCFSPEstablishedInd
				1,			--LegNumber
				1,			--FinalLegInd
				@LegStatus,		--LegStatus
				0,			--ShagUnitInd
				@CreationDate,		--CreationDate
				'ChryslerImport',	--CreatedBy
				0			--OutsideCarrierFuelSurchargeType
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @ImportStatus = 'ERROR CREATING DEFAULT LEG'
				GOTO Error_Encountered
			END
			SELECT @RecordStatus = 'Imported'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = GetDate()
			SELECT @ImportedBy = @UserCode
		END

		--update logic here.
		Do_Update:
		UPDATE ChryslerVehicleImport
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE ChryslerVehicleImportID = @ChryslerVehicleImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @ImportStatus = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH ChryslerVehicleImportCursor INTO @ChryslerVehicleImportID,@VIN,@VehicleDescription,@Status,
			@ReceivedDate,@Days,@Location,@Damage,@HoldFlag,@Owner,@DealerCode,@LanguageCode,
			@RailcarNumber,@DestinationRamp,@Comments,@ImportedInd,@ImportedDate,@ImportedBy,
			@RecordStatus,@VehicleYear,@Make,@Model,@Bodystyle,@VehicleLength,@VehicleWidth,
			@VehicleHeight,@VINDecodedInd

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
		CLOSE ChryslerVehicleImportCursor
		DEALLOCATE ChryslerVehicleImportCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ChryslerVehicleImportCursor
		DEALLOCATE ChryslerVehicleImportCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @ImportStatus
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
			SELECT @ReturnMessage = @ImportStatus
			GOTO Do_Return
	END
	
	Do_Return:
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage
	
	RETURN
END
GO
