USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateFordStatusChangeData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateFordStatusChangeData] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID				int,
	--FordExportStatusChange table variables
	@BatchID				int,
	@VehicleID				int,
	@FordDelayTransactionsID		int,
	@InterchangeSenderID			varchar(15),
	@InterchangeReceiverID			varchar(15),
	@FunctionalID				varchar(2),
	@SenderCode				varchar(12),
	@ReceiverCode				varchar(12),
	@TransmissionDateTime			datetime,
	@InterchangeControlNumber		int,
	@ResponsibleAgencyCode			varchar(2),
	@VersionNumber				varchar(12),
	@TransactionSetControlNumber		varchar(9),
	@SCACCode				varchar(4),
	@RecordType				varchar(2),
	@RampCode				varchar(2),
	@ActionDate				datetime,
	@ExceptionCode				varchar(2),		
	@ExceptionAuthorization			varchar(7),		
	@ChargeToCode				varchar(12),		
	@UnitChargeType				varchar(1),		
	@UnitsCharged				varchar(3),		
	@StorageStartDate			datetime,		
	@SequenceNumber				varchar(1),		
	@ExportedInd				int,
	@ExportedDate				datetime,
	@ExportedBy				varchar(20),
	@RecordStatus				varchar(100),
	@CreationDate				datetime,
	@UpdatedDate				datetime,
	@UpdatedBy				varchar(20),
	--processing variables
	@CustomerID				int,
	@LegsID					int,
	@CustomerIdentification			varchar(25),
	@LoopCounter				int,
	@Status					varchar(100),
	@ReturnCode				int,
	@ReturnMessage				varchar(100)	

	/************************************************************************
	*	spGenerateFordStatusChangeData					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the status change export data for Fords*
	*	that have been put on hold.					*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	09/14/2010 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'FordCustomerID'
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
	WHERE ValueKey = 'NextFordStatusChangeExportBatchID'
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
	
	--get ramp code, will need to change if ever more than one ramp
	/*
	SELECT TOP 1 @RampCode = Code
	FROM Code
	WHERE CodeType = 'FordLocationCode'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting RampCode'
		GOTO Error_Encountered2
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Error Getting RampCode'
		GOTO Error_Encountered2
	END
	*/
	
	SELECT @ErrorID = 0
	
	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextFordStatusChangeExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END
	
	--set the default values
	SELECT @LoopCounter = 0
	SELECT @InterchangeSenderID = 'GCXXA'
	SELECT @InterchangeReceiverID = 'F159B'
	SELECT @FunctionalID = 'FT'
	SELECT @SenderCode = 'GCXXA'
	SELECT @ReceiverCode = 'F159B'
	SELECT @TransmissionDateTime = NULL --value set during export
	SELECT @InterchangeControlNumber = NULL --value set during export
	SELECT @ResponsibleAgencyCode = 'X'
	SELECT @VersionNumber = '003030'
	SELECT @TransactionSetControlNumber = NULL --value set during export
	SELECT @SCACCode = 'DVAI'
	SELECT @RecordType = '4A'
	SELECT @ChargeToCode = ''
	SELECT @UnitChargeType = ''
	SELECT @UnitsCharged = '1'
	SELECT @SequenceNumber = ''
	SELECT @ExportedInd = 0
	SELECT @ExportedDate = NULL
	SELECT @ExportedBy = NULL
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @UpdatedDate = NULL
	SELECT @UpdatedBy = NULL
	
	-- this inserts the record to be exported, the export will flag the delay as reported
	INSERT INTO FordExportStatusChange SELECT @BatchID, FDT.VehicleID, FDT.FordDelayTransactionsID,
	@InterchangeSenderID, @InterchangeReceiverID, @FunctionalID, @SenderCode, @ReceiverCode, @TransmissionDateTime,
	@InterchangeControlNumber, @ResponsibleAgencyCode, @VersionNumber, @TransactionSetControlNumber,
	@SCACCode, @RecordType,
	C.Code, --@RampCode, --03/09/2016 - CMK - C.Code replaces @RampCode
	FDT.DelayEffectiveDate, FDT.COPACExceptionCode, FDT.COPACExceptionAuthorization,
	@ChargeToCode, @UnitChargeType, @UnitsCharged, 
	CASE WHEN FDT.DelayType = 'VehicleStorage' THEN FDT.DelayEffectiveDate ELSE NULL END,
	@SequenceNumber, @ExportedInd, @ExportedDate, @ExportedBy, @RecordStatus, @CreationDate, @CreatedBy,
	@UpdatedDate, @UpdatedBy
	FROM FordDelayTransactions FDT
	LEFT JOIN Vehicle V ON FDT.VehicleID = V.VehicleID
	LEFT JOIN Code C ON CONVERT(varchar(10),V.PickupLocationID) = C.Value1
	AND C.CodeType = 'FordLocationCode'
	WHERE FDT.DelayReportedToCOPACInd = 0
	AND C.Code IS NOT NULL
	ORDER BY FDT.VehicleID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating Chrysler record'
		GOTO Error_Encountered
	END
			
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		--CLOSE FordDeliveryExportCursor
		--DEALLOCATE FordDeliveryExportCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		--CLOSE FordDeliveryExportCursor
		--DEALLOCATE FordDeliveryExportCursor
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
