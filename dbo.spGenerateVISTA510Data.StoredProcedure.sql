USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateVISTA510Data]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateVISTA510Data] (@CreatedBy varchar(20), @CutoffDate datetime)
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	--ExportVISTA510 table variables
	@BatchID			int,
	@CustomerID			int,
	@VehicleID			int,
	@InterchangeSenderID		varchar(15),
	@InterchangeReceiverID		varchar(15),
	@FunctionalID			varchar(2),
	@SenderCode			varchar(12),
	@ReceiverCode			varchar(12),
	@TransmissionDateTime		datetime,
	@InterchangeControlNumber	int,
	@ResponsibleAgencyCode		varchar(2),
	@VersionNumber			varchar(12),
	@OriginSPLC			varchar(10),
	@VIN				varchar(17),
	@RouteCodeOrigin		varchar(13),
	@RouteCodeDestination		varchar(13),
	@VehicleOrderNumber		varchar(16),
	@DealerIdentificationNumber	varchar(5),
	@PickupDateTime			datetime,
	@PickupStatus			varchar(1),
	@DeliveryDateTime		datetime,
	@DeliveryDateQualifier		varchar(1),
	@InvoiceNumber			varchar(16),
	@LineNumber			int,
	@RateQualifier			varchar(2),
	@ChargeRate			decimal(19,2),
	@ReferenceNumberQualifier	varchar(2),
	@ReferenceNumber		varchar(30),
	@ExportedInd			int,
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	--processing variables
	@LegsID				int,
	@ChargeRateOverrideInd		int,
	@ValidatedRate			decimal(19,2),
	@OutsideCarrierPaymentMethod	int,
	@IndividualInvoiceNumber	varchar(10),
	@ReleaseCode			varchar(20),
	@LoopCounter			int,
	@SequenceNumber			int,
	@NextChryslerInvoiceNumber	int,
	@ChryslerInvoicePrefix		varchar(10),
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateVISTA510Data						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the VISTA 510 export data for Chryslers*
	*	that have been delivered.					*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/07/2007 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ChryslerCustomerID'
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

	--get the next batch id from the setting table
	SELECT @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextVISTA510ExportBatchID'
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
	SELECT @ChryslerInvoicePrefix = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'ChryslerInvoicePrefix'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Invoice Prefix'
		GOTO Error_Encountered2
	END
	IF @ChryslerInvoicePrefix IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Invoice Prefix Not Found'
		GOTO Error_Encountered2
	END

	--get the next invoice number from the setting table
	Select @NextChryslerInvoiceNumber = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextChryslerInvoiceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Invoice Number'
		GOTO Error_Encountered2
	END
	IF @NextChryslerInvoiceNumber IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Invoice Number Not Found'
		GOTO Error_Encountered2
	END
	
	--get the next sequence number from the setting table
	SELECT @SequenceNumber = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextVISTA510SequenceNumber'
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
	
	IF @CutoffDate IS NULL
	BEGIN
		SELECT @CutoffDate = CONVERT(varchar(10),CURRENT_TIMESTAMP,101)
	END
	
	DECLARE VISTA510ExportCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, L.LegsID,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'VistaLocationCode'
		AND Value1 = CONVERT(varchar(10),L3.LocationID)) ELSE L3.SPLCCode END,
		V.VIN,
		SUBSTRING(VIN,11,1),
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 REPLACE(Code,'.','') FROM Code WHERE CodeType = 'VistaLocationCode'
		AND Value1 = CONVERT(varchar(10),L3.LocationID)) ELSE L3.SPLCCode END,
		V.CustomerIdentification,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'VistaLocationCode'
		AND Value1 = CONVERT(varchar(10),L4.LocationID)) ELSE L4.CustomerLocationCode END,
		L.PickupDate, L.DropoffDate, 
		--V.ChargeRate,
		ISNULL(CASE WHEN O.CustomerChargeType = 0 OR V.ChargeRateOverrideInd = 1 THEN V.ChargeRate WHEN O.PricingInd = 0 THEN O.PerUnitChargeRate ELSE O.OrderChargeRate/O.Units END,0),
		V.ReleaseCode, CASE WHEN O.CustomerChargeType = 1 THEN 1 ELSE V.ChargeRateOverrideInd END, L.OutsideCarrierPaymentMethod
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
		LEFT JOIN Run R ON L2.RunID = R.RunID
		LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
		LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
		LEFT JOIN Driver D ON L2.DriverID = D.DriverID
		LEFT JOIN OutsideCarrier OC ON L2.OutsideCarrierID = OC.OutsideCarrierID
		LEFT JOIN OutsideCarrier OC2 ON D.OutsideCarrierID = OC2.OutsideCarrierID
		LEFT JOIN Orders O ON V.OrderID = O.OrdersID
		WHERE V.BilledInd = 0
		--AND V.PickupLocationID = @OriginID	-- want to do each railyard separately
		AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0
		AND V.CustomerID = @CustomerID
		AND V.VehicleStatus = 'Delivered'
		AND L.FinalLegInd = 1
		--AND (V.VIN IN (SELECT IV.VIN FROM ImportVISTA660 IV WHERE IV.VIN = V.VIN) OR V.PickupLocationID = 12570) --can only bill this way if we have an ASN
		AND L.PickupDate < DATEADD(day,1,@CutoffDate)
		AND L.DropoffDate > L.PickupDate
		AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
		--AND V.CustomerIdentification IS NOT NULL
		--AND V.CustomerIdentification <> ''
		AND (V.ChargeRate > 0 
		OR (V.ChargeRate = 0 AND V.ChargeRateOverrideInd = 1)
		OR (O.CustomerChargeType = 1 AND (O.PerUnitChargeRate > 0 OR O.OrderChargeRate > 0)))
		AND V.VehicleID NOT IN (SELECT EV.VehicleID FROM ExportVISTA510 EV)
		AND (D.OutsideCarrierInd = 0
		OR (D.OutsideCarrierInd = 1 AND (L.OutsideCarrierPay > 0 OR OC2.StandardCommissionRate > 0))
		OR (L.OutsideCarrierID > 0 AND (L.OutsideCarrierPay > 0 OR OC.StandardCommissionRate > 0)))
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN VISTA510ExportCursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextVISTA510ExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END
	
	--set the next chrysler invoice number in the setting table
	UPDATE SettingTable
	SET ValueDescription = @NextChryslerInvoiceNumber+1	
	WHERE ValueKey = 'NextChryslerInvoiceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting Next Invoice Number'
		GOTO Error_Encountered
	END

	--set the default values
	SELECT @LoopCounter = 0
	SELECT @InterchangeSenderID = '58792'
	SELECT @InterchangeReceiverID = 'VISTA'
	SELECT @FunctionalID = 'VI'
	SELECT @SenderCode = 'DVAI'
	SELECT @ReceiverCode = 'VISTA'
	SELECT @TransmissionDateTime = NULL --value set during export
	SELECT @InterchangeControlNumber = NULL --value set during export
	SELECT @ResponsibleAgencyCode = 'T'
	SELECT @VersionNumber = '1'
	SELECT @PickupStatus = 'A'
	SELECT @DeliveryDateQualifier = 'A'
	SELECT @LineNumber = NULL --value set during export
	SELECT @RateQualifier = 'PV'
	SELECT @ReferenceNumberQualifier = 'BM'				
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @InvoiceNumber = @ChryslerInvoicePrefix+REPLICATE(0,5-DATALENGTH(CONVERT(VARCHAR(20),@NextChryslerInvoiceNumber)))+CONVERT(varchar(20),@NextChryslerInvoiceNumber)
	
	FETCH VISTA510ExportCursor INTO @VehicleID,@LegsID,@OriginSPLC,@VIN,@RouteCodeOrigin,@RouteCodeDestination,@VehicleOrderNumber,
		@DealerIdentificationNumber,@PickupDateTime,@DeliveryDateTime,@ChargeRate,@ReleaseCode,
		@ChargeRateOverrideInd,@OutsideCarrierPaymentMethod
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @LoopCounter = @LoopCounter + 1
		
		SELECT @IndividualInvoiceNumber = @InvoiceNumber+REPLICATE('0',4-DATALENGTH(CONVERT(varchar(10),@LoopCounter)))+CONVERT(varchar(10),@LoopCounter)
		
		SELECT @SequenceNumber = @SequenceNumber + 1
		
		IF @ReleaseCode = 'SA'
		BEGIN
			SELECT @RouteCodeOrigin = 'SPEC'
			SELECT @RouteCodeDestination = 'AUTH'
		END
		
		IF @DealerIdentificationNumber IS NULL OR @DealerIdentificationNumber = ''
		BEGIN
			GOTO End_Of_Loop
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
				GOTO End_Of_Loop
			END
			
			IF @ValidatedRate <> @ChargeRate
			BEGIN
				SELECT @ChargeRate = @ValidatedRate
				
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
		
		INSERT INTO ExportVISTA510(
			BatchID,
			CustomerID,
			VehicleID,
			InterchangeSenderID,
			InterchangeReceiverID,
			FunctionalID,
			SenderCode,
			ReceiverCode,
			TransmissionDateTime,
			InterchangeControlNumber,
			ResponsibleAgencyCode,
			VersionNumber,
			OriginSPLC,
			VIN,
			RouteCodeOrigin,
			RouteCodeDestination,
			VehicleOrderNumber,
			DealerIdentificationNumber,
			PickupDateTime,
			PickupStatus,
			DeliveryDateTime,
			DeliveryDateQualifier,
			InvoiceNumber,
			LineNumber,
			RateQualifier,
			ChargeRate,
			ReferenceNumberQualifier,
			ReferenceNumber,
			ExportedInd,
			RecordStatus,
			CreationDate,
			CreatedBy,
			PaymentReceivedInd
		)
		VALUES(
			@BatchID,
			@CustomerID,
			@VehicleID,
			@InterchangeSenderID,
			@InterchangeReceiverID,
			@FunctionalID,
			@SenderCode,
			@ReceiverCode,
			@TransmissionDateTime,
			@InterchangeControlNumber,
			@ResponsibleAgencyCode,
			@VersionNumber,
			@OriginSPLC,
			@VIN,
			@RouteCodeOrigin,
			@RouteCodeDestination,
			@VehicleOrderNumber,
			@DealerIdentificationNumber,
			@PickupDateTime,
			@PickupStatus,
			@DeliveryDateTime,
			@DeliveryDateQualifier,
			@IndividualInvoiceNumber,
			@LineNumber,
			@RateQualifier,
			@ChargeRate,
			@ReferenceNumberQualifier,
			@ReferenceNumber,
			@ExportedInd,
			@RecordStatus,
			@CreationDate,
			@CreatedBy,
			0		--PaymentReceivedInd
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating Chrysler record'
			GOTO Error_Encountered
		END
			
		End_Of_Loop:
		FETCH VISTA510ExportCursor INTO @VehicleID,@LegsID,@OriginSPLC,@VIN,@RouteCodeOrigin,@RouteCodeDestination,@VehicleOrderNumber,
			@DealerIdentificationNumber,@PickupDateTime,@DeliveryDateTime,@ChargeRate,@ReleaseCode,
			@ChargeRateOverrideInd,@OutsideCarrierPaymentMethod

	END --end of loop
	
	--set the next sequence number in the setting table
	UPDATE SettingTable
	SET ValueDescription = @SequenceNumber+1	
	WHERE ValueKey = 'NextVISTA510SequenceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE VISTA510ExportCursor
		DEALLOCATE VISTA510ExportCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE VISTA510ExportCursor
		DEALLOCATE VISTA510ExportCursor
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
