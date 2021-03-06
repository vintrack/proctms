USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportPortStorageVehicles]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportPortStorageVehicles] (@BatchID int, @UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@ErrorEncountered		varchar(5000),
	@loopcounter		int,
	-- ImportPortStorageVehicles Variables
	@ImportPortStorageVehiclesID	int,
	@DateIn				varchar(10),
	@DealerCode			varchar(6),
	@VIN				varchar(17),
	@ModelYear			varchar(4),
	@ModelName			varchar(6),
	@Color				varchar(20),
	@Location			varchar(20),
	@VehicleYear			varchar(6),
	@Make				varchar(50),
	@Model				varchar(50),
	@Bodystyle			varchar(50),
	@VehicleLength			varchar(10),
	@VehicleWidth			varchar(10),
	@VehicleHeight			varchar(10),
	@VINDecodedInd			int,
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@RecordStatus			varchar(100),
	@DamageCodeList			varchar(1000),
	-- PortStorageVehicles Variables
	@VehicleID			int,
	@CustomerID			int,
	@CreationDate			datetime,
	@CreatedBy			varchar(20),
	@EntryRate			decimal(19,2),
	@PerDiemGraceDays		int,
	@DamageCode			varchar(5),
	-- Other Processing Variables
	@InspectionID			int,
	@VINCount			int,
	@Status				varchar(1000),
	@ReturnCode			int,
	@ReturnMessage			varchar(1000),
	@ErrorEncounteredInd		int

	/************************************************************************
	*	spImportPortStorageVehicles					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the PortStorageVehiclesImport*
	*	table and creates the new port storage vehicle records.		*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	11/06/2006 CMK    Initial version				*
	*									*
	************************************************************************/
	
	DECLARE ImportPortStorageVehicles CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT PortStorageVehiclesImportID, DateIn, DealerCode, VIN, ModelYear,
		ModelName, Color, Location, VehicleYear, Make, Model, Bodystyle,
		VehicleLength, VehicleWidth, VehicleHeight, VINDecodedInd, DamageCodeList
		FROM PortStorageVehiclesImport
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY PortStorageVehiclesImportID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = @UserCode
	SELECT @ErrorEncounteredInd = 0
	
	OPEN ImportPortStorageVehicles

	BEGIN TRAN

	FETCH ImportPortStorageVehicles into @ImportPortStorageVehiclesID, @DateIn, @DealerCode, @VIN, @ModelYear,
		@ModelName, @Color, @Location, @VehicleYear, @Make, @Model, @Bodystyle,
		@VehicleLength, @VehicleWidth, @VehicleHeight, @VINDecodedInd, @DamageCodeList

	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		--PRINT 'Inside the while loop first time through'

		SELECT @CustomerID = NULL
		
		--just need this statement until full port storage conversion is done
		SELECT @DealerCode = 
			CASE @DealerCode
				WHEN '401080' THEN '94117'
				WHEN '60058' THEN '42845'
				WHEN '60059' THEN '49862'
				WHEN '60057' THEN '93420'
				WHEN '60065' THEN '42860'
				WHEN '60066' THEN '94653'
				WHEN '60067' THEN '94066'
				WHEN '20126' THEN '92596'
				WHEN '60043' THEN '92073'
				WHEN '42286' THEN '42946'
				WHEN '60060' THEN '49108'
				WHEN '60062' THEN '49779'
				WHEN '60061' THEN '92443'
				WHEN '60053' THEN '42083'
				ELSE @DealerCode
			END
			
		--get the CustomerID		
		SELECT TOP 1 @CustomerID = CustomerID
		FROM Customer
		WHERE CustomerCode = @DealerCode
		IF @@Error <> 0
		BEGIN
			--print 'in origin error'
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR GETTING CUSTOMER ID'
			GOTO Error_Encountered
		END
		IF @CustomerID IS NULL
		BEGIN
			SELECT @RecordStatus = 'Dealer Code '+@DealerCode+' Not Found'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			SELECT @ErrorEncounteredInd = 1
			GOTO Update_Record
		END
		

		--see if the vin already exists as an open record.
		SELECT @VINCOUNT = COUNT(*)
		FROM PortStorageVehicles
		WHERE VIN = @VIN
		AND CustomerID = @CustomerID
		AND DateOut IS NULL
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error getting vin count'
			GOTO Error_Encountered
		END

		IF @VINCOUNT > 0
		BEGIN
			SELECT @RecordStatus = 'Vehicle already exists.'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			SELECT @ErrorEncounteredInd = 1
			GOTO Update_Record
			
			
		END
		ELSE
		BEGIN	
			--get the rate info
			SELECT @EntryRate = EntryFee,
			@PerDiemGraceDays = PerDiemGraceDays
			FROM PortStorageRates
			WHERE CustomerID = @CustomerID
			AND @DateIn >= StartDate
			AND @DateIn < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting rates'
				GOTO Error_Encountered
			END
			
			--and now do the vehicle
			INSERT INTO PortStorageVehicles(
				CustomerID,
				VehicleYear,
				Make,
				Model,
				Bodystyle,
				VIN,
				Color,
				VehicleLength,
				VehicleWidth,
				VehicleHeight,
				VehicleStatus,
				CustomerIdentification,
				SizeClass,
				BayLocation,
				EntryRate,
				EntryRateOverrideInd,
				PerDiemGraceDays,
				PerDiemGraceDaysOverrideInd,
				TotalCharge,
				DateIn,
				BilledInd,
				VINDecodedInd,
				RecordStatus,
				CreationDate,
				CreatedBy,
				CreditHoldInd,
				RequestPrintedInd,
				LastPhysicalDate
			)
			VALUES(
				@CustomerID,
				@VehicleYear,
				@Make,
				@Model,
				@Bodystyle,
				@VIN,
				@Color,
				@VehicleLength,
				@VehicleWidth,
				@VehicleHeight,
				'InInventory',	--VehicleStatus,
				'',		--CustomerIdentification,
				'A',		--SizeClass,
				@Location,	--BayLocation,
				@EntryRate,
				0,		--EntryRateOverrideInd,
				@PerDiemGraceDays,
				0,		--PerDiemGraceDaysOverrideInd,
				0,		--TotalCharge,
				@DateIn,
				0,		--BilledInd,
				@VINDecodedInd,
				'Active',	--RecordStatus,
				@CreationDate,
				@CreatedBy,
				0,		--CreditHoldInd
				0,		--RequestPrintedInd
				@CreationDate	--LastPhysicalDate
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR CREATING VEHICLE RECORD'
				GOTO Error_Encountered
			END

			SELECT @VehicleID = @@IDENTITY
			
			IF @VehicleID IS NULL
			BEGIN
				SELECT @RecordStatus = 'Error Getting VehicleID, damages may not have updated.'
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				SELECT @ErrorEncounteredInd = 1
				GOTO Update_Record
			END
			
			--create the inspection record
			SELECT @ReturnCode = 1
			EXEC spCreatePortStorageVehicleInspectionRecord 
				@VehicleID,0,@DateIn,@UserCode,0,0,1,'',
				@rRecordID = @InspectionID OUTPUT,
				@rReturnCode = @ReturnCode OUTPUT
			IF @ReturnCode <> 0
			BEGIN
				SELECT @RecordStatus = 'inspid:'+convert(varchar(10),@InspectionID)+' retcd:'+convert(varchar(10),@ReturnCode)+' Error Inserting Inspection Record.'
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				SELECT @ErrorEncounteredInd = 1
				GOTO Update_Record
			END
			
			--insert any damages
			IF DATALENGTH(@DamageCodeList) > 0
			BEGIN
				WHILE DATALENGTH(@DamageCodeList) > 0
				BEGIN
					IF CHARINDEX(',',@DamageCodeList)>0
					BEGIN
						SELECT @DamageCode = LEFT(@DamageCodeList,CHARINDEX(',',@DamageCodeList)-1)
						SELECT @DamageCodeList = RIGHT(@DamageCodeList,DATALENGTH(@DamageCodeList)-(CHARINDEX(',',@DamageCodeList)))
					END
					ELSE
					BEGIN
						SELECT @DamageCode = @DamageCodeList
						SELECT @DamageCodeList = ''
					END
					
					IF DATALENGTH(@DamageCode)>0
					BEGIN
						SELECT @ReturnCode = 1
						EXEC spProcessPortStorageDamageCode 
						@VehicleID,@InspectionID,@DamageCode,
						'',@DateIn,@UserCode,
						@rReturnCode = @ReturnCode OUTPUT
						IF @ReturnCode <> 0
						BEGIN
							SELECT @RecordStatus = 'Error Adding Damage Code.'
							SELECT @ImportedInd = 1
							SELECT @ImportedDate = NULL
							SELECT @ImportedBy = NULL
							SELECT @ErrorEncounteredInd = 1
							GOTO Update_Record
						END
					END
				END	
			END
			
			--add in the location history record
			INSERT INTO PortStorageVehiclesLocationHistory(
				PortStorageVehiclesID,
				BayLocation,
				LocationDate,
				CreationDate,
				CreatedBy
			)
			VALUES(
				@VehicleID,
				@Location,
				@CreationDate,
				@CreationDate,
				@UserCode
			)
			IF @@ERROR <> 0
			BEGIN
				SELECT @RecordStatus = 'Error Adding Location History Record.'
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				SELECT @ErrorEncounteredInd = 1
				GOTO Update_Record
			END
			
			SELECT @RecordStatus = 'Imported'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = GetDate()
			SELECT @ImportedBy = @UserCode
		END

		--update logic here.
		Update_Record:
		UPDATE PortStorageVehiclesImport
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE PortStorageVehiclesImportID = @ImportPortStorageVehiclesID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH ImportPortStorageVehicles into @ImportPortStorageVehiclesID, @DateIn, @DealerCode, @VIN, @ModelYear,
		@ModelName, @Color, @Location, @VehicleYear, @Make, @Model, @Bodystyle,
		@VehicleLength, @VehicleWidth, @VehicleHeight, @VINDecodedInd, @DamageCodeList

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ImportPortStorageVehicles
		DEALLOCATE ImportPortStorageVehicles
		--PRINT 'ImportPortStorageVehicles Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		IF @ErrorEncounteredInd = 0
		BEGIN
			SELECT @ReturnMessage = 'Processing Completed Successfully'
		END
		ELSE
		BEGIN
			SELECT @ReturnMessage = 'Processing Completed, But With Errors'
		END
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ImportPortStorageVehicles
		DEALLOCATE ImportPortStorageVehicles
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			--PRINT 'ImportPortStorageVehicles Error_Encountered =' + STR(@ErrorID)
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
