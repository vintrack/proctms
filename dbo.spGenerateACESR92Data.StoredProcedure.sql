USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateACESR92Data]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateACESR92Data] (@CustomerID int, @ACESCustomerCode varchar(5),@CreatedBy varchar(20), @CutoffDate datetime)
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--ExportACESR92 table variables
	@BatchID			int,
	@VehicleID			int,
	@InvoiceNumber			varchar(15),
	@DateOfInvoice			datetime,
	@ACESAccountCode		varchar(4),
	@DamageCode			varchar(6),
	@PIOCode			varchar(4),
	@Origin				varchar(7),
	@DestinationCode		varchar(7),
	@Sign				varchar(1),
	@Amount				varchar(8),
	@CompletionDate			datetime,
	@ShipmentAuthorizationCode	varchar(12),
	@ManualInvoiceFlag		varchar(1),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(20),
	@CreationDate			datetime,
	--processing variables
	@ChargeRate			decimal(19,2),
	@LegsID			int,
	@ChargeRateOverrideInd		int,
	@ValidatedRate			decimal(19,2),
	@OutsideCarrierPaymentMethod	int,
	@OutsideCarrierUnitInd		int,
	@PreviousOutsideCarrierUnitInd	int,
	@VIN				varchar(20),
	@CustomerOf			varchar(20),
	@G95RecordCount			int,
	@InvoicePrefixCode		varchar(10),			
	@NextInvoiceNumber		int,
	@CursorHasRowsInd		int,
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateACESR92Data						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the ACES R92 export data for vehicles	*
	*	(for the specified ACES customer) that have been delivered.	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	02/02/2009 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the next batch id from the setting table
	Select @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextACES'+@ACESCustomerCode+'R92BatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting BatchID'
		GOTO Error_Encountered2
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'BatchID Not Found'
		GOTO Error_Encountered2
	END

	--get the next invoice number from the setting table
	Select @NextInvoiceNumber = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextACES'+@ACESCustomerCode+'InvoiceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Invoice Number'
		GOTO Error_Encountered2
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Next Invoice Number Not Found'
		GOTO Error_Encountered2
	END
	
	SELECT @InvoicePrefixCode = Value2
	FROM Code
	WHERE CodeType = 'ACESCustomerCode'
	AND Code = @ACESCustomerCode
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Invoice Prefix Code'
		GOTO Error_Encountered2
	END
	IF @InvoicePrefixCode IS NULL OR DATALENGTH(@InvoicePrefixCode) < 1
	BEGIN
		SELECT @ErrorID = 100005
		SELECT @Status = 'Invoice Prefix Code Not Found'
		GOTO Error_Encountered2
	END
	
	
	IF @CutoffDate IS NULL
	BEGIN
		SELECT @CutoffDate = CONVERT(varchar(10),CURRENT_TIMESTAMP,101)
	END
	
	--cursor for the pickup records
	DECLARE ACESR92Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, L.LegsID,
		CASE WHEN DATALENGTH(C2.Code) > 0 THEN C2.Code WHEN DATALENGTH(L4.CustomerLocationCode) > 0 THEN L4.CustomerLocationCode ELSE LEFT(L4.Zip,5) END,
		ISNULL(L3.CustomerLocationCode,LEFT(L3.Zip,5)),				
		CONVERT(int,V.ChargeRate*100), L.DropoffDate,V.CustomerIdentification, V.VIN,
		V.ChargeRate, V.ChargeRateOverrideInd, L.OutsideCarrierPaymentMethod, C.CustomerOf,
		CASE WHEN ISNULL(OC.OutsideCarrierID,0) > 0 OR ISNULL(OC2.OutsideCarrierID,0) > 0 THEN 1 ELSE 0 END OCInd
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.FinalLegInd = 1
		LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
		LEFT JOIN Location L3 ON V.DropoffLocationID = L3.LocationID
		LEFT JOIN Location L4 ON V.PickupLocationID = L4.LocationID
		LEFT JOIN Driver D ON L2.DriverID = D.DriverID
		LEFT JOIN OutsideCarrier OC ON L2.OutsideCarrierID = OC.OutsideCarrierID
		LEFT JOIN OutsideCarrier OC2 ON D.OutsideCarrierID = OC2.OutsideCarrierID
		LEFT JOIN Customer C ON V.CustomerID = C.CustomerID
		LEFT JOIN Code C2 ON V.PickupLocationID = CONVERT(int,C2.Value1)
		AND C2.CodeType = 'ACES'+@ACESCustomerCode+'LocationCode'
		WHERE V.CustomerID = @CustomerID
		AND V.BilledInd = 0
		AND V.VehicleStatus = 'Delivered'
		AND (V.ChargeRate > 0 OR (V.ChargeRate = 0 AND V.ChargeRateOverrideInd = 1))
		AND L.DropoffDate < DATEADD(day,1,@CutoffDate)
		AND L.DropoffDate > L.PickupDate
		AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
		AND V.CustomerIdentification IS NOT NULL
		AND V.CustomerIdentification <> ''
		AND V.VehicleID NOT IN (SELECT A.VehicleID FROM ACESExportR92 A WHERE A.VehicleID = V.VehicleID)
		AND V.VehicleID NOT IN (SELECT E.VehicleID FROM ExportICLR92 E WHERE E.VehicleID = V.VehicleID)
		AND (D.OutsideCarrierInd = 0
		OR (D.OutsideCarrierInd = 1 AND (L.OutsideCarrierPay > 0 OR OC2.StandardCommissionRate > 0))
		OR (L.OutsideCarrierID > 0 AND (L.OutsideCarrierPay > 0 OR OC.StandardCommissionRate > 0)))
		--ORDER BY OCInd, V.VehicleID
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN ACESR92Cursor

	BEGIN TRAN
	
	--set the default values
	--SELECT @PreviousOutsideCarrierUnitInd = NULL
	SELECT @ExportedInd = 0
	SELECT @InvoiceNumber = @InvoicePrefixCode+REPLICATE(0,4-DATALENGTH(CONVERT(VARCHAR(20),@NextInvoiceNumber)))+CONVERT(varchar(20),@NextInvoiceNumber)
	IF @CutoffDate IS NOT NULL
	BEGIN
		SELECT @DateOfInvoice = @CutoffDate
	END
	ELSE
	BEGIN
		SELECT @DateOfInvoice = CURRENT_TIMESTAMP
	END
	SELECT @CursorHasRowsInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @DamageCode = ''
	SELECT @PIOCode = ''
	SELECT @Sign = '+'
	SELECT @ManualInvoiceFlag = 'F'
	
	FETCH ACESR92Cursor INTO @VehicleID,@LegsID, @Origin, @DestinationCode, @Amount, @CompletionDate, @ShipmentAuthorizationCode,
		@VIN,@ChargeRate,@ChargeRateOverrideInd,@OutsideCarrierPaymentMethod, @CustomerOf, @OutsideCarrierUnitInd
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		/*
		IF @CustomerOf = 'DAT'
		BEGIN
			IF @PreviousOutsideCarrierUnitInd IS NOT NULL AND @PreviousOutsideCarrierUnitInd <> @OutsideCarrierUnitInd
			BEGIN
				SELECT @NextInvoiceNumber = @NextInvoiceNumber + 1
				SELECT @InvoiceNumber = @InvoicePrefixCode+REPLICATE(0,4-DATALENGTH(CONVERT(VARCHAR(20),@NextInvoiceNumber)))+CONVERT(varchar(20),@NextInvoiceNumber)
			END
		END
		*/
		
		SELECT @CursorHasRowsInd = 1
		--validate the rate
		IF @ChargeRateOverrideInd = 0
		BEGIN
			SELECT TOP 1 @ValidatedRate = ISNULL(CR.Rate,-1)
			FROM Vehicle V
			LEFT JOIN Customer C ON V.CustomerID = C.CustomerID
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			AND L.FinalLegInd = 1
			LEFT JOIN ChargeRate CR ON CR.CustomerID = V.CustomerID
			AND CR.StartLocationID = V.PickupLocationID
			AND CR.EndLocationID = V.DropoffLocationID
			AND CR.RateType = CASE WHEN V.SizeClass = 'N/A' THEN 'Size A Rate' WHEN V.SizeClass IS NULL THEN 'Size A Rate' ELSE 'Size '+V.SizeClass+' Rate' END
			AND ISNULL(L.DropoffDate,CURRENT_TIMESTAMP) >= CR.StartDate
			AND ISNULL(L.DropoffDate,CURRENT_TIMESTAMP) < DATEADD(day,1,ISNULL(CR.EndDate,CURRENT_TIMESTAMP))
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
				GOTO End_Of_Loop
			END
			
			IF @ValidatedRate <> @ChargeRate
			BEGIN
				SELECT @ChargeRate = @ValidatedRate
				SELECT @Amount = CONVERT(int,@ChargeRate*100)
				UPDATE Vehicle
				SET ChargeRate = @ChargeRate,
				UpdatedDate = CURRENT_TIMESTAMP,
				UpdatedBy = @CreatedBy
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Updating Rate'
					GOTO Error_Encountered
				END
				
				--if this is an outside carrier leg, update the outside carrier pay
				IF @OutsideCarrierPaymentMethod = 1
				BEGIN
					-- by zeroing out the carrier pay the invoicing method will automatically recalculate it
					UPDATE Legs
					SET OutsideCarrierPay = 0,
					UpdatedDate = CURRENT_TIMESTAMP,
					UpdatedBy = @CreatedBy
					WHERE LegsID = @LegsID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'Error updating leg records'
						GOTO Error_Encountered
					END
				END
			END
		END
		
		SELECT @G95RecordCount = Count(*)
		FROM ACESImportG95
		WHERE VIN = @VIN
		AND ShipmentAuthorizationCode = @ShipmentAuthorizationCode
		AND ImportedInd = 1
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting G95 Record Count'
			GOTO Error_Encountered
		END
		
		IF @G95RecordCount >= 1
		BEGIN
			SELECT @ACESAccountCode = '1450'
		END
		ELSE
		BEGIN
			SELECT @ACESAccountCode = '1415'
		END
	
		
		INSERT INTO ACESExportR92(
			BatchID,
			CustomerID,
			ACESCustomerCode,
			VehicleID,
			InvoiceNumber,
			DateOfInvoice,
			ACESAccountCode,
			DamageCode,
			PIOCode,
			Origin,
			DestinationCode,
			Sign,
			Amount,
			CompletionDate,
			ShipmentAuthorizationCode,
			ManualInvoiceFlag,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@CustomerID,
			@ACESCustomerCode,
			@VehicleID,
			@InvoiceNumber,
			@DateOfInvoice,
			@ACESAccountCode,
			@DamageCode,
			@PIOCode,
			@Origin,
			@DestinationCode,
			@Sign,
			@Amount,
			@CompletionDate,
			@ShipmentAuthorizationCode,
			@ManualInvoiceFlag,
			@ExportedInd,
			@ExportedDate,
			@ExportedBy,
			@RecordStatus,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating R92 record'
			GOTO Error_Encountered
		END
			
		End_Of_Loop:
		SELECT @PreviousOutsideCarrierUnitInd = @OutsideCarrierUnitInd
		
		FETCH ACESR92Cursor INTO @VehicleID,@LegsID, @Origin, @DestinationCode, @Amount, @CompletionDate, @ShipmentAuthorizationCode,
			@VIN,@ChargeRate,@ChargeRateOverrideInd,@OutsideCarrierPaymentMethod, @CustomerOf, @OutsideCarrierUnitInd

	END --end of loop
	
	--set the next batchid and invoicenumber
	IF @CursorHasRowsInd = 1
	BEGIN
		--set the next batch id in the setting table
		UPDATE SettingTable
		SET ValueDescription = @BatchID+1	
		WHERE ValueKey = 'NextACES'+@ACESCustomerCode+'R92BatchID'
		IF @@ERROR <> 0
		BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Setting BatchID'
				GOTO Error_Encountered
		END
	
		--set the next invoice number in the setting table
		UPDATE SettingTable
		SET ValueDescription = @NextInvoiceNumber+1	
		WHERE ValueKey = 'NextACES'+@ACESCustomerCode+'InvoiceNumber'
		IF @@ERROR <> 0
		BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Setting InvoiceNumber'
				GOTO Error_Encountered
		END
	END
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ACESR92Cursor
		DEALLOCATE ACESR92Cursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ACESR92Cursor
		DEALLOCATE ACESR92Cursor
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
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage, @BatchID AS BatchID
	
	RETURN
END
GO
