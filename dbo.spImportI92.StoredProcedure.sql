USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportI92]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportI92] (@BatchID int, @CustomerCode varchar(20),
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	@ErrorEncountered	varchar(5000),
	@loopcounter		int,
	@ImportI92ID		int,
	@VendorInvoiceNumber	varchar(15),
	@VIN			varchar(17),
	@AuditReportCode	varchar(4),
	@ICLVoucherNumber	varchar(8),
	@AccountNumber		varchar(4),
	@RecordStatus		varchar(100),
	@VINCOUNT		int,
	@ExportICLR92ID		int,
	@CurrentAuditCode	varchar(4),
	@ReturnCode		int,
	@ReturnMessage		varchar(100),
	@Status			varchar(100),
	@ImportedInd		int,
	@ImportedDate		datetime,
	@ImportedBy		varchar(20),
	@UpdatedDate		datetime

	/************************************************************************
	*	spImportI92							*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the ImportI92 table and 	*
	*	updates the R92 records with the latest status code and date.	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	07/24/2006 CMK    Initial version				*
	*									*
	************************************************************************/
	
	SELECT @UpdatedDate = CURRENT_TIMESTAMP
	
	DECLARE ImportI92 CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT ImportI92ID,VendorInvoiceNumber,VIN,AccountNumber,
		AuditReportCode,ICLVoucherNumber
		FROM ImportI92
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY AuditReportCode DESC

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN ImportI92

	BEGIN TRAN

	FETCH ImportI92 INTO @ImportI92ID,@VendorInvoiceNumber,@VIN,@AccountNumber,
		@AuditReportCode,@ICLVoucherNumber
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM ExportICLR92 E
 		LEFT JOIN Vehicle V ON E.VehicleID = V.VehicleID
		WHERE V.VIN = @VIN
		AND E.InvoiceNumber = @VendorInvoiceNumber
		AND E.ICLAccountCode = @AccountNumber
		--AND ((@AccountNumber = '1430' AND E.ICLAccountCode = '1430')	--bit ugly but fuel is always billed/paid on 1430
		--OR (@AccountNumber <> '1430' AND E.ICLAccountCode <> '1430'))	--and transport can be billed on 1415 or 1450 and paid on different
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error getting vin count'
			GOTO Error_Encountered
		END

		IF @VINCOUNT = 1
		BEGIN
			--get the vehicle id
			SELECT @ExportICLR92ID = E.ExportICLR92ID,
			@CurrentAuditCode = LastAuditCodeReceived
			FROM ExportICLR92 E
			LEFT JOIN Vehicle V ON E.VehicleID = V.VehicleID
			WHERE V.VIN = @VIN
			AND E.InvoiceNumber = @VendorInvoiceNumber
			AND E.ICLAccountCode = @AccountNumber
			--AND ((@AccountNumber = '1430' AND E.ICLAccountCode = '1430')	--bit ugly but fuel is always billed/paid on 1430
			--OR (@AccountNumber <> '1430' AND E.ICLAccountCode <> '1430'))	--and transport can be billed on 1415 or 1450 and paid on different
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting last audit code'
				GOTO Error_Encountered
			END

			-- check the origin/destination
			IF @CurrentAuditCode = '9000'
			BEGIN
				SELECT @RecordStatus = 'ALREADY AUDIT CODE 9000'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Record_Status
			END
			
			--update logic here.
			UPDATE ExportICLR92
			SET LastAuditCodeReceived = @AuditReportCode,
			LastAuditCodeDate = @UpdatedDate,
			ICLVoucherNumber = @ICLVoucherNumber
			WHERE ExportICLR92ID = @ExportICLR92ID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING R92 RECORD'
				GOTO Error_Encountered
			END
			
			SELECT @RecordStatus = 'Imported'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = GetDate()
			SELECT @ImportedBy = @UserCode
		END
		ELSE IF @VINCOUNT > 1
		BEGIN
			SELECT @RecordStatus = 'MULTIPLE MATCHES FOR VIN'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
		END
		ELSE IF @VINCOUNT = 0
		BEGIN
			SELECT @RecordStatus = 'VIN NOT FOUND'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
		END
		
		--update logic here.
		Update_Record_Status:
		UPDATE ImportI92
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE ImportI92ID = @ImportI92ID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH ImportI92 INTO @ImportI92ID,@VendorInvoiceNumber,@VIN,@AccountNumber,
		@AuditReportCode,@ICLVoucherNumber

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ImportI92
		DEALLOCATE ImportI92
		PRINT 'ImportI92 Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ImportI92
		DEALLOCATE ImportI92
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			PRINT 'ImportI92 Error_Encountered =' + STR(@ErrorID)
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
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage

	RETURN
END
GO
