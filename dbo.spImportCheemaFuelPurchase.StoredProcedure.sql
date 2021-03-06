USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportCheemaFuelPurchase]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportCheemaFuelPurchase] (@BatchID int, @UserCode varchar(20))
AS
BEGIN
	DECLARE	--CheemaFuelPurchaseImport Table Variables
	@CheemaFuelPurchaseImportID	int,
	@PurchaseDate			datetime,
	@TruckNumber			varchar(10),
	@SlipNumber			varchar(10),
	@Gallons			decimal(19,4),
	@PricePerGallon			decimal(19,2),
	@TotalPurchase			decimal(19,2),
	--Code Table Variables
	@FuelDealerName			varchar(100),
	@TruckID			int,
	@PurchaseState			varchar(2),
	@CreationDate			datetime,
	@CreatedBy			varchar(20),
	--Processing Variables
	@RecordStatus			varchar(50),
	@ErrorEncounteredInd		int,
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@Status				varchar(50),
	@ErrorID			int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@RowCount			int,
	@LastClosedAccountingPeriod	datetime,
	@loopcounter			int

	/************************************************************************
	*	spImportCheemaFuelPurchase					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the CheemaFuelPurchaseImport	*
	*	table and creates new FuelPurchase records.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	06/04/2010 CMK    Initial version				*
	*									*
	************************************************************************/
	
	set nocount on
	print 'about to get last closed accounting period'
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
	print 'last closed accounting period = ' + convert(varchar(10),@LastClosedAccountingPeriod,101)
	/* Declare the main processing cursor */
	print 'getting cursor'
	DECLARE ImportFuelPurchaseCursor INSENSITIVE CURSOR
		FOR
		SELECT CheemaFuelPurchaseImportID, PurchaseDate, TruckNumber, SlipNumber, Gallons,
		PricePerGallon, TotalPurchase
		FROM CheemaFuelPurchaseImport
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY PurchaseDate, SlipNumber

	SELECT @loopcounter = 0
	OPEN ImportFuelPurchaseCursor
	
	BEGIN TRAN
	
	SELECT @RowCount = @@cursor_rows
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = @UserCode
	SELECT @ErrorID = 0
	SELECT @FuelDealerName = 'Cheema Oil'
	SELECT @PurchaseState = 'NJ'
	SELECT @ErrorEncounteredInd = 0
	
	FETCH ImportFuelPurchaseCursor INTO @CheemaFuelPurchaseImportID, @PurchaseDate, @TruckNumber, @SlipNumber, @Gallons,
		@PricePerGallon, @TotalPurchase
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		print 'in loop'
		SELECT @TruckID = NULL
		SELECT @ErrorID = 0
		--Get the TruckID
		print 'getting truck id'
		SELECT TOP 1 @TruckID = TruckID
		FROM Truck
		WHERE TruckNumber = CASE WHEN DATALENGTH(@TruckNumber) < 3 THEN REPLICATE('0',3-DATALENGTH(@TruckNumber)) ELSE '' END+@TruckNumber
		IF @@Error <> 0
		BEGIN
			print 'error getting truck id'
			SELECT @ErrorID = @@Error
			SELECT @ErrorEncounteredInd = 1
			SELECT @RecordStatus = 'Error Getting Truck ID'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			GOTO Update_Record
		END
		
		IF @TruckID IS NULL
		BEGIN
			print 'truck id is null'
			--SELECT @ErrorID = 100001
			SELECT @ErrorEncounteredInd = 1
			SELECT @RecordStatus = 'Truck ID Not Found'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			GOTO Update_Record
		END
		
		IF @PurchaseDate <= @LastClosedAccountingPeriod
		BEGIN
			print 'changing purchases date'
			SELECT @PurchaseDate = DATEADD(day,1,@LastClosedAccountingPeriod)
		END
		print 'about to insert'
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
			@Gallons,
			@PricePerGallon,
			@TotalPurchase,
			@SlipNumber,
			@PurchaseDate,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			print 'insert error'
			SELECT @ErrorID = @@Error
			SELECT @Status = 'Error Inserting Fuel Purchase Record'
			GOTO Update_Record
		END
			
		--update the import record
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
		
		Update_Record:
		print 'in update record'
		UPDATE CheemaFuelPurchaseImport
		SET ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy,
		RecordStatus = @RecordStatus
		WHERE CheemaFuelPurchaseImportID = @CheemaFuelPurchaseImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Status = 'Error Updating Import Record'
			GOTO Error_Encountered
		END
		
		FETCH ImportFuelPurchaseCursor INTO @CheemaFuelPurchaseImportID, @PurchaseDate, @TruckNumber, @SlipNumber, @Gallons,
			@PricePerGallon, @TotalPurchase
	END
	SELECT @ErrorID = 0 --if we got to this point this should be fine
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		print 'error id = 0'
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
		print 'error id is not 0'
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
