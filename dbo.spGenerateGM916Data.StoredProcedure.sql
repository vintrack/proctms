USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateGM916Data]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateGM916Data] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	--GMExport916 table variables
	@BatchID		int,
	@VehicleID		int,
	@EventType		varchar(2),
	@SCAC			varchar(4),
	@CDLCode		varchar(2),
	@VIN			varchar(17),
	@RequestDateTime	datetime,
	@ReasonCode		varchar(2),
	@ExportedInd		int,
	@ExportedDate		datetime,
	@ExportedBy		varchar(20),
	@RecordStatus		varchar(100),
	@CreationDate		datetime,
	--processing variables
	@CustomerID		int,
	@GMDelayTransactionsID	int,
	@Status			varchar(100),
	@ReturnCode		int,
	@ReturnMessage		varchar(100),
	@ReturnBatchID		int	

	/************************************************************************
	*	spGenerateGM916Data						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the GM550 data for GM vehicles that	*
	*	have been put onto or removed from hold.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	11/07/2013 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'GMCustomerID'
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
	WHERE ValueKey = 'NextGM916ExportBatchID'
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
	
	DECLARE GM916ExportCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT GDT.GMDelayTransactionsID, GDT.VehicleID, 'CH' EventType, C.Code,
		V.VIN, CASE WHEN GI.ReceiptDateTime > GDT.DelayEffectiveDate THEN GI.ReceiptDateTime ELSE GDT.DelayEffectiveDate END, GDT.DelayCode
		FROM GMDelayTransactions GDT
		LEFT JOIN Vehicle V ON GDT.VehicleID = V.VehicleID
		LEFT JOIN Code C ON V.PickupLocationID = CONVERT(int,C.Value1)
		AND C.CodeType = 'GMLocationCode'
		LEFT JOIN GMImport900 GI ON V.VehicleID = GI.VehicleID
		WHERE V.CustomerID = @CustomerID
		AND GDT.DelayReportedInd = 0
		AND GI.StatusCode IN ('A','W')
		UNION SELECT GDT.GMDelayTransactionsID, GDT.VehicleID, 'CR' EventType, C.Code,
		V.VIN, CURRENT_TIMESTAMP, GDT.DelayCode
		FROM GMDelayTransactions GDT
		LEFT JOIN Vehicle V ON GDT.VehicleID = V.VehicleID
		LEFT JOIN Code C ON V.PickupLocationID = CONVERT(int,C.Value1)
		AND C.CodeType = 'GMLocationCode'
		WHERE V.CustomerID = @CustomerID
		AND GDT.DelayReportedInd = 1
		AND GDT.ReleaseReportedInd = 0
		AND GDT.DateReleased IS NOT NULL
		ORDER BY EventType, GDT.DelayCode, V.VIN

	SELECT @ErrorID = 0
	
	OPEN GM916ExportCursor

	BEGIN TRAN
	
	--set the default values
	SELECT @SCAC = 'DVAI'
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	FETCH GM916ExportCursor INTO @GMDelayTransactionsID, @VehicleID, @EventType,
		@CDLCode, @VIN, @RequestDateTime, @ReasonCode
	
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		INSERT INTO GMExport916(
			BatchID,
			VehicleID,
			EventType,
			SCAC,
			CDLCode,
			VIN,
			RequestDateTime,
			ReasonCode,
			ExportedInd,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@EventType,
			@SCAC,
			@CDLCode,
			@VIN,
			@RequestDateTime,
			@ReasonCode,
			@ExportedInd,
			@RecordStatus,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating GM Delay record'
			GOTO Error_Encountered
		END
			
		--update the delay transactiontable to flag the records as exported
		IF @EventType = 'CH'
		BEGIN
			UPDATE GMDelayTransactions
			SET DelayReportedInd = 1,
			DateDelayReported = CURRENT_TIMESTAMP
			WHERE GMDelayTransactionsID = @GMDelayTransactionsID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error updating delay transactions table'
				GOTO Error_Encountered
			END
		END
		ELSE IF @EventType = 'CR'
		BEGIN
			UPDATE GMDelayTransactions
			SET ReleaseReportedInd = 1,
			DateReleaseReported = CURRENT_TIMESTAMP
			WHERE GMDelayTransactionsID = @GMDelayTransactionsID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error updating delay transactions table'
				GOTO Error_Encountered
			END
		END
		FETCH GM916ExportCursor INTO @GMDelayTransactionsID, @VehicleID, @EventType,
			@CDLCode, @VIN, @RequestDateTime, @ReasonCode

	END --end of loop
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextGM916ExportBatchID'
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
		CLOSE GM916ExportCursor
		DEALLOCATE GM916ExportCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE GM916ExportCursor
		DEALLOCATE GM916ExportCursor
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
