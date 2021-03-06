USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateFordVehicleDelayData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateFordVehicleDelayData] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	--FordExportVehicleDelay table variables
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
	@ReasonCode		varchar(2),
	@DamageCategory		varchar(3),
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
	*	spGenerateFordVehicleDelayData					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the vehicle delay export data for	*
	*	Fords that have been delayed.					*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	09/16/2010 CMK    Initial version				*
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
	WHERE ValueKey = 'NextFordVehicleDelayExportBatchID'
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
	WHERE ValueKey = 'NextFordVehicleDelayExportBatchID'
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
	SELECT @CorrectionIdentifier = ''
	SELECT @ExportedInd = 0
	SELECT @ExportedDate = NULL
	SELECT @ExportedBy = NULL
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @UpdatedDate = NULL
	SELECT @UpdatedBy = NULL
	
	INSERT INTO FordExportVehicleDelays (
		BatchID,
		VehicleID,
		FordDelayTransactionsID,
		AuthorizationID,
		TransmissionDateTime,
		BODID,
		CarrierCode,
		LocationType,
		LocationCode,
		EventDateTime,
		TransactionType,
		ReasonCode,
		DamageCategory,
		CorrectionIdentifier,
		ExportedInd,
		ExportedDate,
		ExportedBy,
		RecordStatus,
		CreationDate,
		CreatedBy,
		UpdatedDate,
		UpdatedBy
	)
	SELECT @BatchID,
		FDT.VehicleID,
		FDT.FordDelayTransactionsID,
		@AuthorizationID,
		@TransmissionDateTime,
		@BODID,
		@CarrierCode,
		'R' LocationType,
		C.Code,
		FDT.DelayEffectiveDate EventDate,
		C2.Value1,
		FDT.VVReasonCode,
		FDT.VVDamageCategory,
		@CorrectionIdentifier,
		@ExportedInd,
		@ExportedDate,
		@ExportedBy,
		@RecordStatus,
		@CreationDate,
		@CreatedBy,
		@UpdatedDate,
		@UpdatedBy
	FROM FordDelayTransactions FDT
	LEFT JOIN Vehicle V ON FDT.VehicleID = V.VehicleID
	LEFT JOIN Code C ON V.PickupLocationID = CONVERT(int,C.Value1)
	AND C.CodeType = 'FordLocationCode'
	LEFT JOIN Code C2 ON FDT.DelayType = C2.Code
	AND C2.CodeType = 'FordDelayType'
	WHERE FDT.DelayReportedToVVInd = 0
	AND FDT.DelayType <> 'VehicleSentOffsite'
	ORDER BY FDT.DelayType, EventDate, V.VehicleID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating FordExportVehicleDelay record'
		GOTO Error_Encountered
	END
			
	UPDATE FordDelayTransactions
	SET DelayReportedToVVInd = 1,
	DateDelayReportedToVV = CURRENT_TIMESTAMP
	WHERE FordDelayTransactions.FordDelayTransactionsID IN (SELECT FEVD.FordDelayTransactionsID
								FROM FordExportVehicleDelays FEVD
								WHERE FEVD.BatchID = @BatchID)
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error updating FordDelayTransactions records'
		GOTO Error_Encountered
	END
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
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
