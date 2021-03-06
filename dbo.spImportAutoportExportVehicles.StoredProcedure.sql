USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportAutoportExportVehicles]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportAutoportExportVehicles] (@BatchID int, @UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@ErrorEncountered		varchar(5000),
	@loopcounter			int,
	@AutoportExportVehiclesImportID	int,
	@DateReceived			varchar(10),
	@VIN				varchar(17),
	@BayLocation			varchar(20),
	@VoyageID			int,
	--@VesselID			int,
	@BookingNumber			varchar(20),
	@BookingNumberSuffix		varchar(20),
	--@VoyageNumber			varchar(20),
	@DestinationName		varchar(100),
	@VehicleYear			varchar(6),
	@Make				varchar(50),
	@Model				varchar(50),
	@Bodystyle			varchar(50),
	@VehicleLength			varchar(10),
	@VehicleWidth			varchar(10),
	@VehicleHeight			varchar(10),
	@VehicleWeight			varchar(10),
	@VehicleCubicFeet		varchar(10),
	@SizeClass			varchar(20),
	@VINDecodedInd			int,
	@AudioSystemFlag		varchar(20),
	@NavigationSystemFlag		varchar(20),
	@HandheldCustomerCode		varchar(50),
	@CustomerID			int,
	@CreationDate			datetime,
	@CreatedBy			varchar(20),
	@EntryRate			decimal(19,2),
	@PerDiemGraceDays		int,
	@HasAudioSystemInd		int,
	@HasNavigationSystemInd		int,
	@VIVTagNumber			varchar(10),
	@Color				varchar(20),
	@RunnerInd			int,
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@VehicleDestinationName		varchar(100),
	@VehicleDateReceived		datetime,
	@VehicleStatus			varchar(20),
	@VehicleCustomerID		int,
	@FullDestinationName		varchar(100),
	@VINCount			int,
	@AutoportExportVehiclesID	int,
	@ACLCustomerID			int,
	@InspectorCode			varchar(30),
	@InspectorName			varchar(30),
	@InspectorNotFoundInd		int,
	@RecordStatus			varchar(100),
	@Status				varchar(1000),
	@ReturnCode			int,
	@ReturnMessage			varchar(1000),
	@ErrorEncounteredInd		int

	/********************************************************************************
	*	spImportAutoportExportVehicles						*
	*										*
	*	Description								*
	*	-----------								*
	*	This procedure takes the data from the AutoportExportVehiclesImport	*
	*	table and creates the new autoport import vehicle records.		*
	*										*
	*	Change History								*
	*	--------------								*
	*	Date       Init's Description						*
	*	---------- ------ ----------------------------------------		*
	*	07/27/2007 CMK    Initial version					*
	*										*
	********************************************************************************/
	
	DECLARE ImportAutoportExportVehicles CURSOR
		LOCAL FORWARD_ONLY STATIC READ_ONLY
		FOR
			SELECT AutoportExportVehiclesImportID, CONVERT(varchar(10),CreationDate,101), UPPER(VIN), 
			BayLocation, 'BOS'+BookingNumber, DestinationName, VehicleYear, Make, Model, Bodystyle,
			VehicleLength, VehicleWidth, VehicleHeight, VehicleWeight, VehicleCubicFeet,
			VINDecodedInd, SizeClass, AudioSystemFlag, NavigationSystemFlag, CustomerName, Inspector,
			VIVTagNumber, Color, CASE WHEN RunnerInd = 1 THEN 0 ELSE 1 END
			FROM AutoportExportVehiclesImport
			WHERE BatchID = @BatchID
			AND ImportedInd = 0
			ORDER BY AutoportExportVehiclesImportID
	
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = @UserCode
	SELECT @ErrorEncounteredInd = 0
	
	SELECT TOP 1 @ACLCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ACLCustomerID'
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Customer ACL ID'
		GOTO Error_Encountered
	END
		
	OPEN ImportAutoportExportVehicles
	
	BEGIN TRAN

	FETCH ImportAutoportExportVehicles into @AutoportExportVehiclesImportID, @DateReceived, @VIN,
		@BayLocation, @BookingNumber, @DestinationName, @VehicleYear, @Make, @Model, @Bodystyle,
		@VehicleLength, @VehicleWidth, @VehicleHeight, @VehicleWeight, @VehicleCubicFeet,
		@VINDecodedInd, @SizeClass, @AudioSystemFlag, @NavigationSystemFlag, @HandheldCustomerCode,
		@InspectorCode, @VIVTagNumber, @Color, @RunnerInd

	
	
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @InspectorNotFoundInd = 0
		/*
		IF @DestinationName = 'Beruit' -- spelled incorrectly on phone
		BEGIN
			SELECT @DestinationName = 'Beirut'
		END
		--ELSE IF @DestinationName = 'Lagos' -- lagos is inactive and no misurate on phone
		--BEGIN
		--	SELECT @DestinationName = 'Misurate'
		--END
		ELSE IF @DestinationName = 'A'
		BEGIN
			SELECT @DestinationName = 'Aqaba'
		END
		ELSE IF @DestinationName = 'AB'
		BEGIN
			SELECT @DestinationName = 'Abidjan'
		END
		ELSE IF @DestinationName = 'B'
		BEGIN
			SELECT @DestinationName = 'Beirut'
		END
		ELSE IF @DestinationName = 'BA'
		BEGIN
			SELECT @DestinationName = 'Banjul'
		END
		ELSE IF @DestinationName = 'BO'
		BEGIN
			SELECT @DestinationName = 'Boma'
		END
		ELSE IF @DestinationName = 'C'
		BEGIN
			SELECT @DestinationName = 'Cotonou'
		END
		ELSE IF @DestinationName = 'CO'
		BEGIN
			SELECT @DestinationName = 'Conakry'
		END
		ELSE IF @DestinationName = 'DA'
		BEGIN
			SELECT @DestinationName = 'Dammam'
		END
		ELSE IF @DestinationName = 'DK'
		BEGIN
			SELECT @DestinationName = 'Dakar'
		END
		ELSE IF @DestinationName = 'DO'
		BEGIN
			SELECT @DestinationName = 'Douala'
		END
		ELSE IF @DestinationName = 'DU'
		BEGIN
			SELECT @DestinationName = 'Dubai'
		END
		ELSE IF @DestinationName = 'FR'
		BEGIN
			SELECT @DestinationName = 'Freetown'
		END
		ELSE IF @DestinationName = 'J'
		BEGIN
			SELECT @DestinationName = 'Jeddah'
		END
		ELSE IF @DestinationName = 'L'
		BEGIN
			SELECT @DestinationName = 'Lome'
		END
		ELSE IF @DestinationName = 'LA'
		BEGIN
			SELECT @DestinationName = 'Lagos'
		END
		ELSE IF @DestinationName = 'LO'
		BEGIN
			SELECT @DestinationName = 'Lobito'
		END
		ELSE IF @DestinationName = 'LU'
		BEGIN
			SELECT @DestinationName = 'Luanda'
		END
		ELSE IF @DestinationName = 'LY'
		BEGIN
			SELECT @DestinationName = 'Libya'
		END
		ELSE IF @DestinationName = 'M'
		BEGIN
			SELECT @DestinationName = 'Misurate'
		END
		ELSE IF @DestinationName = 'PN'
		BEGIN
			SELECT @DestinationName = 'Pointe Noire'
		END
		ELSE IF @DestinationName = 'T'
		BEGIN
			SELECT @DestinationName = 'Tema'
		END
		ELSE IF @DestinationName = 'TA'
		BEGIN
			SELECT @DestinationName = 'Takadori'
		END
		*/
		--Get the full destination name
		IF DATALENGTH(@DestinationName) <= 3
		BEGIN
			SELECT @FullDestinationName = NULL
			SELECT TOP 1 @FullDestinationName = Code
			FROM Code
			WHERE CodeType = 'ExportDischargePort'
			AND Value2 = @DestinationName
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Getting Destination'
				GOTO Error_Encountered
			END
			
			IF @FullDestinationName IS NOT NULL
			BEGIN
				SELECT @DestinationName = @FullDestinationName
			END
		END
		
		--Get the inspectors name
		SELECT @InspectorName = NULL
		IF DATALENGTH(ISNULL(@InspectorCode,'')) > 0
		BEGIN
			SELECT TOP 1 @InspectorName = U.FirstName+' '+U.LastName
			FROM Users U
			WHERE U.PortPassIDNumber = @InspectorCode
			OR U.UserCode = @InspectorCode
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Getting Inspector'
				GOTO Error_Encountered
			END
				
			IF @InspectorName IS NULL
			BEGIN
				SELECT @InspectorName = @InspectorCode
				SELECT @InspectorNotFoundInd = 1
			END
		END
		ELSE
		BEGIN
			SELECT @InspectorName = ''
		END
		--see if the vin already exists as an open record.
		SELECT @VINCOUNT = COUNT(*)
		FROM AutoportExportVehicles
		WHERE VIN = @VIN
		--AND CustomerID = @CustomerID
		AND DateShipped IS NULL
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error getting vin count'
			GOTO Error_Encountered
		END

		IF @VINCOUNT = 1
		BEGIN
			SELECT @AutoportExportVehiclesID = AutoportExportVehiclesID,
			@VehicleDestinationName = DestinationName,
			@VehicleDateReceived = DateReceived,
			@VehicleStatus = VehicleStatus,
			@VehicleCustomerID = CustomerID
			FROM AutoportExportVehicles
			WHERE VIN = @VIN
			--AND CustomerID = @CustomerID
			AND DateShipped IS NULL
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting vin count'
				GOTO Error_Encountered
			END
							
			IF DATALENGTH(@HandheldCustomerCode) >0
			BEGIN
				SELECT @CustomerID = NULL
							
				SELECT TOP 1 @CustomerID = CustomerID
				FROM Customer
				WHERE AutoportExportCustomerInd = 1
				AND HandheldScannerCustomerCode = @HandheldCustomerCode
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Getting Customer ID'
					GOTO Error_Encountered
				END
							
				IF @CustomerID IS NULL
				BEGIN
					SELECT @ErrorEncounteredInd = 1
					SELECT @RecordStatus = 'CUSTOMER NOT FOUND'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record
				END
				
				IF @CustomerID <> @VehicleCustomerID
				BEGIN
					SELECT @RecordStatus = 'CUSTOMER MISMATCH'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record
				END
			END
			
			IF DATALENGTH(@DestinationName)>0
			BEGIN
				--validate the destination
				IF @VehicleDestinationName <> @DestinationName
				BEGIN
					SELECT @RecordStatus = 'DESTINATION MISMATCH'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record
				END
			END
			
			IF @VehicleDateReceived IS NULL AND @VehicleStatus = 'Pending'
			BEGIN
				UPDATE AutoportExportVehicles
				SET DateReceived = @DateReceived,
				ReceivedBy = @InspectorName,
				VehicleStatus = 'Received',
				BayLocation = @BayLocation,
				LastPhysicalDate = @CreationDate,
				LastPhysicalBy = @InspectorName,
				VIVTagNumber = CASE WHEN DATALENGTH(@VIVTagNumber) > 0 AND @VIVTagNumber <> '0' THEN @VIVTagNumber ELSE VIVTagNumber END 
				WHERE VIN = @VIN
				--AND CustomerID = @CustomerID
				AND DateShipped IS NULL
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error updating vehicle status'
					GOTO Error_Encountered
				END
				
				INSERT INTO AEVehicleStatusHistory(
					AutoportExportVehiclesID,
					VehicleStatus,
					StatusDate,
					CreationDate,
					CreatedBy
				)
				VALUES(
					@AutoportExportVehiclesID,
					'Received',
					@DateReceived,
					@CreationDate,
					@UserCode
				)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error adding Status History Record'
					GOTO Error_Encountered
				END
				
				SELECT @RecordStatus = 'Imported'
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = CURRENT_TIMESTAMP
				SELECT @ImportedBy = @UserCode
			END
			ELSE IF DATALENGTH(@BayLocation)>0
			BEGIN
				UPDATE AutoportExportVehicles
				SET BayLocation = @BayLocation,
				LastPhysicalDate = @CreationDate,
				LastPhysicalBy = @InspectorName
				WHERE VIN = @VIN
				--AND CustomerID = @CustomerID
				AND DateShipped IS NULL
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error updating bay location'
					GOTO Error_Encountered
				END
				SELECT @RecordStatus = 'Bay Location Updated'
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = CURRENT_TIMESTAMP
				SELECT @ImportedBy = @UserCode
			END
			ELSE
			BEGIN
				SELECT @RecordStatus = 'Duplicate VIN'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
			END			
			GOTO Update_Record
			
			
		END
		ELSE IF @VINCOUNT > 1
		BEGIN
			SELECT @ErrorEncounteredInd = 1
			SELECT @RecordStatus = 'Multiple Matches For VIN'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			GOTO Update_Record
		END
		ELSE
		BEGIN	
			IF DATALENGTH(@HandheldCustomerCode) > 0
			BEGIN
				SELECT @BookingNumberSuffix = Value2
				FROM Code
				WHERE CodeType = 'ExportDischargePort'
				AND Code = @DestinationName
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error getting booking number suffix'
					GOTO Error_Encountered
				END
						
				SELECT @CustomerID = NULL
							
				SELECT TOP 1 @CustomerID = CustomerID
				FROM Customer
				WHERE AutoportExportCustomerInd = 1
				AND HandheldScannerCustomerCode = @HandheldCustomerCode
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Getting Customer ID'
					GOTO Error_Encountered
				END
							
				IF @CustomerID IS NULL
				BEGIN
					SELECT @ErrorEncounteredInd = 1
					SELECT @RecordStatus = 'CUSTOMER NOT FOUND'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record
				END
										
				SELECT @VoyageID = NULL
							
				--get the next vesselid/voyage number
				SELECT TOP 1 @VoyageID = AEV.AEVoyageID
				FROM AEVoyage AEV
				LEFT JOIN AEVoyageDestination AEVD ON AEV.AEVoyageID = AEVD.AEVoyageID
				LEFT JOIN AEVoyageCustomer AEVC ON AEV.AEVoyageID = AEVC.AEVoyageID
				WHERE AEV.VoyageClosedInd = 0
				AND AEV.VoyageDate >= CONVERT(varchar(10),CURRENT_TIMESTAMP,101)
				AND AEVD.DestinationName = @DestinationName
				AND AEVC.CustomerID = @CustomerID
				ORDER BY AEV.VoyageDate
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Getting Customer ID'
					GOTO Error_Encountered
				END
									
				IF @VoyageID IS NULL
				BEGIN
					SELECT @ErrorEncounteredInd = 1
					SELECT @RecordStatus = 'NEXT VOYAGE NOT FOUND'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record
				END
										
				SELECT @VINCOUNT = COUNT(*)
				FROM AutoportExportVehicles
				WHERE VIN = @VIN
				AND CustomerID = @CustomerID
				AND DateShipped IS NOT NULL
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error getting vin count'
					GOTO Error_Encountered
				END
							
				IF @VINCOUNT > 0
				BEGIN
					SELECT @ErrorEncounteredInd = 1
					SELECT @RecordStatus = 'Shows As Shipped'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record
				END
							
			
				--get the rate info
				SELECT @EntryRate = EntryFee,
				@PerDiemGraceDays = PerDiemGraceDays
				FROM AutoportExportRates
				WHERE CustomerID = @CustomerID
				AND @DateReceived >= StartDate
				AND @DateReceived < DATEADD(day,1,ISNULL(EndDate, '12/31/2099'))
				AND RateType = 'Size '+@SizeClass+' Rate'
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error getting rates'
					GOTO Error_Encountered
				END
			
				IF ISNULL(@AudioSystemFlag,'') = 'Y'
				BEGIN
					SELECT @HasAudioSystemInd = 1
				END
				ELSE
				BEGIN
					SELECT @HasAudioSystemInd = 0
				END
				
				IF ISNULL(@NavigationSystemFlag,'') = 'Y'
				BEGIN
					SELECT @HasNavigationSystemInd = 1
				END
				ELSE
				BEGIN
					SELECT @HasNavigationSystemInd = 0
				END
				IF @VIVTagNumber = '0'
				BEGIN
					SELECT @VIVTagNumber = ''
				END
				
				SELECT @BookingNumber = 'REC' --@BookingNumber + @BookingNumberSuffix
				--SELECT @DestinationName = ''
				--and now do the vehicle
				INSERT INTO AutoportExportVehicles(
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
					VehicleWeight,
					VehicleCubicFeet,
					VehicleStatus,
					DestinationName,
					--VesselID,
					BookingNumber,
					--VoyageNumber,
					SizeClass,
					BayLocation,
					EntryRate,
					EntryRateOverrideInd,
					PerDiemGraceDays,
					PerDiemGraceDaysOverrideInd,
					TotalCharge,
					DateReceived,
					BilledInd,
					VINDecodedInd,
					Note,
					RecordStatus,
					CreationDate,
					CreatedBy,
					CreditHoldInd,
					CustomsApprovalPrintedInd,
					VoyageID,
					CustomsCoverSheetPrintedInd,
					NoStartInd,
					LastPhysicalDate,
					HasAudioSystemInd,
					HasNavigationSystemInd,
					CustomsApprovedCoverSheetPrintedInd,
					ReceivedBy,
					LastPhysicalBy,
					BarCodeLabelPrintedInd,
					VIVTagNumber,
					MechanicalExceptionInd,
					LeftBehindInd
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
					@VehicleWeight,
					@VehicleCubicFeet,
					'Received',	--VehicleStatus,
					@DestinationName,
					--@VesselID,
					@BookingNumber,
					--@VoyageNumber,
					@SizeClass,
					@BayLocation,
					@EntryRate,
					0,		--EntryRateOverrideInd,
					@PerDiemGraceDays,
					0,		--PerDiemGraceDaysOverrideInd,
					0,		--TotalCharge,
					@DateReceived,
					0,		--BilledInd,
					@VINDecodedInd,
					'',		--Note,
					'Active',	--RecordStatus,
					@CreationDate,
					@CreatedBy,
					0,		--CreditHoldInd
					0,		--CustomsApprovalPrintedInd
					@VoyageID,
					0,		--CustomsCoverSheetPrintedInd
					@RunnerInd,		--NoStartInd
					@CreationDate,
					@HasAudioSystemInd,
					@HasNavigationSystemInd,
					0,		--CustomsApprovedCoverSheetPrintedInd
					@InspectorName,	--ReceivedBy
					@InspectorName,	--LastPhysicalBy
					0,		--BarCodeLabelPrintedInd
					@VIVTagNumber,
					0,		--MechanicalExceptionInd
					0		--LeftBehindInd
				)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR CREATING VEHICLE RECORD'
					GOTO Error_Encountered
				END

				SELECT @AutoportExportVehiclesID = @@IDENTITY
				
				INSERT INTO AEVehicleStatusHistory(
					AutoportExportVehiclesID,
					VehicleStatus,
					StatusDate,
					CreationDate,
					CreatedBy
				)
				VALUES(
					@AutoportExportVehiclesID,
					'Received',
					@DateReceived,
					@CreationDate,
					@UserCode
				)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error adding Status History Record'
					GOTO Error_Encountered
				END
								
				IF @CustomerID = @ACLCustomerID
				BEGIN
					SELECT @RecordStatus = 'ACL RECORD CREATED'
				END
				ELSE IF DATALENGTH(@SizeClass) > 0
				BEGIN
					SELECT @RecordStatus = 'Imported'
				END
				ELSE
				BEGIN
					SELECT @RecordStatus = 'SIZE CLASS NEEDED'
				END
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = GetDate()
				SELECT @ImportedBy = @UserCode
			END
			ELSE
			BEGIN
				SELECT @RecordStatus = 'VIN Not Found'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
			END
		END

		--update logic here.
		Update_Record:
		IF @InspectorNotFoundInd = 1
		BEGIN
			SELECT @RecordStatus = @RecordStatus + ', Invalid Inspector (' + @InspectorCode + ')' 
		END
		
		UPDATE AutoportExportVehiclesImport
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedBy = @ImportedBy,
		ImportedDate = @ImportedDate
		WHERE AutoportExportVehiclesImportID = @AutoportExportVehiclesImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH ImportAutoportExportVehicles into @AutoportExportVehiclesImportID, @DateReceived, @VIN,
			@BayLocation, @BookingNumber, @DestinationName, @VehicleYear, @Make, @Model, @Bodystyle,
			@VehicleLength, @VehicleWidth, @VehicleHeight, @VehicleWeight, @VehicleCubicFeet,
			@VINDecodedInd, @SizeClass, @AudioSystemFlag, @NavigationSystemFlag, @HandheldCustomerCode,
			@InspectorCode, @VIVTagNumber, @Color, @RunnerInd

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ImportAutoportExportVehicles
		DEALLOCATE ImportAutoportExportVehicles
		--PRINT 'ImportAutoportExportVehicles Error_Encountered =' + STR(@ErrorID)
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
		CLOSE ImportAutoportExportVehicles
		DEALLOCATE ImportAutoportExportVehicles
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			--PRINT 'ImportAutoportExportVehicles Error_Encountered =' + STR(@ErrorID)
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
