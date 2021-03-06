USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportGM911]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportGM911] (@BatchID int,
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	@GMImport911ID			int,
	@ActionCode			varchar(1),
	@SCAC				varchar(4),
	@RequestNumber			varchar(6),
	@RequestDateTime		datetime,
	@RateQualifier			varchar(1),
	@OriginSellingDivision		varchar(2),
	@OriginDealerCode		varchar(5),
	@OriginCDL			varchar(2),
	@OriginName			varchar(23),
	@OriginStreet			varchar(26),
	@OriginCity			varchar(20),
	@OriginState			varchar(15),
	@OriginContactName		varchar(15),
	@OriginPhoneNumber		varchar(12),
	@RequestedPickupDateTime	datetime,
	@DestinationSellingDivision	varchar(2),
	@DestinationDealerCode		varchar(5),
	@DestinationCDL			varchar(2),
	@DestinationName		varchar(23),
	@DestinationStreet		varchar(26),
	@DestinationCity		varchar(20),
	@DestinationState		varchar(2),
	@DestinationContactName		varchar(15),
	@DestinationPhoneNumber		varchar(12),
	@VIN				varchar(17),
	@Remarks			varchar(40),
	@VehicleYear			varchar(6),
	@Make				varchar(50),
	@Model				varchar(50),
	@Bodystyle			varchar(50),
	@VehicleLength			varchar(10),
	@VehicleWidth			varchar(10),
	@VehicleHeight			varchar(10),
	@VINDecodedInd			int,
	@CreationDate			datetime,
	@VINCOUNT			int,
	@DestinationID			int,
	@OriginID			int,
	@ChargeRate			decimal(19,2),
	@CustomerID			int,
	@OrderID			int,
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
	@ImportError			int,
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@VehicleOriginID		int,
	@VehicleDestinationID		int,
	@VehicleDestinationCode		varchar(20),
	@CustomerIdentification		varchar(20),
	@VehicleLoadID			int,
	@VehiclePoolID			int,
	@LegStatus			varchar(20),
	@VehicleStatus			varchar(20),
	@SizeClass			varchar(20),
	@PoolRecordCount		int,
	@LoadID				int,
	@LoadNumber			varchar(20),
	@LegsID				int,
	@Reserved			int,
	@Available			int,
	@PoolSize			int,
	@OldLegStatus			varchar(20),
	@RailcarNumber			varchar(20),
	@AvailableForPickupDate		datetime,
	@StatusCode			varchar(1),
	@ErrorCode			varchar(3),
	@PriorityInd			int,
	@Count				int

	/************************************************************************
	*	spImportGM911							*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the GMImport911 table and	*
	*	creates the new orders and vehicle records. It can also delete	*
	*	existing records if the Action Code is 'D'			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	11/15/2013 CMK    Initial version				*
	*									*
	************************************************************************/
	SELECT @PreviousOrigin = 0
	SELECT @PreviousDestination = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @NeedsReviewInd = 0
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'GMCustomerID'
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

	DECLARE GM911Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT GMImport911ID, ActionCode, SCAC, RequestNumber, RequestDateTime,
		RateQualifier, OriginSellingDivision, OriginDealerCode, OriginCDL, OriginName, OriginStreet,
		OriginCity, OriginState, OriginContactName, OriginPhoneNumber, RequestedPickupDateTime,
		DestinationSellingDivision, DestinationDealerCode, DestinationCDL, DestinationName,
		DestinationStreet, DestinationCity, DestinationState, DestinationContactName,
		DestinationPhoneNumber, VIN, Remarks, VehicleYear, Make, Model, Bodystyle,
		VehicleLength, VehicleWidth, VehicleHeight, VINDecodedInd
		FROM GMImport911
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY ActionCode DESC, OriginDealerCode, OriginCDL, OriginName, DestinationDealerCode, DestinationCDL, DestinationName

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN GM911Cursor

	BEGIN TRAN

	FETCH GM911Cursor INTO @GMImport911ID, @ActionCode, @SCAC, @RequestNumber, @RequestDateTime,
		@RateQualifier, @OriginSellingDivision, @OriginDealerCode, @OriginCDL, @OriginName, @OriginStreet,
		@OriginCity, @OriginState, @OriginContactName, @OriginPhoneNumber, @RequestedPickupDateTime,
		@DestinationSellingDivision, @DestinationDealerCode, @DestinationCDL, @DestinationName,
		@DestinationStreet, @DestinationCity, @DestinationState, @DestinationContactName,
		@DestinationPhoneNumber, @VIN, @Remarks, @VehicleYear, @Make, @Model, @Bodystyle,
		@VehicleLength, @VehicleWidth, @VehicleHeight, @VINDecodedInd

	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @ImportedInd = 0
		SELECT @ImportedDate = NULL
		SELECT @ImportedBy = NULL
		SELECT @OriginID = NULL
		SELECT @DestinationID = NULL
		SELECT @ImportError = 0
		
		IF @ActionCode = 'D' -- try to delete the vehicle
		BEGIN
			--get the vin, if it exists then see if it can be deleted.
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
				--validate the origin and destination
				--make sure the vin is not en route or delivered
				SELECT TOP 1 @VehicleID = V.VehicleID,
				@VehicleDestinationID = V.DropoffLocationID,
				@VehicleDestinationCode = L2.CustomerLocationCode,
				@CustomerIdentification = V.CustomerIdentification,
				@VehicleStatus = V.VehicleStatus,
				@LoadID = L3.LoadsID,
				@LoadNumber = L3.LoadNumber,
				@VehiclePoolID = L.PoolID,
				@LegsID = L.LegsID
				FROM Vehicle V
				LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
				LEFT JOIN Location L2 ON V.DropoffLocationID = L2.LocationID
				LEFT JOIN Loads L3 ON L.LoadID = L3.LoadsID
				WHERE V.VIN = @VIN
				--AND LEFT(CustomerID,2) = @DealerSellingDivision
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING VEHICLE STATUS'
					GOTO Error_Encountered
				END
				/*		
				IF @DealerCode <> @VehicleDestinationCode
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'CANNOT DELETE - DESTINATON MISMATCH'
					GOTO Update_Record_Status
				END
				*/
				/*
				IF @DealerSellingDivision+'/' <> @CustomerIdentification
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'CANNOT DELETE - CUSTOMER IDENTIFICATION MISMATCH'
					GOTO Update_Record_Status
				END
				*/		
				IF @VehicleStatus = 'Delivered'
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'CANNOT DELETE - VEHICLE DELIVERED'
					SELECT @ImportedInd = 1
					SELECT @StatusCode = 'R'
					SELECT @ErrorCode = '84'	--Vehicle has been shipped - cannot update
					GOTO Update_Record_Status
				END
						
				IF @VehicleStatus = 'EnRoute'
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'CANNOT DELETE - VEHICLE ENROUTE'
					SELECT @ImportedInd = 1
					SELECT @StatusCode = 'R'
					SELECT @ErrorCode = '84'	--Vehicle has been shipped - cannot update
					GOTO Update_Record_Status
				END
				
				SELECT @Count = COUNT(*)
				FROM VehicleDamageDetail
				WHERE VehicleID = @VehicleID
				AND (DamageClaimID IS NOT NULL
				OR DamageIncidentReportID IS NOT NULL)
				
				IF @Count > 0
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'CANNOT DELETE - HAS INCIDENT OR CLAIM'
					SELECT @ImportedInd = 1
					SELECT @StatusCode = 'R'
					SELECT @ErrorCode = '84'	--Vehicle has been shipped - cannot update
					GOTO Update_Record_Status
				END
						
				SELECT @RecordStatus = ''
						
				-- got this far so we should be able to delete the vehicle
						
				-- if the vehicle is in a load remove it from the load
				IF @LoadID IS NOT NULL
				BEGIN
					SELECT @ReturnCode = 1
					EXEC spRemoveVehicleFromLoad @LegsID, @LoadID, @CreationDate,
					@UserCode, @rReturnCode = @ReturnCode OUTPUT
					IF @ReturnCode <> 0
					BEGIN
						SELECT @ErrorID = @ReturnCode
						GOTO Error_Encountered
					END
							
					--since we removed the vehicle from a load, it should now have a pool id
					SELECT @VehiclePoolID = PoolID
					FROM Legs
					WHERE LegsID = @LegsID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR GETTING POOL ID'
						GOTO Error_Encountered
					END
					
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'VEHICLE DELETED - REMOVED FROM LOAD '+@LoadNumber+', '
				END
					
				-- if there is a pool id reduce the pool size
				IF @VehiclePoolID IS NOT NULL
				BEGIN
					UPDATE VehiclePool
					SET PoolSize = PoolSize - 1,
					Available = Available - 1
					WHERE VehiclePoolID = @VehiclePoolID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING POOL'
						GOTO Error_Encountered
					END
				END
				
				-- delete the vehicle
				DELETE Vehicle
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR DELETING VEHICLE'
					GOTO Error_Encountered
				END
				
				-- delete any vehicle holds
				DELETE VehicleHolds
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR DELETING VEHICLE'
					GOTO Error_Encountered
				END
				
				-- delete the leg
				DELETE Legs
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR DELETING LEG'
					GOTO Error_Encountered
				END
				
				--delete any inspection records
				DELETE VehicleInspection
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR DELETING INSPECTION'
					GOTO Error_Encountered
				END
				
				--delete any damage records
				DELETE VehicleDamageDetail
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR DELETING DAMAGE'
					GOTO Error_Encountered
				END
								
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = GetDate()
				SELECT @ImportedBy = @UserCode
				SELECT @RecordStatus = @RecordStatus +'VEHICLE DELETED'
			END
			ELSE IF @VINCOUNT > 1
			BEGIN
				SELECT @NeedsReviewInd = 1
				SELECT @RecordStatus = 'CANNOT DELETE - MULTIPLE MATCHES FOUND FOR VIN'
				SELECT @ImportedInd = 1
				SELECT @StatusCode = 'R'
				SELECT @ErrorCode = '903'	--VEHICLE NOT FOUND
			END
			ELSE
			BEGIN
				SELECT @NeedsReviewInd = 1
				SELECT @RecordStatus = 'CANNOT DELETE - VIN NOT FOUND'
				SELECT @ImportedInd = 1
				SELECT @StatusCode = 'R'
				SELECT @ErrorCode = '903'	--VEHICLE NOT FOUND
			END
			GOTO Update_Record_Status
		END
		ELSE
		BEGIN
			--get the destination
			IF DATALENGTH(@DestinationCDL) > 0
			BEGIN
				SELECT @DestinationID = CONVERT(int,Value1)
				FROM Code
				WHERE CodeType = 'GMLocationCode'
				AND Code = @DestinationCDL
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING DESTINATION LOCATION CDL CODE'
					GOTO Error_Encountered
				END
			END
			ELSE IF DATALENGTH(@DestinationDealerCode) > 0
			BEGIN
				SELECT TOP 1 @DestinationID = LocationID
				FROM Location
				WHERE ParentRecordID = @CustomerID
				AND ParentRecordTable = 'Customer'
				AND (CustomerLocationCode = @DestinationDealerCode
				OR CustomerLocationCode = @DestinationSellingDivision+'-'+@DestinationDealerCode)
				ORDER BY CASE WHEN DATALENGTH(CustomerLocationCode) > 5 THEN 0 ELSE 1 END	--match with selling division and dealer code is preferred match
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING DESTINATION LOCATION BY DEALER CODE'
					GOTO Error_Encountered
				END
			END
			ELSE
			BEGIN
				SELECT TOP 1 @DestinationID = LocationID
				FROM Location
				WHERE LocationName = @DestinationName
				AND AddressLine1 = @DestinationStreet
				AND City = @DestinationCity
				AND State = @DestinationState
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING DESTINATION LOCATION BY NAME'
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
					CustomerLocationCode,
					AddressLine1,
					City,
					State,
					Country,
					MainPhone,
					PrimaryContactFirstName,
					PrimaryContactPhone,
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
					CASE WHEN DATALENGTH(@DestinationName) > 0 THEN @DestinationName ELSE 'NEED LOCATION NAME' END,
					@DestinationDealerCode,
					@DestinationStreet,
					@DestinationCity,
					@DestinationState,
					'U.S.A.',
					@DestinationPhoneNumber,
					@DestinationContactName,
					@DestinationPhoneNumber,
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
			IF DATALENGTH(@OriginCDL) > 0
			BEGIN
				SELECT @OriginID = CONVERT(int,Value1)
				FROM Code
				WHERE CodeType = 'GMLocationCode'
				AND Code = LEFT(@OriginCDL,2)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING ORIGIN LOCATION BY CDL CODE'
					GOTO Error_Encountered
				END			END
			ELSE IF DATALENGTH(@OriginDealerCode) > 0
			BEGIN
				SELECT @OriginID = LocationID
				FROM Location
				WHERE ParentRecordID = @CustomerID
				AND ParentRecordTable = 'Customer'
				AND (CustomerLocationCode = @OriginDealerCode
				OR CustomerLocationCode = @OriginSellingDivision+'-'+@OriginDealerCode)
				ORDER BY CASE WHEN DATALENGTH(CustomerLocationCode) > 5 THEN 0 ELSE 1 END	--match with selling division and dealer code is preferred matchIF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING ORIGIN LOCATION BY DEALER CODE'
					GOTO Error_Encountered
				END
			END
			ELSE
			BEGIN
				SELECT TOP 1 @OriginID = LocationID
				FROM Location
				WHERE LocationName = @OriginName
				AND AddressLine1 = @OriginStreet
				AND City = @OriginCity
				AND State = @OriginState
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING ORIGIN LOCATION BY NAME'
					GOTO Error_Encountered
				END
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
					AddressLine1,
					City,
					State,
					Country,
					MainPhone,
					PrimaryContactFirstName,
					PrimaryContactPhone,
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
					CASE WHEN DATALENGTH(@OriginName) > 0 THEN @OriginName ELSE 'NEED LOCATION NAME' END,
					@OriginDealerCode,
					@OriginStreet,
					@OriginCity,
					@OriginState,
					'U.S.A.',
					@OriginPhoneNumber,
					@OriginContactName,
					@OriginPhoneNumber,
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
					SELECT @Status = 'ERROR CREATING ORIGIN LOCATION'
					GOTO Error_Encountered
				END
				SELECT @OriginID = @@Identity
			END
			
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
			
			SELECT @ChargeRate = NULL
			
			IF @RateQualifier = 'S'
			BEGIN
				--From these values we can get the financial information.
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
					SELECT @Status = 'Error getting rate'
					GOTO Error_Encountered
				END
			END
			
			SELECT @RailcarNumber = ''
			
			SELECT @PriorityInd = 0
			
			SELECT @AvailableForPickupDate = @RequestDateTime
						
			--get the vin, if it exists then just update anything that might have changed.
			SELECT @VINCOUNT = COUNT(*)
			FROM Vehicle
			WHERE VIN = @VIN
			AND PickupLocationID = @OriginID
			AND DropoffLocationID = @DestinationID
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
				@CustomerIdentification = V.CustomerIdentification,
				@VehicleLoadID = L.LoadID,
				@VehiclePoolID = L.PoolID,
				@OldLegStatus = LegStatus,
				@LegsID = L.LegsID
				FROM Vehicle V
				LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
				AND L.LegNumber = 1
				WHERE V.VIN = @VIN
				AND V.PickupLocationID = @OriginID
				AND V.DropoffLocationID = @DestinationID
				ORDER BY V.VehicleID DESC	--want the most recent vehicle if multiples
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING VEHICLE STATUS'
					GOTO Error_Encountered
				END
							
				-- check the origin/destination/allocation number
				IF @OriginID = @VehicleOriginID 
					AND @DestinationID = @VehicleDestinationID
					AND LEFT(@CustomerIdentification,2) = @DestinationSellingDivision
				BEGIN
					IF @OldLegStatus IN ('Complete','EnRoute')
					BEGIN
						SELECT @RecordStatus = 'ALREADY ENROUTE'
					END
					ELSE IF @OldLegStatus = 'Delivered'
					BEGIN
						SELECT @RecordStatus = 'ALREADY DELIVERED'
					END
					ELSE
					BEGIN
						SELECT @RecordStatus = 'VIN ALREADY EXISTS'
					END
					SELECT @ImportedInd = 1
					SELECT @ImportedDate = GetDate()
					SELECT @ImportedBy = @UserCode
					SELECT @StatusCode = 'A'
					SELECT @ErrorCode = ''
					GOTO Update_Record_Status
				END
							
				IF @OldLegStatus = 'OnHold'
				BEGIN
					SELECT @LegStatus = 'OnHold'
					SELECT @VehicleStatus = 'OnHold'
					SELECT @AvailableForPickupDate = NULL
				END
				ELSE IF @AvailableForPickupDate IS NULL
				BEGIN
					SELECT @LegStatus = 'Pending'
					SELECT @VehicleStatus = 'Pending'
				END
				ELSE
				BEGIN
					SELECT @LegStatus = 'Available'
					SELECT @VehicleStatus = 'Available'
				END	
				
				SELECT @CustomerIdentification = @DestinationSellingDivision+'/'+@RequestNumber
			
				IF @OriginID = @VehicleOriginID 
					AND @DestinationID = @VehicleDestinationID
				BEGIN
					UPDATE Vehicle
					SET CustomerIdentification = @CustomerIdentification,
					RailcarNumber = @RailcarNumber,
					PriorityInd = @PriorityInd,
					Note = @Remarks
					WHERE VehicleID = @VehicleID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
						GOTO Error_Encountered
					END
					SELECT @RecordStatus = 'VEHICLE ORDER NUMBER UPDATED'
					SELECT @ImportedInd = 1
					SELECT @ImportedDate = GetDate()
					SELECT @ImportedBy = @UserCode
					SELECT @StatusCode = 'A'
					SELECT @ErrorCode = ''
					GOTO Update_Record_Status
				END
				ELSE IF @OriginID <> @VehicleOriginID AND @DestinationID <> @VehicleDestinationID
				BEGIN
					IF @OldLegStatus IN ('Complete','EnRoute')
					BEGIN
						SELECT @NeedsReviewInd = 1
						SELECT @RecordStatus = 'DEST. MISMATCH - ENROUTE'
						SELECT @ImportedInd = 0
						SELECT @ImportedDate = NULL
						SELECT @ImportedBy = NULL
						SELECT @StatusCode = 'R'
						SELECT @ErrorCode = '84'	--Vehicle has been shipped - cannot update
						GOTO Update_Record_Status
					END
					ELSE IF @OldLegStatus = 'Delivered'
					BEGIN
						SELECT @NeedsReviewInd = 1
						SELECT @RecordStatus = 'DEST. MISMATCH - DELIVERED'
						SELECT @ImportedInd = 0
						SELECT @ImportedDate = NULL
						SELECT @ImportedBy = NULL
						SELECT @StatusCode = 'R'
						SELECT @ErrorCode = '84'	--Vehicle has been shipped - cannot update
						GOTO Update_Record_Status
					END
					ELSE IF @VehicleLoadID IS NOT NULL
					BEGIN
						SELECT @ReturnCode = 1
						EXEC spRemoveVehicleFromLoad @LegsID, @VehicleLoadID, @CreationDate,
						@UserCode, @rReturnCode = @ReturnCode OUTPUT
						IF @ReturnCode <> 0
						BEGIN
							SELECT @ErrorID = @ReturnCode
							GOTO Error_Encountered
						END
							
						--since we removed the vehicle from a load, it should now have a pool id
						SELECT @VehiclePoolID = PoolID
						FROM Legs
						WHERE LegsID = @LegsID
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @Status = 'ERROR GETTING POOL ID'
							GOTO Error_Encountered
						END
							
						SELECT @NeedsReviewInd = 1				
						SELECT @RecordStatus = 'ORIGIN & DEST CHANGED - REMOVED FROM LOAD'
					END
					ELSE
					BEGIN
						SELECT @RecordStatus = 'ORIGIN & DEST CHANGED'
					END
				END
				ELSE IF @OriginID <> @VehicleOriginID
				BEGIN
					-- first two cases should not happen, adding just to be safe
					IF @OldLegStatus IN ('Complete','EnRoute')
					BEGIN
						SELECT @RecordStatus = 'ORIGIN MISMATCH - ENROUTE'
						SELECT @ImportedInd = 0
						SELECT @ImportedDate = NULL
						SELECT @ImportedBy = NULL
						SELECT @StatusCode = 'R'
						SELECT @ErrorCode = '84'	--Vehicle has been shipped - cannot update
						GOTO Update_Record_Status
					END
					ELSE IF @OldLegStatus = 'Delivered'
					BEGIN
						SELECT @RecordStatus = 'ORIGIN MISMATCH - DELIVERED'
						SELECT @ImportedInd = 0
						SELECT @ImportedDate = NULL
						SELECT @ImportedBy = NULL
						SELECT @StatusCode = 'R'
						SELECT @ErrorCode = '84'	--Vehicle has been shipped - cannot update
						GOTO Update_Record_Status
					END
					ELSE IF @VehicleLoadID IS NOT NULL
					BEGIN
						SELECT @ReturnCode = 1
						EXEC spRemoveVehicleFromLoad @LegsID, @VehicleLoadID, @CreationDate,
						@UserCode, @rReturnCode = @ReturnCode OUTPUT
						IF @ReturnCode <> 0
						BEGIN
							SELECT @ErrorID = @ReturnCode
							GOTO Error_Encountered
						END
							
						--since we removed the vehicle from a load, it should now have a pool id
						SELECT @VehiclePoolID = PoolID
						FROM Legs
						WHERE LegsID = @LegsID
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @Status = 'ERROR GETTING POOL ID'
							GOTO Error_Encountered
						END
							
						SELECT @NeedsReviewInd = 1				
						SELECT @RecordStatus = 'ORIGIN CHANGED - REMOVED FROM LOAD'
					END
					ELSE
					BEGIN
						SELECT @RecordStatus = 'ORIGIN CHANGED'
					END
				END
				ELSE IF @DestinationID <> @VehicleDestinationID
				BEGIN
					IF @OldLegStatus IN ('Complete','EnRoute')
					BEGIN
						SELECT @NeedsReviewInd = 1
						SELECT @RecordStatus = 'DEST. MISMATCH - ENROUTE'
						SELECT @ImportedInd = 0
						SELECT @ImportedDate = NULL
						SELECT @ImportedBy = NULL
						SELECT @StatusCode = 'R'
						SELECT @ErrorCode = '84'	--Vehicle has been shipped - cannot update
						GOTO Update_Record_Status
					END
					ELSE IF @OldLegStatus = 'Delivered'
					BEGIN
						SELECT @NeedsReviewInd = 1
						SELECT @RecordStatus = 'DEST. MISMATCH - DELIVERED'
						SELECT @ImportedInd = 0
						SELECT @ImportedDate = NULL
						SELECT @ImportedBy = NULL
						SELECT @StatusCode = 'R'
						SELECT @ErrorCode = '84'	--Vehicle has been shipped - cannot update
						GOTO Update_Record_Status
					END
					ELSE IF @VehicleLoadID IS NOT NULL
					BEGIN
						SELECT @ReturnCode = 1
						EXEC spRemoveVehicleFromLoad @LegsID, @VehicleLoadID, @CreationDate,
						@UserCode, @rReturnCode = @ReturnCode OUTPUT
						IF @ReturnCode <> 0
						BEGIN
							SELECT @ErrorID = @ReturnCode
							GOTO Error_Encountered
						END
							
						--since we removed the vehicle from a load, it should now have a pool id
						SELECT @VehiclePoolID = PoolID
						FROM Legs
						WHERE LegsID = @LegsID
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @Status = 'ERROR GETTING POOL ID'
							GOTO Error_Encountered
						END
							
						SELECT @NeedsReviewInd = 1			
						SELECT @RecordStatus = 'DESTINATION CHANGED - REMOVED FROM LOAD'
					END
					ELSE
					BEGIN
						SELECT @RecordStatus = 'DESTINATION CHANGED'
					END
				END
				--update logic here.
				UPDATE Vehicle
				SET PickupLocationID = @OriginID,
				DropoffLocationID = @DestinationID,
				CustomerIdentification = @CustomerIdentification,
				RailcarNumber = @RailcarNumber,
				ChargeRate = @ChargeRate,
				AvailableForPickupDate = @AvailableForPickupDate,
				PriorityInd = @PriorityInd,
				VehicleStatus = @VehicleStatus,
				Note = @Remarks,
				DateMadeAvailable = ISNULL(DateMadeAvailable,@RequestDateTime)
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
				
				IF @VehiclePoolID IS NOT NULL
				BEGIN
					UPDATE VehiclePool
					SET PoolSize = PoolSize - 1,
					Available = Available - 1
					WHERE VehiclePoolID = @VehiclePoolID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING OLD POOL'
						GOTO Error_Encountered
					END
				END
							
				IF @LegStatus = 'Available'
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
							'911 IMPORT'	--CreatedBy
						)
						IF @@Error <> 0
						BEGIN
							SELECT @ErrorID = @@ERROR
							SELECT @Status = 'ERROR CREATING POOL RECORD'
							GOTO Error_Encountered
						END
						SELECT @VehiclePoolID = @@Identity
						SELECT @Reserved = 0
						SELECT @Available = 0
						SELECT @PoolSize = 0
					END
					ELSE
					BEGIN
						SELECT @VehiclePoolID = VehiclePoolID,
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
					--add one to the pool
					UPDATE VehiclePool
					SET PoolSize = PoolSize + 1,
					Available = Available + 1
					WHERE VehiclePoolID = @VehiclePoolID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING POOL RECORD'
						GOTO Error_Encountered
					END
				END
				ELSE
				BEGIN
					SELECT @VehiclePoolID = NULL
				END
			
				UPDATE Legs
				SET PoolID = @VehiclePoolID
				WHERE VehicleID = @VehicleID
				AND LegNumber = 1
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error updating starting leg'
					GOTO Error_Encountered
				END
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = GetDate()
				SELECT @ImportedBy = @UserCode
				SELECT @StatusCode = 'A'
				SELECT @ErrorCode = ''
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
						'911 IMPORT',	--CreatedBy,
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
				
				SELECT @CustomerIdentification = @DestinationSellingDivision+'/'+@RequestNumber
							
			
				--NEED CODE FOR HoldStorageIndicator HERE
				--IF @HoldStorageIndicator IN ('S','B','H')
				--BEGIN
					--add or remove the hold as necessary and change the Leg/Vehicle Status
				--END
				
				INSERT VEHICLE(
					CustomerID,
					OrderID,
					VehicleYear,
					Make,
					Model,
					Bodystyle,
					VIN,
					--Color,
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
					Note,
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
					--@ExteriorColorCode,		--Color,
					@VehicleLength,			--VehicleLength
					@VehicleWidth,			--VehicleWidth
					@VehicleHeight,			--VehicleHeight
					@OriginID,			--PickupLocationID,
					@DestinationID,			--DropoffLocationID,
					'Available',			--VehicleStatus,
					'Pickup Point',			--VehicleLocation,
					@CustomerIdentification,	--CustomerIdentification,
					@SizeClass,			--SizeClass,
					NULL,				--BayLocation,
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
					GetDate(),			--CreationDate
					'911 IMPORT',			--CreatedBy
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
					@Remarks,			--Note
					@RequestDateTime		--DateMadeAvailable
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
	
				--get the poolid
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
						'911 IMPORT'	--CreatedBy
					)
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR CREATING POOL RECORD'
						GOTO Error_Encountered
					END
					SELECT @VehiclePoolID = @@Identity
					SELECT @Reserved = 0
					SELECT @Available = 0
					SELECT @PoolSize = 0
				END
				ELSE
				BEGIN
					SELECT @VehiclePoolID = VehiclePoolID,
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
				--add one to the pool
				UPDATE VehiclePool
				SET PoolSize = PoolSize + 1,
				Available = Available + 1
				WHERE VehiclePoolID = @VehiclePoolID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING POOL RECORD'
					GOTO Error_Encountered
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
					@VehiclePoolID,			--PoolID
					@AvailableForPickupDate,	--DateAvailable
					@OriginID,
					@DestinationID,
					0, 				--OutsideCarrierLegInd
					0, 				--OutsideCarrierPaymentMethod
					0, 				--OutsideCarrierPercentage
					0, 				--OutsideCarrierPay
					0,				--OutsideCarrierFuelSurchargePercentage
					0,				--OCFSPEstablishedInd
					1, 				--LegNumber
					1, 				--FinalLegInd
					'Available',
					0,
					GetDate(), 			--CreationDate
					'911 IMPORT', 			--CreatedBy
					0				--OutsideCarrierFuelSurchargeType
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
				SELECT @StatusCode = 'A'
				SELECT @ErrorCode = ''
			END
		END
		
		--update logic here.
		Update_Record_Status:
		UPDATE GMImport911
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE GMImport911ID = @GMImport911ID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END
		
		--also insert record for GM 915 Export
		INSERT INTO GMExport915(
			VehicleID,
			EventType,
			SCAC,
			CDLCode,
			RequestNumber,
			VIN,
			RequestDateTime,
			StatusCode,
			ErrorCode,
			ExportedInd,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@VehicleID,
			'SM',			--EventType
			@SCAC,
			CASE WHEN DATALENGTH(@OriginCDL) > 0 THEN @OriginCDL ELSE 'K9' END,
			@RequestNumber,		--RequestNumber
			@VIN,
			CURRENT_TIMESTAMP,	--RequestDateTime
			@StatusCode,
			@ErrorCode,
			0,			--ExportedInd
			'Export Pending',	--RecordStatus
			@CreationDate,
			@UserCode		--CreatedBy
		)
		
		FETCH GM911Cursor INTO @GMImport911ID, @ActionCode, @SCAC, @RequestNumber, @RequestDateTime,
			@RateQualifier, @OriginSellingDivision, @OriginDealerCode, @OriginCDL, @OriginName, @OriginStreet,
			@OriginCity, @OriginState, @OriginContactName, @OriginPhoneNumber, @RequestedPickupDateTime,
			@DestinationSellingDivision, @DestinationDealerCode, @DestinationCDL, @DestinationName,
			@DestinationStreet, @DestinationCity, @DestinationState, @DestinationContactName,
			@DestinationPhoneNumber, @VIN, @Remarks, @VehicleYear, @Make, @Model, @Bodystyle,
			@VehicleLength, @VehicleWidth, @VehicleHeight, @VINDecodedInd

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
		CLOSE GM911Cursor
		DEALLOCATE GM911Cursor
		PRINT 'GM Import 911 Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE GM911Cursor
		DEALLOCATE GM911Cursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			PRINT 'GM Import 911 Error_Encountered =' + STR(@ErrorID)
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
