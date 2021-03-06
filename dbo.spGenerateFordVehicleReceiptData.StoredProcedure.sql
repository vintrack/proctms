USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateFordVehicleReceiptData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateFordVehicleReceiptData] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	--FordExportVehicleReceipt table variables
	@BatchID		int,
	@VehicleID		int,
	@AuthorizationID	varchar(4),
	@TransmissionDateTime	datetime,
	@BODID			varchar(40),
	@CarrierCode		varchar(4),
	@LocationType		varchar(2),
	@LocationCode		varchar(10),
	@EventDateTime		datetime,
	@TransactionType	varchar(10),
	@CorrectionIdentifier	varchar(1),
	@ExportedInd		int,
	@ExportedDate		datetime,
	@ExportedBy		varchar(20),
	@RecordStatus		varchar(100),
	@CreationDate		datetime,
	@UpdatedDate		datetime,
	@UpdatedBy		varchar(20),
	--processing variables
	@CustomerID		int,
	@LegsID			int,
	@CustomerIdentification	varchar(25),
	@LoopCounter		int,
	@Status			varchar(100),
	@ReturnCode		int,
	@ReturnMessage		varchar(100)	

	/************************************************************************
	*	spGenerateFordVehicleReceiptData				*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the vehicle receipt export data for	*
	*	Fords that have been dropped at the railhead.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	07/29/2010 CMK    Initial version				*
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
	WHERE ValueKey = 'NextFordVehicleReceiptExportBatchID'
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
	
	SELECT @ErrorID = 0
	
	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextFordVehicleReceiptExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END
	
	--set the default values
	SELECT @LoopCounter = 0
	SELECT @AuthorizationID = 'DVAI'
	SELECT @TransmissionDateTime = NULL --value set during export
	SELECT @BODID = NULL --value set during export
	SELECT @CarrierCode = 'DVAI'
	SELECT @TransactionType = '340'
	SELECT @CorrectionIdentifier = ''
	SELECT @ExportedInd = 0
	SELECT @ExportedDate = NULL
	SELECT @ExportedBy = NULL
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @UpdatedDate = NULL
	SELECT @UpdatedBy = NULL
	
	INSERT INTO FordExportVehicleReceipt(
		BatchID,
		VehicleID,
		AuthorizationID,
		TransmissionDateTime,
		BODID,
		CarrierCode,
		LocationType,
		LocationCode,
		EventDateTime,
		TransactionType,
		CorrectionIdentifier,
		ExportedInd,
		ExportedDate,
		ExportedBy,
		RecordStatus,
		CreationDate,
		CreatedBy,
		UpdatedDate,
		UpdatedBy)
 	SELECT 
 		@BatchID,
		V.VehicleID,
		@AuthorizationID,
		@TransmissionDateTime,
		@BODID,
		@CarrierCode,
		'R' LocationType,
		C.Code,
		ISNULL((SELECT TOP 1 NS.CreationDate FROM NSTruckerNotificationImport NS WHERE NS.VIN = V.VIN ORDER BY NS.CreationDate DESC),V.AvailableForPickupDate) EventDate,
		@TransactionType,
		@CorrectionIdentifier,
		@ExportedInd,
		@ExportedDate,
		@ExportedBy,
		@RecordStatus,
		@CreationDate,
		@CreatedBy,
		@UpdatedDate,
		@UpdatedBy
	FROM Vehicle V
	LEFT JOIN Code C ON V.PickupLocationID = CONVERT(int,C.Value1)
	AND C.CodeType = 'FordLocationCode'
	WHERE V.CustomerID = @CustomerID
	AND V.AvailableForPickupDate IS NOT NULL
	AND CONVERT(int,C.Value1) IS NOT NULL
	AND V.VehicleID NOT IN (SELECT FEVR.VehicleID FROM FordExportVehicleReceipt FEVR WHERE FEVR.VehicleID = V.VehicleID)
	ORDER BY LocationType,C.Code,EventDate, V.VehicleID
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
