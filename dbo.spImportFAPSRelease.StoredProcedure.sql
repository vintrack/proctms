USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportFAPSRelease]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportFAPSRelease] (@BatchID int,@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@ErrorEncountered		varchar(5000),
	@loopcounter			int,
	@FAPSReleaseImportID		int,
	@VIN				varchar(17),
	@DeliveryLocation		varchar(10),
	@ModelName			varchar(10),
	@ExteriorColor			varchar(10),
	@BayLocation			varchar(10),
	@PriorityCode			varchar(3),
	@FAPSRecordCode			varchar(3),
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
	@CreationDate			datetime
	

	/************************************************************************
	*	spImportFAPSRelease						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the FAPSRelease table and 	*
	*	updates the vehicle records with the availability information.	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	01/20/2006 CMK    Initial version				*
	*									*
	************************************************************************/

	DECLARE FAPSReleaseCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT FAPSReleaseImportID,VIN,LTRIM(RIGHT(BayLocation,DATALENGTH(BayLocation)-1)),PortCode,
		DeliveryLocation,ReleaseDate,PriorityCode,CarrierID,
		ModelName,ExteriorColor,Voyage,FAPSRecordCode
		FROM FAPSReleaseImport
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY FAPSReleaseImportID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP

	OPEN FAPSReleaseCursor

	BEGIN TRAN

	-- get the origin
	SELECT @OriginID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'FAPSLocationID'
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
	
	FETCH FAPSReleaseCursor INTO @FAPSReleaseImportID,@VIN,@BayLocation,@PortCode,
		@DeliveryLocation,@ReleaseDate,@PriorityCode,@CarrierID,
		@ModelName,@ExteriorColor,@Voyage,@FAPSRecordCode
	
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
			
			IF @VehicleStatus = 'Damaged' OR @LegStatus = 'Pending Repair'
			BEGIN
				--update the vehicle status
				UPDATE Vehicle
				SET VehicleStatus = 'Available',
				BayLocation = @BayLocation,
				PriorityInd = 0, --CASE WHEN @RequiredDeliveryDate IS NULL THEN 0 ELSE 1 END,
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
			ELSE IF @VehicleStatus <> 'Pending' OR @LegStatus <> 'Pending'
			BEGIN
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
			
			IF @OriginID <> @VehicleOriginID OR (@DestinationCode <> @DeliveryLocation AND @DestinationCode <> 'DS'+REPLICATE('0',3-DATALENGTH(@DeliveryLocation))+@DeliveryLocation)
			BEGIN
				-- see if we can find the new destination
				SELECT @DestinationID = NULL
				
				SELECT @DestinationID = LocationID
				FROM Location
				WHERE ParentRecordID = @CustomerID
				AND (CustomerLocationCode = @DeliveryLocation
				OR CustomerLocationCode = 'DS'+REPLICATE('0',3-DATALENGTH(@DeliveryLocation))+@DeliveryLocation)
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
				AND RateType = 'Size A Rate'
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
				PriorityInd = 0, --CASE WHEN @RequiredDeliveryDate IS NULL THEN 0 ELSE 1 END,
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
			
			--update logic here.
			
			--update the vehicle record
			UPDATE Vehicle
			SET VehicleStatus = 'Available',
			AvailableForPickupDate = @ReleaseDate,
			BayLocation = @BayLocation,
			PriorityInd = 0, --CASE WHEN @RequiredDeliveryDate IS NULL THEN 0 ELSE 1 END,
			UpdatedBy = 'FAPS IMPORT',
			UpdatedDate = CURRENT_TIMESTAMP
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
			GOTO Update_Record_Status
		END
		ELSE
		BEGIN
			SELECT @RecordStatus = 'VIN NOT FOUND'
			GOTO Update_Record_Status
			
		END

		--update the record status here.
		Update_Record_Status:
		UPDATE FAPSReleaseImport
		SET RecordStatus = @RecordStatus,
		ImportedInd = @NewImportedind,
		ImportedDate = CASE WHEN @NewImportedInd = 1 THEN GetDate() ELSE NULL END,
		ImportedBy = CASE WHEN @NewImportedInd = 1 THEN @UserCode ELSE NULL END
		WHERE FAPSReleaseImportID = @FAPSReleaseImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH FAPSReleaseCursor INTO @FAPSReleaseImportID,@VIN,@BayLocation,@PortCode,
			@DeliveryLocation,@ReleaseDate,@PriorityCode,@CarrierID,
			@ModelName,@ExteriorColor,@Voyage,@FAPSRecordCode
	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE FAPSReleaseCursor
		DEALLOCATE FAPSReleaseCursor
		PRINT 'FAPS Release Import Error_Encountered =' + STR(@ErrorID)
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
			PRINT 'FAPS Release Import Error_Encountered =' + STR(@ErrorID)
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
