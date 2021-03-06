USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportMercedesInvoice]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportMercedesInvoice] (@BatchID int, @UserCode varchar(20)) 
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@MercedesImportInvoiceID	int,
	@VIN				varchar(17),
	@VINCOUNT			int,
	@Status				varchar(50),
	@CustomerID			int,
	@RecordStatus			varchar(50),
	@VehicleStatus			varchar(20),
	@VehicleID			int,
	@DeliveryYear			int,
	@DeliveryMonth			int,
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@VendorInvoiceNumber		varchar(20),
	@InternalInvoiceNumber		varchar(10),
	@InvoicePrefix			varchar(5),
	@NextInvoiceNumber		int,
	@BergenLocationID		int,
	@BillingID			int,
	@LastVendorInvoiceNumber	int,
	@LastDeliveryYear		int,
	@LastDeliveryMonth		int,
	@ChargeRateOverrideInd		int,
	@ValidatedRate			decimal(19,2),
	@ChargeRate			decimal(19,2),
	@FuelSurcharge			decimal(19,2),
	@PerformanceBonus		decimal(19,2),
	@VehicleChargeRate		decimal(19,2),
	@ProcessingBatchID		int,
	@ErrorEncounteredInd		int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100)

	/************************************************************************
	*	spImportMercedesInvoice						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the MercedesImportInvoice  	*
	*	table and updates it with the vehicle id.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	05/17/2005 CMK    Initial version				*
	*	11/29/2005 CMK    Added code to only invoice delivered vehicles	*
	*	                  and to also include any vehicles that were	*
	*	                  in a previous batch that failed to invoice and*
	*	                  that are now delivered			*
	*																
	*08-30-2018				---Added on 08-30-2018
	************************************************************************/

	SELECT @CustomerID = NULL
	SELECT @ErrorEncounteredInd = 0
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'MercedesCustomerID'
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

	--get the mercedes invoice prefix
	SELECT @InvoicePrefix = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'MercedesInvoicePrefix'
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
	--get the next mercedes invoice number
	SELECT @NextInvoiceNumber = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextMercedesInvoiceNumber'
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
	
	--get the north bergen locationid
	SELECT @BergenLocationID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'BergenLocationID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Bergen LocationID'
		GOTO Error_Encountered2
	END
	IF @BergenLocationID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Bergen LocationID Not Found'
		GOTO Error_Encountered2
	END
	
	--declare the cursor
	DECLARE MercedesInvoiceCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT MII.MercedesImportInvoiceID, V.VIN, MII.InvoiceNumber,
		V.VehicleID, V.BillingID, V.VehicleStatus,
		DATEPART(yyyy,L.DropoffDate) TheYear, DATEPART(mm,L.DropoffDate) TheMonth,
		V.VehicleID, V.ChargeRateOverrideInd, V.ChargeRate,
		MII.BaseRate, MII.FuelSurcharge, MII.PerformanceBonus
		FROM MercedesImportInvoice MII
		LEFT JOIN Vehicle V ON MII.VIN = V.VIN
		AND V.CustomerID = @CustomerID
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		---Added on 08-30-2018
		AND V.PickupLocationID = L.PickupLocationID
		---Added on 08-30-2018
		AND L.FinalLegInd = 1
		WHERE MII.ImportedInd = 0
		--WHERE BatchID = @BatchID
		--AND ImportedInd = 0
		ORDER BY MII.InvoiceNumber, TheYear, TheMonth, MercedesImportInvoiceID

	SELECT @ErrorID = 0
	--SELECT @InternalInvoiceNumber = @InvoicePrefix+REPLICATE('0',4-DATALENGTH(CONVERT(varchar(10),@NextInvoiceNumber)))+CONVERT(varchar(10),@NextInvoiceNumber)
	SELECT @LastVendorInvoiceNumber = ''
	SELECT @LastDeliveryYear = 0
	SELECT @LastDeliveryMonth = 0
	OPEN MercedesInvoiceCursor

	BEGIN TRAN

	FETCH NEXT FROM MercedesInvoiceCursor INTO @MercedesImportInvoiceID, @VIN, @VendorInvoiceNumber, @VehicleID,
		@BillingID, @VehicleStatus, @DeliveryYear, @DeliveryMonth,
		@VehicleID, @ChargeRateOverrideInd, @VehicleChargeRate, @ChargeRate, @FuelSurcharge, @PerformanceBonus
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		
		/*
		IF @LastVendorInvoiceNumber <> @VendorInvoiceNumber AND @LastVendorInvoiceNumber <> ''
		BEGIN
			SELECT @NextInvoiceNumber = @NextInvoiceNumber + 1
		END
		SELECT @LastVendorInvoiceNumber = @VendorInvoiceNumber
		*/
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

		--IF @VINCOUNT > 0
		IF DATALENGTH(@VIN) > 0
		BEGIN
			/*
			--get the vehicle id
			SELECT TOP 1 @VehicleID = V.VehicleID,
			@BillingID = V.BillingID,
			@VehicleStatus = V.VehicleStatus
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			WHERE V.VIN = @VIN
			AND V.CustomerID = @CustomerID
			ORDER BY V.BilledInd, L.PickupDate
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Getting Vehicle Information'
				GOTO Error_Encountered
			END
			*/
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
				--SELECT @VehicleID = NULL
				SELECT @ProcessingBatchID = NULL
				SELECT @RecordStatus = 'VEHICLE NOT DELIVERED'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				SELECT @ErrorEncounteredInd = 1
				GOTO Do_Update
			END
			
			--validate the rate
			IF @ChargeRateOverrideInd = 0
			BEGIN
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
				AND ISNULL(CASE WHEN V.PickupLocationID = @BergenLocationID THEN V.CreationDate ELSE L.PickupDate END,CURRENT_TIMESTAMP) >= CR.StartDate
				AND ISNULL(CASE WHEN V.PickupLocationID = @BergenLocationID THEN V.CreationDate ELSE L.PickupDate END,CURRENT_TIMESTAMP) < DATEADD(day,1,ISNULL(CR.EndDate,CURRENT_TIMESTAMP))
				WHERE V.VehicleID = @VehicleID
				ORDER BY CR.StartDate DESC
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Validating Rate'
					GOTO Error_Encountered
				END
				
				IF ISNULL(@ValidatedRate,-1) = -1
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
				
				/*
				IF @ValidatedRate <> ISNULL(@ChargeRate,0)
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
				*/
				IF @ValidatedRate <> ISNULL(@ChargeRate,0) OR @ValidatedRate <> ISNULL(@VehicleChargeRate,0)
				BEGIN
					--want to override the rate on the vehicle to what was supplied in the file
					UPDATE Vehicle
					SET ChargeRate = @ChargeRate,
					ChargeRateOverrideInd = 1,
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
			
			UPDATE Vehicle
			SET FuelSurcharge = ISNULL(@FuelSurcharge,0),
			MiscellaneousAdditive = ISNULL(@PerformanceBonus,0),
			UpdatedDate = CURRENT_TIMESTAMP,
			UpdatedBy = @UserCode
			WHERE VehicleID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Updating Rate'
				GOTO Error_Encountered
			END
			
			SELECT @ProcessingBatchID = @BatchID
			SELECT @RecordStatus = 'Imported'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = CURRENT_TIMESTAMP
			SELECT @ImportedBy = @UserCode
		END
		ELSE
		BEGIN
			SELECT @VehicleID = NULL
			SELECT @ProcessingBatchID = NULL
			SELECT @RecordStatus = 'VIN NOT FOUND'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			SELECT @ErrorEncounteredInd = 1
			GOTO Do_Update
		END
		--update logic here.
		IF (@LastVendorInvoiceNumber <> @VendorInvoiceNumber AND @LastVendorInvoiceNumber <> '')
		OR (@LastDeliveryYear <> @DeliveryYear AND @LastDeliveryYear <> 0)
		OR (@LastDeliveryMonth <> @DeliveryMonth AND @LastDeliveryMonth <> 0)
		BEGIN
			SELECT @NextInvoiceNumber = @NextInvoiceNumber + 1
		END
		SELECT @LastVendorInvoiceNumber = @VendorInvoiceNumber
		SELECT @LastDeliveryYear = @DeliveryYear
		SELECT @LastDeliveryMonth = @DeliveryMonth
		SELECT @InternalInvoiceNumber = @InvoicePrefix+REPLICATE('0',4-DATALENGTH(CONVERT(varchar(10),@NextInvoiceNumber)))+CONVERT(varchar(10),@NextInvoiceNumber)
	
		Do_Update:
		UPDATE MercedesImportInvoice
		SET VehicleID = @VehicleID,
		FuelSurcharge = ISNULL(FuelSurcharge,0),
		PerformanceBonus = ISNULL(PerformanceBonus,0),
		RecordStatus = @RecordStatus,
		InternalInvoiceNumber = @InternalInvoiceNumber,
		ProcessingBatchID = @ProcessingBatchID,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE MercedesImportInvoiceID = @MercedesImportInvoiceID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Updating Mercedes Import Invoice'
			GOTO Error_Encountered
		END
		
		FETCH NEXT FROM MercedesInvoiceCursor INTO @MercedesImportInvoiceID, @VIN, @VendorInvoiceNumber, @VehicleID,
		@BillingID, @VehicleStatus, @DeliveryYear, @DeliveryMonth,
		@VehicleID, @ChargeRateOverrideInd, @VehicleChargeRate, @ChargeRate, @FuelSurcharge, @PerformanceBonus

	END

	--update the next mercedes invoice number
	UPDATE SettingTable
	SET ValueDescription = CONVERT(varchar(10),@NextInvoiceNumber+1)
	WHERE ValueKey = 'NextMercedesInvoiceNumber'
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
		CLOSE MercedesInvoiceCursor
		DEALLOCATE MercedesInvoiceCursor
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
		CLOSE MercedesInvoiceCursor
		DEALLOCATE MercedesInvoiceCursor
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
