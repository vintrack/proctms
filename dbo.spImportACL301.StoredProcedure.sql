USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportACL301]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportACL301] (@BatchID int, @UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@ErrorEncountered		varchar(5000),
	@loopcounter			int,
	--ACL 301 variables
	@ImportACL301ID			int,
	@ReservationActionCode		varchar(1),
	@BookingNumber			varchar(17),
	@DischargePortLocationQualifier	varchar(2),
	@DischargePortLocationIdentifier	varchar(30),
	@Weight				varchar(10),
	@Volume				varchar(8),
	@VolumeUnitQualifier		varchar(1),
	@WeightUnitCode			varchar(1),
	@ManufacturerCode		varchar(30),
	@VIN				varchar(48),
	@ModelCode			varchar(30),
	@Length				varchar(8),
	@Width				varchar(8),
	@Height				varchar(8),
	@MeasurementUnitQualifier	varchar(1),
	@VesselName			varchar(28),
	@VoyageNumber			varchar(10),
	@VehicleYear			varchar(6),
	@Make				varchar(50),
	@Model				varchar(50),
	@Bodystyle			varchar(50),
	@VehicleLength			varchar(10),
	@VehicleWidth			varchar(10),
	@VehicleHeight			varchar(10),
	@VINDecodedInd			int,
	--processing variables
	@MetricHeight			decimal(19,2),
	@CubicInches			decimal(19,2),
	@VoyageID			int,
	@SizeClass			varchar(20),
	@VehicleWeight			varchar(10),
	@VehicleCubicFeet		varchar(10),
	@AutoportExportVehiclesID	int,
	@VehicleStatus			varchar(20),
	@DateReceived			datetime,
	@VehicleCustomerID		int,
	@DestinationName		varchar(20),
	@CustomerID			int,
	@CreationDate			datetime,
	@CreatedBy			varchar(20),
	@EntryRate			decimal(19,2),
	@PerDiemGraceDays		int,
	@HasAudioSystemInd		int,
	@HasNavigationSystemInd		int,
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@VehicleDestinationName		varchar(100),
	@VINCount			int,
	@RecordStatus			varchar(100),
	@Status				varchar(1000),
	@ReturnCode			int,
	@ReturnMessage			varchar(1000),
	@ErrorEncounteredInd		int

	/********************************************************************************
	*	spImportACL301								*
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
	*	03/30/2009 CMK    Initial version					*
	*										*
	********************************************************************************/
	
	DECLARE ImportACL301 CURSOR
		LOCAL FORWARD_ONLY STATIC READ_ONLY
		FOR
			SELECT ImportACL301ID, ReservationActionCode, BookingNumber,
			DischargePortLocationQualifier, DischargePortLocationIdentifier, Weight,
			Volume, VolumeUnitQualifier, WeightUnitCode, ManufacturerCode, VIN,
			ModelCode, Length, Width, Height, MeasurementUnitQualifier, VesselName,
			VoyageNumber, VehicleYear, Make, Model, Bodystyle, VehicleLength,
			VehicleWidth, VehicleHeight, VINDecodedInd
			FROM ImportACL301
			WHERE BatchID = @BatchID
			AND ImportedInd = 0
			ORDER BY ImportACL301ID
	
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = @UserCode
	SELECT @ErrorEncounteredInd = 0
	
	OPEN ImportACL301
	
	BEGIN TRAN

	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ACLCustomerID'
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Customer ID'
		GOTO Error_Encountered
	END

	FETCH ImportACL301 into @ImportACL301ID, @ReservationActionCode, @BookingNumber,
		@DischargePortLocationQualifier, @DischargePortLocationIdentifier, @Weight,
		@Volume, @VolumeUnitQualifier, @WeightUnitCode, @ManufacturerCode, @VIN,
		@ModelCode, @Length, @Width, @Height, @MeasurementUnitQualifier, @VesselName,
		@VoyageNumber, @VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength,
		@VehicleWidth, @VehicleHeight, @VINDecodedInd
	

	
	
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--print 'vin = ' + @VIN
		SELECT @RecordStatus = 'Imported'
		SELECT @DestinationName = ''
		--print 'record status = imported'
		IF @ReservationActionCode IN ('D','R')
		BEGIN
			--print 'reservation action code in D,R'
			--see if we can delete the vehicle
			SELECT @VINCount = COUNT(*)
			FROM AutoportExportVehicles
			WHERE VIN = @VIN
			AND CustomerID = @CustomerID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Getting VIN Count'
				GOTO Error_Encountered
			END
			IF @VINCount = 0
			BEGIN
				SELECT @ErrorEncounteredInd = 1
				SELECT @RecordStatus = 'VIN NOT FOUND'
				--print 'record status = VIN NOT FOUND'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Record
			END
			ELSE IF @VINCount = 1
			BEGIN
				SELECT @AutoportExportVehiclesID = AutoportExportVehiclesID,
				@VehicleStatus = VehicleStatus, @DateReceived = DateReceived
				FROM AutoportExportVehicles
				WHERE VIN = @VIN
				AND CustomerID = @CustomerID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Getting Vehicle Info'
					GOTO Error_Encountered
				END
				
				IF @VehicleStatus <> 'Pending'
				BEGIN
					SELECT @ErrorEncounteredInd = 1
					SELECT @RecordStatus = 'CANNOT DELETE - NOT PENDING'
					--print 'record status = CANNOT DELETE - NOT PENDING'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record
				END
				
				IF @DateReceived IS NOT NULL
				BEGIN
					SELECT @ErrorEncounteredInd = 1
					SELECT @RecordStatus = 'CANNOT DELETE - ALREADY RECEIVED'
					--print 'record status = CANNOT DELETE - ALREADY RECEIVED'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record
				END
				
				DELETE FROM AutoportExportVehicles
				WHERE AutoportExportVehiclesID = @AutoportExportVehiclesID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Getting Vehicle Info'
					GOTO Error_Encountered
				END
				
				SELECT @RecordStatus = 'VEHICLE DELETED'
				--print 'record status = VEHICLE DELETED'
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = CURRENT_TIMESTAMP
				SELECT @ImportedBy = @UserCode
				GOTO Update_Record
			END
			ELSE
			BEGIN
				SELECT @ErrorEncounteredInd = 1
				SELECT @RecordStatus = 'CANNOT DELETE - MULTIPLE MATCHES'
				--print 'record status = CANNOT DELETE - MULTIPLE MATCHES'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Record
			END
		END
		ELSE IF @ReservationActionCode IN ('N','U')
		BEGIN
			--print 'reservation action code in N,U'
			IF @DischargePortLocationQualifier = 'D'
			BEGIN
				--print 'discharge loc qual is D'
				SELECT TOP 1 @DestinationName = CodeDescription
				FROM Code
				WHERE CodeType = 'ScheduleDCode'
				AND Code = @DischargePortLocationIdentifier
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Getting Destination Name'
					GOTO Error_Encountered
				END
				IF ISNULL(@DestinationName,'') = ''
				BEGIN
					SELECT @RecordStatus = 'IMPORTED, DEST NEEDED. Sched D Code '+@DischargePortLocationIdentifier+ ' not found!'
					--print 'record status = IMPORTED, DEST NEEDED. Sched D Code...'
					SELECT @ErrorEncounteredInd = 1
				END
			END
			ELSE IF @DischargePortLocationQualifier = 'K'
			BEGIN
				--print 'discharge loc qual is K'
				SELECT TOP 1 @DestinationName = CodeDescription
				FROM Code
				WHERE CodeType = 'ScheduleKCode'
				AND Code = @DischargePortLocationIdentifier
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Getting Destination Name'
					GOTO Error_Encountered
				END
				IF ISNULL(@DestinationName,'') = ''
				BEGIN
					SELECT @RecordStatus = 'IMPORTED, DEST NEEDED. Sched K Code '+@DischargePortLocationIdentifier+ ' not found!'
					--print 'record status = IMPORTED, DEST NEEDED. Sched K Code...'
					SELECT @ErrorEncounteredInd = 1
				END
			END
			ELSE
			BEGIN
				--print 'discharge loc qual is blank'
				SELECT @DestinationName = ''
				SELECT @RecordStatus = 'IMPORTED, DEST NEEDED.'
				--print 'record status = IMPORTED, DEST NEEDED.'
				SELECT @ErrorEncounteredInd = 1
			END
			--PRINT 'Inside the while loop first time through'
			SELECT @VoyageID = NULL
			
			--get the next vesselid/voyage number
			SELECT TOP 1 @VoyageID = AEV.AEVoyageID
			FROM AEVoyage AEV
			LEFT JOIN AEVoyageDestination AEVD ON AEV.AEVoyageID = AEVD.AEVoyageID
			LEFT JOIN AEVoyageCustomer AEVC ON AEV.AEVoyageID = AEVC.AEVoyageID
			WHERE AEV.VoyageClosedInd = 0
			AND AEV.VoyageDate >= CONVERT(varchar(10),CURRENT_TIMESTAMP,101)
			AND AEV.VoyageNumber = @VoyageNumber
			AND AEVD.DestinationName = @DestinationName
			AND AEVC.CustomerID = @CustomerID
			ORDER BY AEV.VoyageDate
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Getting Voyage ID'
				GOTO Error_Encountered
			END
			
			IF @VoyageID IS NULL
			BEGIN
				SELECT @RecordStatus = 'VOYAGE NOT FOUND'
				--print 'record status = VOYAGE NOT FOUND'
				SELECT @ErrorEncounteredInd = 1
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
			--print 'vincount = '+convert(varchar(10),@VINCOUNT)	
			IF @VINCOUNT = 1
			BEGIN
				--print 'in vin count = 1'
				SELECT @RecordStatus = 'Vehicle Updated'
				--print 'record status = Vehicle Updated'
				
				SELECT @VehicleCustomerID = CustomerID,
				@VehicleDestinationName = DestinationName
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
					
				--validate the destination
				IF DATALENGTH(@DestinationName)>0
				BEGIN
					IF @VehicleDestinationName <> @DestinationName
					BEGIN
						SELECT @ErrorEncounteredInd = 1
						SELECT @RecordStatus = 'DESTINATION UPDATED'
						--print 'record status = DESTINATION UPDATED'
					END
				END
				
				--validate the customer
				IF @VehicleCustomerID <> @CustomerID
				BEGIN
					SELECT @ErrorEncounteredInd = 1
					SELECT @RecordStatus = 'CUSTOMER MISMATCH'
					--print 'record status = CUSTOMER MISMATCH'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record
				END
				--print 'about to update vehicle'
				UPDATE AutoportExportVehicles
				SET DestinationName = @DestinationName,
				BookingNumber = @BookingNumber
				WHERE VIN = @VIN
				AND CustomerID = @CustomerID
				AND DateShipped IS NULL
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error updating bay location'
					GOTO Error_Encountered
				END
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = CURRENT_TIMESTAMP
				SELECT @ImportedBy = @UserCode
				GOTO Update_Record				
			END
			ELSE IF @VINCOUNT > 1
			BEGIN
				--print 'in vincount > 1'
				SELECT @ErrorEncounteredInd = 1
				SELECT @RecordStatus = 'Multiple Matches For VIN'
				--print 'record status = Multiple Matches For VIN'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Record
			END
			ELSE
			BEGIN	
				--print 'in vincount else statement'
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
					--print 'shipped vin count > 0'
					SELECT @ErrorEncounteredInd = 1
					SELECT @RecordStatus = 'Shows As Shipped'
					--print 'record status = Shows As Shipped'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record
				END
				
				--get the size class
				IF DATALENGTH(ISNULL(@Height,'')) > 0
				BEGIN
					SELECT @MetricHeight = ROUND(CONVERT(decimal(19,2),@Height),1)
				END
				ELSE IF DATALENGTH(ISNULL(@VehicleHeight,'')) > 0
				BEGIN
					SELECT @MetricHeight = ROUND(CONVERT(decimal(19,2),@VehicleHeight) * 0.0254,1)
				END
				ELSE
				BEGIN
					SELECT @MetricHeight = 0
				END
				
				IF @MetricHeight = 0
				BEGIN
					SELECT @SizeClass = ''
				END
				ELSE IF @MetricHeight <= 1.7
				BEGIN
					SELECT @SizeClass = 'A'
				END
				ELSE IF @MetricHeight > 1.7 AND @MetricHeight <= 2.2
				BEGIN
					SELECT @SizeClass = 'B'
				END
				ELSE
				BEGIN
					SELECT @SizeClass = 'Z'
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
								
				--get the cubic feet
				IF DATALENGTH(@Volume) > 0
				BEGIN
					SELECT @VehicleCubicFeet = CONVERT(varchar(20),ROUND(CONVERT(decimal(19,2),@Volume)*35.3146667,0))
				END
				ELSE IF DATALENGTH(@VehicleLength) > 0 AND DATALENGTH(@VehicleWidth) >0 AND DATALENGTH(@VehicleHeight) >0
				BEGIN
					SELECT @CubicInches = CONVERT(decimal(19,2),@VehicleLength)*CONVERT(decimal(19,2),@VehicleWidth)*CONVERT(decimal(19,2),@VehicleHeight)
					SELECT @VehicleCubicFeet = CONVERT(varchar(20),ROUND(CONVERT(decimal(19,2),@CubicInches)*.000578703704,0))
				END
				ELSE
				BEGIN
					SELECT @VehicleCubicFeet = ''
				END
				
				IF DATALENGTH(@Weight) > 0
				BEGIN
					SELECT @VehicleWeight = @Weight
				END
				--print 'about to insert'
				--and now do the vehicle
				INSERT INTO AutoportExportVehicles(
					CustomerID,
					VehicleYear,
					Make,
					Model,
					Bodystyle,
					VIN,
					VehicleLength,
					VehicleWidth,
					VehicleHeight,
					VehicleWeight,
					VehicleCubicFeet,
					VehicleStatus,
					DestinationName,
					BookingNumber,
					SizeClass,
					EntryRate,
					EntryRateOverrideInd,
					PerDiemGraceDays,
					PerDiemGraceDaysOverrideInd,
					TotalCharge,
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
					TransshipPortName,
					LastPhysicalDate,
					HasAudioSystemInd,
					HasNavigationSystemInd,
					CustomsApprovedCoverSheetPrintedInd,
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
					@VehicleLength,
					@VehicleWidth,
					@VehicleHeight,
					@VehicleWeight,
					@VehicleCubicFeet,
					'Pending',	--VehicleStatus,
					@DestinationName,
					@BookingNumber,
					@SizeClass,
					@EntryRate,
					0,		--EntryRateOverrideInd,
					@PerDiemGraceDays,
					0,		--PerDiemGraceDaysOverrideInd,
					0,		--TotalCharge,
					0,		--BilledInd,
					@VINDecodedInd,
					'',		--Note,
					'Active',	--RecordStatus,
					@CreationDate,
					'301 Import',	--CreatedBy,
					0,		--CreditHoldInd
					0,		--CustomsApprovalPrintedInd
					@VoyageID,
					0,		--CustomsCoverSheetPrintedInd
					0,		--NoStartInd
					'',		--TransshipPortName
					NULL,		--LastPhysicalDate,
					0,		--HasAudioSystemInd,
					0,		--HasNavigationSystemInd,
					0,		--CustomsApprovedCoverSheetPrintedInd
					0,		--BarCodeLabelPrintedInd
					'',		--VIVTagNumber
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
				
				--print 'insert done'
				IF DATALENGTH(@SizeClass) > 0
				BEGIN
					SELECT @RecordStatus = 'Imported'
					--print 'record status = Imported'
				END
				ELSE
				BEGIN
					SELECT @RecordStatus = 'Imported, Size Class Needed'
					--print 'record status = Imported, Size Class Needed'
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
					'Pending',
					CONVERT(varchar(10),CURRENT_TIMESTAMP,101),
					@CreationDate,
					'301 Import'
				)
				
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error adding Status History Record'
					GOTO Error_Encountered
				END
				
				
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = GetDate()
				SELECT @ImportedBy = @UserCode
			END
			
		END
		ELSE
		BEGIN
			--print 'in invalid action code'
			SELECT @RecordStatus = 'INVALID ACTION CODE'
			--print 'record status = INVALID ACTION CODE'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			SELECT @ErrorEncounteredInd = 1
		END
		
		--update logic here.
		Update_Record:
		--print 'at update record'
		UPDATE ImportACL301
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedBy = @ImportedBy,
		ImportedDate = @ImportedDate
		WHERE ImportACL301ID = @ImportACL301ID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH ImportACL301 into @ImportACL301ID, @ReservationActionCode, @BookingNumber,
			@DischargePortLocationQualifier, @DischargePortLocationIdentifier, @Weight,
			@Volume, @VolumeUnitQualifier, @WeightUnitCode, @ManufacturerCode, @VIN,
			@ModelCode, @Length, @Width, @Height, @MeasurementUnitQualifier, @VesselName,
			@VoyageNumber, @VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength,
			@VehicleWidth, @VehicleHeight, @VINDecodedInd

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ImportACL301
		DEALLOCATE ImportACL301
		--PRINT 'ImportACL301 Error_Encountered =' + STR(@ErrorID)
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
		CLOSE ImportACL301
		DEALLOCATE ImportACL301
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			--PRINT 'ImportACL301 Error_Encountered =' + STR(@ErrorID)
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
