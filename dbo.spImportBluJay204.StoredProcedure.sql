USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportBluJay204]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportBluJay204] (@BatchID int,
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--BluJayImport204 table variables
	@BluJayImport204ID		int,
	@ShipmentIdentificationNumber	varchar(30),
	@TransactionSetPurposeCode	varchar(2),
	@ModelYearNumber		varchar(30),
	@TransportationPriorityNumber	varchar(30),
	@RepetitivePatternCode		varchar(30),
	@PurchaseOrderNumber		varchar(30),
	@MotorVehicleIDNumber		varchar(30),
	@ShipperIdentificationCode	varchar(80),
	@PickupFromDateTime		datetime,
	@ShipFromName			varchar(60),
	@ShipFromCode			varchar(80),
	@ShipFromAddress		varchar(55),
	@ShipFromCity			varchar(30),
	@ShipFromState			varchar(2),
	@ShipFromPostalCode		varchar(15),
	@ShipFromCountry		varchar(3),
	@ShipToName			varchar(60),
	@ShipToCode			varchar(80),
	@ShipToAddress			varchar(55),
	@ShipToCity			varchar(30),
	@ShipToState			varchar(2),
	@ShipToPostalCode		varchar(15),
	@ShipToCountry			varchar(3),
	@DeliveryFromDateTime		datetime,
	@ImportedInd			int,
	@VehicleYear			varchar(6),
	@Make				varchar(50),
	@Model				varchar(50),
	@Bodystyle			varchar(50),
	@VehicleLength			varchar(10),
	@VehicleWidth			varchar(10),
	@VehicleHeight			varchar(10),
	@VINDecodedInd			int,
	@ReadyToShipDateTime		datetime,
	--processing variables
	@VINCOUNT			int,
	@OldLegStatus			varchar(20),
	@OldVehicleStatus		varchar(20),
	@DestinationID			int,
	@OriginID			int,
	@ChargeRate			decimal(19,2),
	@MiscellaneousAdditive		decimal(19,2),
	@SizeClass			varchar(1),
	@CustomerIdentification		varchar(25),
	@BayLocation			varchar(20),
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
	@VehicleReservationsID		int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@NeedsReviewInd			int,
	@TotalOrderUnits		int,
	@TotalOrderChargeRate		decimal(19,2),
	@LegsCount			int,
	@DateAvailable			datetime,
	@PriorityInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@VehicleOriginID		int,
	@CreationDate			datetime,
	@VehicleDestinationID		int,
	@DestinationLocationCode	varchar(10),
	@VehicleStatus			varchar(20),
	@DropoffLocationName		varchar(50),
	@LegsID				int,
	@LoadNumber			varchar(20),
	@UpdatedDate			datetime,
	@VehiclePoolID			int,
	@Count				int,
	@DamageIncidentReportCount	int,
	@DamageClaimCount		int,
	@DateMadeAvailable		datetime

	/************************************************************************
	*	spImportBluJay204						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the ToyotaImportTender table	*
	*	and creates the new orders and vehicle records.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	08/14/2008 CMK    Initial version				*
	*	07/27/2012 CMK    Changed Delete To Make Unavailable		*
	*									*
	************************************************************************/
	
	SELECT @PreviousOrigin = 0
	SELECT @PreviousDestination = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @UpdatedDate = CURRENT_TIMESTAMP
	SELECT @NeedsReviewInd = 0
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'VolvoCustomerID'
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

	DECLARE BluJay204Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT BluJayImport204ID, ShipmentIdentificationNumber, TransactionSetPurposeCode, ModelYearNumber,
		TransportationPriorityNumber, 
		LEFT(SUBSTRING(RepetitivePatternCode,CHARINDEX(' ',RepetitivePatternCode)+1,DATALENGTH(RepetitivePatternCode)-CHARINDEX(' ',RepetitivePatternCode)+1),20),
		PurchaseOrderNumber, MotorVehicleIDNumber,
		ShipperIdentificationCode, PickupFromDateTime, ShipFromName, ShipFromCode, ShipFromAddress,
		ShipFromCity, ShipFromState, ShipFromPostalCode, ShipFromCountry, ShipToName, ShipToCode,
		ShipToAddress, ShipToCity, ShipToState, ShipToPostalCode, ShipToCountry, DeliveryFromDateTime,
		VehicleYear, Make, Model, Bodystyle, VehicleLength, VehicleWidth, VehicleHeight, VINDecodedInd,
		ReadyToShipDateTime
		FROM BluJayImport204
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY BluJayImport204ID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN BluJay204Cursor

	BEGIN TRAN

	FETCH BluJay204Cursor INTO @BluJayImport204ID, @ShipmentIdentificationNumber, @TransactionSetPurposeCode, @ModelYearNumber,
		@TransportationPriorityNumber, @RepetitivePatternCode, @PurchaseOrderNumber, @MotorVehicleIDNumber,
		@ShipperIdentificationCode, @PickupFromDateTime, @ShipFromName, @ShipFromCode, @ShipFromAddress,
		@ShipFromCity, @ShipFromState, @ShipFromPostalCode, @ShipFromCountry, @ShipToName, @ShipToCode,
		@ShipToAddress, @ShipToCity, @ShipToState, @ShipToPostalCode, @ShipToCountry, @DeliveryFromDateTime,
		@VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength, @VehicleWidth, @VehicleHeight, @VINDecodedInd,
		@ReadyToShipDateTime

	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @VehicleID = NULL
		
		IF @TransactionSetPurposeCode = '01'	--Cancellation
		BEGIN
			--get the vin, if it exists then just update anything that might have changed.
			SELECT @VINCOUNT = COUNT(*)
			FROM Vehicle
			WHERE VIN = @MotorVehicleIDNumber
			AND CustomerID = @CustomerID
			AND CustomerIdentification = @ShipmentIdentificationNumber
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting vin count'
				GOTO Error_Encountered
			END
					
			IF @VINCOUNT = 1
			BEGIN
				--validate the origin and destination
				--make sure the vin is not en route or delivered
				SELECT TOP 1 @VehicleID = V.VehicleID,
				@VehicleDestinationID = V.DropoffLocationID,
				@CustomerIdentification = V.CustomerIdentification,
				@DestinationLocationCode = L2.CustomerLocationCode,
				@DropoffLocationName = L2.LocationName,
				@VehicleStatus = V.VehicleStatus,
				@LoadNumber = L3.LoadNumber,
				@LoadID = L3.LoadsID,
				@PoolID = L.PoolID,
				@LegsID = L.LegsID
				FROM Vehicle V
				LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
				LEFT JOIN Location L2 ON V.DropoffLocationID = L2.LocationID
				LEFT JOIN Loads L3 ON L.LoadID = L3.LoadsID
				WHERE V.VIN = @MotorVehicleIDNumber
				AND V.CustomerID = @CustomerID
				AND CustomerIdentification = @ShipmentIdentificationNumber
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING VEHICLE STATUS'
					GOTO Error_Encountered
				END
					
				IF @ShipToCode <> @DestinationLocationCode
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'CANNOT UNTENDER - DEALER MISMATCH: Vehicle Shows '+@DestinationLocationCode+', Not '+@ShipToCode
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Do_Update
				END
						
				IF @VehicleStatus = 'Delivered'
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'CANNOT UNTENDER - VEHICLE DELIVERED TO '+ @DropoffLocationName
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Do_Update
				END
				
				IF @VehicleStatus = 'EnRoute'
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'CANNOT UNTENDER - VEHICLE ENROUTE TO '+ @DropoffLocationName+' ON LOAD '+@LoadNumber
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Do_Update
				END
				
				IF @VehicleStatus = 'OnHold'
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'CANNOT UNTENDER - VEHICLE IS ON HOLD'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Do_Update
				END
				
				SELECT @RecordStatus = ''
				
				-- if the vehicle is in a load remove it from the load
				IF @LoadID IS NOT NULL
				BEGIN
					SELECT @ReturnCode = 1
					EXEC spRemoveVehicleFromLoad @LegsID, @LoadID, @UpdatedDate,
					@UserCode, @rReturnCode = @ReturnCode OUTPUT
					IF @ReturnCode <> 0
					BEGIN
						SELECT @ErrorID = @ReturnCode
						GOTO Error_Encountered
					END
							
					--since we removed the vehicle from a load, it should now have a pool id
					SELECT @PoolID = PoolID
					FROM Legs
					WHERE LegsID = @LegsID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR GETTING POOL ID'
						GOTO Error_Encountered
					END
							
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'VEHICLE REMOVED FROM LOAD '+@LoadNumber+', '
				END
						
				-- if there is a pool id reduce the pool size
				IF @PoolID IS NOT NULL
				BEGIN
					UPDATE VehiclePool
					SET PoolSize = PoolSize - 1,
					Available = Available - 1
					WHERE VehiclePoolID = @PoolID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING POOL'
						GOTO Error_Encountered
					END
				END
				
				-- update the vehicle
				UPDATE Vehicle
				SET AvailableForPickupDate = NULL,
				VehicleStatus = 'Pending'
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UNTENDERING VEHICLE'
					GOTO Error_Encountered
				END
				-- update the leg
				UPDATE Legs
				SET PoolID = NULL,
				DateAvailable = NULL,
				LegStatus = 'Pending'
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UNTENDERING LEG'
					GOTO Error_Encountered
				END
										
				SELECT @ImportedInd = 1
				SELECT @NeedsReviewInd = 1
				SELECT @RecordStatus = @RecordStatus +'VEHICLE UNTENDERED'
				SELECT @ImportedDate = GetDate()
				SELECT @ImportedBy = @UserCode
				GOTO Do_Update
			END
			ELSE IF @VINCOUNT > 1
			BEGIN
				SELECT @NeedsReviewInd = 1
				SELECT @RecordStatus = 'MULTIPLE MATCHES FOUND FOR VIN'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Do_Update
			END
			ELSE
			BEGIN
				SELECT @NeedsReviewInd = 1
				SELECT @RecordStatus = 'VIN NOT FOUND'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Do_Update
			END
		END
		ELSE IF @TransactionSetPurposeCode IN ('13')	--Spot Bid Request
		BEGIN
			--still waiting to hear on how to handle spot bids, just setting to imported for now
			SELECT @ImportedInd = 1
			SELECT @NeedsReviewInd = 1
			SELECT @RecordStatus = 'Spot Bid Request'
			SELECT @ImportedDate = GetDate()
			SELECT @ImportedBy = @UserCode
			GOTO Do_Update
		END
		ELSE IF @TransactionSetPurposeCode IN ('44')	--Spot Bid Rejection
		BEGIN
			--still waiting to hear on how to handle spot bids, just setting to imported for now
			SELECT @ImportedInd = 1
			SELECT @NeedsReviewInd = 1
			SELECT @RecordStatus = 'Spot Bid Request'
			SELECT @ImportedDate = GetDate()
			SELECT @ImportedBy = @UserCode
			GOTO Do_Update
		END
		ELSE IF @TransactionSetPurposeCode IN ('56')	--Expiry Notification
		BEGIN
			--still waiting to hear on how to this, just setting to imported for now
			SELECT @ImportedInd = 1
			SELECT @NeedsReviewInd = 1
			SELECT @RecordStatus = 'Spot Bid Request'
			SELECT @ImportedDate = GetDate()
			SELECT @ImportedBy = @UserCode
			GOTO Do_Update
		END
		ELSE IF @TransactionSetPurposeCode IN ('00','05','55')	--Original Tender/Replace
		BEGIN		
			SELECT @OriginID = NULL
			SELECT @DestinationID = NULL
			SELECT @RecordStatus = ''
			
			--get the destination.
			SELECT @DestinationID = LocationID
			FROM Location
			WHERE ParentRecordID = @CustomerID
			AND ParentRecordTable = 'Customer'
			AND CustomerLocationCode = @ShipToCode
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
					AddressLine1,
					City,
					State,
					Zip,
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
					@ShipToName,
					@ShipToAddress,
					@ShipToCity,
					@ShipToState,
					@ShipToPostalCode,
					CASE WHEN @ShipToCountry = 'USA' THEN 'U.S.A.' ELSE @ShipTocountry END,
					@ShipToCode,
					0,
					0,
					0,
					0,
					0,
					0,
					0,
					'Active',
					getDate(),
					'BluJay204',
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
					
			--get the Origin
			SELECT @OriginID = CONVERT(int,Value1)
			FROM Code
			WHERE CodeType = 'VolvoLocationCode'
			AND Code = @ShipFromCode
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
					AddressLine1,
					City,
					State,
					Zip,
					Country,
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
					@ShipFromName,
					@ShipFromAddress,
					@ShipFromCity,
					@ShipFromState,
					@ShipFromPostalCode,
					CASE WHEN @ShipFromCountry = 'USA' THEN 'U.S.A.' ELSE @ShipFromcountry END,
					@ShipFromCode,
					0,
					0,
					0,
					0,
					0,
					0,
					'Active',
					GetDate(),
					'BluJay204',
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
			SELECT @MiscellaneousAdditive = NULL
			
			
			IF LEFT(@Model,2) = 'XC' --STILL WAITING TO HEAR IF SIZE CLASS IS INCLUDED IN 204 FILE
			BEGIN
				SELECT @SizeClass = 'B'
			END
			ELSE
			BEGIN
				SELECT @SizeClass = 'A'
			END
			
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
			
			IF @MiscellaneousAdditive IS NULL
			BEGIN
				SELECT @MiscellaneousAdditive = 0
			END
		
			IF @TransportationPriorityNumber IN ('10','11','69','71') --06/29/2018 CMK - confirmed priority statuses from Volvo
			BEGIN
				SELECT @PriorityInd = 1
			END
			ELSE
			BEGIN
				SELECT @PriorityInd = 0
			END
						
			--get the vin, if it exists then just update anything that might have changed.
			SELECT @VINCOUNT = COUNT(*)
			FROM Vehicle
			WHERE VIN = @MotorVehicleIDNumber
			AND CustomerID = @CustomerID
			AND CustomerIdentification = @ShipmentIdentificationNumber
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting vin count'
				GOTO Error_Encountered
			END
	
			IF @VINCOUNT > 0
			BEGIN
				--get the vehicle id
				SELECT TOP 1 @VehicleID = V.VehicleID,
				@VehicleOriginID = V.PickupLocationID,
				@VehicleDestinationID = V.DropoffLocationID,
				@VehiclePoolID = L.PoolID,
				@OldLegStatus = L.LegStatus,
				@CustomerIdentification = V.CustomerIdentification,
				@BayLocation = V.BayLocation
				FROM Vehicle V
				LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
				WHERE V.VIN = @MotorVehicleIDNumber
				AND V.CustomerID = @CustomerID
				AND CustomerIdentification = @ShipmentIdentificationNumber
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error getting vin count'
					GOTO Error_Encountered
				END

				IF @ReadyToShipDateTime IS NOT NULL
				BEGIN
					SELECT @AvailableForPickupDate = CONVERT(varchar(10),CURRENT_TIMESTAMP,101)
					SELECT @DateMadeAvailable = CURRENT_TIMESTAMP
					SELECT @LegStatus = 'Available'
				END
				ELSE
				BEGIN
					SELECT @AvailableForPickupDate = NULL
					SELECT @DateMadeAvailable = NULL
					SELECT @LegStatus = 'Pending'
				END
				
				IF @OldLegStatus <> 'Pending'
				BEGIN
					SELECT @NeedsReviewInd = 1
					--Handle Origin Or Destination Change When On Hold 
					IF @OldLegStatus = 'OnHold'
					BEGIN
						IF @OriginID <> @VehicleOriginID OR @DestinationID <> @VehicleDestinationID
						BEGIN
							SELECT @AvailableForPickupDate = NULL
							SELECT @DateMadeAvailable = NULL
							SELECT @LegStatus = @OldLegStatus
							SELECT @RecordStatus = 'VEHICLE IS ON HOLD - '
						END
						ELSE
						BEGIN
							SELECT @RecordStatus = 'VEHICLE IS ON HOLD'
							SELECT @ImportedInd = 0
							SELECT @ImportedDate = NULL
							SELECT @ImportedBy = NULL
							GOTO Do_Update
						END
					END
					ELSE
					BEGIN
						SELECT @RecordStatus = 'VEHICLE IS NOT PENDING'
						SELECT @ImportedInd = 0
						SELECT @ImportedDate = NULL
						SELECT @ImportedBy = NULL
						GOTO Do_Update
					END
					--Handle Origin Or Destination Change When On Hold 
				END
				
				-- start of origin/destination change code
				IF @OriginID <> @VehicleOriginID OR @DestinationID <> @VehicleDestinationID
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
								
					IF @AvailableForPickupDate IS NOT NULL
					BEGIN
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
							UpdatedBy = 'BluJay204'
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
								'BluJay204'
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
					
					-- update the vehicle record to make the vehicle available and set the new destination
					UPDATE Vehicle
					SET Color = @RepetitivePatternCode,
					PickupLocationID = @OriginID,
					DropoffLocationID = @DestinationID,
					ChargeRate = @ChargeRate,
					MiscellaneousAdditive = @MiscellaneousAdditive,
					CustomerIdentification = @ShipmentIdentificationNumber,
					SizeClass = @SizeClass,
					PriorityInd = @PriorityInd,
					VehicleStatus = @LegStatus,
					AvailableForPickupDate = @AvailableForPickupDate,
					UpdatedBy = 'BluJay204',
					UpdatedDate = CURRENT_TIMESTAMP,
					DateMadeAvailable = ISNULL(DateMadeAvailable, @DateMadeAvailable),
					DealerETADate = @DeliveryFromDateTime
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
					DateAvailable = @AvailableForPickupDate,
					LegStatus = @LegStatus,
					UpdatedDate = CURRENT_TIMESTAMP,
					UpdatedBy = 'Toyota Tender'
					WHERE VehicleID = @VehicleID
					AND LegNumber = 1
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING LEG RECORD'
						GOTO Error_Encountered
					END
								
					SELECT @ImportedInd = 1
					SELECT @ImportedDate = GetDate()
					SELECT @ImportedBy = @UserCode
					
					--10/13/2015 CMK Start Mods To Handle Origin Or Destination Change When On Hold 
					IF @OriginID <> @VehicleOriginID AND @DestinationID <> @VehicleDestinationID
					BEGIN
						SELECT @RecordStatus = @RecordStatus + 'ORIGIN & DESTINATION UPDATED'
					END
					ELSE IF @OriginID <> @VehicleOriginID
					BEGIN
						SELECT @RecordStatus = @RecordStatus + 'ORIGIN UPDATED'
					END
						ELSE IF @DestinationID <> @VehicleDestinationID
					BEGIN
						SELECT @RecordStatus = @RecordStatus + 'DESTINATION UPDATED'
					END
					
					--10/13/2015 CMK End Mods To Handle Origin Or Destination Change When On Hold 
					GOTO Do_Update
				END
				--end of update origin/destination code
				--update logic here.
				UPDATE Vehicle
				SET Color = @RepetitivePatternCode,
				PickupLocationID = @OriginID,
				DropoffLocationID = @DestinationID,
				ChargeRate = @ChargeRate,
				MiscellaneousAdditive = @MiscellaneousAdditive,
				CustomerIdentification = @ShipmentIdentificationNumber,
				PriorityInd = @PriorityInd,
				SizeClass = @SizeClass,
				VehicleStatus = @LegStatus,
				AvailableForPickupDate = @AvailableForPickupDate,
				DateMadeAvailable = ISNULL(DateMadeAvailable,@DateMadeAvailable),
				DealerETADate = @DeliveryFromDateTime
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
								'BluJay204'	--CreatedBy
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
								'BluJay204'	--CreatedBy
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
						'BluJay204',	--CreatedBy
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
						NULL,			--RequestedPickupDate,
						NULL,			--RequestedDeliveryDate,
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
						@PurchaseOrderNumber,	--PONumber,
						'Pending',		--OrderStatus,
						GetDate(),		--CreationDate,
						'BluJay204',		--CreatedBy,
						NULL,			--UpdatedDate,
						NULL			--UpdatedBy
					)
	
					--need to get the orderId key here, to insert into the vehicle record.			
					SELECT @OrderID = @@identity
				END

				--and now do the vehicle
				IF @VehicleYear IS NULL OR DATALENGTH(@VehicleYear)<1
				BEGIN
					SELECT @VehicleYear = @ModelYearNumber
				END
				IF @Make IS NULL OR DATALENGTH(@Make)<1
				BEGIN
					SELECT @Make = 'Volvo'
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
				
				IF @ReadyToShipDateTime IS NOT NULL
				BEGIN
					SELECT @AvailableForPickupDate = CONVERT(varchar(10),CURRENT_TIMESTAMP,101)
					SELECT @DateMadeAvailable = CURRENT_TIMESTAMP
					SELECT @LegStatus = 'Available'
				END
				ELSE
				BEGIN
					SELECT @AvailableForPickupDate = NULL
					SELECT @DateMadeAvailable = NULL
					SELECT @LegStatus = 'Pending'
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
					DateMadeAvailable,
					DealerETADate
				)
				VALUES(
					@CustomerID,			--CustomerID,
					@OrderID,			--OrderID,
					@VehicleYear,			--VehicleYear,
					@Make,				--Make,
					@Model,				--Model,
					@Bodystyle,			--Bodystyle,
					@MotorVehicleIDNumber,		--VIN,
					@RepetitivePatternCode,		--Color,
					@VehicleLength,			--VehicleLength
					@VehicleWidth,			--VehicleWidth
					@VehicleHeight,			--VehicleHeight
					@OriginID,			--PickupLocationID,
					@DestinationID,			--DropoffLocationID,
					@LegStatus,			--VehicleStatus,
					'Pickup Point',			--VehicleLocation,
					@ShipmentIdentificationNumber,	--CustomerIdentification,
					@SizeClass,			--SizeClass,
					'',				--BayLocation,
					NULL,				--RailCarNumber,
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
					'BluJay204',			--CreatedBy
					NULL,				--UpdatedDate,
					NULL,				--UpdatedBy
					0,				--CreditHoldInd
					0,				--PickupNotificationSentInd
					0,				--STIDeliveryNotificationSentInd
					0,				--BillOfLadingSentInd
					0,				--DealerHoldOverrideInd
					@MiscellaneousAdditive,		--MiscellaneousAdditive
					0,				--FuelSurcharge
					0,				--AccessoriesCompleteInd,
					0,				--PDICompleteInd
					0,				--FinalShipawayInspectionDoneInd
					@DateMadeAvailable,		--DateMadeAvailable
					@DeliveryFromDateTime		--DealerETADate
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
							'BluJay204'	--CreatedBy
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
					'BluJay204',	--CreatedBy
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
		END
		ELSE
		BEGIN
			SELECT @RecordStatus = 'UNKNOWN TRANS SET PURPOSE'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
		END
		
		--update logic here.
		Do_Update:
		UPDATE BluJayImport204
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy,
		VehicleID = @VehicleID
		WHERE BluJayImport204ID = @BluJayImport204ID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH BluJay204Cursor INTO @BluJayImport204ID, @ShipmentIdentificationNumber, @TransactionSetPurposeCode, @ModelYearNumber,
			@TransportationPriorityNumber, @RepetitivePatternCode, @PurchaseOrderNumber, @MotorVehicleIDNumber,
			@ShipperIdentificationCode, @PickupFromDateTime, @ShipFromName, @ShipFromCode, @ShipFromAddress,
			@ShipFromCity, @ShipFromState, @ShipFromPostalCode, @ShipFromCountry, @ShipToName, @ShipToCode,
			@ShipToAddress, @ShipToCity, @ShipToState, @ShipToPostalCode, @ShipToCountry, @DeliveryFromDateTime,
			@VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength, @VehicleWidth, @VehicleHeight, @VINDecodedInd,
			@ReadyToShipDateTime

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
		CLOSE BluJay204Cursor
		DEALLOCATE BluJay204Cursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE BluJay204Cursor
		DEALLOCATE BluJay204Cursor
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
