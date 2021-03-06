USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportNORADRelease]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportNORADRelease] (@BatchID int,@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	@ErrorEncountered	varchar(5000),
	@loopcounter		int,
	@NORADReleaseImportID	int,
	@VIN			varchar(17),
	@DealerCode		varchar(20),
	@BayLocation		varchar(20),
	@ModelCode		varchar(20),
	@Color			varchar(4),
	@ReleaseDate		datetime,
	@SoldCode		varchar(1),
	@VehicleYear		varchar(6),
	@Make			varchar(50),
	@Model			varchar(50),
	@Bodystyle		varchar(50),
	@VehicleLength		varchar(10),
	@VehicleWidth		varchar(10),
	@VehicleHeight		varchar(10),
	@VINDecodedInd		int,
	@CreatedBy		varchar(20),
	@VINCOUNT		int,
	@VehicleID		int,
	@VehicleStatus		varchar(20),
	@LegStatus		varchar(20),
	@Status			varchar(50),
	@RecordStatus		varchar(100),
	@ImportedInd		int,
	@NewImportedInd		int,
	@CustomerID		int,
	@VehicleBayLocation	varchar(20),
	@VehicleOriginID	int,
	@VehicleDestinationID	int,
	@VehiclePoolID		int,
	@VehicleLoadID		int,
	@OriginID		int,
	@DestinationID		int,
	@PoolID			int,
	@LoadID			int,
	@Count			int,
	@ReturnCode		int,
	@ReturnMessage		varchar(100),
	@NeedsReviewInd		int,
	@PortCode		varchar(3),
	@CarrierID		varchar(3),
	@Voyage			varchar(10),
	@DestinationCode	varchar(20),
	@ChargeRate		decimal(19,2),
	@CreationDate		datetime,
	@PreviousOrigin		int,
	@PreviousDestination	int,
	@OrderID		int,
	@TotalOrderUnits	int,
	@TotalOrderChargeRate	int,
	@OrderNumber		int,
	@OrderNumberPlusOne	int,
	@AvailableForPickupDate	datetime,
	@PriorityInd		int,
	@SizeClass		varchar(10),
	@DateAvailable		datetime,
	@PoolRecordCount	int,
	@VolkswagenCustomerID	int,
	@ChryslerCustomerID	int,
	@GMCustomerID		int,
	@VWModelCode		varchar(20),
	@PlantCode		varchar(1),
	@VINSquish		varchar(10),
	@DealerSellingDivision	varchar(3)
	

	/************************************************************************
	*	spImportNORADRelease						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the NORADRelease table and 	*
	*	updates the vehicle records with the availability information.	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	09/10/2008 CMK    Initial version				*
	*	04/13/2018 CMK    Added in functionality for Chrysler		*
	*	06/25/2018 CMK	  Added in functionality for GM			*
	*									*
	************************************************************************/

	SELECT @PreviousOrigin = 0
	SELECT @PreviousDestination = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @NeedsReviewInd = 0
	
	/*
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,Value1)
	FROM Code
	WHERE CodeType = 'ICLCustomerCode'
	AND Code = 'SW' --volkswagen only right now
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
	*/

	--get the volkswagen customer id from the setting table
	SELECT @VolkswagenCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'VolkswagenCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Volkswagen CustomerID'
		GOTO Error_Encountered2
	END
	
	--get the chrysler customer id from the setting table
	SELECT @ChryslerCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ChryslerCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Volkswagen CustomerID'
		GOTO Error_Encountered2
	END
	
	--get the gm customer id from the setting table
	SELECT @GMCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'GMCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Volkswagen CustomerID'
		GOTO Error_Encountered2
	END
	
	DECLARE NORADReleaseCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT NORADReleaseImportID, VIN, DealerCode,
		BayLocation, ModelCode, Color, ReleaseDate, SoldCode,
		VehicleYear, Make, Model, Bodystyle, VehicleLength,
		VehicleWidth, VehicleHeight, VINDecodedInd
		FROM NORADReleaseImport
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY DealerCode, NORADReleaseImportID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP

	OPEN NORADReleaseCursor

	BEGIN TRAN

	FETCH NORADReleaseCursor INTO @NORADReleaseImportID, @VIN, @DealerCode,
		@BayLocation, @ModelCode, @Color, @ReleaseDate, @SoldCode,
		@VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength,
		@VehicleWidth, @VehicleHeight, @VINDecodedInd
	
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @DestinationID = NULL
		SELECT @OriginID = NULL
		SELECT @CustomerID = NULL
		SELECT @DealerSellingDivision = ''

		-- get the origin
		SELECT @OriginID = CONVERT(int,ValueDescription)
		FROM SettingTable
		WHERE ValueKey = 'DavisvilleLocationID'
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Origin ID'
			GOTO Error_Encountered
		END
		IF @OriginID IS NULL
		BEGIN
			SELECT @ErrorID = 100000
			SELECT @Status = 'Error Getting Origin ID'
			GOTO Error_Encountered
		END
			
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
			@VehicleLoadID = L.LoadID
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			WHERE V.VIN = @VIN
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING VEHICLE STATUS'
				GOTO Error_Encountered
			END
			
			--Davisville is now multiple locations, so keep what is on the vehicle
			SELECT @OriginID = @VehicleOriginID
			
			--get the destination.
			SELECT @DestinationID = LocationID
			FROM Location
			WHERE ParentRecordID = @CustomerID
			AND ParentRecordTable = 'Customer'
			AND CustomerLocationCode = @DealerCode
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
					@DealerCode,
					0,
					0,
					0,
					0,
					0,
					0,
					'Active',
					GetDate(),
					'NORAD Import',
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
			
			IF @CustomerID = @VolkswagenCustomerID
			BEGIN
				-- also update spImportVolkswagenAvailableVehicles, spImportNSTrukerNotification, spCSXRailheadFeedUpdate, spImportI73 and spImportI95 when adding new model codes
				SELECT @VWModelCode = LEFT(@VIN,3)+ SUBSTRING(@VIN,7,2)
				IF @VWModelCode IN ('WVG7L','WA14L','WA1FE','WVGA9','2V4D1','2V4DX','WVGBP','2C4AG','2C4BG','2C4CG','2C4DG','WA1F7','1V2CA')
				BEGIN
					SELECT @SizeClass = 'B'
				END
				ELSE
				BEGIN
					SELECT @SizeClass = 'A'
				END
			END
			ELSE IF @CustomerID = @ChryslerCustomerID
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
					SELECT @SizeClass = 'A'
				END
			END
			ELSE IF @CustomerID = @GMCustomerID
			BEGIN
				IF LEFT(@VIN,5) IN ('1GB0G','1GB3G','1GB6G','1GBYG','1GB0H','1GB3H','1GB6H','1GBYH','1GD07','1GD37','1GD67','1GDY7','1GD08','1GD38','1GD68','1GDY8')
				BEGIN
					SELECT @SizeClass = 'D'
				END
				ELSE IF LEFT(@VIN,4) IN ('5GAK','3GYF','1GNA','1GNF','2GNA','2GNF','KL77','1GNK','1GKK','2GKA','2GKF','1GYF','1GYK','1GNE')
				BEGIN
					SELECT @SizeClass = 'B'
				END
				ELSE IF LEFT(@VIN,3) IN ('1GY','1GA','1GB','1GC','1GN','1GD','1GJ','1GK','1GT','2GB','2GC','2GT','3GT','3GD', '3GC', '3N6')
				BEGIN
					SELECT @SizeClass = 'C'
				END
				ELSE
				BEGIN
					SELECT @SizeClass = 'A'
				END
			END
			ELSE
			BEGIN
				SELECT @SizeClass = 'A'
			END
				
		
			SELECT @ChargeRate = NULL
			--From these values we can get the financial information.
			--Need to add logic to check size class. not in this particular file.
			SELECT @ChargeRate = Rate
			FROM ChargeRate
			WHERE StartLocationID = @OriginID
			AND EndLocationID = @DestinationID
			AND CustomerID = @CustomerID
			AND RateType = 'Size '+@SizeClass+' Rate'
			AND @CreationDate >= StartDate
			AND @CreationDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
			
			IF @VehicleStatus = 'Damaged' OR @LegStatus = 'Pending Repair'
			BEGIN
				--update the vehicle status
				UPDATE Vehicle
				SET VehicleStatus = 'Available',
				BayLocation = @BayLocation,
				PriorityInd = CASE WHEN ISNULL(@SoldCode,'') = 'S' THEN 1 ELSE 0 END,
				UpdatedBy = 'NORAD Import',
				UpdatedDate = CURRENT_TIMESTAMP,
				DateMadeAvailable = ISNULL(DateMadeAvailable,CURRENT_TIMESTAMP)
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
				UpdatedBy = 'NORAD Import'
				WHERE VehicleID = @VehicleID
				AND LegNumber = 1
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR CREATING POOL RECORD'
					GOTO Error_Encountered
				END
				
				SELECT @NewImportedInd = 1
				SELECT @NeedsReviewInd = 1
				SELECT @RecordStatus = 'Re-Released'
				GOTO Update_Record_Status
			
			END
			ELSE IF @VehicleStatus <> 'Pending' OR @LegStatus <> 'Pending'
			BEGIN
				SELECT @NeedsReviewInd = 1
				SELECT @RecordStatus = 'VEHICLE IS NOT PENDING'
				GOTO Update_Record_Status
			END
			
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
			
			IF @OriginID <> @VehicleOriginID OR PATINDEX('%'+@DealerCode+'%',@DestinationCode) = 0
			BEGIN
				-- see if we can find the new destination
				SELECT @DestinationID = NULL
				
				SELECT @DestinationID = LocationID
				FROM Location
				WHERE ParentRecordID = @CustomerID
				AND CustomerLocationCode = @DealerCode
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING DESTINATION LOCATION'
					GOTO Error_Encountered
				END
				
				IF @DestinationID IS NULL
				BEGIN
					SELECT @ErrorID = 100000
					SELECT @Status = 'ERROR GETTING DESTINATION LOCATION'
					GOTO Error_Encountered
				END
				-- if there is an existing pool id, reduce the available count
				IF @VehiclePoolID IS NOT NULL
				BEGIN
					UPDATE VehiclePool
					SET PoolSize = PoolSize - 1,
					Available = Available - 1
					WHERE VehiclePoolID = @PoolID
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
					UpdatedBy = 'NORAD Import'
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
						'NORAD Import'
					)
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR CREATING POOL RECORD'
						GOTO Error_Encountered
					END
					
					SELECT @PoolID = @@IDENTITY
				END
								
				-- update the vehicle record to make the vehicle available and set the new destination
				UPDATE Vehicle
				SET VehicleStatus = 'Available',
				PickupLocationID = @OriginID,
				DropoffLocationID = @DestinationID,
				AvailableForPickupDate = @ReleaseDate,
				BayLocation = @BayLocation,
				PriorityInd = CASE WHEN ISNULL(@SoldCode,'') = 'S' THEN 1 ELSE 0 END,
				ChargeRate = @ChargeRate,
				UpdatedBy = 'NORAD Import',
				UpdatedDate = CURRENT_TIMESTAMP,
				DateMadeAvailable = ISNULL(DateMadeAvailable,CURRENT_TIMESTAMP)
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
				UpdatedBy = 'NORAD Import'
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
			
			--update logic here.
			
			--update the vehicle record
			UPDATE Vehicle
			SET VehicleStatus = 'Available',
			AvailableForPickupDate = @ReleaseDate,
			BayLocation = @BayLocation,
			PriorityInd = CASE WHEN ISNULL(@SoldCode,'') = 'S' THEN 1 ELSE 0 END,
			UpdatedBy = 'NORAD Import',
			UpdatedDate = CURRENT_TIMESTAMP,
			DateMadeAvailable = ISNULL(DateMadeAvailable,CURRENT_TIMESTAMP)
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
				UpdatedBy = 'NORAD Import'
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
					'NORAD Import'
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
			UpdatedBy = 'NORAD Import'
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
			SELECT @NeedsReviewInd = 1
			SELECT @RecordStatus = 'MULTIPLE MATCHES FOUND FOR VIN'
			GOTO Update_Record_Status
		END
		ELSE
		BEGIN
			--no customer identifier in the file, so have to count on the vin decode to get the customer
			IF ISNULL(@Make,'') = ''
			BEGIN
				SELECT @NeedsReviewInd = 1
				SELECT @NewImportedInd = 1
				SELECT @RecordStatus = 'VIN NOT FOUND'
			END
			ELSE IF @Make IN ('Volkswagen','Audi')
			BEGIN
				SELECT @CustomerID = @VolkswagenCustomerID
			END
			ELSE IF @Make IN ('Alfa Romeo','Dodge','FIAT','Jeep','Chrysler','Ram','Maserati')
			BEGIN
				SELECT @CustomerID = @ChryslerCustomerID
			END
			ELSE IF @Make IN ('Buick','Cadillac','Chevrolet','GMC')
			BEGIN
				SELECT @CustomerID = @GMCustomerID
				
				IF @Make = 'Buick'
				BEGIN
					SELECT @DealerSellingDivision = '11/'
				END
				ELSE IF @Make = 'Cadillac'
				BEGIN
					SELECT @DealerSellingDivision = '12/'
				END
				ELSE IF @Make = 'Chevrolet'
				BEGIN
					SELECT @DealerSellingDivision = '13/'
				END
				ELSE IF @Make = 'GMC'
				BEGIN
					SELECT @DealerSellingDivision = '48/'
				END
			END
			ELSE
			BEGIN
				SELECT @NeedsReviewInd = 1
				SELECT @NewImportedInd = 1
				SELECT @RecordStatus = 'VIN NOT FOUND'
			END
			--get the destination.
			SELECT @DestinationID = LocationID
			FROM Location
			WHERE ParentRecordID = @CustomerID
			AND ParentRecordTable = 'Customer'
			AND CustomerLocationCode = @DealerCode
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
					@DealerCode,
					0,
					0,
					0,
					0,
					0,
					0,
					'Active',
					GetDate(),
					'NORAD Import',
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
			
			IF @CustomerID = @VolkswagenCustomerID
			BEGIN
				-- also update spImportVolkswagenAvailableVehicles, spImportNSTrukerNotification, spCSXRailheadFeedUpdate, spImportI73 and spImportI95 when adding new model codes
				SELECT @VWModelCode = LEFT(@VIN,3)+ SUBSTRING(@VIN,7,2)
				IF @VWModelCode IN ('WVG7L','WA14L','WA1FE','WVGA9','2V4D1','2V4DX','WVGBP','2C4AG','2C4BG','2C4CG','2C4DG','WA1F7','1V2CA')
				BEGIN
					SELECT @SizeClass = 'B'
				END
				ELSE
				BEGIN
					SELECT @SizeClass = 'A'
				END
			END
			ELSE IF @CustomerID = @ChryslerCustomerID
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
					SELECT @SizeClass = 'A'
				END
			END
			ELSE IF @CustomerID = @GMCustomerID
			BEGIN
				IF LEFT(@VIN,5) IN ('1GB0G','1GB3G','1GB6G','1GBYG','1GB0H','1GB3H','1GB6H','1GBYH','1GD07','1GD37','1GD67','1GDY7','1GD08','1GD38','1GD68','1GDY8')
				BEGIN
					SELECT @SizeClass = 'D'
				END
				ELSE IF LEFT(@VIN,4) IN ('5GAK','3GYF','1GNA','1GNF','2GNA','2GNF','KL77','1GNK','1GKK','2GKA','2GKF','1GYF','1GYK','1GNE')
				BEGIN
					SELECT @SizeClass = 'B'
				END
				ELSE IF LEFT(@VIN,3) IN ('1GY','1GA','1GB','1GC','1GN','1GD','1GJ','1GK','1GT','2GB','2GC','2GT','3GT','3GD', '3GC', '3N6')
				BEGIN
					SELECT @SizeClass = 'C'
				END
				ELSE
				BEGIN
					SELECT @SizeClass = 'A'
				END
			END
			ELSE
			BEGIN
				SELECT @SizeClass = 'A'
			END
				
		
			SELECT @ChargeRate = NULL
			--From these values we can get the financial information.
			--Need to add logic to check size class. not in this particular file.
			SELECT @ChargeRate = Rate
			FROM ChargeRate
			WHERE StartLocationID = @OriginID
			AND EndLocationID = @DestinationID
			AND CustomerID = @CustomerID
			AND RateType = 'Size '+@SizeClass+' Rate'
			AND @CreationDate >= StartDate
			AND @CreationDate < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
			
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
					'NORAD Import',	--CreatedBy,
					NULL,		--UpdatedDate,
					NULL		--UpdatedBy
				)
				--need to get the orderId key here, to insert into the vehicle record.			
				SELECT @OrderID = @@identity
			END
			
			--and now do the vehicle
			IF @VehicleYear IS NULL OR DATALENGTH(@VehicleYear)<1
			BEGIN
				SELECT @VehicleYear = ''
			END
			IF @Model IS NULL OR DATALENGTH(@Model)<1
			BEGIN
				SELECT @Model = @ModelCode
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
			
			SELECT @AvailableForPickupDate = @ReleaseDate
			SELECT @LegStatus = 'Available'
			
			SELECT @PriorityInd = CASE WHEN ISNULL(@SoldCode,'') = 'S' THEN 1 ELSE 0 END
			
			--get the vin, if it exists then just update anything that might have changed.
			SELECT @VINCOUNT = COUNT(*)
			FROM Vehicle
			WHERE (VIN = @VIN
			OR RIGHT(VIN,8) = RIGHT(@VIN,8))
			AND CustomerID IS NULL
			AND (OrderID IS NULL OR OrderID = -1)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting vin count'
				GOTO Error_Encountered
			END
			
			IF @VINCOUNT > 0
			BEGIN -- null customerid and ordersid means vehicle was added by phone, so update vehicle and leg
							
				--get the vehicleid
				SELECT @VehicleID = VehicleID
				FROM Vehicle
				WHERE (VIN = @VIN
				OR RIGHT(VIN,8) = RIGHT(@VIN,8))
				AND CustomerID IS NULL
				AND (OrderID IS NULL OR OrderID = -1)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error getting vehicle id'
					GOTO Error_Encountered
				END
			
				--update the vehicle
				UPDATE Vehicle
				SET CustomerID = @CustomerID,
				OrderID = @OrderID,
				VIN = @VIN,			--in case only the vin key was originally entered
				VehicleYear = @VehicleYear,
				Make = @Make,
				Model = @Model,
				Bodystyle = @Bodystyle,
				Color = @Color,
				PickupLocationID = @OriginID,
				DropoffLocationID = @DestinationID,
				VehicleLength = @VehicleLength,
				VehicleWidth = @VehicleWidth,
				VehicleHeight = @VehicleHeight,
				SizeClass = @SizeClass,
				PriorityInd = @PriorityInd,
				ChargeRate = @ChargeRate,
				BayLocation = @BayLocation,
				VINDecodedInd = @VINDecodedInd,
				UpdatedDate = GetDate(),
				UpdatedBy = 'NORAD Import'
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
					GOTO Error_Encountered
				END
			
				--update the leg
				UPDATE Legs
				SET PickupLocationID = @OriginID,
				DropoffLocationID = @DestinationID,
				UpdatedDate = GetDate(),
				UpdatedBy = 'NORAD Import'
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING LEG RECORD'
					GOTO Error_Encountered
				END
			END
			ELSE
			BEGIN
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
					DateMadeAvailable
				)
				VALUES(
					@CustomerID,		--CustomerID,
					@OrderID,		--OrderID,
					@VehicleYear,		--VehicleYear,
					@Make,			--Make,
					@Model,			--Model,
					@Bodystyle,		--Bodystyle,
					@VIN,			--VIN,
					@Color,			--Color,
					@VehicleLength,		--VehicleLength
					@VehicleWidth,		--VehicleWidth
					@VehicleHeight,		--VehicleHeight
					@OriginID,		--PickupLocationID,
					@DestinationID,		--DropoffLocationID,
					'Available',		--VehicleStatus,
					'Pickup Point',		--VehicleLocation,
					@DealerSellingDivision,	--CustomerIdentification,
					@SizeClass,		--SizeClass,  --decode sizeclass.  might come up with logic for determining the size class.
					@BayLocation,		--BayLocation,
					NULL,			--RailCarNumber,
					@PriorityInd,		--PriorityInd
					NULL,			--HaulType,
					@AvailableForPickupDate,	--AvailableForPickupDate,
					0,			--ShopWorkStartedInd,
					NULL,			--ShopWorkStartedDate,
					0,			--ShopWorkCompleteInd
					NULL,			--ShopWorkCompleteDate
					NULL,			--PaperworkReceivedDate,
					NULL,			--ICLAuditCode,
					@ChargeRate,		--ChargeRate
					0,			--ChargeRateOverrideInd
					0,			--BilledInd
					NULL,			--Datebilled
					@VINDecodedInd,		--VINDecodedInd
					'Active',		--RecordStatus,
					GetDate(),		--CreationDate,
					'NORAD Import',		--CreatedBy,
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
					0,			--FinalShipawayInspectionDoneInd
					CURRENT_TIMESTAMP	--DateMadeAvailable
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
							'NORAD Import'	--CreatedBy
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
					'NORAD Import',	--CreatedBy
					0		--OutsideCarrierFuelSurchargeType
				)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR CREATING DEFAULT LEG'
					GOTO Error_Encountered
				END
			END
			SELECT @NeedsReviewInd = 1
			SELECT @RecordStatus = 'VEHICLE CREATED'
			SELECT @NewImportedInd = 1
		END

		--update the record status here.
		Update_Record_Status:
		UPDATE NORADReleaseImport
		SET RecordStatus = @RecordStatus,
		ImportedInd = @NewImportedind,
		ImportedDate = CASE WHEN @NewImportedInd = 1 THEN GetDate() ELSE NULL END,
		ImportedBy = CASE WHEN @NewImportedInd = 1 THEN @UserCode ELSE NULL END
		WHERE NORADReleaseImportID = @NORADReleaseImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH NORADReleaseCursor INTO @NORADReleaseImportID, @VIN, @DealerCode,
			@BayLocation, @ModelCode, @Color, @ReleaseDate, @SoldCode,
			@VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength,
			@VehicleWidth, @VehicleHeight, @VINDecodedInd
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
		CLOSE NORADReleaseCursor
		DEALLOCATE NORADReleaseCursor
		PRINT 'NORAD Release Import Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE NORADReleaseCursor
		DEALLOCATE NORADReleaseCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			PRINT 'NORAD Release Import Error_Encountered =' + STR(@ErrorID)
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
