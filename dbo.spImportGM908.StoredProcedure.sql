USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportGM908]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportGM908] (@BatchID int,
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	@loopcounter		int,
	@GMImport908ID		int,
	@VehicleID		int,
	@EventType		varchar(2),
	@SCACRequestToCode	varchar(4),
	@CDLCode		varchar(2),
	@VIN			varchar(17),
	@RequestDateTime	datetime,
	@InTransitPending	varchar(1),
	@ReasonCode		varchar(2),
	@Route			varchar(6),
	@SCACHandling		varchar(4),
	@SellingDivision	varchar(2),
	@DealerCode		varchar(5),
	@ImportedInd		int,
	@ImportedDate		datetime,
	@ImportedBy		varchar(20),
	@RecordStatus		varchar(100),
	@CreationDate		datetime,
	@CreatedBy		varchar(20),
	@CustomerID		int,
	@StatusCode		varchar(1),
	@ErrorCode		varchar(3),
	@GMDelayTransactionsID	int,
	@VehicleHoldsID		int,
	@OriginID		int,
	@DestinationID		int,
	@VehicleOriginID	int,
	@VehicleOriginCode	varchar(50),
	@VehicleDestinationID	int,
	@VehicleDestinationCode	varchar(50),
	@CustomerIdentification	varchar(25),
	@OldLegStatus		varchar(20),
	@VehicleStatus 		varchar(20),
	@VehicleLoadID		int,
	@LoadNumber		varchar(20),
	@VehiclePoolID		int,
	@LegsID			int,
	@AvailableForPickupDate	datetime,
	@SizeClass		varchar(10),
	@ChargeRate		decimal(19,2),
	@PoolRecordCount	int,
	@Reserved		int,
	@Available		int,
	@PoolSize		int,
	@ReturnCode		int,
	@ReturnMessage		varchar(100),
	@NeedsReviewInd		int,
	@Count			int,
	@Status			varchar(100)

	/************************************************************************
	*	spImportGM908							*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the GMImport908 table and	*
	*	add/removes the Reconsignment/Diversion, Hold or Storage	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	11/07/2013 CMK    Initial version				*
	*									*
	************************************************************************/
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

	DECLARE GM908Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT GMImport908ID, EventType, SCACRequestToCode, CDLCode, VIN, RequestDateTime,
		InTransitPending, ReasonCode, Route, SCACHandling, SellingDivision, DealerCode
		FROM GMImport908
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY GMImport908ID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN GM908Cursor

	BEGIN TRAN

	FETCH GM908Cursor INTO @GMImport908ID, @EventType, @SCACRequestToCode, @CDLCode, @VIN, @RequestDateTime,
		@InTransitPending, @ReasonCode, @Route, @SCACHandling, @SellingDivision, @DealerCode

	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @Count = COUNT(*)
		FROM Vehicle
		WHERE VIN = @VIN
		AND CustomerID = @CustomerID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error getting vin count'
			GOTO Error_Encountered
		END
	
		IF @Count > 0
		BEGIN
			SELECT @RecordStatus = 'Imported'
			
			--see if there are any changes to the origin/destination
			SELECT TOP 1 @VehicleID = V.VehicleID
			FROM Vehicle V
			WHERE V.VIN = @VIN
			AND V.CustomerID = @CustomerID
			ORDER BY V.VehicleID DESC	--want the most recent vehicle if multiples
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING VEHICLE STATUS'
				GOTO Error_Encountered
			END
			
			IF @EventType = 'HD'
			BEGIN
				--add the GM Hold
				SELECT @ReturnCode = 1
				EXEC spAddGMDelayTransaction @VehicleID, @ReasonCode, @RequestDateTime,
				'GM 908', @rReturnCode = @ReturnCode OUTPUT
				IF @ReturnCode NOT IN (0, 100002, 100000, 100001)
				BEGIN
					SELECT @ErrorID = @ReturnCode
					GOTO Error_Encountered
				END
				
				IF @ReturnCode IN (100000,100001)
				BEGIN
					SELECT @StatusCode = 'R'
					SELECT @ErrorCode = '84'	--Vehicle has been shipped - cannot update
				END
				
				UPDATE GMDelayTransacations
				SET DelayReportedInd = 1,
				DateDelayReported = @CreationDate
				WHERE VehicleID = @VehicleID
				AND RecordStatus = 'Open'
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @ReturnCode
					GOTO Error_Encountered
				END
				
				SELECT @NeedsReviewInd = 1
			END
			ELSE IF @EventType = 'ST'
			BEGIN
				--add a Vehicle Hold
				SELECT @ReturnCode = 1
				EXEC spAddVehicleHold @VehicleID, 'GM 908 Storage Request', @RequestDateTime,
				'GM 908', @rReturnCode = @ReturnCode OUTPUT
				IF @ReturnCode NOT IN (0, 100000, 100001, 100002, 100003, 100004)
				BEGIN
					SELECT @ErrorID = @ReturnCode
					GOTO Error_Encountered
				END
						
				IF @ReturnCode IN (100002,100003)
				BEGIN
					SELECT @StatusCode = 'R'
					SELECT @ErrorCode = '84'	--Vehicle has been shipped - cannot update
				END
				
				SELECT @NeedsReviewInd = 1
			END
			ELSE IF @EventType = 'RH'
			BEGIN
				--remove the GM Hold
				SELECT @GMDelayTransactionsID = NULL
				SELECT TOP 1 @GMDelayTransactionsID = GMDelayTransactionsID
				FROM GMDelayTransactions
				WHERE VehicleID = @VehicleID
				AND RecordStatus = 'Open'
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @ReturnCode
					GOTO Error_Encountered
				END
				
				IF @GMDelayTransactionsID IS NOT NULL
				BEGIN
					SELECT @ReturnCode = 1
					EXEC spRemoveGMDelayTransaction @GMDelayTransactionsID, @RequestDateTime,
					'GM 908', 1, NULL, @rReturnCode = @ReturnCode OUTPUT
					IF @ReturnCode NOT IN (0, 100000, 100001)
					BEGIN
						SELECT @ErrorID = @ReturnCode
						GOTO Error_Encountered
					END
									
					IF @ReturnCode IN (100000,100001)
					BEGIN
						SELECT @StatusCode = 'R'
						SELECT @ErrorCode = '82'	--Matching hold event not found - cannot release
					END
									
					UPDATE GMDelayTransacations
					SET ReleaseReportedInd = 1,
					DateReleaseReported = @CreationDate
					WHERE VehicleID = @VehicleID
					AND RecordStatus = 'Open'
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @ReturnCode
						GOTO Error_Encountered
					END
				END
				ELSE
				BEGIN
					SELECT @StatusCode = 'R'
					SELECT @ErrorCode = '82'	--Matching hold event not found - cannot release
				END
			END
			ELSE IF @EventType = 'RS'
			BEGIN
				--remove the Vehicle Hold
				SELECT @VehicleHoldsID = NULL
				SELECT TOP 1 @VehicleHoldsID = VehicleHoldsID
				FROM VehicleHolds
				WHERE VehicleID = @VehicleID
				AND RecordStatus = 'Open'
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @ReturnCode
					GOTO Error_Encountered
				END
								
				IF @VehicleHoldsID IS NOT NULL
				BEGIN
					SELECT @ReturnCode = 1
					EXEC spRemoveVehicleHold @VehicleHoldsID, @RequestDateTime,
					'GM 908', @rReturnCode = @ReturnCode OUTPUT
					IF @ReturnCode NOT IN (0, 100000, 100001)
					BEGIN
						SELECT @ErrorID = @ReturnCode
						GOTO Error_Encountered
					END
										
					IF @ReturnCode IN (100000,100001)
					BEGIN
						SELECT @StatusCode = 'R'
						SELECT @ErrorCode = '251'	--VEHICLE NOT IN STORAGE - CANNOT RELEASE
					END
				END
				ELSE
				BEGIN
					SELECT @StatusCode = 'R'
					SELECT @ErrorCode = '251'	--VEHICLE NOT IN STORAGE - CANNOT RELEASE
				END

			END
			
			IF @EventType IN ('RD','DV','RH','RS')
			BEGIN
				IF DATALENGTH(@DealerCode) > 0
				BEGIN
					--get the destination
					SELECT TOP 1 @DestinationID = LocationID
					FROM Location
					WHERE ParentRecordID = @CustomerID
					AND ParentRecordTable = 'Customer'
					AND (CustomerLocationCode = @DealerCode
					OR CustomerLocationCode = @SellingDivision+'-'+@DealerCode)
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
				END
				ELSE
				BEGIN
					SELECT @DestinationID = 0
				END
				
				IF DATALENGTH(@CDLCode) > 0
				BEGIN
					--get the Origin.
					SELECT @OriginID = CONVERT(int,Value1)
					FROM Code
					WHERE CodeType = 'GMLocationCode'
					AND Code = @CDLCode
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR GETTING ORIGIN LOCATION'
						GOTO Error_Encountered
					END
				END
				ELSE
				BEGIN
					SELECT @OriginID = 0
				END
				
				--validate/update the origin/destination
				SELECT TOP 1 @VehicleOriginID = V.PickupLocationID,
				@VehicleOriginCode = CASE WHEN L2.ParentRecordTable = 'Common' THEN C.Code ELSE L2.CustomerLocationCode END,
				@VehicleDestinationID = V.DropoffLocationID,
				@VehicleDestinationCode = L3.CustomerLocationCode,
				@CustomerIdentification = V.CustomerIdentification,
				@OldLegStatus = L1.LegStatus,
				@VehicleLoadID = L4.LoadsID,
				@LoadNumber = L4.LoadNumber,
				@VehiclePoolID = L1.PoolID,
				@LegsID = L1.LegsID,
				@SizeClass = V.SizeClass
				FROM Vehicle V
				LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
				LEFT JOIN Location L2 ON V.PickupLocationID = L2.LocationID
				LEFT JOIN Location L3 ON V.DropoffLocationID = L3.LocationID
				LEFT JOIN Loads L4 ON L1.LoadID = L4.LoadsID
				LEFT JOIN Code C ON V.PickupLocationID = CONVERT(int,C.Value1)
				AND C.CodeType = 'GMLocationCode'
				WHERE V.VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING VEHICLE STATUS'
					GOTO Error_Encountered
				END
				
				SELECT @CustomerIdentification = @SellingDivision+'/'
							
				IF @OriginID = 0
				BEGIN
					SELECT @OriginID = @VehicleOriginID
				END
				
				IF @DestinationID = 0
				BEGIN
					SELECT @DestinationID = @VehicleDestinationID
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
							
				SELECT @AvailableForPickupDate = CONVERT(varchar(10), @RequestDateTime,101)
				
				IF @OriginID = @VehicleOriginID AND @DestinationID = @VehicleDestinationID
				BEGIN
					UPDATE Vehicle
					SET CustomerIdentification = @CustomerIdentification
					WHERE VehicleID = @VehicleID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
						GOTO Error_Encountered
					END
					SELECT @RecordStatus = 'Imported'
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
				SELECT @VehicleStatus = 'Available'
				
				UPDATE Vehicle
				SET PickupLocationID = @OriginID,
				DropoffLocationID = @DestinationID,
				CustomerIdentification = @CustomerIdentification,
				ChargeRate = @ChargeRate,
				AvailableForPickupDate = @AvailableForPickupDate,
				VehicleStatus = @VehicleStatus
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
					GOTO Error_Encountered
				END
								
				--update any legs records
				UPDATE Legs
				SET PickupLocationID = @OriginID,
				LegStatus = @VehicleStatus,
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
											
				IF @VehicleStatus = 'Available'
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
			END
			
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = GetDate()
			SELECT @ImportedBy = @UserCode
			SELECT @StatusCode = 'A'
			SELECT @ErrorCode = ''
			
		END
		ELSE
		BEGIN
			SELECT @NeedsReviewInd = 1
			SELECT @VehicleID = NULL
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			SELECT @RecordStatus = 'VIN NOT FOUND'
			SELECT @StatusCode = 'R'
			SELECT @ErrorCode = '903'	--VEHICLE NOT FOUND

		END
			
		--update logic here.
		Update_Record_Status:
		UPDATE GMImport908 
		SET VehicleID = @VehicleID,
		RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE GMImport908ID = @GMImport908ID
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
			@EventType,
			@SCACRequestToCode,
			@CDLCode,
			'',			--RequestNumber
			@VIN,
			CURRENT_TIMESTAMP,	--RequestDateTime
			@StatusCode,
			@ErrorCode,
			0,			--ExportedInd
			'Export Pending',	--RecordStatus
			@CreationDate,
			@UserCode		--CreatedBy
		)
		
		FETCH GM908Cursor INTO @GMImport908ID, @EventType, @SCACRequestToCode, @CDLCode, @VIN, @RequestDateTime,
			@InTransitPending, @ReasonCode, @Route, @SCACHandling, @SellingDivision, @DealerCode

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE GM908Cursor
		DEALLOCATE GM908Cursor
		PRINT 'GM Import 908 Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE GM908Cursor
		DEALLOCATE GM908Cursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			PRINT 'GM Import 908 Error_Encountered =' + STR(@ErrorID)
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
