USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportNissanPL]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportNissanPL] (@BatchID int,
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--NissanImportPL table variables
	@NissanImportPLID		int,
	@RecordType			varchar(2),
	@HoldFlag			varchar(1),
	@VIN				varchar(17),
	@D6Number			varchar(6),
	@BillingTCode			varchar(5),
	@ModelLine			varchar(3),
	@ModelCode			varchar(5),
	@ColorCode			varchar(3),
	@ShipToDealer			varchar(5),
	@RampCode			varchar(3),
	@BayLocation			varchar(6),
	@EstimateTenderDate		varchar(8),
	@EstimateTenderTime		varchar(4),
	@ActualTenderDate		varchar(8),
	@ActualTenderTime		varchar(4),
	@CommitFlag			varchar(1),
	@EstimatedYardExitDate		varchar(8),
	@EstimatedYardExitTime		varchar(4),
	@ActualYardExitDate		varchar(8),
	@ActualYardExitTime		varchar(4),
	@DealerETA			varchar(8),
	@CustomerPreferenceName		varchar(20),
	@DropShipName			varchar(20),
	@DropShipAddress		varchar(25),
	@DropShipCity			varchar(22),
	@DropShipState			varchar(2),
	@DropShipZip			varchar(5),
	@FleetWindowStart		varchar(8),
	@FleetWindowEnd			varchar(8),
	@DealerMessage1			varchar(18),
	@DealerMessage2			varchar(24),
	@DealerMessage3			varchar(24),
	@DealerMessage4			varchar(24),
	@InboundConveyance		varchar(10),
	@OriginRampCode			varchar(3),
	@OriginDepartureDate		varchar(8),
	@EstimatedOngroundDate		varchar(8),
	@EstimatedOngroundTime		varchar(4),
	@ActualOngroundDate		varchar(8),
	@ActualOngroundTime		varchar(4),
	@ImportedInd			int,
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
	@VehicleOriginID		int,
	@VehiclePoolID			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@CreationDate			datetime,
	@VehicleDestinationID		int,
	@Count				int

	/************************************************************************
	*	spImportNissanPL						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the NissanImportPL table and *
	*	creates the new orders and vehicle records.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/28/2005 CMK    Initial version				*
	*	03/31/2011 CMK    Origin/Destination Change Handling		*
	*									*
	************************************************************************/
	SELECT @PreviousOrigin = 0
	SELECT @PreviousDestination = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @NeedsReviewInd = 0
	
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

	DECLARE NissanPLCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT NissanImportPLID, RecordType, HoldFlag, VIN, D6Number,
		BillingTCode, ModelLine, ModelCode, ColorCode, ShipToDealer, RampCode,
		BayLocation, EstimateTenderDate, EstimateTenderTime, ActualTenderDate,
		ActualTenderTime, CommitFlag, EstimatedYardExitDate, EstimatedYardExitTime,
		ActualYardExitDate, ActualYardExitTime, DealerETA, CustomerPreferenceName,
		DropShipName, DropShipAddress, DropShipCity, DropShipState, DropShipZip,
		FleetWindowStart, FleetWindowEnd, DealerMessage1, DealerMessage2,
		DealerMessage3, DealerMessage4, InboundConveyance, OriginRampCode,
		OriginDepartureDate, EstimatedOngroundDate, EstimatedOngroundTime,
		ActualOngroundDate, ActualOngroundTime, ImportedInd, VehicleYear, 
		Make, Model, Bodystyle, VehicleLength, VehicleWidth,
		VehicleHeight, VINDecodedInd
		FROM NissanImportPL
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY RampCode, ShipToDealer, DropShipName, DropShipAddress, NissanImportPLID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN NissanPLCursor

	BEGIN TRAN

	FETCH NissanPLCursor INTO @NissanImportPLID, @RecordType, @HoldFlag, @VIN, @D6Number,
		@BillingTCode, @ModelLine, @ModelCode, @ColorCode, @ShipToDealer, @RampCode,
		@BayLocation, @EstimateTenderDate, @EstimateTenderTime, @ActualTenderDate,
		@ActualTenderTime, @CommitFlag, @EstimatedYardExitDate, @EstimatedYardExitTime,
		@ActualYardExitDate, @ActualYardExitTime, @DealerETA, @CustomerPreferenceName,
		@DropShipName, @DropShipAddress, @DropShipCity, @DropShipState, @DropShipZip,
		@FleetWindowStart, @FleetWindowEnd, @DealerMessage1, @DealerMessage2,
		@DealerMessage3, @DealerMessage4, @InboundConveyance, @OriginRampCode,
		@OriginDepartureDate, @EstimatedOngroundDate, @EstimatedOngroundTime,
		@ActualOngroundDate, @ActualOngroundTime, @ImportedInd, @VehicleYear, 
		@Make, @Model, @Bodystyle, @VehicleLength, @VehicleWidth,
		@VehicleHeight, @VINDecodedInd

	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @OriginID = NULL
		SELECT @DestinationID = NULL

		IF DATALENGTH(LTRIM(RTRIM(@DropShipName)))>0
		BEGIN
			SELECT TOP 1 @DestinationID = LocationID
			FROM Location 
			WHERE AddressLine1 = @DropShipAddress
			AND City = @DropShipCity
			AND State = @DropShipState
			AND Zip = @DropShipZip 
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
					@DropShipName,
					@DropShipAddress,
					@DropShipCity,
					@DropShipState,
					@DropShipZip,
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
					'NissanPL',
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
			--get the destination.
			SELECT @DestinationID = LocationID
			FROM Location
			WHERE ParentRecordID = @CustomerID
			AND ParentRecordTable = 'Customer'
			AND (CustomerLocationCode = @ShipToDealer
			OR CustomerLocationCode = '0'+@ShipToDealer)
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
					@ShipToDealer,
					0,
					0,
					0,
					0,
					0,
					0,
					0,
					'Active',
					getDate(),
					'NissanPL',
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
		
		--get the Origin
		/*
		SELECT @OriginID = LocationID
		FROM Location
		WHERE ParentRecordID = @CustomerID
		AND ParentRecordTable = 'Customer'
		AND CustomerLocationCode = @OriginRampCode
		*/
		SELECT @OriginID = CONVERT(int,Value1)
		FROM Code
		WHERE CodeType = 'NissanRailheadCode'
		AND Code = @OriginRampCode
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
				@OriginRampCode,
				0,
				0,
				0,
				0,
				0,
				0,
				'Active',
				GetDate(),
				'NissanPL',
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
		--SELECT @RateClass = SUBSTRING(@BillingTCode,5,1)
		
		IF @ModelLine = 'NV2'
		BEGIN
			SELECT @RateClass = 'B'
		END
		ELSE IF DATALENGTH(@BillingTCode) = 5
		BEGIN
			SELECT @RateClass = SUBSTRING(@BillingTCode,5,1)
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
		AND RateType = 'Size '+@RateClass+' Rate'
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
			SELECT @Status = 'Error getting vin count'
			GOTO Error_Encountered
		END

		IF @VINCOUNT > 0
		BEGIN
			--get the vehicle id
			SELECT @VehicleID = V.VehicleID,
			@VehicleOriginID = V.PickupLocationID,
			@VehicleDestinationID = V.DropoffLocationID,
			@VehiclePoolID = L.PoolID,
			@OldLegStatus = L.LegStatus
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			AND L.LegNumber = 1
			WHERE V.VIN = @VIN
			AND V.CustomerID = @CustomerID
			--AND V.CustomerIdentification = @D6Number
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting vin count'
				GOTO Error_Encountered
			END
			
			IF @OldLegStatus <> 'Pending'
			BEGIN
				SELECT @RecordStatus = 'VEHICLE IS NOT PENDING'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Do_Update
			END
			
			/*
			IF @HoldFlag = 'Y' OR @ActualTenderDate = '00000000'
			BEGIN
				SELECT @AvailableForPickupDate = NULL
				SELECT @LegStatus = 'Pending'
			END
			ELSE
			BEGIN
				SELECT @AvailableForPickupDate = SUBSTRING(@ActualTenderDate,5,2)+'/'+SUBSTRING(@ActualTenderDate,7,2)+'/'+SUBSTRING(@ActualTenderDate,1,4)
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
			
			IF @AvailableForPickupDate IS NOT NULL
			BEGIN
				-- if there is an existing pool id, reduce the available count
				IF @VehiclePoolID IS NOT NULL
				BEGIN
					UPDATE VehiclePool
					SET PoolSize = PoolSize - 1,
					Available = Available - 1
					WHERE VehiclePoolID = @VehiclePoolID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING POOL RECORD'
						GOTO Error_Encountered
					END
				END
						
				-- get/create the new pool id
				SELECT @Count = COUNT(*)
				FROM VehiclePool
				WHERE OriginID = @OriginID
				AND DestinationID = @DestinationID 
				AND CustomerID = @CustomerID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING POOL COUNT'
					GOTO Error_Encountered
				END
									
				IF @Count > 0
				BEGIN
					--get the pool id
					SELECT TOP 1 @PoolID = VehiclePoolID
					FROM VehiclePool
					WHERE OriginID = @OriginID
					AND DestinationID = @DestinationID 
					AND CustomerID = @CustomerID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR GETTING POOL ID'
						GOTO Error_Encountered
					END
							
					--update the pool size and available count
					UPDATE VehiclePool
					SET PoolSize = PoolSize + 1,
					Available = Available + 1,
					UpdatedDate = CURRENT_TIMESTAMP,
					UpdatedBy = 'Toyota Tender'
					WHERE VehiclePoolID = @PoolID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING POOL RECORD'
						GOTO Error_Encountered
					END
				END
				ELSE
				BEGIN
					--create the pool
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
						1,
						0,
						1,
						CURRENT_TIMESTAMP,
						'Nissan PL'
					)
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR CREATING POOL RECORD'
						GOTO Error_Encountered
					END
						
					SELECT @PoolID = @@IDENTITY
				END
			END
			ELSE
			BEGIN
				SELECT @PoolID = NULL
			END
			*/	
			-- start of origin/destination change code
			IF @OriginID <> @VehicleOriginID OR @DestinationID <> @VehicleDestinationID
			BEGIN
				-- update the vehicle record to make the vehicle available and set the new destination
				UPDATE Vehicle
				SET Color = @ColorCode,
				PickupLocationID = @OriginID,
				DropoffLocationID = @DestinationID,
				RailcarNumber = @InboundConveyance,
				ChargeRate = @ChargeRate,
				CustomerIdentification = @D6Number,
				SizeClass = @RateClass,
				--BayLocation = @BayLocation,
				--VehicleStatus = @LegStatus,
				--AvailableForPickupDate = @AvailableForPickupDate,
				UpdatedBy = 'Nissan PL',
				UpdatedDate = CURRENT_TIMESTAMP
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
					GOTO Error_Encountered
				END
				
				-- update the leg record, set the new pool id, make the leg available and set the new destination
				UPDATE Legs
				SET --PoolID = @PoolID,
				PickupLocationID = @OriginID,
				DropoffLocationID = @DestinationID,
				--DateAvailable = @AvailableForPickupDate,
				--LegStatus = @LegStatus,
				UpdatedDate = CURRENT_TIMESTAMP,
				UpdatedBy = 'Nissan PL'
				WHERE VehicleID = @VehicleID
				AND LegNumber = 1
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING LEG RECORD'
					GOTO Error_Encountered
				END
							
				IF @OriginID <> @VehicleOriginID AND @DestinationID <> @VehicleDestinationID
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'ORIGIN & DESTINATION UPDATED'
				END
				ELSE IF @OriginID <> @VehicleOriginID
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'ORIGIN UPDATED'
				END
					ELSE IF @DestinationID <> @VehicleDestinationID
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'DESTINATION UPDATED'
				END
				
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = GetDate()
				SELECT @ImportedBy = @UserCode
				GOTO Do_Update
			END
			--end of update origin/destination code
			--update logic here.
			UPDATE Vehicle
			SET Color = @ColorCode,
			--PickupLocationID = @OriginID,
			--DropoffLocationID = @DestinationID,
			RailcarNumber = @InboundConveyance,
			ChargeRate = @ChargeRate,
			CustomerIdentification = @D6Number,
			SizeClass = @RateClass,
			--BayLocation = @BayLocation,
			--VehicleStatus = @LegStatus,
			--AvailableForPickupDate = @AvailableForPickupDate,
			UpdatedBy = 'Nissan PL',
			UpdatedDate = CURRENT_TIMESTAMP,
			EstimatedReleaseDate = SUBSTRING(@EstimateTenderDate,5,2)+'/'+SUBSTRING(@EstimateTenderDate,7,2)+'/'+SUBSTRING(@EstimateTenderDate,1,4)
			WHERE VehicleID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
				GOTO Error_Encountered
			END
			/*
			--update any legs records
			UPDATE Legs
			SET --PoolID = @PoolID,
			--PickupLocationID = @OriginID,
			--DropoffLocationID = @DestinationID,
			--DateAvailable = @AvailableForPickupDate,
			--LegStatus = @LegStatus,
			UpdatedDate = CURRENT_TIMESTAMP,
			UpdatedBy = 'Nissan PL'
			WHERE VehicleID = @VehicleID
			AND LegNumber = 1
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING LEG RECORD'
				GOTO Error_Encountered
			END
			*/
			SELECT @RecordStatus = 'VEHICLE UPDATED'
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
					'NissanPL',	--CreatedBy,
					NULL,		--UpdatedDate,
					NULL		--UpdatedBy
				)

				--need to get the orderId key here, to insert into the vehicle record.			
				SELECT @OrderID = @@identity
			END

			--and now do the vehicle
			IF @CommitFlag = 'Y'
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
				SELECT @Make = 'Nissan'
			END
			IF @Model IS NULL OR DATALENGTH(@Model)<1
			BEGIN
				SELECT @Model = @ModelLine
			END
			IF @Bodystyle IS NULL OR DATALENGTH(@Bodystyle)<1
			BEGIN
				SELECT @Bodystyle = @ModelCode
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
			
			--IF @HoldFlag = 'Y' OR @ActualTenderDate = '00000000'
			--BEGIN
				SELECT @AvailableForPickupDate = NULL
				SELECT @LegStatus = 'Pending'
			--END
			--ELSE
			--BEGIN
			--	SELECT @AvailableForPickupDate = SUBSTRING(@ActualTenderDate,5,2)+'/'+SUBSTRING(@ActualTenderDate,7,2)+'/'+SUBSTRING(@ActualTenderDate,1,4)
			--	SELECT @LegStatus = 'Available'
			--END
			
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
				@ColorCode,			--Color,
				@VehicleLength,			--VehicleLength
				@VehicleWidth,			--VehicleWidth
				@VehicleHeight,			--VehicleHeight
				@OriginID,			--PickupLocationID,
				@DestinationID,			--DropoffLocationID,
				@LegStatus,			--VehicleStatus,
				'Pickup Point',			--VehicleLocation,
				@D6Number,			--CustomerIdentification,
				@RateClass,			--SizeClass,
				@BayLocation,			--BayLocation,
				@InboundConveyance,		--RailCarNumber,
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
				'NissanPL',			--CreatedBy
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
				SUBSTRING(@EstimateTenderDate,5,2)+'/'+SUBSTRING(@EstimateTenderDate,7,2)+'/'+SUBSTRING(@EstimateTenderDate,1,4) --EstimatedReleaseDate
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
						'NissanPL'	--CreatedBy
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
				SELECT @LegStatus = 'Pending'
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
				'NissanPL',	--CreatedBy
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
		Do_Update:
		UPDATE NissanImportPL
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE NissanImportPLID = @NissanImportPLID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH NissanPLCursor INTO @NissanImportPLID, @RecordType, @HoldFlag, @VIN, @D6Number,
			@BillingTCode, @ModelLine, @ModelCode, @ColorCode, @ShipToDealer, @RampCode,
			@BayLocation, @EstimateTenderDate, @EstimateTenderTime, @ActualTenderDate,
			@ActualTenderTime, @CommitFlag, @EstimatedYardExitDate, @EstimatedYardExitTime,
			@ActualYardExitDate, @ActualYardExitTime, @DealerETA, @CustomerPreferenceName,
			@DropShipName, @DropShipAddress, @DropShipCity, @DropShipState, @DropShipZip,
			@FleetWindowStart, @FleetWindowEnd, @DealerMessage1, @DealerMessage2,
			@DealerMessage3, @DealerMessage4, @InboundConveyance, @OriginRampCode,
			@OriginDepartureDate, @EstimatedOngroundDate, @EstimatedOngroundTime,
			@ActualOngroundDate, @ActualOngroundTime, @ImportedInd, @VehicleYear, 
			@Make, @Model, @Bodystyle, @VehicleLength, @VehicleWidth,
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
		CLOSE NissanPLCursor
		DEALLOCATE NissanPLCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE NissanPLCursor
		DEALLOCATE NissanPLCursor
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
