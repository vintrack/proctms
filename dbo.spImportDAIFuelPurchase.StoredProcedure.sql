USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportDAIFuelPurchase]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportDAIFuelPurchase] (@BatchID int, @UserCode varchar(20))
AS
BEGIN
	DECLARE	--DAIFuelPurchaseImport Table Variables
	@DAIFuelPurchaseImportID	int,
	@SiteID				varchar(20),
	@TransactionNumber		varchar(20),
	@TotalPrice			decimal(19,2),
	@ProductCode			varchar(20),
	@UnitPrice			decimal(19,2),
	@Quantity			decimal(19,2),
	@OdometerReading		varchar(20),
	@PumpNumber			varchar(20),
	@PurchaseDate			datetime,
	@UserNumber			varchar(20),
	@CardNumber			varchar(20),
	@TruckNumber			varchar(20),
	@RecordNumber			varchar(20),
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	--Fuel Purchase Table Variables
	@FuelDealerName			varchar(100),
	@TruckID			int,
	@PurchaseState			varchar(2),
	@CreationDate			datetime,
	@CreatedBy			varchar(20),
	--Processing Variables
	@DriverID			int,
	@RunID				int,
	@DuplicateRecordCount		int,
	@ErrorEncounteredInd		int,
	@RecordStatus			varchar(50),
	@Status				varchar(50),
	@ErrorID			int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@RowCount			int,
	@LastClosedAccountingPeriod	datetime,
	@loopcounter			int

	/************************************************************************
	*	spImportDAIFuelPurchase						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the DAIFuelPurchaseImport	*
	*	table and creates new FuelPurchase records.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	11/14/2005 CMK    Initial version				*
	*									*
	************************************************************************/
	
	set nocount on
	
	--get the most recent closed accounting month end date
	SELECT TOP 1 @LastClosedAccountingPeriod = PeriodEndDate
	FROM BillingPeriod
	WHERE PeriodClosedInd = 1
	ORDER BY PeriodEndDate DESC
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@Error
		SELECT @Status = 'Error Getting Last Billing Period'
		GOTO Error_Encountered2
	END
	IF @LastClosedAccountingPeriod IS NULL
	BEGIN
		SELECT @ErrorID = 100000
		SELECT @Status = 'Last Billing Period Is NULL'
		GOTO Error_Encountered2
	END
	
	/* Declare the main processing cursor */
	DECLARE ImportFuelPurchaseCursor INSENSITIVE CURSOR
		FOR
		SELECT DAIFuelPurchaseImportID, REPLICATE('0',4-DATALENGTH(SiteID))+SiteID, TransactionNumber,
		TotalPrice, ProductCode, UnitPrice, Quantity, OdometerReading,
		PumpNumber, PurchaseDate, UserNumber, CardNumber, TruckNumber,
		RecordNumber
		FROM DAIFuelPurchaseImport
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY PurchaseDate, RecordNumber

	SELECT @loopcounter = 0
	OPEN ImportFuelPurchaseCursor
	
	print 'about to begin tran'
	BEGIN TRAN
	
	SELECT @RowCount = @@cursor_rows
	print 'Cursor rows = '+convert(varchar(10),@RowCount)
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = @UserCode
	SELECT @ErrorID = 0
	SELECT @RecordStatus = 'Imported'
	SELECT @FuelDealerName = 'DAI'
	SELECT @ErrorEncounteredInd = 0
	
	FETCH ImportFuelPurchaseCursor INTO @DAIFuelPurchaseImportID, @SiteID, @TransactionNumber,
		@TotalPrice, @ProductCode, @UnitPrice, @Quantity, @OdometerReading, @PumpNumber,
		@PurchaseDate, @UserNumber, @CardNumber, @TruckNumber, @RecordNumber
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @LoopCounter = @LoopCounter + 1
		SELECT @DuplicateRecordCount = 0
		SELECT @ErrorID = 0
		print 'in loop, iteration: '+CONVERT(varchar(10),@LoopCounter)
		SELECT @TruckID = NULL
		--Get the TruckID
		SELECT TOP 1 @TruckID = TruckID
		FROM Truck
		WHERE TruckNumber = CASE WHEN DATALENGTH(@TruckNumber) < 3 THEN REPLICATE('0',3-DATALENGTH(@TruckNumber)) ELSE '' END+@TruckNumber
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Status = 'Error Getting Truck ID'
			GOTO Update_Record
		END
		/*
		--make sure this is not a duplicate
		SELECT @DuplicateRecordCount = COUNT(*)
		FROM DAIFuelPurchaseImport
		WHERE TransactionNumber = @TransactionNumber
		AND PurchaseDate = @PurchaseDate
		AND DAIFuelPurchaseImportID <> @DAIFuelPurchaseImportID
		AND ImportedInd = 1
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Status = 'Error Getting Dupicate Record Count'
			GOTO Update_Record
		END
		IF @DuplicateRecordCount > 0
		BEGIN
			SELECT @ErrorID = 100001
			SELECT @Status = 'Duplicate Record!'
			GOTO Update_Record
		END
		*/
		IF @TruckID IS NULL
		BEGIN
			--See if we can get the truckid from the users card and purchase date
			SELECT @DriverID = NULL
			SELECT TOP 1 @DriverID = DriverID
			FROM Driver
			WHERE (FuelCard1Name = 'DAI' AND FuelCard1Number = @CardNumber)
			OR (FuelCard2Name = 'DAI' AND FuelCard2Number = @CardNumber)
			OR (FuelCard3Name = 'DAI' AND FuelCard3Number = @CardNumber)
			OR (FuelCard4Name = 'DAI' AND FuelCard4Number = @CardNumber)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				SELECT @Status = 'Error Getting DriverID'
				GOTO Update_Record
			END
			IF @DriverID IS NULL
			BEGIN
				SELECT @ErrorID = 100002
				SELECT @Status = 'Driver ID Not Found Using Fuel Card Number'
				GOTO Update_Record
			END
			
			--now that we have the driver id, see if we can find the truck he was using
			SELECT @RunID = NULL
			SELECT TOP 1 @RunID = RunID
			FROM Run
			WHERE DriverID = @DriverID
			AND ((RunStartDate >= @PurchaseDate
			AND RunEndDate <= @PurchaseDate)
			OR CONVERT(varchar(10), CreationDate, 101) = CONVERT(varchar(10),@PurchaseDate,101))
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				SELECT @Status = 'Error Getting RunID'
				GOTO Update_Record
			END
			IF @RunID IS NULL
			BEGIN
				SELECT @ErrorID = 100004
				SELECT @Status = 'RunID Not Found Using DriverID And Purchase Date'
				GOTO Update_Record
			END
			
			SELECT @TruckID = TruckID
			FROM Run
			WHERE RunID = @RunID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				SELECT @Status = 'Error Getting TruckID'
				GOTO Update_Record
			END
			IF @TruckID IS NULL
			BEGIN
				SELECT @ErrorID = 100004
				SELECT @Status = 'TruckID Not Found Using RunID'
				GOTO Update_Record
			END
		END
		
		SELECT @PurchaseState = C.Value1
		FROM Code C
		WHERE CodeType = 'DAIFuelSiteCode'
		AND Code = @SiteID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Status = 'Error Getting Purchase State'
			GOTO Update_Record
		END
		IF @TruckID IS NULL
		BEGIN
			SELECT @ErrorID = 100004
			SELECT @Status = 'State Not Found Using SiteID'
			GOTO Update_Record
		END
		
		IF @PurchaseDate < @LastClosedAccountingPeriod
		BEGIN
			SELECT @PurchaseDate = DATEADD(day,1,@LastClosedAccountingPeriod)
		END
		
		--Insert the Fuel Purchase Record
		INSERT INTO FuelPurchase (
			FuelDealerName,
			TruckID,
			PurchaseDate,
			PurchaseState,
			GallonsPurchased,
			PricePerGallon,
			TotalPurchase,
			InvoiceNumber,
			InvoiceDate,
			CreationDate,
			CreatedBy
		)
		VALUES (
			@FuelDealerName,
			@TruckID,
			@PurchaseDate,
			@PurchaseState,
			@Quantity,
			@UnitPrice,
			@TotalPrice,
			@RecordNumber,
			@PurchaseDate,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Status = 'Error Inserting Fuel Purchase Record'
			GOTO Update_Record
		END
			
		Update_Record:
		print 'entered update record'
		IF @ErrorID = 0
		BEGIN
			print 'error id is 0'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = CURRENT_TIMESTAMP
			SELECT @ImportedBy = @CreatedBy
			SELECT @RecordStatus = 'Imported'
		END
		ELSE
		BEGIN
			print 'error id is: '+convert(varchar(10),@ErrorID)
			SELECT @ErrorEncounteredInd = 1
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			SELECT @RecordStatus = @Status
		END
		--update the import record
		UPDATE DAIFuelPurchaseImport
		SET ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy,
		RecordStatus = @RecordStatus
		WHERE DAIFuelPurchaseImportID = @DAIFuelPurchaseImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Status = 'Error Updating Import Record'
			GOTO Error_Encountered
		END
		
		FETCH ImportFuelPurchaseCursor INTO @DAIFuelPurchaseImportID, @SiteID, @TransactionNumber,
			@TotalPrice, @ProductCode, @UnitPrice, @Quantity, @OdometerReading, @PumpNumber,
			@PurchaseDate, @UserNumber, @CardNumber, @TruckNumber, @RecordNumber
	END
	SELECT @ErrorID = 0 --if we got to this point this should be fine
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ImportFuelPurchaseCursor
		DEALLOCATE ImportFuelPurchaseCursor
		IF @ErrorEncounteredInd = 0
		BEGIN
			SELECT @ReturnCode = 0
			SELECT @ReturnMessage = 'Processing Completed Successfully'
		END
		ELSE
		BEGIN
			SELECT @ReturnCode = 0
			SELECT @ReturnMessage = 'Processing Completed, But With Errors'
		END
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ImportFuelPurchaseCursor
		DEALLOCATE ImportFuelPurchaseCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END
	
	Error_Encountered2:
	IF @ErrorID = 0
	BEGIN
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
