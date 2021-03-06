USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateNissanMOTOPSData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateNissanMOTOPSData] (@LocationID int, @Railhead varchar(3), @VPC varchar(2),@CreatedBy varchar(20), @CutoffDate datetime)
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--NissanExportMOTOPS table variables
	@NissanExportMOTOPSID		int,
	@BatchID			int,
	@VehicleID			int,
	@FileDate			datetime,
	@FileBatchID			varchar(2),
	@TransportCode			varchar(5),
	@InvoiceNumber			varchar(9),	
	@InvoiceDate			datetime,
	@D6Number			varchar(6),
	@BOLDate			datetime,
	@YardExitDate			datetime,
	@DeliveryDate			datetime,
	@PROID				varchar(6),
	@PRODate			datetime,
	@NumberOfUnits			varchar(2),
	@FreightRate			varchar(7),
	@FreightAmount			varchar(7),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(50),
	@CreationDate			datetime,
	--processing variables
	@LegsID				int,
	@ChargeRateOverrideInd		int,
	@ValidatedRate			decimal(19,2),
	@OutsideCarrierPaymentMethod	int,
	@ChargeRate			decimal(19,2),
	@SizeClass			varchar(1),
	@NextNissanInvoiceNumber	int,
	@NissanInvoicePrefix		varchar(10),
	@TCode				varchar(10),
	@CustomerID			int,
	@DamageCode			varchar(5),
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateNissanMOTOPSData					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the invoice export data for Nissans	*
	*	that have been delivered.					*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	05/12/2005 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the customer id from the setting table
	Select @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NissanCustomerID'
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

	--get the tcode from the code table
	Select @TCODE = Value1
	FROM Code
	WHERE CodeType = 'NissanCarrierCode'
	AND Code = @Railhead
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting TCode'
		GOTO Error_Encountered2
	END
	IF @TCode IS NULL OR DATALENGTH(@TCode)<1
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'TCode Not Found'
		GOTO Error_Encountered2
	END
	
	--get the next batch id from the setting table
	Select @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextNissan'+@Railhead+'ExportBatchID'
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
	
	--get the invoice prefix from the setting table
	Select @NissanInvoicePrefix = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'NissanInvoicePrefix'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Invoice Prefix'
		GOTO Error_Encountered2
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Invoice Prefix Not Found'
		GOTO Error_Encountered2
	END

	--get the next invoice number from the setting table
	Select @NextNissanInvoiceNumber = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextNissanInvoiceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Invoice Number'
		GOTO Error_Encountered2
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Invoice Number Not Found'
		GOTO Error_Encountered2
	END
	
	IF @CutoffDate IS NULL
	BEGIN
		SELECT @CutoffDate = CONVERT(varchar(10),CURRENT_TIMESTAMP,101)
	END
	
	DECLARE NissanMOTOPSCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, L.LegsID, V.CustomerIdentification,L.DateAvailable,
		L.PickupDate,L.DropoffDate,RIGHT(L2.LoadNumber,6), L.PickupDate,
		CONVERT(varchar(20),CONVERT(int,V.ChargeRate*100)),
		CONVERT(varchar(20),CONVERT(int,V.ChargeRate*100)),
		V.SizeClass, V.ChargeRate, V.ChargeRateOverrideInd, L.OutsideCarrierPaymentMethod
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
		LEFT JOIN Driver D ON L2.DriverID = D.DriverID
		LEFT JOIN OutsideCarrier OC ON L2.OutsideCarrierID = OC.OutsideCarrierID
		LEFT JOIN OutsideCarrier OC2 ON D.OutsideCarrierID = OC2.OutsideCarrierID
		WHERE V.PickupLocationID = @LocationID
		AND L.PickupLocationID = @LocationID
		AND V.CustomerID = @CustomerID
		AND V.VehicleStatus = 'Delivered'
		AND L.PickupDate < DATEADD(day,1,@CutoffDate)
		AND L.DropoffDate > L.PickupDate
		AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
		AND V.CustomerIdentification IS NOT NULL
		AND V.CustomerIdentification <> ''
		AND (V.ChargeRate > 0 OR (V.ChargeRate = 0 AND V.ChargeRateOverrideInd = 1))
		AND V.VehicleID NOT IN (SELECT VehicleID FROM NissanExportMOTOPS)
		AND (D.OutsideCarrierInd = 0
		OR (D.OutsideCarrierInd = 1 AND (L.OutsideCarrierPay > 0 OR OC2.StandardCommissionRate > 0))
		OR (L.OutsideCarrierID > 0 AND (L.OutsideCarrierPay > 0 OR OC.StandardCommissionRate > 0)))
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN NissanMOTOPSCursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextNissan'+@Railhead+'ExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END
	
	--set the next nissan invoice number in the setting table
	UPDATE SettingTable
	SET ValueDescription = @NextNissanInvoiceNumber+1	
	WHERE ValueKey = 'NextNissanInvoiceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting Next Invoice Number'
		GOTO Error_Encountered
	END

	--set the default values
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @FileDate = CURRENT_TIMESTAMP
	SELECT @FileBatchID = '01'
	SELECT @InvoiceNumber = @NissanInvoicePrefix+REPLICATE(0,4-DATALENGTH(CONVERT(VARCHAR(20),@NextNissanInvoiceNumber)))+CONVERT(varchar(20),@NextNissanInvoiceNumber)
	SELECT @InvoiceDate = CURRENT_TIMESTAMP
	SELECT @NumberOfUnits = '01'
	
	FETCH NissanMOTOPSCursor INTO @VehicleID,@LegsID,@D6Number,@BOLDate,
		@YardExitDate,@DeliveryDate,@PROID,
		@PRODate,@FreightRate,@FreightAmount,@SizeClass,@ChargeRate,
		@ChargeRateOverrideInd,@OutsideCarrierPaymentMethod
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		SELECT @TransportCode = @TCode+@SizeClass
		
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
				GOTO End_Of_Loop
			END
			
			IF @ValidatedRate <> @ChargeRate
			BEGIN
				SELECT @ChargeRate = @ValidatedRate
				SELECT @FreightRate = CONVERT(varchar(20),CONVERT(int,@ChargeRate*100))
				SELECT @FreightAmount = CONVERT(varchar(20),CONVERT(int,@ChargeRate*100))
				
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
		
		INSERT INTO NissanExportMOTOPS(
			BatchID,
			VehicleID,
			VPC,
			Railhead,
			FileDate,
			FileBatchID,
			TransportCode,
			InvoiceNumber,	
			InvoiceDate,
			D6Number,
			BOLDate,
			YardExitDate,
			DeliveryDate,
			PROID,
			PRODate,
			NumberOfUnits,
			FreightRate,
			FreightAmount,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@VPC,
			@Railhead,
			@FileDate,
			@FileBatchID,
			@TransportCode,
			@InvoiceNumber,	
			@InvoiceDate,
			@D6Number,
			@BOLDate,
			@YardExitDate,
			@DeliveryDate,
			@PROID,
			@PRODate,
			@NumberOfUnits,
			@FreightRate,
			@FreightAmount,
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
			SELECT @Status = 'Error creating NissanExportYE record'
			GOTO Error_Encountered
		END
			
		End_Of_Loop:
		FETCH NissanMOTOPSCursor INTO @VehicleID,@LegsID,@D6Number,@BOLDate,
			@YardExitDate,@DeliveryDate,@PROID,
			@PRODate,@FreightRate,@FreightAmount,@SizeClass,@ChargeRate,
			@ChargeRateOverrideInd,@OutsideCarrierPaymentMethod

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE NissanMOTOPSCursor
		DEALLOCATE NissanMOTOPSCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE NissanMOTOPSCursor
		DEALLOCATE NissanMOTOPSCursor
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
