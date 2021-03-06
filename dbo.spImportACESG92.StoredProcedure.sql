USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportACESG92]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportACESG92] (@BatchID int, @CustomerCode varchar(20),
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	@ErrorEncountered	varchar(5000),
	@loopcounter		int,
	@ACESImportG92ID	int,
	@VendorInvoiceNumber	varchar(15),
	@VIN			varchar(17),
	@AuditReportCode	varchar(4),
	@ACESVoucherNumber	varchar(8),
	@RecordStatus		varchar(100),
	@VINCOUNT		int,
	@ACESExportR92ID	int,
	@CurrentAuditCode	varchar(4),
	@ReturnCode		int,
	@ReturnMessage		varchar(100),
	@NeedsReviewInd		int,
	@Status			varchar(100),
	@ImportedInd		int,
	@ImportedDate		datetime,
	@ImportedBy		varchar(20),
	@UpdatedDate		datetime

	/************************************************************************
	*	spImportACESG92							*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the ACESImportG92 table and 	*
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
	SELECT @NeedsReviewInd = 0
	
	DECLARE ImportACESG92 CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT ACESImportG92ID,VendorInvoiceNumber,VIN,
		AuditReportCode,VoucherNumber
		FROM ACESImportG92
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY AuditReportCode DESC

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN ImportACESG92

	BEGIN TRAN

	FETCH ImportACESG92 INTO @ACESImportG92ID,@VendorInvoiceNumber,@VIN,
		@AuditReportCode,@ACESVoucherNumber
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM ACESExportR92 E
 		LEFT JOIN Vehicle V ON E.VehicleID = V.VehicleID
		WHERE V.VIN = @VIN
		AND E.InvoiceNumber = @VendorInvoiceNumber
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error getting vin count'
			GOTO Error_Encountered
		END

		IF @VINCOUNT =1
		BEGIN
			--get the vehicle id
			SELECT @ACESExportR92ID = E.ACESExportR92ID,
			@CurrentAuditCode = LastAuditCodeReceived
			FROM ACESExportR92 E
			LEFT JOIN Vehicle V ON E.VehicleID = V.VehicleID
			WHERE V.VIN = @VIN
			AND E.InvoiceNumber = @VendorInvoiceNumber
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
			UPDATE ACESExportR92
			SET LastAuditCodeReceived = @AuditReportCode,
			LastAuditCodeDate = @UpdatedDate,
			ACESVoucherNumber = @ACESVoucherNumber
			WHERE ACESExportR92ID = @ACESExportR92ID
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
			SELECT @NeedsReviewInd = 1
			SELECT @RecordStatus = 'MULTIPLE MATCHES FOR VIN'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
		END
		ELSE IF @VINCOUNT = 0
		BEGIN
			SELECT @NeedsReviewInd = 1
			SELECT @RecordStatus = 'VIN NOT FOUND'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL			
		END
		
		--update logic here.
		Update_Record_Status:
		UPDATE ACESImportG92
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE ACESImportG92ID = @ACESImportG92ID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH ImportACESG92 INTO @ACESImportG92ID,@VendorInvoiceNumber,@VIN,
		@AuditReportCode,@ACESVoucherNumber

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ImportACESG92
		DEALLOCATE ImportACESG92
		PRINT 'ImportACESG92 Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ImportACESG92
		DEALLOCATE ImportACESG92
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
	BEGIN
		PRINT 'ImportACESG92 Error_Encountered =' + STR(@ErrorID)
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
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage, @NeedsReviewInd AS NeedsReviewInd

	RETURN
END
GO
