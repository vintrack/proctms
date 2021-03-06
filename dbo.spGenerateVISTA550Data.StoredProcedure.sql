USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateVISTA550Data]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROC [dbo].[spGenerateVISTA550Data] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	--ExportVISTA550 table variables
	@BatchID			int,
	@CustomerID			int,
	@VISTADelayTransactionsID	int,
	@InterchangeSenderID		varchar(15),
	@InterchangeReceiverID		varchar(15),
	@FunctionalID			varchar(2),
	@SenderCode			varchar(12),
	@ReceiverCode			varchar(12),
	@TransmissionDateTime		datetime,
	@InterchangeControlNumber	int,
	@ResponsibleAgencyCode		varchar(2),
	@VersionNumber			varchar(12),
	@TransactionSetControlNumber	varchar(9),
	@SegmentTypeIdentifier		varchar(1),
	@SCAC				varchar(4),
	@DelayCode			varchar(2),
	@DelayDateTime			datetime,
	@OriginSPLC			varchar(9),
	@DestinationSPLC		varchar(9),
	@SpecialServiceCode		varchar(9),
	@VesselName			varchar(28),
	@VIN				varchar(17),
	@RouteCodeOrigin		varchar(13),
	@RouteCodeDestination		varchar(13),
	@VehicleOrderNumber		varchar(16),
	@DealerIdentificationNumber	varchar(5),
	@StorageStartDate		datetime,
	@StorageEndDate			datetime,
	@ShipFromDealerCode		varchar(5),
	@VehicleUpdateDateTime		datetime,
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	--processing variables
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
	*	spGenerateVISTA550Data						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the VISTA 550 export data for Chryslers*
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
	WHERE ValueKey = 'NextVISTA550ExportBatchID'
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
	
	DECLARE VISTA550ExportCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT VD.VISTADelayTransactionsID, 'E' SegmentType,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT Value2 FROM Code WHERE CodeType = 'VISTALocationCode'
		AND Value1 = CONVERT(varchar(10),L3.LocationID)) ELSE L3.SPLCCode END,
		VD.DelayCode, VD.DelayEffectiveDate,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT Value2 FROM Code WHERE CodeType = 'VISTALocationCode'
		AND Value1 = CONVERT(varchar(10),L4.LocationID)) ELSE L4.SPLCCode END,
		V.VIN,
		--origin route code is the plant and destination route code is the railhead
		SUBSTRING(VIN,11,1),
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT Code FROM Code WHERE CodeType = 'VistaLocationCode'
		AND Value1 = CONVERT(varchar(10),L3.LocationID)) ELSE L3.CustomerLocationCode END,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT Value2 FROM Code WHERE CodeType = 'VistaLocationCode'
		AND Value1 = CONVERT(varchar(10),L4.LocationID)) ELSE L4.CustomerLocationCode END,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN NULL ELSE L3.CustomerLocationCode END,
		V.ReleaseCode
		FROM VISTADelayTransactions VD
		LEFT JOIN Vehicle V ON VD.VehicleID = V.VehicleID
		LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
		LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
		WHERE V.CustomerID = @CustomerID
		AND VD.DelayReportedInd = 0
		UNION SELECT VD.VISTADelayTransactionsID, 'T' SegmentType,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT Value2 FROM Code WHERE CodeType = 'VISTALocationCode'
		AND Value1 = CONVERT(varchar(10),L3.LocationID)) ELSE L3.SPLCCode END,
		VD.DelayCode, VD.DateReleased,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT Value2 FROM Code WHERE CodeType = 'VISTALocationCode'
		AND Value1 = CONVERT(varchar(10),L4.LocationID)) ELSE L4.SPLCCode END,
		V.VIN,
		--origin route code is the plant and destination route code is the railhead
		SUBSTRING(VIN,11,1),
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT Code FROM Code WHERE CodeType = 'VistaLocationCode'
		AND Value1 = CONVERT(varchar(10),L3.LocationID)) ELSE L3.CustomerLocationCode END,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT Value2 FROM Code WHERE CodeType = 'VistaLocationCode'
		AND Value1 = CONVERT(varchar(10),L4.LocationID)) ELSE L4.CustomerLocationCode END,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN NULL ELSE L3.CustomerLocationCode END,
		V.ReleaseCode
		FROM VISTADelayTransactions VD
		LEFT JOIN Vehicle V ON VD.VehicleID = V.VehicleID
		LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
		LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
		WHERE V.CustomerID = @CustomerID
		AND VD.ReleaseReportedInd = 0
		AND VD.DateReleased IS NOT NULL
		ORDER BY SegmentType, VD.DelayCode, V.VIN

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN VISTA550ExportCursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextVISTA550ExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
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
	SELECT @TransactionSetControlNumber = NULL --value set during export
	SELECT @SCAC = 'DVAI'
	SELECT @SpecialServiceCode = NULL
	SELECT @VesselName = NULL
	SELECT @VehicleOrderNumber = NULL
	SELECT @StorageStartDate = NULL
	SELECT @StorageEndDate = NULL
	SELECT @VehicleUpdateDateTime = NULL
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	FETCH VISTA550ExportCursor INTO @VISTADelayTransactionsID, @SegmentTypeIdentifier,
		@OriginSPLC, @DelayCode, @DelayDateTime, @DestinationSPLC, @VIN,
		@RouteCodeOrigin, @RouteCodeDestination, @DealerIdentificationNumber,
		@ShipFromDealerCode, @ReleaseCode
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF ISNULL (@ReleaseCode,'') = 'SA'
		BEGIN
			SELECT @RouteCodeOrigin = 'SPEC'
			SELECT @RouteCodeDestination = 'AUTH'
		END
		
		INSERT INTO ExportVISTA550(
			BatchID,
			CustomerID,
			VISTADelayTransactionsID,
			InterchangeSenderID,
			InterchangeReceiverID,
			FunctionalID,
			SenderCode,
			ReceiverCode,
			TransmissionDateTime,
			InterchangeControlNumber,
			ResponsibleAgencyCode,
			VersionNumber,
			TransactionSetControlNumber,
			SegmentTypeIdentifier,
			SCAC,
			OriginSPLC,
			DelayCode,
			DelayDateTime,
			DestinationSPLC,
			SpecialServiceCode,
			VesselName,
			VIN,
			RouteCodeOrigin,
			RouteCodeDestination,
			VehicleOrderNumber,
			DealerIdentificationNumber,
			StorageStartDate,
			StorageEndDate,
			ShipFromDealerCode,
			VehicleUpdateDateTime,
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
			@VISTADelayTransactionsID,
			@InterchangeSenderID,
			@InterchangeReceiverID,
			@FunctionalID,
			@SenderCode,
			@ReceiverCode,
			@TransmissionDateTime,
			@InterchangeControlNumber,
			@ResponsibleAgencyCode,
			@VersionNumber,
			@TransactionSetControlNumber,
			@SegmentTypeIdentifier,
			@SCAC,
			@OriginSPLC,
			@DelayCode,
			@DelayDateTime,
			@DestinationSPLC,
			@SpecialServiceCode,
			@VesselName,
			@VIN,
			@RouteCodeOrigin,
			@RouteCodeDestination,
			@VehicleOrderNumber,
			@DealerIdentificationNumber,
			@StorageStartDate,
			@StorageEndDate,
			@ShipFromDealerCode,
			@VehicleUpdateDateTime,
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
			SELECT @Status = 'Error creating Chrysler record'
			GOTO Error_Encountered
		END
			
		--update the delay transactiontable to flag the records as exported
		IF @SegmentTypeIdentifier = 'E'
		BEGIN
			UPDATE VISTADelayTransactions
			SET DelayReportedInd = 1,
			DateDelayReported = CURRENT_TIMESTAMP
			WHERE VISTADelayTransactionsID = @VISTADelayTransactionsID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error updating delay transactions table'
				GOTO Error_Encountered
			END
		END
		ELSE IF @SegmentTypeIdentifier = 'T'
		BEGIN
			UPDATE VISTADelayTransactions
			SET ReleaseReportedInd = 1,
			DateReleaseReported = CURRENT_TIMESTAMP
			WHERE VISTADelayTransactionsID = @VISTADelayTransactionsID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error updating delay transactions table'
				GOTO Error_Encountered
			END
		END
		FETCH VISTA550ExportCursor INTO @VISTADelayTransactionsID, @SegmentTypeIdentifier,
			@OriginSPLC, @DelayCode, @DelayDateTime, @DestinationSPLC, @VIN,
			@RouteCodeOrigin, @RouteCodeDestination, @DealerIdentificationNumber,
			@ShipFromDealerCode, @ReleaseCode

	END --end of loop
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE VISTA550ExportCursor
		DEALLOCATE VISTA550ExportCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE VISTA550ExportCursor
		DEALLOCATE VISTA550ExportCursor
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
