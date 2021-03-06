USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportLocations]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportLocations]
AS
BEGIN
	DECLARE	--ImportLocation Table Variables
	@ImportLocationID		int,
	@LocationID			int,
	@ParentRecordID			int,		--customerid
	@LocationType			varchar(20),
	@LocationSubType		varchar(20),
	@LocationName			varchar(100),
	@CustomerLocationCode		varchar(50),
	@CustomerRegionCode		varchar(50),
	@AddressLine1			varchar(50),
	@AddressLine2			varchar(50),
	@City				varchar(30),
	@State				varchar(2),
	@Zip				varchar(14),
	@Country			varchar(30),
	@MainPhone			varchar(20),
	@FaxNumber			varchar(20),
	@PrimaryContactFirstName	varchar(30),
	@PrimaryContactLastName		varchar(30),
	@PrimaryContactPhone		varchar(20),
	@PrimaryContactExtension	varchar(10),
	@PrimaryContactCellPhone	varchar(20),
	@PrimaryContactEmail		varchar(255),
	@AlternateContactFirstName	varchar(30),
	@AlternateContactLastName	varchar(30),
	@AlternateContactPhone		varchar(20),
	@AlternateContactExtension	varchar(10),
	@AlternateContactCellPhone	varchar(20),
	@AlternateContactEmail		varchar(255),
	@OtherPhone1Description		varchar(50),
	@OtherPhone1			varchar(20),
	@OtherPhone2Description		varchar(50),
	@OtherPhone2			varchar(20),
	@Status				varchar(20),
	@SPLCCode			varchar(50),
	--Location Table Variables
	@ParentRecordTable		varchar(20),
	@AuctionPayOverrideInd		int,
	@AuctionPayRate			decimal(19,2),
	@FlatDeliveryPayInd		int,
	@FlatDeliveryPayRate		decimal(19,2),
	@DeliveryTimes			varchar(100),
	@LocationNotes			varchar(1000),
	@DriverDirections		varchar(1000),
	@SortOrder			int,
	@AlwaysShowInWIPInd		int,
	@RecordStatus			varchar(15),
	@CreationDate			datetime,
	@CreatedBy			varchar(20),
	@UpdatedDate			datetime,
	@UpdatedBy			varchar(20),
	--Processing Variables
	@AddEditInd			int,		-- 1= add location, 0 = edit location
	@ErrorID			int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@ExceptionEncounteredInd	int,
	@RowCount			int,
	@loopcounter			int

	/************************************************************************
	*	spImportCustomers						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the ImportLocations table 	*
	*	and creates/updates the Location records.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	04/01/2005 CMK    Initial version				*
	*									*
	************************************************************************/
	
	set nocount on
	/* Declare the main processing cursor */
	DECLARE ImportLocationsCursor INSENSITIVE CURSOR
		FOR
		SELECT ImportLocationID,LocationID,ParentRecordID,LocationType,LocationSubType,LocationName,
		CustomerLocationCode,CustomerRegionCode,AddressLine1,AddressLine2,City,
		State,Zip,Country,MainPhone,FaxNumber,PrimaryContactFirstName,
		PrimaryContactLastName,PrimaryContactPhone,PrimaryContactExtension,
		PrimaryContactCellPhone,PrimaryContactEmail,AlternateContactFirstName,
		AlternateContactLastName,AlternateContactPhone,AlternateContactExtension,
		AlternateContactCellPhone,AlternateContactEmail,OtherPhone1Description,
		OtherPhone1,OtherPhone2Description,OtherPhone2,SPLCCode
		FROM ImportLocation
	ORDER BY ParentRecordID, LocationName


	SELECT @loopcounter = 0
	OPEN ImportLocationsCursor
	
	BEGIN TRAN
	
	SELECT @RowCount = @@cursor_rows
	SELECT @ExceptionEncounteredInd = 0
	
	
	FETCH ImportLocationsCursor INTO @ImportLocationID,@LocationID,@ParentRecordID,@LocationType,@LocationSubType,@LocationName,
		@CustomerLocationCode,@CustomerRegionCode,@AddressLine1,@AddressLine2,@City,
		@State,@Zip,@Country,@MainPhone,@FaxNumber,@PrimaryContactFirstName,
		@PrimaryContactLastName,@PrimaryContactPhone,@PrimaryContactExtension,
		@PrimaryContactCellPhone,@PrimaryContactEmail,@AlternateContactFirstName,
		@AlternateContactLastName,@AlternateContactPhone,@AlternateContactExtension,
		@AlternateContactCellPhone,@AlternateContactEmail,@OtherPhone1Description,
		@OtherPhone1,@OtherPhone2Description,@OtherPhone2,@SPLCCode
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--Reset the Processing Variables
		SELECT @ErrorID = 0
		SELECT @AddEditInd = 1
		
		
		--Validate the customerID
		IF @ParentRecordID IS NULL OR @ParentRecordID = ''
		BEGIN
			SELECT @ErrorID = 100003
			GOTO End_Of_Loop
		END
		
		SELECT @RowCount = Count(*)
		FROM Customer
		WHERE CustomerID = @ParentRecordID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			GOTO Error_Encountered
		END
		ELSE IF @RowCount = 0
		BEGIN
			SELECT @ErrorID = 100000
			GOTO End_Of_Loop
		END
				
		--determine whether we are creating a new location or just adding a new one
		IF ISNULL(@LocationID,0) > 0
		BEGIN
			--validate that the location id belongs to the customer
			SELECT @RowCount = COUNT(*)
			FROM Location
			WHERE LocationID = @LocationID
			AND ParentRecordTable = 'Customer'
			AND ParentRecordID = @ParentrecordID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				GOTO Error_Encountered
			END
			ELSE IF @RowCount = 0
			BEGIN
				SELECT @ErrorID = 100001
				GOTO End_Of_Loop
			END
			
			SELECT @AddEditInd = 0
			GOTO Do_Insert_Edit
		END
		IF DATALENGTH(@CustomerLocationCode) > 0
		BEGIN
			--validate that the location id belongs to the customer or is a common location
			SELECT @RowCount = COUNT(*)
			FROM Location
			WHERE CustomerLocationCode = @CustomerLocationCode
			AND ParentRecordTable = 'Customer'
			AND ParentRecordID = @ParentRecordID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				GOTO Error_Encountered
			END
			ELSE IF @RowCount = 0
			BEGIN
				SELECT @AddEditInd = 1
				GOTO Do_Insert_Edit
			END
			ELSE IF @RowCount = 1
			BEGIN
				SELECT @AddEditInd = 0
				
				--get the location id
				SELECT @LocationID = LocationID
				FROM Location
				WHERE CustomerLocationCode = @CustomerLocationCode
				AND ParentRecordTable = 'Customer'
				AND ParentRecordID = @ParentrecordID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@Error
					GOTO Error_Encountered
				END
				GOTO Do_Insert_Edit
			END
			ELSE
			BEGIN
				SELECT @ErrorID = 100002
				GOTO End_Of_Loop
			END
		END
		
		-- see if we can find a match on the address
		SELECT @RowCount = COUNT(*)
		FROM Location
		WHERE AddressLine1 = @AddressLine1
		AND AddressLine2 = @AddressLine2
		AND City = @City
		AND State = @State
		AND Zip = @Zip
		AND ParentRecordTable = 'Customer'
		AND ParentRecordID = @ParentrecordID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			GOTO Error_Encountered
		END
		ELSE IF @RowCount = 0
		BEGIN
			SELECT @AddEditInd = 1
			GOTO Do_Insert_Edit
		END
		ELSE IF @RowCount = 1
		BEGIN
			SELECT @AddEditInd = 0
			
			--get the location id
			SELECT @LocationID = LocationID
			FROM Location
			WHERE AddressLine1 = @AddressLine1
			AND AddressLine2 = @AddressLine2
			AND City = @City
			AND State = @State
			AND Zip = @Zip
			AND ParentRecordTable = 'Customer'
			AND ParentRecordID = @ParentrecordID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				GOTO Error_Encountered
			END
			GOTO Do_Insert_Edit
		END
		ELSE
		BEGIN
			SELECT @ErrorID = 100002
			GOTO End_Of_Loop
		END
		
		Do_Insert_Edit:
		IF @AddEditInd = 1
		BEGIN
			--Create the Location
			--Set the defaults
			SELECT @ParentRecordTable = 'Customer'
			IF @Country IS NULL OR @Country = ''
			BEGIN
				SELECT @Country = 'U.S.A.'
			END
			SELECT @AuctionPayOverrideInd =0
			SELECT @AuctionPayRate = 0
			SELECT @FlatDeliveryPayInd = 0
			SELECT @FlatDeliveryPayRate = 0
			SELECT @DeliveryTimes = ''
			SELECT @LocationNotes = ''
			SELECT @DriverDirections = ''
			SELECT @SortOrder = 0
			SELECT @AlwaysShowInWIPInd = 0
			SELECT @RecordStatus = 'Active'
			SELECT @CreationDate = Current_Timestamp
			SELECT @CreatedBy = 'LOCATION IMPORT'
			SELECT @UpdatedDate = NULL
			SELECT @UpdatedBy = NULL
					
			--Insert into the Location table
			INSERT INTO Location (
				ParentRecordID,
				ParentRecordTable,
				LocationType,
				LocationSubType,
				LocationName,
				CustomerLocationCode,
				CustomerRegionCode,
				AddressLine1,
				AddressLine2,
				City,
				State,
				Zip,
				Country,
				MainPhone,
				FaxNumber,
				PrimaryContactFirstName,
				PrimaryContactLastName,
				PrimaryContactPhone,
				PrimaryContactExtension,
				PrimaryContactCellPhone,
				PrimaryContactEmail,
				AlternateContactFirstName,
				AlternateContactLastName,
				AlternateContactPhone,
				AlternateContactExtension,
				AlternateContactCellPhone,
				AlternateContactEmail,
				OtherPhone1Description,
				OtherPhone1,
				OtherPhone2Description,
				OtherPhone2,
				AuctionPayOverrideInd,
				AuctionPayRate,
				FlatDeliveryPayInd,
				FlatDeliveryPayRate,
				MileagePayBoostOverrideInd,
				MileagePayBoost,
				DeliveryTimes,
				LocationNotes,
				DriverDirections,
				SortOrder,
				AlwaysShowInWIPInd,
				RecordStatus,
				CreationDate,
				CreatedBy,
				UpdatedDate,
				UpdatedBy,
				SPLCCode,
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
				@ParentRecordID,
				@ParentRecordTable,
				@LocationType,
				@LocationSubType,
				@LocationName,
				@CustomerLocationCode,
				@CustomerRegionCode,
				@AddressLine1,
				@AddressLine2,
				@City,
				@State,
				@Zip,
				@Country,
				@MainPhone,
				@FaxNumber,
				@PrimaryContactFirstName,
				@PrimaryContactLastName,
				@PrimaryContactPhone,
				@PrimaryContactExtension,
				@PrimaryContactCellPhone,
				@PrimaryContactEmail,
				@AlternateContactFirstName,
				@AlternateContactLastName,
				@AlternateContactPhone,
				@AlternateContactExtension,
				@AlternateContactCellPhone,
				@AlternateContactEmail,
				@OtherPhone1Description,
				@OtherPhone1,
				@OtherPhone2Description,
				@OtherPhone2,
				@AuctionPayOverrideInd,
				@AuctionPayRate,
				@FlatDeliveryPayInd,
				@FlatDeliveryPayRate,
				0,
				0,
				@DeliveryTimes,
				@LocationNotes,
				@DriverDirections,
				@SortOrder,
				@AlwaysShowInWIPInd,
				@RecordStatus,
				@CreationDate,
				@CreatedBy,
				@UpdatedDate,
				@UpdatedBy,
				@SPLCCode,
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
				SELECT @ErrorID = @@Error
				GOTO End_Of_Loop
			END
			ELSE
			BEGIN
				SELECT @LocationID = @@Identity
			END
			SELECT @Status = 'Location Created'
		END
		ELSE
		BEGIN
			--update the location
			SELECT @UpdatedDate = Current_Timestamp
			SELECT @UpdatedBy = 'Location Import'
			UPDATE Location
			SET LocationType = @LocationType,
			LocationSubType = @LocationSubType,
			LocationName = @LocationName,
			CustomerLocationCode = @CustomerLocationCode,
			CustomerRegionCode = @CustomerRegionCode,
			AddressLine1 = @AddressLine1,
			AddressLine2 = @AddressLine2,
			City = @City,
			State = @State,
			Zip = @Zip,
			Country = @Country,
			MainPhone = @MainPhone,
			FaxNumber = @FaxNumber,
			PrimaryContactFirstName = @PrimaryContactFirstName,
			PrimaryContactLastName = @PrimaryContactLastName,
			PrimaryContactPhone = @PrimaryContactPhone,
			PrimaryContactExtension = @PrimaryContactExtension,
			PrimaryContactCellPhone = @PrimaryContactCellPhone,
			PrimaryContactEmail = @PrimaryContactEmail,
			AlternateContactFirstName = @AlternateContactFirstName,
			AlternateContactLastName = @AlternateContactLastName,
			AlternateContactPhone = @AlternateContactPhone,
			AlternateContactExtension = @AlternateContactExtension,
			AlternateContactCellPhone = @AlternateContactCellPhone,
			AlternateContactEmail = @AlternateContactEmail,
			OtherPhone1Description = @OtherPhone1Description,
			OtherPhone1 = @OtherPhone1,
			OtherPhone2Description = @OtherPhone2Description,
			OtherPhone2 = @OtherPhone2,
			UpdatedBy = @UpdatedBy,
			UpdatedDate = @UpdatedDate,
			SPLCCode = @SPLCCode
			WHERE LocationID = @LocationID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				GOTO End_Of_Loop
			END
			SELECT @Status = 'Location Updated'
		END


		End_Of_Loop:
		IF @ErrorID = 100000
		BEGIN
			SELECT @Status = 'Customer Not Found'
			SELECT @ExceptionEncounteredInd = 1
		END
		ELSE IF @ErrorID = 100001
		BEGIN
			SELECT @Status = 'Customer ID And Location ID Mismatch'
			SELECT @ExceptionEncounteredInd = 1
		END
		ELSE IF @ErrorID = 100002
		BEGIN
			SELECT @Status = 'Multiple Matches On Customer Location Code'
			SELECT @ExceptionEncounteredInd = 1
		END
		ELSE IF @ErrorID = 100003
		BEGIN
			SELECT @Status = 'Need Parent Record ID'
			SELECT @ExceptionEncounteredInd = 1
		END
					
		--update the import record
		UPDATE ImportLocation
		SET Status = @Status
		WHERE importLocationID = @ImportLocationID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			GOTO Error_Encountered
		END
		
		FETCH ImportLocationsCursor INTO @ImportLocationID,@LocationID,@ParentRecordID,@LocationType,@LocationSubType,@LocationName,
		@CustomerLocationCode,@CustomerRegionCode,@AddressLine1,@AddressLine2,@City,
		@State,@Zip,@Country,@MainPhone,@FaxNumber,@PrimaryContactFirstName,
		@PrimaryContactLastName,@PrimaryContactPhone,@PrimaryContactExtension,
		@PrimaryContactCellPhone,@PrimaryContactEmail,@AlternateContactFirstName,
		@AlternateContactLastName,@AlternateContactPhone,@AlternateContactExtension,
		@AlternateContactCellPhone,@AlternateContactEmail,@OtherPhone1Description,
		@OtherPhone1,@OtherPhone2Description,@OtherPhone2,@SPLCCode
	END

	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ImportLocationsCursor
		DEALLOCATE ImportLocationsCursor
		SELECT @ReturnCode = 0
		IF @ExceptionEncounteredInd = 0
		BEGIN
			SELECT @ReturnMessage = 'Processing Completed Successfully'
		END
		ELSE
		BEGIN
			SELECT @ReturnMessage = 'Processing Completed Successfully, but with exceptions'
		END
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ImportLocationsCursor
		DEALLOCATE ImportLocationsCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
	END
	
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage
	
	RETURN
END
GO
