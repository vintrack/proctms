USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportFordFAPSRelease]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spImportFordFAPSRelease] (@BatchID int,@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@ErrorEncountered		varchar(5000),
	@loopcounter			int,
	@FordImportFAPSReleaseID	int,
	@VIN				varchar(17),
	@ShipToDealer			varchar(10),
	@ModelName			varchar(10),
	@ColorName			varchar(10),
	@BayLocation			varchar(20),
	@ReleaseDate			datetime,
	@VINCOUNT			int,
	@VehicleID			int,
	@VehicleStatus			varchar(20),
	@LegStatus			varchar(20),
	@Status				varchar(50),
	@RecordStatus			varchar(100),
	@ImportedInd			int,
	@NewImportedInd			int,
	@CustomerID			int,
	@VehicleBayLocation		varchar(20),
	@VehicleOriginID		int,
	@VehicleDestinationID		int,
	@VehiclePoolID			int,
	@VehicleLoadID			int,
	@SizeClass			varchar(10),
	@CustomerIdentification		varchar(25),
	@OriginID			int,
	@DestinationID			int,
	@PoolID				int,
	@LoadID				int,
	@Count				int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@PortCode			varchar(3),
	@CarrierID			varchar(3),
	@Voyage				varchar(10),
	@DestinationCode		varchar(20),
	@ChargeRate			decimal(19,2),
	@CreationDate			datetime,
	@NeedsReviewInd			int,
	@DateMadeAvailable		datetime,
	@VehicleYear			varchar(6),
	@Make				varchar(50),
	@Model				varchar(50),
	@Bodystyle			varchar(50),
	@VehicleLength			varchar(10),
	@VehicleWidth			varchar(10),
	@VehicleHeight			varchar(10),
	@VINDecodedInd			int,
	@PlantCode			varchar(1),
	@VINBodyType			varchar(1),
	@VehicleType			varchar(1),
	@FordCustomerID			int,
	@GMCustomerID			int,
	@VolvoCustomerID		int,
	@PreviousOrigin			int,
	@PreviousDestination		int,
	@OrderID			int,
	@TotalOrderUnits		int,
	@TotalOrderChargeRate		decimal(19,2),
	@OrderNumber			int,
	@OrderNumberPlusOne		int			

	/************************************************************************
	*	spImportFordFAPSRelease						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the FordImportFAPSRelease	*
	*	table and updates the vehicle records with the availability	*
	*	information.							*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	04/16/2014 CMK    Initial version				*
	*									*
	************************************************************************/

	-- get the origin
	SELECT TOP 1 @OriginID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'FordFAPSLocationID'
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Origin ID'
		GOTO Error_Encountered2
	END
	IF @OriginID IS NULL
	BEGIN
		SELECT @ErrorID = 100000
		SELECT @Status = 'Error Getting Origin ID'
		GOTO Error_Encountered2
	END
	
	-- get the ford customerid
	SELECT TOP 1 @FordCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'FordCustomerID'
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Ford Customer ID'
		GOTO Error_Encountered2
	END
	IF @FordCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Error Getting Ford Customer ID'
		GOTO Error_Encountered2
	END
	
	-- get the gm customerid
	SELECT TOP 1 @GMCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'GMCustomerID'
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting GM Customer ID'
		GOTO Error_Encountered2
	END
	IF @GMCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Status = 'Error Getting GM Customer ID'
		GOTO Error_Encountered2
	END
	
	-- get the volvo customerid
	SELECT TOP 1 @VolvoCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'VolvoCustomerID'
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Volvo Customer ID'
		GOTO Error_Encountered2
	END
	IF @VolvoCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Status = 'Error Getting Volvo Customer ID'
		GOTO Error_Encountered2
	END
	
	DECLARE FAPSReleaseCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT FordImportFAPSReleaseID, VIN, ShipToDealer, ModelName,
		ColorName, CurLot+'-'+CurSec+'-'+CurRow+'-'+CurSpt, ReleaseDate,
		VehicleYear, Make, Model, Bodystyle, VehicleLength, VehicleWidth, VehicleHeight, VINDecodedInd
		FROM FordImportFAPSRelease
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY FordImportFAPSReleaseID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP

	OPEN FAPSReleaseCursor

	BEGIN TRAN

	SELECT @PreviousOrigin = 0
	SELECT @PreviousDestination = 0
	SELECT @NeedsReviewInd = 0
	
	FETCH FAPSReleaseCursor INTO @FordImportFAPSReleaseID, @VIN, @ShipToDealer, @ModelName,
		@ColorName, @BayLocation, @ReleaseDate,
		@VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength, @VehicleWidth, @VehicleHeight, @VINDecodedInd
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		SELECT @NewImportedInd = 0
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM Vehicle
		WHERE VIN = @VIN
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error getting vin count'
			GOTO Error_Encountered
		END
		
		IF @VINCOUNT = 1
		BEGIN
			--make sure the vin is not en route or delivered
			SELECT TOP 1 @CustomerID = V.CustomerID, @VehicleID = V.VehicleID, @VehicleStatus = V.VehicleStatus,
			@LegStatus = L.LegStatus, @VehicleOriginID = V.PickupLocationID,
			@VehicleDestinationID = V.DropoffLocationID, @VehiclePoolID = L.PoolID,
			@VehicleLoadID = L.LoadID, @SizeClass = V.SizeClass
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			WHERE V.VIN = @VIN
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING VEHICLE STATUS'
				GOTO Error_Encountered
			END
			
			IF @VehicleStatus = 'Damaged' OR @LegStatus = 'Pending Repair'
			BEGIN
				--update the vehicle status
				UPDATE Vehicle
				SET VehicleStatus = 'Available',
				BayLocation = @BayLocation,
				UpdatedBy = 'FAPS IMPORT',
				UpdatedDate = CURRENT_TIMESTAMP
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
					GOTO Error_Encountered
				END
				
				--update the leg status
				UPDATE Legs
				SET LegStatus = 'Available',
				UpdatedDate = CURRENT_TIMESTAMP,
				UpdatedBy = 'FAPS Import'
				WHERE VehicleID = @VehicleID
				AND LegNumber = 1
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR CREATING POOL RECORD'
					GOTO Error_Encountered
				END
				
				SELECT @NewImportedInd = 1
				SELECT @RecordStatus = 'Re-Released'
				GOTO Update_Record_Status
			
			END
			ELSE IF @VehicleStatus = 'OnHold'
			BEGIN
				--update the vehicle status
				UPDATE Vehicle
				SET BayLocation = @BayLocation,
				UpdatedBy = 'FAPS IMPORT',
				UpdatedDate = CURRENT_TIMESTAMP
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
					GOTO Error_Encountered
				END
				
				SELECT @NewImportedInd = 1
				SELECT @RecordStatus = 'On Hold - Bay Updated'
				GOTO Update_Record_Status
			END
			ELSE IF @VehicleStatus <> 'Pending' OR @LegStatus <> 'Pending'
			BEGIN
				SELECT @RecordStatus = 'VEHICLE IS NOT PENDING'
				GOTO Update_Record_Status
			END
			/*
			-- check the origin and destination
			--get the destination.
			SELECT @DestinationCode = CustomerLocationCode
			FROM Location
			WHERE LocationID = @VehicleDestinationID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING DESTINATION LOCATION'
				GOTO Error_Encountered
			END
			
			IF @OriginID <> @VehicleOriginID OR @DestinationCode <> @ShipToDealer
			BEGIN
				-- see if we can find the new destination
				SELECT @DestinationID = NULL
				
				SELECT @DestinationID = LocationID
				FROM Location
				WHERE ParentRecordID = @CustomerID
				AND CustomerLocationCode = @ShipToDealer
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING DESTINATION LOCATION'
					GOTO Error_Encountered
				END
				
				IF @DestinationID IS NULL
				BEGIN
					SELECT @NewImportedInd = 0
					SELECT @RecordStatus = 'ERROR GETTING DESTINATION'
					GOTO Update_Record_Status
				END
				
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
					UpdatedBy = 'FAPS Import'
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
						'FAPS Import'
					)
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR CREATING POOL RECORD'
						GOTO Error_Encountered
					END
					
					SELECT @PoolID = @@IDENTITY
				END
				-- get the charge rate
				SELECT @ChargeRate = NULL
				
				SELECT @ChargeRate = Rate
				FROM ChargeRate
				WHERE StartLocationID = @OriginID
				AND EndLocationID = @DestinationID
				AND CustomerID = @CustomerID
				AND RateType = 'Size '+@SizeClass+' Rate'
				AND @CreationDate >= StartDate
				AND @CreationDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING CHARGE RATE'
					GOTO Error_Encountered
				END
				
				-- update the vehicle record to make the vehicle available and set the new destination
				UPDATE Vehicle
				SET VehicleStatus = 'Available',
				PickupLocationID = @OriginID,
				DropoffLocationID = @DestinationID,
				AvailableForPickupDate = @ReleaseDate,
				BayLocation = @BayLocation,
				ChargeRate = @ChargeRate,
				UpdatedBy = 'FAPS IMPORT',
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
				SET PoolID = @PoolID,
				PickupLocationID = @OriginID,
				DropoffLocationID = @DestinationID,
				DateAvailable = @ReleaseDate,
				LegStatus = 'Available',
				UpdatedDate = CURRENT_TIMESTAMP,
				UpdatedBy = 'FAPS Import'
				WHERE VehicleID = @VehicleID
				AND LegNumber = 1
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING LEG RECORD'
					GOTO Error_Encountered
				END
				
				SELECT @NewImportedInd = 1
				IF @OriginID <> @VehicleOriginID AND @DestinationID <> @VehicleDestinationID
				BEGIN
					SELECT @RecordStatus = 'ORIGIN & DESTINATION UPDATED'
				END
				ELSE IF @OriginID <> @VehicleOriginID
				BEGIN
					SELECT @RecordStatus = 'ORIGIN UPDATED'
				END
				ELSE IF @DestinationID <> @VehicleDestinationID
				BEGIN
					SELECT @RecordStatus = 'DESTINATION UPDATED'
				END
				GOTO Update_Record_Status
			END
			ELSE
				BEGIN SELECT @DestinationID = @VehicleDestinationID
			END
			*/
			--update logic here.
			
			--update the vehicle record
			UPDATE Vehicle
			SET VehicleStatus = 'Available',
			AvailableForPickupDate = @ReleaseDate,
			BayLocation = @BayLocation,
			UpdatedBy = 'FAPS IMPORT',
			UpdatedDate = CURRENT_TIMESTAMP,
			DateMadeAvailable = CURRENT_TIMESTAMP
			WHERE VehicleID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
				GOTO Error_Encountered
			END
			
			-- get the pool id or create the pool
			SELECT @Count = COUNT(*)
			FROM VehiclePool
			WHERE OriginID = @VehicleOriginID
			AND DestinationID = @VehicleDestinationID 
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
				WHERE OriginID = @VehicleOriginID
				AND DestinationID = @VehicleDestinationID 
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
				UpdatedBy = 'FAPS Import'
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
					@VehicleOriginID,
					@VehicleDestinationID,
					@CustomerID,
					1,
					0,
					1,
					CURRENT_TIMESTAMP,
					'FAPS Import'
				)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR CREATING POOL RECORD'
					GOTO Error_Encountered
				END
				
				SELECT @PoolID = @@IDENTITY
			END
			
			-- update the leg
			UPDATE Legs
			SET PoolID = @PoolID,
			DateAvailable = @ReleaseDate,
			LegStatus = 'Available',
			UpdatedDate = CURRENT_TIMESTAMP,
			UpdatedBy = 'FAPS Import'
			WHERE VehicleID = @VehicleID
			AND LegNumber = 1
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING LEG RECORD'
				GOTO Error_Encountered
			END
					
			SELECT @NewImportedInd = 1
			SELECT @RecordStatus = 'Imported'
		END
		ELSE IF @VINCOUNT > 1
		BEGIN
			SELECT @RecordStatus = 'MULTIPLE MATCHES FOUND FOR VIN'
			SELECT @NeedsReviewInd = 1
			GOTO Update_Record_Status
		END
		ELSE
		BEGIN
			--try to get the customer
			SELECT @CustomerID = NULL
			SELECT @CustomerIdentification = NULL
			
			IF ISNULL(@Make,'') IN ('Ford','Lincoln','Mercury')
			BEGIN
				SELECT @CustomerID = @FordCustomerID
			END
			ELSE IF ISNULL(@Make,'') IN ('Buick','Cadillac','Chevrolet','Chevy','GMC')
			BEGIN
				SELECT @CustomerID = @GMCustomerID
				
				IF @Make = 'Buick'
				BEGIN
					SELECT @CustomerIdentification = '11/'
				END
				ELSE IF @Make = 'Cadillac'
				BEGIN
					SELECT @CustomerIdentification = '12/'
				END
				ELSE IF @Make IN ('Chevrolet','Chevy')
				BEGIN
					SELECT @CustomerIdentification = '13/'
				END
				ELSE IF @Make = 'GMC'
				BEGIN
					SELECT @CustomerIdentification = '48/'
				END
			END
			ELSE IF ISNULL(@Make,'') = 'Volvo'
			BEGIN
				SELECT @CustomerID = @VolvoCustomerID
			END
			ELSE
			BEGIN
				SELECT @RecordStatus = 'UNABLE TO DETERMINE CUSTOMER'
				SELECT @NeedsReviewInd = 1
				GOTO Update_Record_Status
			END
			
			IF DATALENGTH(@ShipToDealer) < 1
			BEGIN
				SELECT @RecordStatus = 'NO DEALER CODE OR ASN'
				SELECT @NeedsReviewInd = 1
				GOTO Update_Record_Status	
			END
			
			SELECT TOP 1 @DestinationID = L.LocationID
			FROM Location L
			WHERE ParentRecordID = @CustomerID
			AND CustomerLocationCode = @ShipToDealer
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING LEG RECORD'
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
					@ShipToDealer,
					0,
					0,
					0,
					0,
					0,
					0,
					'Active',
					GetDate(),
					'FAPS IMPORT',
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
						
			--get the size class
			IF @CustomerID = @GMCustomerID
			BEGIN
				IF LEFT(@VIN,5) IN ('1GB0G','1GB3G','1GB6G','1GBYG','1GB0H','1GB3H','1GB6H','1GBYH','1GD07','1GD37','1GD67','1GDY7','1GD08','1GD38','1GD68','1GDY8')
				BEGIN
					SELECT @SizeClass = 'D'
				END
				ELSE IF LEFT(@VIN,4) IN ('5GAK','3GYF','1GNA','1GNF','2GNA','2GNF','KL77','1GNK','1GKK','2GKA','2GKF','1GYF','1GYK','1GNE')
				BEGIN
					SELECT @SizeClass = 'B'
				END
				ELSE IF LEFT(@VIN,3) IN ('1GY','1GA','1GB','1GC','1GN','1GD','1GJ','1GK','1GT','2GB','2GC','2GT','3GT','3GD','3GC', '3N6')
				BEGIN
					SELECT @SizeClass = 'C'
				END
				ELSE
				BEGIN
					SELECT @SizeClass = 'A'
				END
			END
			ELSE IF @CustomerID = @FordCustomerID
			BEGIN
				SELECT @SizeClass = ''
			
				SELECT @VINBodyType = SUBSTRING(@VIN,7,1)
				SELECT @PlantCode = SUBSTRING(@VIN,11,1)
				SELECT @VehicleType = SUBSTRING(@VIN,12,1)
				
				IF CHARINDEX(@VehicleType,'123456789') > 0
				BEGIN
					IF @PlantCode IN ('T','1')
					BEGIN
						SELECT @SizeClass = 'B'
					END
					ELSE
					BEGIN
						SELECT @SizeClass = 'A'
					END
				END
				ELSE
				BEGIN
					IF @PlantCode IN ('D','E','K')
					BEGIN
						IF @VINBodyType IN ('U', 'X')
						BEGIN
							SELECT @SizeClass = 'D'
						END
						ELSE IF SUBSTRING(@VIN,5,2) IN ('F1','W1','X1','S6','S7','E6','E7','S8','S9','E8','E9','J1','J2','J3','J4','J5','J6','J7','J8','J9')
							AND SUBSTRING(@VIN,5,3) NOT IN ('J2H','J2J','J3H','J3J','J2K','J2L','J3K','J3L','S6P','S8P','S9P','S6Z','S8Z','S9Z') --Navigator and Transit overlaps
						BEGIN
							SELECT @SizeClass = 'B'
						END
						ELSE
						BEGIN
							SELECT @SizeClass = 'C'
						END
					END
					ELSE
					BEGIN
						SELECT @SizeClass = 'B'
					END
				END
			END
			
			SELECT @ChargeRate = NULL
			--From these values we can get the financial information.
			SELECT @ChargeRate = Rate
			FROM ChargeRate
			WHERE StartLocationID = @OriginID
			AND EndLocationID = @DestinationID
			AND CustomerID = @CustomerID
			AND RateType = 'Size '+@SizeClass+' Rate'
			AND @ReleaseDate >= StartDate
			AND @ReleaseDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
					
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
				SELECT @OrderNumber = NextOrderNumber from ApplicationConstants
				
				--add one to it, so it can be updated.
				SELECT @OrderNumberPlusOne = @OrderNumber + 1			
			
				--now update the app constants table with the number + 1
				UPDATE ApplicationConstants
				SET NextOrderNumber = @OrderNumberPlusOne
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
					'FAPS IMPORT',	--CreatedBy,
					NULL,		--UpdatedDate,
					NULL		--UpdatedBy
				)
			
				--need to get the orderId key here, to insert into the vehicle record.			
				SELECT @OrderID = @@identity
			END
			
			--and now do the vehicle
			IF ISNULL(@VehicleYear,'') = ''
			BEGIN
				SELECT @VehicleYear = ''
			END
			IF ISNULL(@Make,'') = ''
			BEGIN
				SELECT @Make = ''
			END
			IF ISNULL(@Model,'') = ''
			BEGIN
				SELECT @Model = ''
			END
			IF ISNULL(@Bodystyle,'') = ''
			BEGIN
				SELECT @Bodystyle = ''
			END
			IF ISNULL(@VehicleLength,'') = ''
			BEGIN
				SELECT @VehicleLength = ''
			END
			IF ISNULL(@VehicleWidth,'') = ''
			BEGIN
				SELECT @VehicleWidth = ''
			END
			IF ISNULL(@VehicleHeight,'') = ''
			BEGIN
				SELECT @VehicleHeight = ''
			END
			IF ISNULL(@VINDecodedInd,0) = 0
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
				SpotBuyUnitInd
			)
			VALUES(
				@CustomerID,			--CustomerID,
				@OrderID,			--OrderID,
				@VehicleYear,			--VehicleYear,
				@Make,				--Make,
				@Model,				--Model,
				@Bodystyle,			--Bodystyle,
				@VIN,				--VIN,
				@ColorName,			--Color,
				@VehicleLength,			--VehicleLength
				@VehicleWidth,			--VehicleWidth
				@VehicleHeight,			--VehicleHeight
				@OriginID,			--PickupLocationID,
				@DestinationID,			--DropoffLocationID,
				'Pending',			--VehicleStatus,
				'Pickup Point',			--VehicleLocation,
				@CustomerIdentification,	--CustomerIdentification,
				@SizeClass,			--SizeClass,
				@BayLocation,			--BayLocation,
				NULL,				--RailCarNumber,
				0,				--PriorityInd
				NULL,				--HaulType,
				NULL,				--AvailableForPickupDate,
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
				'FAPS IMPORT',			--CreatedBy
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
				0				--SpotBuyUnitInd
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
			SELECT @PreviousDestination = @DestinationID
			
			--get the Origin.
			SELECT @PreviousOrigin = @OriginID
			
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
				NULL,
				NULL,
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
				'Pending',	--LegStatus
				0,
				GetDate(), 	--CreationDate
				'FAPS IMPORT', 	--CreatedBy
				0		--OutsideCarrierFuelSurchargeType
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR CREATING DEFAULT LEG'
				GOTO Error_Encountered
			END
			
			--write to the RailVehicleCreatedLog
			INSERT INTO RailVehicleCreatedLog(
				CustomerID,
				VehicleID,
				RailCompany,
				VIN,
				OriginCode,
				DestinationCode,
				ActionTaken,
				CreationDate,
				CreatedBy
			)
			VALUES(
				@CustomerID,	--CustomerID,
				@VehicleID,	--VehicleID,
				'FAPS',		--RailCompany,
				@VIN,		--VIN,
				'FAPS',		--OriginCode,
				@ShipToDealer,	--DestinationCode,
				'Open',		--ActionTaken,
				GetDate(),	--CreationDate,
				'FAPS IMPORT'	--CreatedBy
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR CREATING LOG RECORD'
				GOTO Error_Encountered
			END
			
			SELECT @RecordStatus = 'VEHICLE CREATED'
			SELECT @NewImportedInd = 1
		END

		--update the record status here.
		Update_Record_Status:
		UPDATE FordImportFAPSRelease
		SET RecordStatus = @RecordStatus,
		ImportedInd = @NewImportedind,
		ImportedDate = CASE WHEN @NewImportedInd = 1 THEN CURRENT_TIMESTAMP ELSE NULL END,
		ImportedBy = CASE WHEN @NewImportedInd = 1 THEN @UserCode ELSE NULL END
		WHERE FordImportFAPSReleaseID = @FordImportFAPSReleaseID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH FAPSReleaseCursor INTO @FordImportFAPSReleaseID, @VIN, @ShipToDealer, @ModelName,
			@ColorName, @BayLocation, @ReleaseDate,
			@VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength, @VehicleWidth, @VehicleHeight, @VINDecodedInd
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
		CLOSE FAPSReleaseCursor
		DEALLOCATE FAPSReleaseCursor
		PRINT 'Ford FAPS Release Import Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE FAPSReleaseCursor
		DEALLOCATE FAPSReleaseCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
	BEGIN
		PRINT 'Ford FAPS Release Import Error_Encountered =' + STR(@ErrorID)
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
