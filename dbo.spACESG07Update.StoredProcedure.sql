USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spACESG07Update]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spACESG07Update] (@BatchID int, @CustomerCode varchar(20),
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@ErrorEncountered		varchar(5000),
	@loopcounter			int,
	@ACESImportG07ID		int,
	@VIN				varchar(17),
	@AllocationNumber		varchar(12),
	@TenderDate			datetime,
	@PickupLocation			varchar(7),
	@YardBayLocation		varchar(10),
	@DeliveryLocation		varchar(7),
	@ShipToAddress1			varchar(30),
	@ShipToAddress2			varchar(30),
	@ShipToAddress3			varchar(30),
	@ZipCode			varchar(10),
	@TelephoneNumber		varchar(20),
	@ContactName			varchar(30),
	@DropshipFlag			varchar(1),
	@RequiredDeliveryDate		datetime,
	@VINExteriorColor		varchar(4),
	@VINCOUNT			int,
	@VehicleID			int,
	@VehicleStatus			varchar(20),
	@LegStatus			varchar(20),
	@Status				varchar(50),
	@RecordStatus			varchar(100),
	@ImportedInd			int,
	@NewImportedInd			int,
	@CustomerID			int,
	@VehicleOriginID		int,
	@VehicleDestinationID		int,
	@OriginID			int,
	@DestinationID			int,
	@PoolID				int,
	@LoadID				int,
	@Count				int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100)

	/************************************************************************
	*	spACESG07Update							*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the ACESImportG07 table and 	*
	*	updates the vehicle records with the availability information.	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	02/05/2009 CMK    Initial version				*
	*									*
	************************************************************************/

	--get the customer id from the setting table
	SELECT @CustomerID = Value1
	FROM Code
	WHERE CodeType = 'ACESCustomerCode'
	AND Code = @CustomerCode
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

	DECLARE G07Update CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT ACESImportG07ID, VIN, AllocationNumber, TenderDate,
		PickupLocation, YardBayLocation, DeliveryLocation,
		ShipToAddress1, ShipToAddress2, ShipToAddress3,
		ZipCode, TelephoneNumber, ContactName,
		DropshipFlag, RequiredDeliveryDate, VINExteriorColor
		FROM ACESImportG07
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		AND Header = @CustomerCode
		ORDER BY ACESImportG07ID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN G07Update

	BEGIN TRAN

	FETCH G07Update INTO @ACESImportG07ID, @VIN, @AllocationNumber, @TenderDate,
		@PickupLocation, @YardBayLocation, @DeliveryLocation,
		@ShipToAddress1, @ShipToAddress2, @ShipToAddress3,
		@ZipCode, @TelephoneNumber, @ContactName,
		@DropshipFlag, @RequiredDeliveryDate, @VINExteriorColor
		
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		SELECT @NewImportedInd = 0
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM Vehicle
		WHERE VIN = @VIN
		AND CustomerID = @CustomerID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error getting vin count'
			GOTO Error_Encountered
		END
		
		IF @VINCOUNT = 1
		BEGIN
			--make sure the vin is not en route or delivered
			SELECT TOP 1 @VehicleID = V.VehicleID, @VehicleStatus = V.VehicleStatus,
			@LegStatus = L.LegStatus, @VehicleOriginID = V.PickupLocationID,
			@VehicleDestinationID = V.DropoffLocationID,
			@LoadID = L.LoadID, @PoolID = L.PoolID
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
			
			
			IF @VehicleStatus = 'Delivered'
			BEGIN
				SELECT @RecordStatus = 'Already Delivered'
				SELECT @NewImportedInd = 1
				GOTO Update_Record_Status
			END
			ELSE IF @VehicleStatus = 'EnRoute'
			BEGIN
				SELECT @RecordStatus = 'Already En Route'
				SELECT @NewImportedInd = 1
				GOTO Update_Record_Status
			END
			/*
			IF @VehicleStatus = 'Damaged' OR @LegStatus = 'Pending Repair'
			BEGIN
				--update the vehicle status
				UPDATE Vehicle
				SET VehicleStatus = 'Available',
				BayLocation = @YardBayLocation,
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
					SELECT @Status = 'ERROR UPDATING LEG RECORD'
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
			*/
			
			IF @VehicleStatus NOT IN ('Pending','Damaged') OR @LegStatus NOT IN ('Pending', 'Pending Repair')
			BEGIN
				SELECT @RecordStatus = 'VEHICLE IS NOT PENDING'
				GOTO Update_Record_Status
			END
			-- check the origin
			SELECT @OriginID = convert(int,value1)
			FROM Code
			WHERE CodeType = 'ACES'+@CustomerCode+'LocationCode'
			AND Code = @PickupLocation
			IF @@Error <> 0
			BEGIN
				print 'in origin error'
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING ORIGIN LOCATION'
				GOTO Error_Encountered
			END
			
			IF @OriginID <> @VehicleOriginID
			BEGIN
				SELECT @RecordStatus = 'ORIGIN MISMATCH'
				GOTO Update_Record_Status
			END
			
			-- check the destination
			--get the destination.
			SELECT @DestinationID = LocationID
			FROM Location
			WHERE ParentRecordID = @CustomerID
			AND ParentRecordTable = 'Customer'
			AND CustomerLocationCode = @DeliveryLocation
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING DESTINATION LOCATION'
				GOTO Error_Encountered
			END
			
			IF @DestinationID <> @VehicleDestinationID
			BEGIN
				SELECT @RecordStatus = 'DESTINATION MISMATCH'
				GOTO Update_Record_Status
			END
			
			--update logic here.
			
			--update the vehicle record
			UPDATE Vehicle
			SET CustomerIdentification = @AllocationNumber,
			VehicleStatus = CASE WHEN VehicleStatus = 'Damaged' THEN VehicleStatus ELSE 'Available' END,
			AvailableForPickupDate = @TenderDate,
			BayLocation = @YardBayLocation,
			PriorityInd = CASE WHEN @RequiredDeliveryDate IS NULL THEN 0 ELSE 1 END,
			UpdatedBy = 'G07 IMPORT',
			UpdatedDate = CURRENT_TIMESTAMP
			WHERE VehicleID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
				GOTO Error_Encountered
			END
			
			IF @PoolID IS NULL AND @LoadID IS NULL
			BEGIN
				-- get the pool id or create the pool
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
					UpdatedBy = 'G07 Import'
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
						'G07 Import'
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
			-- update the leg
			UPDATE Legs
			SET PoolID = @PoolID,
			DateAvailable = @TenderDate,
			LegStatus = CASE WHEN LegStatus = 'Pending Repair' THEN LegStatus ELSE 'Available' END,
			UpdatedDate = CURRENT_TIMESTAMP,
			UpdatedBy = 'G07 Import'
			WHERE VehicleID = @VehicleID
			AND LegNumber = 1
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING LEG RECORD'
				GOTO Error_Encountered
			END
					
			SELECT @NewImportedInd = 1
			IF @LegStatus = 'Pending Repair'
			BEGIN
				SELECT @RecordStatus = 'Pending Repair'
			END
			ELSE
			BEGIN
				SELECT @RecordStatus = 'Imported'
			END
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
		UPDATE ACESImportG07
		SET RecordStatus = @RecordStatus,
		ImportedInd = @NewImportedind,
		ImportedDate = CASE WHEN @NewImportedInd = 1 THEN GetDate() ELSE NULL END,
		ImportedBy = CASE WHEN @NewImportedInd = 1 THEN @UserCode ELSE NULL END
		WHERE ACESImportG07ID = @ACESImportG07ID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH G07Update INTO @ACESImportG07ID, @VIN, @AllocationNumber, @TenderDate,
			@PickupLocation, @YardBayLocation, @DeliveryLocation,
			@ShipToAddress1, @ShipToAddress2, @ShipToAddress3,
			@ZipCode, @TelephoneNumber, @ContactName,
			@DropshipFlag, @RequiredDeliveryDate, @VINExteriorColor

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE G07Update
		DEALLOCATE G07Update
		PRINT 'G07Update Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE G07Update
		DEALLOCATE G07Update
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			PRINT 'G07Update Error_Encountered =' + STR(@ErrorID)
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
