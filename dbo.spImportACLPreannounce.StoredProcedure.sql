USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportACLPreannounce]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportACLPreannounce] (@BatchID int, @UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@ErrorEncountered		varchar(5000),
	@loopcounter			int,
	--ACL Preannounce variables
	@ImportACLPreannounceID		int,
	@ShipmentNumber			varchar(20),
	@VoyageNumber			varchar(20),
	@VesselName			varchar(20),
	@ShipmentPOD			varchar(50),
	@VIN				varchar(17),
	@VehicleYear			varchar(6),
	@Make				varchar(50),
	@Model				varchar(50),
	@Bodystyle			varchar(50),
	@VehicleLength			varchar(10),
	@VehicleWidth			varchar(10),
	@VehicleHeight			varchar(10),
	@VehicleWeight			varchar(10),
	@VehicleCubicFeet		varchar(10),
	@VINDecodedInd			int,
	--processing variables
	@BookingNumber			varchar(20),
	@MetricHeight			decimal(19,2),
	@CubicInches			decimal(19,2),
	@VoyageID			int,
	@SizeClass			varchar(20),
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
	*	spImportACLPreannounce							*
	*										*
	*	Description								*
	*	-----------								*
	*	This procedure takes the data from the ImportACLPreannounce		*
	*	table and creates the new autoport import vehicle records.		*
	*										*
	*	Change History								*
	*	--------------								*
	*	Date       Init's Description						*
	*	---------- ------ ----------------------------------------		*
	*	04/21/2009 CMK    Initial version					*
	*										*
	********************************************************************************/
	
	DECLARE ImportACLPreannounce CURSOR
		LOCAL FORWARD_ONLY STATIC READ_ONLY
		FOR
			SELECT ImportACLPreannounceID, ShipmentNumber, VoyageNumber, VesselName,
			ShipmentPOD, VIN, VehicleYear, Make, Model, Bodystyle, VehicleLength,
			VehicleWidth, VehicleHeight, VehicleWeight, VehicleCubicFeet, VINDecodedInd
			FROM ImportACLPreannounce
			WHERE BatchID = @BatchID
			ORDER BY ImportACLPreannounceID
	
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = @UserCode
	SELECT @ErrorEncounteredInd = 0
	
	OPEN ImportACLPreannounce
	
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

	FETCH ImportACLPreannounce into @ImportACLPreannounceID, @ShipmentNumber, @VoyageNumber, @VesselName,
		@ShipmentPOD, @VIN, @VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength,
		@VehicleWidth, @VehicleHeight, @VehicleWeight, @VehicleCubicFeet, @VINDecodedInd
	

	
	
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @RecordStatus = 'Imported'
		
		SELECT @DestinationName = ''
		SELECT @DestinationName = CodeDescription
		FROM Code
		WHERE CodeType = 'ScheduleKCode'
		AND (CodeDescription = @ShipmentPOD
		OR ISNULL(Value1,'') = @ShipmentPOD)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Voyage ID'
			GOTO Error_Encountered
		END
			
		IF DATALENGTH(@DestinationName) < 1
		BEGIN
			SELECT @DestinationName = ''
			SELECT @RecordStatus = 'IMPORTED, DEST NEEDED.'
			SELECT @ErrorEncounteredInd = 1
		END
		
		--PRINT 'Inside the while loop first time through'
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
				
		IF @VINCOUNT = 1
		BEGIN
			SELECT @ErrorEncounteredInd = 1
			SELECT @RecordStatus = 'VEHICLE ALREADY EXISTS'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
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
				
			--get the size class
			IF DATALENGTH(ISNULL(@VehicleHeight,'')) > 0
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
			
			SELECT @BookingNumber = REPLACE(@ShipmentNumber,'-','')
								
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
				@CreatedBy,
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
	
			IF DATALENGTH(@SizeClass) > 0
			BEGIN
				SELECT @RecordStatus = 'Imported'
			END
			ELSE
			BEGIN
				SELECT @RecordStatus = 'Imported, Size Class Needed'
			END
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = GetDate()
			SELECT @ImportedBy = @UserCode
		END
			
		--update logic here.
		Update_Record:
		UPDATE ImportACLPreannounce
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedBy = @ImportedBy,
		ImportedDate = @ImportedDate
		WHERE ImportACLPreannounceID = @ImportACLPreannounceID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH ImportACLPreannounce into @ImportACLPreannounceID, @ShipmentNumber, @VoyageNumber, @VesselName,
			@ShipmentPOD, @VIN, @VehicleYear, @Make, @Model, @Bodystyle, @VehicleLength, @VehicleWidth,
			@VehicleHeight, @VehicleWeight, @VehicleCubicFeet, @VINDecodedInd

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ImportACLPreannounce
		DEALLOCATE ImportACLPreannounce
		--PRINT 'ImportACLPreannounce Error_Encountered =' + STR(@ErrorID)
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
		CLOSE ImportACLPreannounce
		DEALLOCATE ImportACLPreannounce
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			--PRINT 'ImportACLPreannounce Error_Encountered =' + STR(@ErrorID)
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
