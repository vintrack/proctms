USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateTokioMarine926Data]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateTokioMarine926Data] (@CustomerID int, @CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--ExportTokioMarine926 table variables
	@BatchID			int,
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
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateTokioMarine926Data					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the Tokio Marine 926 export data for	*
	*	vehicles (for the specified Tokio Marine customer) that have	*
	*	claims.								*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	01/25/2011 CMK    Initial version				*
	*	11/02/2016 CMK    Added CompanySCACCode lookup			*
	*									*
	************************************************************************/
	
	--get the next batch id from the setting table
	--print 'getting batch id'
	SELECT TOP 1 @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextTokioMarine926ExportBatchID'
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
	--print 'have batch id'
	
	SELECT TOP 1 @NextClaimNumberCounter = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextDamageClaimNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Claim Number'
		GOTO Error_Encountered2
	END
	IF @NextClaimNumberCounter IS NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Status = 'NextClaimNumberCounter Not Found'
		GOTO Error_Encountered2
	END
	
	SELECT TOP 1 @InterchangeSenderID = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'CompanySCACCode'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Company SCAC Code'
		GOTO Error_Encountered2
	END
	IF @InterchangeSenderID IS NULL
	BEGIN
		SELECT @ErrorID = 100003
		SELECT @Status = 'InterchangeSenderID Not Found'
		GOTO Error_Encountered2
	END
	
	--cursor for the On Hand claim return data
	DECLARE TokioMarine926Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT DISTINCT ITM.ClaimDate, ITM.CustomerClaimNumber, ITM.TotalClaimAmount,
		V.VehicleID
		FROM ImportTokioMarine924 ITM
		LEFT JOIN Vehicle V ON ITM.VIN = V.VIN
		WHERE ITM.CustomerClaimNumber NOT IN (SELECT ETM.ManufacturerClaimNumber
			FROM ExportTokioMarine926 ETM
			WHERE ETM.StatusCode = 'OH')
		AND V.CustomerID = @CustomerID
		ORDER BY ITM.ClaimDate, ITM.CustomerClaimNumber
	--print 'cursor declared'
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN TokioMarine926Cursor
	--print 'cursor opened'
	
	BEGIN TRAN
	--print 'tran started'
	--set the next batch id in the setting table
	
	--print 'batch id updated'
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextTokioMarine926ExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END
	
	--set the default values
	--SELECT @InterchangeSenderID = 'DVAI'
	SELECT @InterchangeReceiverID = 'TMC01'
	SELECT @FunctionalID = 'GC'
	SELECT @SenderCode = @InterchangeSenderID
	SELECT @ReceiverCode ='TMC01'
	SELECT @TransmissionDateTime = NULL	--populated when exported
	SELECT @InterchangeControlNumber = NULL	--populated when exported
	SELECT @ResponsibleAgencyCode = 'X'
	SELECT @VersionNumber = '004010'
	SELECT @TransactionSetControlNumber = NULL	--populated when exported
	SELECT @AmountPaid = NULL
	SELECT @StatusCode = 'OH'
	SELECT @StatusReportDate = CURRENT_TIMESTAMP
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	--print 'default values set'
	
	FETCH TokioMarine926Cursor INTO @ClaimDate, @ManufacturerClaimNumber, @ClaimAmount, @VehicleID
	
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @CarrierClaimNumber = CONVERT(varchar(10),RIGHT(DATEPART(YY,@CreationDate),2))
		SELECT @CarrierClaimNumber = @CarrierClaimNumber + REPLICATE('0',2-DATALENGTH(CONVERT(varchar(10),DATEPART(day, @CreationDate))))+convert(varchar(10),DATEPART(day, @CreationDate))
		SELECT @CarrierClaimNumber = @CarrierClaimNumber + REPLICATE('0',6-DATALENGTH(CONVERT(varchar(10),@NextClaimNumberCounter)))+CONVERT(varchar(10),@NextClaimNumberCounter)
		
		SELECT @NextClaimNumberCounter = @NextClaimNumberCounter + 1
		
		INSERT INTO ExportTokioMarine926(
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
			SELECT @Status = 'Error creating 926 record'
			GOTO Error_Encountered
		END
			
		FETCH TokioMarine926Cursor INTO @ClaimDate, @ManufacturerClaimNumber, @ClaimAmount, @VehicleID

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
	
	--print 'end of loop'
	Error_Encountered:
	
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE TokioMarine926Cursor
		DEALLOCATE TokioMarine926Cursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE TokioMarine926Cursor
		DEALLOCATE TokioMarine926Cursor
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
