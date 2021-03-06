USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportGM820]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportGM820] (@BatchID int, @UserCode varchar(20)) 
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	@GMImport820ID		int,
	@VIN			varchar(17),
	@PaymentType		varchar(3),
	@PaymentAmount		decimal(19,2),
	@VINCOUNT		int,
	@Status			varchar(50),
	@RecordStatus		varchar (50),
	@VehicleID		int,
	@GMCustomerID		int,
	@GMExportDeliveryID	int,
	@InternalInvoiceNumber	varchar(20),
	@InvoicePrefix		varchar(5),
	@NextInvoiceNumber	int,
	@ImportedInd		int,
	@ImportedDate		datetime,
	@ImportedBy		varchar(20),
	@VehicleStatus		varchar(20),
	@PickupYear		int,
	@PickupMonth		int,
	@LastPickupYear		int,
	@LastPickupMonth	int,
	@BillingID		int,
	@ChargeRate		decimal(19,2),
	@ChargeRateOverrideInd	int,
	@ValidatedRate		decimal(19,2),
	@PreviousVIN		varchar(17),
	@RateMismatchInd	int,
	@ProcessingBatchID	int,
	@ErrorEncounteredInd	int,
	@ReturnCode		int,
	@ReturnMessage		varchar(100)

	/************************************************************************
	*	spImportGM820							*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the GMImport820  		*
	*	table and updates it with the vehicle id.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/18/2008 CMK    Initial version				*
	*									*
	************************************************************************/

	SELECT @ErrorEncounteredInd = 0
	
	SELECT @GMCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'GMCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting GM CustomerID'
		GOTO Error_Encountered2
	END
	IF @GMCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'GM CustomerID Not Found'
		GOTO Error_Encountered2
	END

	--get the gm invoice prefix
	SELECT @InvoicePrefix = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'GMInvoicePrefix'
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
	--get the next gm invoice number
	SELECT @NextInvoiceNumber = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextGMInvoiceNumber'
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
	DECLARE GM820Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT GI.GMImport820ID, V.VIN, V.VehicleID, V.BillingID, V.VehicleStatus,
		DATEPART(yyyy,L.PickupDate) TheYear, DATEPART(mm,L.PickupDate) TheMonth,
		GI.ServiceReferenceIdentification, 
		CONVERT(decimal(19,2),GI.PaymentAmount),
		V.ChargeRate, V.ChargeRateOverrideInd
		FROM GMImport820 GI
		LEFT JOIN Vehicle V ON GI.VehicleReferenceIdentification = V.VIN
		AND V.CustomerID = @GMCustomerID
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.FinalLegInd = 1
		WHERE GI.ImportedInd = 0
		--AND ((SELECT COUNT(*) FROM GMImport820 GI2 WHERE GI2.VehicleReferenceIdentification = GI.VehicleReferenceIdentification) = 3
		--OR V.ReleaseCode = 'SPEC')
		ORDER BY TheYear, TheMonth, V.VIN, CASE WHEN GI.ServiceReferenceIdentification = 'LHV' THEN 0 ELSE 1 END, GMImport820ID

	SELECT @ErrorID = 0
	SELECT @LastPickupYear = 0
	SELECT @LastPickupMonth = 0
	SELECT @PreviousVIN = ''
	SELECT @RateMismatchInd = 0
	
	OPEN GM820Cursor

	BEGIN TRAN

	FETCH NEXT FROM GM820Cursor INTO @GMImport820ID, @VIN, @VehicleID, @BillingID,
		@VehicleStatus, @PickupYear, @PickupMonth, @PaymentType, @PaymentAmount,
		@ChargeRate, @ChargeRateOverrideInd
		
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--PRINT 'VIN = '+@VIN
		
		SELECT @VINCount = 0
		SELECT @VehicleID = NULL
		SELECT @InternalInvoiceNumber = ''
		
		IF @VIN <> @PreviousVIN
		BEGIN
			--PRINT 'resetting rate mismatchind'
			SELECT @RateMismatchInd = 0
		END
		
		--PRINT 'ratemismatchind = '+convert(varchar(10),@ratemismatchind)
		
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM Vehicle V
		WHERE V.VIN = @VIN
		AND BilledInd = 0
		AND CustomerID = @GMCustomerID
		IF @@Error <> 0
		BEGIN
			SELECT @VehicleID = NULL
			SELECT @RecordStatus = 'ERROR GETTING VIN COUNT'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			SELECT @ErrorEncounteredInd = 1
			GOTO Do_Update
		END

		IF @VINCOUNT = 1
		BEGIN
			--PRINT 'In VINCOUNT = 1'
			--PRINT 'paymenttype = '+@paymenttype
			--get the vehicle id
			SELECT TOP 1 @VehicleID = VehicleID
			FROM Vehicle V
			WHERE V.VIN = @VIN
			AND BilledInd = 0
			AND CustomerID = @GMCustomerID
			ORDER BY V.VehicleID DESC --assuming most recent vin
			IF @@Error <> 0
			BEGIN
				SELECT @VehicleID = NULL
				SELECT @RecordStatus = 'ERROR GETTING VEHICLE ID'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				SELECT @ErrorEncounteredInd = 1
				GOTO Do_Update
			END
			
			--validate the rate
			IF @ChargeRateOverrideInd = 0
			BEGIN
				--PRINT 'in validate rate'
				
				SELECT @ValidatedRate = NULL
				
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
				
				--PRINT 'validated rate = '+convert(varchar(10),@Validatedrate)
				
				IF ISNULL(@ValidatedRate,-1) = -1
				BEGIN
					--SELECT @VehicleID = NULL
					SELECT @ProcessingBatchID = NULL
					SELECT @RecordStatus = 'NEED RATE'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					SELECT @ErrorEncounteredInd = 1
					GOTO Do_Update
				END
			END
							
			IF @BillingID > 0
			BEGIN
				--PRINT 'in billingid = 0'
				
				--SELECT @VehicleID = NULL
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
				--PRINT 'in vehiclestatus = delivered'
				
				--SELECT @VehicleID = NULL
				SELECT @ProcessingBatchID = NULL
				SELECT @RecordStatus = 'VEHICLE NOT DELIVERED'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				SELECT @ErrorEncounteredInd = 1
				GOTO Do_Update
			END
			
			IF @PaymentType = 'LHV'
			BEGIN
				--PRINT 'In paymenttype = lhv'
				
				IF @ValidatedRate <> ISNULL(@ChargeRate,0) AND @ChargeRateOverrideInd = 0
				BEGIN
					--PRINT 'In validatedrate <> chargerate'
					
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
				IF @PaymentAmount <> @ChargeRate AND @ChargeRateOverrideInd = 0
				BEGIN
					--PRINT 'In paymentamount <> chargerate'
					SELECT @RateMismatchInd = 1
				END				
			END
			ELSE IF @PaymentType = 'INS' AND @RateMismatchInd = 0
			BEGIN
				--PRINT 'In update misc additive'
				
				UPDATE Vehicle
				SET MiscellaneousAdditive = @PaymentAmount
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @ErrorEncounteredInd = 1
				END
			END
			ELSE IF @PaymentType = 'SUR' AND @RateMismatchInd = 0
			BEGIN
				--PRINT 'In update fuel surcharge'
				UPDATE Vehicle
				SET FuelSurcharge = @PaymentAmount
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @ErrorEncounteredInd = 1
				END
			END
			
			IF @RateMismatchInd = 0
			BEGIN
				--PRINT 'In ratemismatch = 0'
				
				SELECT @ProcessingBatchID = @BatchID
				SELECT @RecordStatus = 'Imported'
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = CURRENT_TIMESTAMP
				SELECT @ImportedBy = @UserCode
				SELECT @InternalInvoiceNumber = @InvoicePrefix+REPLICATE('0',4-DATALENGTH(CONVERT(varchar(10),@NextInvoiceNumber)))+CONVERT(varchar(10),@NextInvoiceNumber)
			END
			ELSE
			BEGIN
				--PRINT 'In ratemismatch = 1'
				
				--SELECT @VehicleID = NULL
				SELECT @RecordStatus = CASE WHEN @PaymentType = 'LHV' THEN 'RATE MISMATCH' ELSE 'LHV NOT APPROVED' END
				SELECT @ProcessingBatchID = NULL
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				SELECT @ErrorEncounteredInd = 1
				GOTO Do_Update
			END
			
		END
		ELSE IF @VINCOUNT > 1
		BEGIN
			SELECT @VehicleID = NULL
			SELECT @RecordStatus = 'MULTIPLE MATCHES FOR VIN'
			SELECT @ProcessingBatchID = NULL
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			SELECT @ErrorEncounteredInd = 1
			GOTO Do_Update
		END
		ELSE IF @VINCOUNT = 0
		BEGIN
			SELECT @VehicleID = NULL
			SELECT @RecordStatus = 'VIN NOT FOUND'
			SELECT @ProcessingBatchID = NULL
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			SELECT @ErrorEncounteredInd = 1
			GOTO Do_Update
		END
		
		IF (@LastPickupYear <> @PickupYear AND @LastPickupYear <> 0)
		OR (@LastPickupMonth <> @PickupMonth AND @LastPickupMonth <> 0)
		BEGIN
			SELECT @NextInvoiceNumber = @NextInvoiceNumber + 1
		END
		SELECT @LastPickupYear = @PickupYear
		SELECT @LastPickupMonth = @PickupMonth
		
		
		--update logic here.
		Do_Update:
		UPDATE GMImport820
		SET VehicleID = @VehicleID,
		InternalInvoiceNumber = @InternalInvoiceNumber,
		RecordStatus = @RecordStatus,
		ProcessingBatchID = @ProcessingBatchID,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE GMImport820ID = @GMImport820ID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @ErrorEncounteredInd = 1
		END
		
		SELECT @PreviousVIN = @VIN
		
		FETCH NEXT FROM GM820Cursor INTO @GMImport820ID, @VIN, @VehicleID, @BillingID,
			@VehicleStatus, @PickupYear, @PickupMonth, @PaymentType, @PaymentAmount,
			@ChargeRate, @ChargeRateOverrideInd
	END
	
	--update the next gm invoice number
	UPDATE SettingTable
	SET ValueDescription = CONVERT(varchar(10),@NextInvoiceNumber+1)
	WHERE ValueKey = 'NextGMInvoiceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting Next Invoice Number'
		GOTO Error_Encountered
	END

	Error_Encountered:
	IF @ErrorEncounteredInd = 0
	BEGIN
		COMMIT TRAN
		CLOSE GM820Cursor
		DEALLOCATE GM820Cursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		COMMIT TRAN
		CLOSE GM820Cursor
		DEALLOCATE GM820Cursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed, But With Errors'
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
