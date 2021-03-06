USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateVISTA510DataTEMP]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateVISTA510DataTEMP] (@InvoiceNumber varchar(20), @OriginID int, @CreatedBy varchar(20))
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
	@VIN				varchar(17),
	@RouteCodeOrigin		varchar(13),
	@RouteCodeDestination		varchar(13),
	@VehicleOrderNumber		varchar(16),
	@DealerIdentificationNumber	varchar(5),
	@PickupDateTime			datetime,
	@PickupStatus			varchar(1),
	@DeliveryDateTime		datetime,
	@DeliveryDateQualifier		varchar(1),
	@LineNumber			int,
	@RateQualifier			varchar(2),
	@ChargeRate			decimal(19,2),
	@ReferenceNumberQualifier	varchar(2),
	@ReferenceNumber		varchar(30),
	@ExportedInd			int,
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	--processing variables
	@InvoiceDate			datetime,
	@OriginSPLC 			varchar(10),
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
	*	spGenerateVISTA510DataTEMP					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the VISTA 510 export data for Chryslers*
	*	that have been billed manually with the supplied invoice number	*
	*	and origin location.						*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	04/11/2007 CMK    Initial version				*
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
	
	DECLARE VISTA510ExportCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, V.VIN,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT Value2 FROM Code WHERE CodeType = 'VistaLocationCode'
		AND Value1 = CONVERT(varchar(10),L3.LocationID)) ELSE L3.CustomerLocationCode END,
		--origin route code is the plant and destination route code is the railhead
		SUBSTRING(VIN,11,1),
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT Code FROM Code WHERE CodeType = 'VistaLocationCode'
		AND Value1 = CONVERT(varchar(10),L3.LocationID)) ELSE L3.CustomerLocationCode END,
		V.CustomerIdentification,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT Value2 FROM Code WHERE CodeType = 'VistaLocationCode'
		AND Value1 = CONVERT(varchar(10),L4.LocationID)) ELSE L4.CustomerLocationCode END,
		L.PickupDate, L.DropoffDate, V.ChargeRate,V.ReleaseCode, B.InvoiceDate
		FROM Vehicle V
		LEFT JOIN Billing B ON V.BillingID = B.BillingID
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
		LEFT JOIN Run R ON L2.RunID = R.RunID
		LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
		LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
		LEFT JOIN Driver D ON L2.DriverID = D.DriverID
		LEFT JOIN OutsideCarrier OC ON L2.OutsideCarrierID = OC.OutsideCarrierID
		LEFT JOIN OutsideCarrier OC2 ON D.OutsideCarrierID = OC2.OutsideCarrierID
		WHERE B.InvoiceNumber = @InvoiceNumber
		AND V.PickupLocationID = @OriginID
		AND V.BilledInd = 1
		AND V.CustomerID = @CustomerID
		AND V.VehicleStatus = 'Delivered'
		AND L.FinalLegInd = 1
		AND (V.ChargeRate > 0 OR (V.ChargeRate = 0 AND V.ChargeRateOverrideInd = 1))
		AND V.VehicleID NOT IN (SELECT EV.VehicleID FROM ExportVISTA510 EV)
		--AND V.VIN IN (SELECT IV.VIN FROM ImportVISTA660 IV WHERE IV.VIN = V.VIN)
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
	
	/*
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
	*/
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
	
	FETCH VISTA510ExportCursor INTO @VehicleID,@VIN, @OriginSPLC, @RouteCodeOrigin,@RouteCodeDestination,@VehicleOrderNumber,
		@DealerIdentificationNumber,@PickupDateTime,@DeliveryDateTime,@ChargeRate,@ReleaseCode, @InvoiceDate
	
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
			CreatedBy
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
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating Chrysler record'
			GOTO Error_Encountered
		END
			
		FETCH VISTA510ExportCursor INTO @VehicleID,@VIN, @OriginSPLC, @RouteCodeOrigin,@RouteCodeDestination,@VehicleOrderNumber,
			@DealerIdentificationNumber,@PickupDateTime,@DeliveryDateTime,@ChargeRate,@ReleaseCode, @InvoiceDate

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
