USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateVICS926Data]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateVICS926Data] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--ExportVICS926 table variables
	@BatchID			int,
	@CustomerID			int,
	@VehicleID			int,
	@InterchangeSenderID		varchar(15),
	@InterchangeReceiverID		varchar(15),
	@FunctionalID			varchar(2),
	@SenderCode			varchar(15),
	@ReceiverCode			varchar(15),
	@TransmissionDateTime		datetime,
	@InterchangeControlNumber	varchar(9),
	@ResponsibleAgencyCode		varchar(2),
	@VersionNumber			varchar(12),
	@TransactionSetControlNumber	varchar(9),
	@ClaimDate			datetime,
	@ManufacturerClaimNumber	varchar(30),
	@CarrierClaimNumber		varchar(30),
	@ClaimAmount			decimal(19,2),
	@AmountPaid			decimal(19,2),
	@StatusCode			varchar(2),
	@StatusReportDate		datetime,
	@DeclineAmendCode		varchar(3),
	@LineItemNumber			varchar(6),
	@DeclineAmendReasonCode		varchar(3),
	@CarrierCheckNumber		varchar(16),
	@CheckDate			datetime,
	@CheckAmount			decimal(19,2),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	--processing variables
	@NextClaimNumberCounter		int,
	@PickupLocationType		varchar(20),
	@DropoffLocationType		varchar(20),
	@InspectionType			int,
	@VIN				varchar(20),
	@I95RecordCount			int,
	@InvoicePrefixCode		varchar(10),			
	@NextInvoiceNumber		int,
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateVICS926Data						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the VICS 926 export data for vehicles	*
	*	that have claims.						*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	05/10/2007 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the next batch id from the setting table
	print 'getting batch id'
	SELECT @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextVICS926ExportBatchID'
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
	print 'have batch id'
	
	--get the chrysler customer id
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ChryslerCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting BatchID'
		GOTO Error_Encountered2
	END
	IF @CustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Status = 'CustomerID Not Found'
		GOTO Error_Encountered2
	END
	--cursor for the pickup records
	DECLARE VICS926Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT DISTINCT IV.ClaimDate, IV.CustomerClaimNumber, IV.TotalClaimAmount,
		V.VehicleID
		FROM ImportVICS924 IV
		LEFT JOIN Vehicle V ON IV.VIN = V.VIN
		AND V.CustomerID = @CustomerID
		WHERE IV.CustomerClaimNumber NOT IN (SELECT EV.ManufacturerClaimNumber
			FROM ExportVICS926 EV
			WHERE EV.StatusCode = 'OH')
		ORDER BY IV.ClaimDate, IV.CustomerClaimNumber
	print 'cursor declared'
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN VICS926Cursor
	print 'cursor opened'
	BEGIN TRAN
	print 'tran started'
	--set the next batch id in the setting table
	
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextVICS926ExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END
	
	Select @NextClaimNumberCounter = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextDamageClaimNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Claim Number'
		GOTO Error_Encountered2
	END
	
	print 'batch id updated'
	--set the default values
	SELECT @InterchangeSenderID = '58792'
	SELECT @InterchangeReceiverID = 'VDICS'
	SELECT @FunctionalID = 'GC'
	SELECT @SenderCode ='58792'
	SELECT @ReceiverCode ='VDICS'
	SELECT @TransmissionDateTime = NULL	--populated when exported
	SELECT @InterchangeControlNumber = NULL	--populated when exported
	SELECT @ResponsibleAgencyCode = 'X'
	SELECT @VersionNumber = '003020'
	SELECT @TransactionSetControlNumber = NULL	--populated when exported
	SELECT @AmountPaid = NULL
	SELECT @StatusCode = 'OH'
	SELECT @StatusReportDate = CURRENT_TIMESTAMP
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	print 'default values set'
	
	FETCH VICS926Cursor INTO @ClaimDate, @ManufacturerClaimNumber, @ClaimAmount, @VehicleID
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @CarrierClaimNumber = CONVERT(varchar(10),RIGHT(DATEPART(YY,@CreationDate),2))
		SELECT @CarrierClaimNumber = @CarrierClaimNumber + REPLICATE('0',2-DATALENGTH(CONVERT(varchar(10),DATEPART(day, @CreationDate))))+convert(varchar(10),DATEPART(day, @CreationDate))
		SELECT @CarrierClaimNumber = @CarrierClaimNumber + REPLICATE('0',6-DATALENGTH(CONVERT(varchar(10),@NextClaimNumberCounter)))+CONVERT(varchar(10),@NextClaimNumberCounter)
		
		SELECT @NextClaimNumberCounter = @NextClaimNumberCounter + 1
		
		INSERT INTO ExportVICS926(
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
			TransactionSetControlNumber,
			ClaimDate,
			ManufacturerClaimNumber,
			CarrierClaimNumber,
			ClaimAmount,
			AmountPaid,
			StatusCode,
			StatusReportDate,
			DeclineAmendCode,
			LineItemNumber,
			DeclineAmendReasonCode,
			CarrierCheckNumber,
			CheckDate,
			CheckAmount,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			RecordStatus,
			CreatedBy,
			CreationDate
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
			@TransactionSetControlNumber,
			@ClaimDate,
			@ManufacturerClaimNumber,
			@CarrierClaimNumber,
			@ClaimAmount,
			@AmountPaid,
			@StatusCode,
			@StatusReportDate,
			@DeclineAmendCode,
			@LineItemNumber,
			@DeclineAmendReasonCode,
			@CarrierCheckNumber,
			@CheckDate,
			@CheckAmount,
			@ExportedInd,
			@ExportedDate,
			@ExportedBy,
			@RecordStatus,
			@CreatedBy,
			@CreationDate
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating 928 record'
			GOTO Error_Encountered
		END
			
		FETCH VICS926Cursor INTO @ClaimDate, @ManufacturerClaimNumber, @ClaimAmount, @VehicleID

	END --end of loop
	
	UPDATE SettingTable
	SET ValueDescription = @NextClaimNumberCounter	
	WHERE ValueKey = 'NextDamageClaimNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting Claim Number'
		GOTO Error_Encountered
	END
	
	print 'end of loop'
	Error_Encountered:
	
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE VICS926Cursor
		DEALLOCATE VICS926Cursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE VICS926Cursor
		DEALLOCATE VICS926Cursor
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
