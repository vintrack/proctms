USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportGM904]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportGM904] (@BatchID int,
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	@GMImport904ID			int,
	@ActionCode			varchar(1),
	@VIN				varchar(17),
	@VehicleOrderNumber		varchar(6),
	@NextRouteCode			varchar(6),
	@DealerSellingDivision		varchar(2),
	@DealerCode			varchar(5),
	@EquipmentType			varchar(1),
	@EquipmentNumber		varchar(10),
	@HoldStorageIndicator		varchar(1),
	@CXDFlag			varchar(1),
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
	@BayLocation			varchar(20),
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
	@DateAvailable			datetime,
	@PoolID				int,
	@PriorityInd			int,
	@Count				int,
	@DateMadeAvailable		datetime

	/************************************************************************
	*	spImportGM904							*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the GMImport904 table and	*
	*	creates the new orders and vehicle records. It can also delete	*
	*	existing records if the Action Code is 'D'			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	05/27/2010 CMK    Initial version				*
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

	DECLARE GM904Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT GMImport904ID, ActionCode, NextRouteCode, DealerSellingDivision, DealerCode, VIN,
			CXDFlag, EquipmentType, EquipmentNumber, VehicleOrderNumber, HoldStorageIndicator,
			VehicleYear, Make, Model, Bodystyle, VehicleLength, VehicleWidth,
			VehicleHeight, VINDecodedInd
		FROM GMImport904
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY ActionCode DESC, NextRouteCode, DealerCode, GMImport904ID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN GM904Cursor

	BEGIN TRAN

	FETCH GM904Cursor INTO @GMImport904ID, @ActionCode, @NextRouteCode, @DealerSellingDivision, @DealerCode, @VIN,
		@CXDFlag, @EquipmentType, @EquipmentNumber, @VehicleOrderNumber, @HoldStorageIndicator, @VehicleYear, @Make, 
		@Model, @Bodystyle, @VehicleLength, @VehicleWidth, @VehicleHeight, @VINDecodedInd

	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @BayLocation = NULL
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
			--AND LEFT(CustomerID,2) = @DealerSellingDivision
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
					GOTO Update_Record_Status
				END
						
				IF @VehicleStatus = 'EnRoute'
				BEGIN
					SELECT @NeedsReviewInd = 1
					SELECT @RecordStatus = 'CANNOT DELETE - VEHICLE ENROUTE'
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
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = GetDate()
				SELECT @ImportedBy = @UserCode
				SELECT @RecordStatus = 'CANNOT DELETE - MULTIPLE MATCHES FOUND FOR VIN'
			END
			ELSE
			BEGIN
				SELECT @NeedsReviewInd = 1
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = GetDate()
				SELECT @ImportedBy = @UserCode
				SELECT @RecordStatus = 'CANNOT DELETE - VIN NOT FOUND'
			END
			GOTO Update_Record_Status
		END
		ELSE
		BEGIN
			--get the destination
			SELECT TOP 1 @DestinationID = LocationID
			FROM Location
			WHERE ParentRecordID = @CustomerID
			AND ParentRecordTable = 'Customer'
			AND (CustomerLocationCode = @DealerCode
			OR CustomerLocationCode = @DealerSellingDivision+'-'+@DealerCode)
			ORDER BY CASE WHEN DATALENGTH(CustomerLocationCode) > 5 THEN 0 ELSE 1 END	--match with selling division and dealer code is preferred match
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
			SELECT @OriginID = CONVERT(int,Value1)
			FROM Code
			WHERE CodeType = 'GMLocationCode'
			AND Code = LEFT(@NextRouteCode,2)
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
				SELECT @RecordStatus = 'ORIGIN CODE '+LEFT(@NextRouteCode,2)+' NOT FOUND'
				GOTO Update_Record_Status
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
						
			IF @EquipmentType = 'R'
			BEGIN
				SELECT @RailcarNumber = @EquipmentNumber
			END
			ELSE
			BEGIN
				SELECT @RailcarNumber = ''
			END
			
			IF @CXDFlag = 'S'
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
			WHERE VIN = @VIN
			--AND CustomerID = @CustomerID
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
				--AND V.CustomerID = @CustomerID
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
					AND LEFT(@CustomerIdentification,2) = @DealerSellingDivision
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
					GOTO Update_Record_Status
				END
							
				-- if we are seeing the vehicle again, want to see if it should be available or not
				SELECT @AvailableForPickupDate = NULL
						
				SELECT @Count = COUNT(*)
				FROM CSXRailheadFeedImport
				WHERE VIN = @VIN
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING CSX RELEASE COUNT'
					GOTO Error_Encountered
				END
							
				IF @Count > 0
				BEGIN
					SELECT TOP 1 @AvailableForPickupDate = UnloadDate,
					@BayLocation = BayLocation
					FROM CSXRailheadFeedImport
					WHERE VIN = @VIN
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR GETTING CSX RELEASE COUNT'
						GOTO Error_Encountered
					END
				END
						
				IF @OldLegStatus = 'OnHold'
				BEGIN
					SELECT @LegStatus = 'OnHold'
					SELECT @VehicleStatus = 'OnHold'
					SELECT @AvailableForPickupDate = NULL
					SELECT @DateMadeAvailable = CURRENT_TIMESTAMP
				END
				ELSE IF @AvailableForPickupDate IS NULL
				BEGIN
					SELECT @LegStatus = 'Pending'
					SELECT @VehicleStatus = 'Pending'
					SELECT @DateMadeAvailable = NULL
				END
				ELSE
				BEGIN
					SELECT @LegStatus = 'Available'
					SELECT @VehicleStatus = 'Available'
					SELECT @DateMadeAvailable = CURRENT_TIMESTAMP
				END	
				
				--NEED CODE FOR HoldStorageIndicator HERE
				--IF @HoldStorageIndicator IN ('S','B','H')
				--BEGIN
					--add or remove the hold as necessary and change the Leg/Vehicle Status
				--END
				
				SELECT @CustomerIdentification = @DealerSellingDivision+'/'
			
				IF @OriginID = @VehicleOriginID 
					AND @DestinationID = @VehicleDestinationID
				BEGIN
					UPDATE Vehicle
					SET CustomerIdentification = @CustomerIdentification,
					RailcarNumber = @RailcarNumber,
					PriorityInd = @PriorityInd
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
						GOTO Update_Record_Status
					END
					ELSE IF @OldLegStatus = 'Delivered'
					BEGIN
						SELECT @NeedsReviewInd = 1
						SELECT @RecordStatus = 'DEST. MISMATCH - DELIVERED'
						SELECT @ImportedInd = 0
						SELECT @ImportedDate = NULL
						SELECT @ImportedBy = NULL
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
						GOTO Update_Record_Status
					END
					ELSE IF @OldLegStatus = 'Delivered'
					BEGIN
						SELECT @RecordStatus = 'ORIGIN MISMATCH - DELIVERED'
						SELECT @ImportedInd = 0
						SELECT @ImportedDate = NULL
						SELECT @ImportedBy = NULL
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
						GOTO Update_Record_Status
					END
					ELSE IF @OldLegStatus = 'Delivered'
					BEGIN
						SELECT @NeedsReviewInd = 1
						SELECT @RecordStatus = 'DEST. MISMATCH - DELIVERED'
						SELECT @ImportedInd = 0
						SELECT @ImportedDate = NULL
						SELECT @ImportedBy = NULL
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
				BayLocation = @BayLocation,
				PriorityInd = @PriorityInd,
				VehicleStatus = @VehicleStatus,
				DateMadeAvailable = ISNULL(DateMadeAvailable,@DateMadeAvailable)
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
							'904 IMPORT'	--CreatedBy
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
						'904 IMPORT',	--CreatedBy,
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
				
				SELECT @CustomerIdentification = @DealerSellingDivision+'/'
							
				SELECT @AvailableForPickupDate = NULL
										
				SELECT @Count = COUNT(*)
				FROM CSXRailheadFeedImport
				WHERE VIN = @VIN
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING CSX RELEASE COUNT'
					GOTO Error_Encountered
				END
											
				IF @Count > 0
				BEGIN
					SELECT TOP 1 @AvailableForPickupDate = UnloadDate,
					@BayLocation = BayLocation
					FROM CSXRailheadFeedImport
					WHERE VIN = @VIN
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR GETTING CSX RELEASE COUNT'
						GOTO Error_Encountered
					END
				END
										
				IF @AvailableForPickupDate IS NULL
				BEGIN
					SELECT @LegStatus = 'Pending'
					SELECT @VehicleStatus = 'Pending'
					SELECT @DateMadeAvailable = NULL
				END
				ELSE
				BEGIN
					SELECT @LegStatus = 'Available'
					SELECT @VehicleStatus = 'Available'
					SELECT @DateMadeAvailable = CURRENT_TIMESTAMP
				END
				
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
					@VehicleStatus,			--VehicleStatus,
					'Pickup Point',			--VehicleLocation,
					@CustomerIdentification,	--CustomerIdentification,
					@SizeClass,			--SizeClass,
					@BayLocation,			--BayLocation,
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
					'904 IMPORT',			--CreatedBy
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
					0,
					GetDate(), 	--CreationDate
					'904 IMPORT', 	--CreatedBy
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
		
		--update logic here.
		Update_Record_Status:
		UPDATE GMImport904
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE GMImport904ID = @GMImport904ID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END
		
		FETCH GM904Cursor INTO @GMImport904ID, @ActionCode, @NextRouteCode, @DealerSellingDivision, @DealerCode, @VIN,
			@CXDFlag, @EquipmentType, @EquipmentNumber, @VehicleOrderNumber, @HoldStorageIndicator, @VehicleYear, @Make, 
			@Model, @Bodystyle, @VehicleLength, @VehicleWidth, @VehicleHeight, @VINDecodedInd

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
		CLOSE GM904Cursor
		DEALLOCATE GM904Cursor
		PRINT 'GM Import 904 Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE GM904Cursor
		DEALLOCATE GM904Cursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			PRINT 'GM Import 904 Error_Encountered =' + STR(@ErrorID)
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
