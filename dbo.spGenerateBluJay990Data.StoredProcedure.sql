USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateBluJay990Data]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateBluJay990Data] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	--BluJayExport990 table variables
	@BatchID			int,
	@CustomerID			int,
	@VehicleID			int,
	@BluJayImport204ID		int,
	@InterchangeSenderID		varchar(15),
	@InterchangeReceiverID		varchar(15),
	@FunctionalID			varchar(2),
	@SenderCode			varchar(12),
	@ReceiverCode			varchar(12),
	@TransmissionDateTime		datetime,
	@InterchangeControlNumber	int,
	@ResponsibleAgencyCode		varchar(2),
	@VersionNumber			varchar(12),
	@StandardCarrierAlphaCode	varchar(4),
	@ShipmentIdentificationNumber	varchar(30),
	@ReservationActionCode		varchar(1),
	@OriginatingCompanyIdentifier	varchar(30),
	@ExportedInd			int,
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	--processing variables
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateBluJay990Data						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the Repsonse To Tender export data	*
	*	for Volvos that have been received through the BluJay 204.	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	06/26/2018 CMK    Initial version				*
	*									*
	************************************************************************/
	
	SELECT @ErrorID = 0
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'VolvoCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting CustomerID'
		GOTO Error_Encountered
	END
	IF @CustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'CustomerID Not Found'
		GOTO Error_Encountered
	END

	--get the next batch id from the setting table
	SELECT @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextBluJay990ExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting BatchID'
		GOTO Error_Encountered
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'BatchID Not Found'
		GOTO Error_Encountered
	END
	
	--get the Interchange Sender ID from the setting table
	SELECT @InterchangeSenderID = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'CompanySCACCode'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Company SCAC Code'
		GOTO Error_Encountered
	END
	IF @InterchangeSenderID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Company SCAC Code Not Found'
		GOTO Error_Encountered
	END
	
	--get the Interchange Receiver ID from the setting table
	SELECT @InterchangeReceiverID = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'BluJayEDICode'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting BluJay EDI Code'
		GOTO Error_Encountered
	END
	IF @InterchangeReceiverID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'BluJay EDI Code Not Found'
		GOTO Error_Encountered
	END
	
	--get the Originating Company Identifier from the setting table
	SELECT @OriginatingCompanyIdentifier = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'VolvoDunsNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Volvo Duns Number'
		GOTO Error_Encountered
	END
	IF @OriginatingCompanyIdentifier IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Volvo Duns Number Not Found'
		GOTO Error_Encountered
	END
	
	--set the default values
	SELECT @FunctionalID = 'GF'
	SELECT @SenderCode = @InterchangeSenderID
	SELECT @ReceiverCode = @InterchangeReceiverID
	SELECT @TransmissionDateTime = NULL --value set during export
	SELECT @InterchangeControlNumber = NULL --value set during export
	SELECT @ResponsibleAgencyCode = 'X'
	SELECT @VersionNumber = '004010'
	SELECT @StandardCarrierAlphaCode = @InterchangeSenderID
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	INSERT INTO BluJayExport990(BatchID, CustomerID, VehicleID, BluJayImport204ID, InterchangeSenderID, InterchangeReceiverID,
		FunctionalID, SenderCode, ReceiverCode, ResponsibleAgencyCode, VersionNumber, StandardCarrierAlphaCode,
		ShipmentIdentificationNumber, ReservationActionCode, OriginatingCompanyIdentifier, ExportedInd, RecordStatus,
		CreationDate, CreatedBy)
	SELECT @BatchID, @CustomerID, I.VehicleID, I.BluJayImport204ID, @InterchangeSenderID, @InterchangeReceiverID,
		@FunctionalID, @SenderCode, @ReceiverCode, @ResponsibleAgencyCode, @VersionNumber, @StandardCarrierAlphaCode,
		I.ShipmentIdentificationNumber, 'A', @OriginatingCompanyIdentifier, @ExportedInd, @RecordStatus,
		@CreationDate, @CreatedBy
		FROM BluJayImport204 I
		WHERE I.BluJayImport204ID NOT IN (SELECT E.BluJayImport204ID FROM BluJayExport990 E WHERE E.ExportedInd = 1)
		AND I.TransactionSetPurposeCode IN ('00','05','55')

	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextBluJay990ExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END
	
	SELECT @Status = 'Processing Completed Successfully'
	
	Error_Encountered:
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
