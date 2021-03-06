USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportFordPayment]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportFordPayment] (@BatchID int, @UserCode varchar(20)) 
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@FordImportPaymentID		int,
	@VIN				varchar(17),
	@VINCOUNT			int,
	@Status				varchar(50),
	@CustomerID			int,
	@RecordStatus			varchar(50),
	@VehicleStatus			varchar(20),
	@PayRecordType			varchar(2),
	@VoucherReference		varchar(11),
	@ItemAmount			decimal(19,2),
	@VehicleID			int,
	@DeliveryYear			int,
	@DeliveryMonth			int,
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@InternalInvoiceNumber		varchar(10),
	@InvoicePrefix			varchar(5),
	@NextInvoiceNumber		int,
	@BillingID			int,
	@LastDeliveryYear		int,
	@LastDeliveryMonth		int,
	@ChargeRateOverrideInd		int,
	@ValidatedRate			decimal(19,2),
	@ChargeRate			decimal(19,2),
	@Count				int,
	@ProcessingBatchID		int,
	@ErrorEncounteredInd		int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100)

	/************************************************************************
	*	spImportFordPayment						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the FordImportPayment  	*
	*	table and updates it with the vehicle id.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/14/2016 CMK    Added Code to not return rate mismatch when	*
	*			  ChargeRateOverrideInd set.			*
	*	07/22/2010 CMK    Initial version				*
	*									*
	************************************************************************/

	SELECT @CustomerID = NULL
	SELECT @ErrorEncounteredInd = 0
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'FordCustomerID'
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

	--get the ford invoice prefix
	SELECT @InvoicePrefix = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'FordInvoicePrefix'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Invoice Prefix'
		GOTO Error_Encountered2
	END
	IF @InvoicePrefix IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Invoice Prefix Not Found'
		GOTO Error_Encountered2
	END
	--get the next ford invoice number
	SELECT @NextInvoiceNumber = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextFordInvoiceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Next Invoice Number'
		GOTO Error_Encountered2
	END
	IF @NextInvoiceNumber IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Next Invoice Number Not Found'
		GOTO Error_Encountered2
	END
	
	--declare the cursor
	DECLARE FordPaymentCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT FIP.FordImportPaymentID, FIP.VIN, V.VehicleID,
			V.BillingID, FIP.PayRecordType, FIP.ItemAmount,
			V.VehicleStatus, DATEPART(yyyy,L.DropoffDate) TheYear,
			DATEPART(mm,L.DropoffDate) TheMonth, FIP.VoucherReference
		FROM FordImportPayment FIP
		LEFT JOIN Vehicle V ON FIP.VIN = V.VIN
		AND V.CustomerID = @CustomerID
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.FinalLegInd = 1
		WHERE FIP.ImportedInd = 0
		AND V.BilledInd = 0
		ORDER BY TheYear, TheMonth, FIP.VIN, CASE WHEN FIP.PayRecordType = 'E3' THEN 1 ELSE 0 END, FordImportPaymentID

	SELECT @ErrorID = 0
	SELECT @LastDeliveryYear = 0
	SELECT @LastDeliveryMonth = 0
	OPEN FordPaymentCursor

	BEGIN TRAN

	FETCH NEXT FROM FordPaymentCursor INTO @FordImportPaymentID, @VIN, @VehicleID,
		@BillingID, @PayRecordType, @ItemAmount, @VehicleStatus, @DeliveryYear, @DeliveryMonth, @VoucherReference
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @InternalInvoiceNumber = ''
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM Vehicle
		WHERE VIN = @VIN
		AND CustomerID = @CustomerID
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting VIN Count'
			GOTO Error_Encountered
		END
		--need to get the vehicle id
		IF @VINCOUNT = 0
		BEGIN
			SELECT @VehicleID = NULL
			SELECT @ProcessingBatchID = NULL
			SELECT @RecordStatus = 'VIN NOT FOUND'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = CURRENT_TIMESTAMP
			SELECT @ImportedBy = @UserCode
			SELECT @ErrorEncounteredInd = 1
			GOTO Do_Update
		END
		ELSE IF @VINCOUNT >= 1
		BEGIN
			--need to figure out which vin, if multiples
			SELECT @VINCOUNT = COUNT(*)
			FROM Vehicle
			WHERE VIN = @VIN
			AND CustomerID = @CustomerID
			AND VehicleStatus = 'Delivered'
			AND BilledInd = 0
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Getting VIN Count'
				GOTO Error_Encountered
			END
			
			IF @VINCOUNT = 1
			BEGIN
				SELECT @VehicleID = VehicleID
				FROM Vehicle
				WHERE VIN = @VIN
				AND CustomerID = @CustomerID
				AND VehicleStatus = 'Delivered'
				AND BilledInd = 0
				IF @@ERROR <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Getting VIN Count'
					GOTO Error_Encountered
				END
			END
			ELSE
			BEGIN
				--IF THIS OCCURS MORE CODE WILL HAVE TO BE ADDED TO FIND THE VEHICLE
				--SELECT @VehicleID = NULL
				--SELECT @ProcessingBatchID = NULL
				--SELECT @RecordStatus = 'MULTIPLE MATCHES ON VIN'
				--SELECT @ImportedInd = 1
				--SELECT @ImportedDate = CURRENT_TIMESTAMP
				--SELECT @ImportedBy = @UserCode
				--SELECT @ErrorEncounteredInd = 1
				--GOTO Do_Update
				
				--9/27/12 - CMK - going to assume oldest delivered record is the match
				SELECT TOP 1 @VehicleID = VehicleID
				FROM Vehicle
				WHERE VIN = @VIN
				AND CustomerID = @CustomerID
				AND VehicleStatus = 'Delivered'
				AND BilledInd = 0
				ORDER BY AvailableForPickupDate
				IF @@ERROR <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Getting VIN Count'
					GOTO Error_Encountered
				END
			END
						
			SELECT @BillingID = V.BillingID,
			@VehicleStatus = V.VehicleStatus,
			@DeliveryYear = DATEPART(yyyy,L.DropoffDate),
			@DeliveryMonth = DATEPART(mm,L.DropoffDate),
			@ChargeRateOverrideInd = V.ChargeRateOverrideInd,
			@ChargeRate = ISNULL(V.ChargeRate,0)
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			AND L.FinalLegInd = 1
			WHERE V.VehicleID = @VehicleID
			AND CustomerID = @CustomerID
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Getting Vehicle Details'
				GOTO Error_Encountered
			END
		END
		
		--validate the rate
		IF @ChargeRateOverrideInd = 0
		BEGIN
			SELECT TOP 1 @ValidatedRate = ISNULL(CR.Rate,-1)
			FROM Vehicle V
			LEFT JOIN Customer C ON V.CustomerID = C.CustomerID
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			AND L.LegNumber = 1
			LEFT JOIN ChargeRate CR ON CR.CustomerID = V.CustomerID
			AND CR.StartLocationID = V.PickupLocationID
			AND CR.EndLocationID = V.DropoffLocationID
			AND CR.RateType = CASE WHEN V.SizeClass = 'N/A' THEN 'Size A Rate' WHEN V.SizeClass IS NULL THEN 'Size A Rate' ELSE 'Size '+V.SizeClass+' Rate' END
			AND ISNULL(L.PickupDate,CURRENT_TIMESTAMP) >= CR.StartDate
			AND ISNULL(L.PickupDate,CURRENT_TIMESTAMP) < DATEADD(day,1,ISNULL(CR.EndDate,CURRENT_TIMESTAMP))
			WHERE V.VehicleID = @VehicleID
			ORDER BY CR.StartDate DESC
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Validating Rate'
				GOTO Error_Encountered
			END
			
			IF @ValidatedRate IS NULL OR @ValidatedRate = -1
			BEGIN
				SELECT @VehicleID = NULL
				SELECT @ProcessingBatchID = NULL
				SELECT @RecordStatus = 'NEED RATE'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				SELECT @ErrorEncounteredInd = 1
				GOTO Do_Update
			END
			
			IF @ValidatedRate <> @ChargeRate
			BEGIN
				SELECT @ChargeRate = @ValidatedRate
				
				UPDATE Vehicle
				SET ChargeRate = @ChargeRate,
				UpdatedDate = CURRENT_TIMESTAMP,
				UpdatedBy = @UserCode
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Updating Rate'
					GOTO Error_Encountered
				END
							
				--if this is an outside carrier leg, update the outside carrier pay
				-- by zeroing out the carrier pay the invoicing method will automatically recalculate it
				UPDATE Legs
				SET OutsideCarrierPay = 0,
				UpdatedDate = CURRENT_TIMESTAMP,
				UpdatedBy = @UserCode
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error updating leg records'
					GOTO Error_Encountered
				END
			END
		END
			
		IF @PayRecordType = 'E3'
		BEGIN
			SELECT @Count = COUNT(*)
			FROM FordImportPayment
			WHERE VIN = @VIN
			AND PayRecordType <> 'E3'
			AND RecordStatus = 'Imported'
			AND VoucherReference = @VoucherReference
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error updating leg records'
				GOTO Error_Encountered
			END
			
			IF @Count < 1
			BEGIN
				SELECT @VehicleID = NULL
				SELECT @ProcessingBatchID = NULL
				SELECT @RecordStatus = 'FREIGHT RECORD NOT APPROVED'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				SELECT @ErrorEncounteredInd = 1
				GOTO Do_Update
			END
		END
		ELSE
		BEGIN
			IF (@ItemAmount <> @ChargeRate) and (@ChargeRateOverrideInd = 0) 
			BEGIN
				SELECT @VehicleID = NULL
				SELECT @ProcessingBatchID = NULL
				SELECT @RecordStatus = 'RATE MISMATCH'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				SELECT @ErrorEncounteredInd = 1
				GOTO Do_Update
			END
		END
		
		IF @BillingID > 0
		BEGIN
			SELECT @VehicleID = NULL
			SELECT @ProcessingBatchID = NULL
			SELECT @RecordStatus = 'ALREADY BILLED'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = CURRENT_TIMESTAMP
			SELECT @ImportedBy = @UserCode
			SELECT @ErrorEncounteredInd = 1
			GOTO Do_Update
		END
		IF @VehicleStatus <> 'Delivered'
		BEGIN
			SELECT @ProcessingBatchID = NULL
			SELECT @RecordStatus = 'VEHICLE NOT DELIVERED'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			SELECT @ErrorEncounteredInd = 1
			GOTO Do_Update
		END
		SELECT @ProcessingBatchID = @BatchID
		SELECT @RecordStatus = 'Imported'
		SELECT @ImportedInd = 1
		SELECT @ImportedDate = CURRENT_TIMESTAMP
		SELECT @ImportedBy = @UserCode
		
		--update logic here.
		IF (@LastDeliveryYear <> @DeliveryYear AND @LastDeliveryYear <> 0)
		OR (@LastDeliveryMonth <> @DeliveryMonth AND @LastDeliveryMonth <> 0)
		BEGIN
			SELECT @NextInvoiceNumber = @NextInvoiceNumber + 1
		END
		SELECT @LastDeliveryYear = @DeliveryYear
		SELECT @LastDeliveryMonth = @DeliveryMonth
		SELECT @InternalInvoiceNumber = @InvoicePrefix+REPLICATE('0',4-DATALENGTH(CONVERT(varchar(10),@NextInvoiceNumber)))+CONVERT(varchar(10),@NextInvoiceNumber)
	
		Do_Update:
		UPDATE FordImportPayment
		SET VehicleID = @VehicleID,
		RecordStatus = @RecordStatus,
		InternalInvoiceNumber = @InternalInvoiceNumber,
		ProcessingBatchID = @ProcessingBatchID,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE FordImportPaymentID = @FordImportPaymentID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Updating Ford Payment Import'
			GOTO Error_Encountered
		END
		
		FETCH NEXT FROM FordPaymentCursor INTO @FordImportPaymentID, @VIN, @VehicleID,
			@BillingID, @PayRecordType, @ItemAmount, @VehicleStatus, @DeliveryYear, @DeliveryMonth, @VoucherReference

	END

	--update the next ford invoice number
	UPDATE SettingTable
	SET ValueDescription = CONVERT(varchar(10),@NextInvoiceNumber+1)
	WHERE ValueKey = 'NextFordInvoiceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting Next Invoice Number'
		GOTO Error_Encountered
	END
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE FordPaymentCursor
		DEALLOCATE FordPaymentCursor
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
		CLOSE FordPaymentCursor
		DEALLOCATE FordPaymentCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = 'Error Encountered'
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
