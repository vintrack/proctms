USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportComdataFuelPurchase]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportComdataFuelPurchase] (@BatchID int, @UserCode varchar(20))
AS
BEGIN
	DECLARE	--CondataFuelPurchaseImport Table Variables
	@ComdataFuelPurchaseImportID		int,
	@RecordIdentifier			varchar(2),
	@CompanyAccountingCode			varchar(5),
	@Filler					varchar(4),
	@TransactionDate			varchar(6),
	@TransactionNumberIndicator		varchar(1),
	@TransactionDateDay			varchar(2),
	@TransactionNumber			varchar(5),
	@UnitNumber				varchar(6),
	@TruckStopCode				varchar(5),
	@TruckStopName				varchar(15),
	@TruckStopCity				varchar(12),
	@TruckStopState				varchar(2),
	@TruckStopInvoiceNumber			varchar(8),
	@TransactionTime			varchar(4),
	@TotalAmountDue				varchar(6),
	@FeesForFuelOilProduct			varchar(4),
	@CheaperFuelAvailabilityFlag		varchar(1),
	@ServiceUsed				varchar(1),
	@NumberOfTractorGallons			varchar(5),
	@TractorFuelPricePerGallon		varchar(5),
	@CostOfTractorFuel			varchar(5),
	@NumberOfReeferGallons			varchar(5),
	@ReeferPricePerGallon			varchar(5),
	@CostOfReeferFuel			varchar(5),
	@NumberOfQuartsOfOil			varchar(2),
	@TotalCostOfOil				varchar(4),
	@TractorFuelBillingFlag			varchar(1),
	@ReeferFuelBillingFlag			varchar(1),
	@OilBillingFlag				varchar(1),
	@HeaderIdentifier			varchar(2),
	@CashAdvanceAmount			varchar(5),
	@ChargesForCashAdvance			varchar(4),
	@DriverName				varchar(12),
	@TripNumber				varchar(10),
	@ConversionRate				varchar(10),
	@HubometerReading			varchar(6),
	@YearToDateMPG				varchar(4),
	@MPGForThisFillUp			varchar(4),
	@FuelCardIDNumber			varchar(8),
	@BillableCurrency			varchar(1),
	@ComcheckCardNumber			varchar(10),
	@EmployeeNumber				varchar(16),
	@NonBillableItem			varchar(1),
	@NotLimitedNtwkLocationFlag		varchar(1),
	@ProductCode1				varchar(1),
	@ProductAmount1				varchar(7),
	@ProductCode2				varchar(1),
	@ProductAmount2				varchar(7),
	@ProductCode3				varchar(1),
	@ProductAmount3				varchar(7),
	@AllianceSelectOrFocusRebateAmount	varchar(5),
	@AllianceLocationFlag			varchar(1),
	@CashBillingFlag			varchar(1),
	@Product1BillingFlag			varchar(1),
	@Product2BillingFlag			varchar(1),
	@Product3BillingFlag			varchar(1),
	@HeaderIdentifier2			varchar(2),
	@DriversLicenseState			varchar(2),
	@DriversLicenseNumber			varchar(20),
	@PurchaseOrderNumber			varchar(10),
	@TrailerNumber				varchar(10),
	@PreviousHubReading			varchar(6),
	@CancelFlag				varchar(1),
	@DateOfOriginalTransaction		varchar(6),
	@ServiceCenterChainCode			varchar(10),
	@ExpandedFuelCode			varchar(10),
	@RebateIndicator			varchar(1),
	@TrailerHubReading			varchar(7),
	@FocusOrSelectDiscount			varchar(1),
	@BulkFuelFlag				varchar(1),
	@AutomatedTransaction			varchar(1),
	@ServiceCenterBridgeTransaction		varchar(1),
	@Number1FuelGallons			varchar(5),
	@Number1FuelPPG				varchar(5),
	@Number1FuelCost			varchar(5),
	@OtherFuelGallons			varchar(5),
	@OtherFuelPPG				varchar(5),
	@OtherFuelCost				varchar(5),
	@CanadianTaxAmtCdnDollar		varchar(4),
	@CanadianTaxAmtUSDollar			varchar(4),
	@CanadianTaxPaidFlag			varchar(1),
	@ImportedInd				int,
	@ImportedDate				datetime,
	@ImportedBy				varchar(20),
	--Fuel Purchase Table Variables
	@FuelDealerName				varchar(100),
	@TruckID				int,
	@PurchaseState				varchar(2),
	@CreationDate				datetime,
	@CreatedBy				varchar(20),
	--Processing Variables
	@Gallons				decimal(19,2),
	@PricePerGallon				decimal(19,4),
	@TotalPurchase				decimal(19,2),
	@PurchaseDate				datetime,
	@PurchaseDateString			varchar(20),
	@ErrorEncounteredInd			int,
	@RecordStatus				varchar(50),
	@Status					varchar(50),
	@ErrorID				int,
	@ReturnCode				int,
	@ReturnMessage				varchar(100),
	@RowCount				int,
	@LastClosedAccountingPeriod		datetime,
	@loopcounter				int

	/************************************************************************
	*	spImportComdataFuelPurchase					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the ComdataFuelPurchaseImport*
	*	table and creates new FuelPurchase records.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	11/16/2005 CMK    Initial version				*
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
		SELECT ComdataFuelPurchaseImportID,RecordIdentifier,CompanyAccountingCode,Filler,
		TransactionDate,TransactionNumberIndicator,TransactionDateDay,TransactionNumber,
		UnitNumber,TruckStopCode,TruckStopName,TruckStopCity,TruckStopState,
		TruckStopInvoiceNumber,TransactionTime,TotalAmountDue,FeesForFuelOilProduct,
		CheaperFuelAvailabilityFlag,ServiceUsed,NumberOfTractorGallons,
		TractorFuelPricePerGallon,CostOfTractorFuel,NumberOfReeferGallons,
		ReeferPricePerGallon,CostOfReeferFuel,NumberOfQuartsOfOil,TotalCostOfOil,
		TractorFuelBillingFlag,ReeferFuelBillingFlag,OilBillingFlag,HeaderIdentifier,
		CashAdvanceAmount,ChargesForCashAdvance,DriverName,TripNumber,ConversionRate,
		HubometerReading,YearToDateMPG,MPGForThisFillUp,FuelCardIDNumber,BillableCurrency,
		ComcheckCardNumber,EmployeeNumber,NonBillableItem,NotLimitedNtwkLocationFlag,
		ProductCode1,ProductAmount1,ProductCode2,ProductAmount2,ProductCode3,ProductAmount3,
		AllianceSelectOrFocusRebateAmount,AllianceLocationFlag,CashBillingFlag,
		Product1BillingFlag,Product2BillingFlag,Product3BillingFlag,HeaderIdentifier2,
		DriversLicenseState,DriversLicenseNumber,PurchaseOrderNumber,TrailerNumber,
		PreviousHubReading,CancelFlag,DateOfOriginalTransaction,ServiceCenterChainCode,
		ExpandedFuelCode,RebateIndicator,TrailerHubReading,FocusOrSelectDiscount,
		BulkFuelFlag,AutomatedTransaction,ServiceCenterBridgeTransaction,Number1FuelGallons,
		Number1FuelPPG,Number1FuelCost,OtherFuelGallons,OtherFuelPPG,OtherFuelCost,
		CanadianTaxAmtCdnDollar,CanadianTaxAmtUSDollar,CanadianTaxPaidFlag
		FROM ComdataFuelPurchaseImport
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY TransactionDate, TruckStopInvoiceNumber
		
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
	SELECT @FuelDealerName = 'Comdata'
	SELECT @ErrorEncounteredInd = 0
		
	FETCH ImportFuelPurchaseCursor INTO @ComdataFuelPurchaseImportID,@RecordIdentifier,
	@CompanyAccountingCode,@Filler,@TransactionDate,@TransactionNumberIndicator,
	@TransactionDateDay,@TransactionNumber,@UnitNumber,@TruckStopCode,@TruckStopName,
	@TruckStopCity,@TruckStopState,@TruckStopInvoiceNumber,@TransactionTime,@TotalAmountDue,
	@FeesForFuelOilProduct,@CheaperFuelAvailabilityFlag,@ServiceUsed,@NumberOfTractorGallons,
	@TractorFuelPricePerGallon,@CostOfTractorFuel,@NumberOfReeferGallons,@ReeferPricePerGallon,
	@CostOfReeferFuel,@NumberOfQuartsOfOil,@TotalCostOfOil,@TractorFuelBillingFlag,
	@ReeferFuelBillingFlag,@OilBillingFlag,@HeaderIdentifier,@CashAdvanceAmount,
	@ChargesForCashAdvance,@DriverName,@TripNumber,@ConversionRate,@HubometerReading,
	@YearToDateMPG,@MPGForThisFillUp,@FuelCardIDNumber,@BillableCurrency,@ComcheckCardNumber,
	@EmployeeNumber,@NonBillableItem,@NotLimitedNtwkLocationFlag,@ProductCode1,@ProductAmount1,
	@ProductCode2,@ProductAmount2,@ProductCode3,@ProductAmount3,
	@AllianceSelectOrFocusRebateAmount,@AllianceLocationFlag,@CashBillingFlag,
	@Product1BillingFlag,@Product2BillingFlag,@Product3BillingFlag,@HeaderIdentifier2,
	@DriversLicenseState,@DriversLicenseNumber,@PurchaseOrderNumber,@TrailerNumber,
	@PreviousHubReading,@CancelFlag,@DateOfOriginalTransaction,@ServiceCenterChainCode,
	@ExpandedFuelCode,@RebateIndicator,@TrailerHubReading,@FocusOrSelectDiscount,@BulkFuelFlag,
	@AutomatedTransaction,@ServiceCenterBridgeTransaction,@Number1FuelGallons,@Number1FuelPPG,
	@Number1FuelCost,@OtherFuelGallons,@OtherFuelPPG,@OtherFuelCost,@CanadianTaxAmtCdnDollar,
	@CanadianTaxAmtUSDollar,@CanadianTaxPaidFlag

	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @LoopCounter = @LoopCounter + 1
		SELECT @ErrorID = 0
		print 'in loop, iteration: '+CONVERT(varchar(10),@LoopCounter)
		SELECT @TruckID = NULL
		--Get the TruckID
		SELECT TOP 1 @TruckID = TruckID
		FROM Truck
		WHERE TruckNumber = REPLICATE('0',3-DATALENGTH(@UnitNumber))+@UnitNumber
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Status = 'Error Getting Truck ID'
			GOTO Update_Record
		END
		IF @TruckID IS NULL
		BEGIN
			SELECT @ErrorID = 100001
			SELECT @Status = 'TruckID Not Found Using RunID'
			GOTO Update_Record
		END
		
		--get the purchase date into a timestamp format
		SELECT @PurchaseDateString = SUBSTRING(@TransactionDate,3,2)
		+'/'+SUBSTRING(@TransactionDate,5,2)
		+'/'+SUBSTRING(@TransactionDate,1,2)
		+' '+SUBSTRING(@TransactionTime,1,2)
		+':'+SUBSTRING(@TransactionTime,3,2)
		
		SELECT @PurchaseDate = @PurchaseDateString
		
		IF @PurchaseDate < @LastClosedAccountingPeriod
		BEGIN
			SELECT @PurchaseDate = DATEADD(day,1,@LastClosedAccountingPeriod)
		END
		
		--convert the units and prices to numbers
		SELECT @Gallons = CONVERT(decimal(19,2),@NumberOfTractorGallons)/100
		SELECT @PricePerGallon = CONVERT(decimal(19,4),@TractorFuelPricePerGallon)/1000
		SELECT @TotalPurchase = CONVERT(decimal(19,2),@CostOfTractorFuel)/100
			
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
			@TruckStopState,
			@Gallons,
			@PricePerGallon,
			@TotalPurchase,
			@TruckStopInvoiceNumber,
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
		UPDATE ComdataFuelPurchaseImport
		SET ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy,
		RecordStatus = @RecordStatus
		WHERE ComdataFuelPurchaseImportID = @ComdataFuelPurchaseImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Status = 'Error Updating Import Record'
			GOTO Error_Encountered
		END
		
		FETCH ImportFuelPurchaseCursor INTO @ComdataFuelPurchaseImportID,@RecordIdentifier,
		@CompanyAccountingCode,@Filler,@TransactionDate,@TransactionNumberIndicator,
		@TransactionDateDay,@TransactionNumber,@UnitNumber,@TruckStopCode,@TruckStopName,
		@TruckStopCity,@TruckStopState,@TruckStopInvoiceNumber,@TransactionTime,@TotalAmountDue,
		@FeesForFuelOilProduct,@CheaperFuelAvailabilityFlag,@ServiceUsed,@NumberOfTractorGallons,
		@TractorFuelPricePerGallon,@CostOfTractorFuel,@NumberOfReeferGallons,@ReeferPricePerGallon,
		@CostOfReeferFuel,@NumberOfQuartsOfOil,@TotalCostOfOil,@TractorFuelBillingFlag,
		@ReeferFuelBillingFlag,@OilBillingFlag,@HeaderIdentifier,@CashAdvanceAmount,
		@ChargesForCashAdvance,@DriverName,@TripNumber,@ConversionRate,@HubometerReading,
		@YearToDateMPG,@MPGForThisFillUp,@FuelCardIDNumber,@BillableCurrency,@ComcheckCardNumber,
		@EmployeeNumber,@NonBillableItem,@NotLimitedNtwkLocationFlag,@ProductCode1,@ProductAmount1,
		@ProductCode2,@ProductAmount2,@ProductCode3,@ProductAmount3,
		@AllianceSelectOrFocusRebateAmount,@AllianceLocationFlag,@CashBillingFlag,
		@Product1BillingFlag,@Product2BillingFlag,@Product3BillingFlag,@HeaderIdentifier2,
		@DriversLicenseState,@DriversLicenseNumber,@PurchaseOrderNumber,@TrailerNumber,
		@PreviousHubReading,@CancelFlag,@DateOfOriginalTransaction,@ServiceCenterChainCode,
		@ExpandedFuelCode,@RebateIndicator,@TrailerHubReading,@FocusOrSelectDiscount,@BulkFuelFlag,
		@AutomatedTransaction,@ServiceCenterBridgeTransaction,@Number1FuelGallons,@Number1FuelPPG,
		@Number1FuelCost,@OtherFuelGallons,@OtherFuelPPG,@OtherFuelCost,@CanadianTaxAmtCdnDollar,
		@CanadianTaxAmtUSDollar,@CanadianTaxPaidFlag
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
