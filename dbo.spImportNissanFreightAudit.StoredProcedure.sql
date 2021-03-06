USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportNissanFreightAudit]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportNissanFreightAudit] (@BatchID int, @UserCode varchar(20)) 
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@NissanImportFreightAuditID	int,
	@NMCBillOfLadingID		varchar(10),
	@InvoiceID			varchar(10),
	@VINCOUNT			int,
	@Status				varchar(50),
	@CustomerID			int,
	@RecordStatus			varchar (50),
	@VehicleID			int,
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@ErrorEncounteredInd		int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100)

	/************************************************************************
	*	spImportNissanFreightAudit					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the NissanImportFreightAudit	*
	*	table and updates it with the vehicle id.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	09/15/2005 CMK    Initial version				*
	*									*
	************************************************************************/

	SELECT @CustomerID = NULL
	SELECT @ErrorEncounteredInd = 0
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NissanCustomerID'
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

	DECLARE NissanFreightAuditCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT NissanImportFreightAuditID, NMCBillOfLadingID, InvoiceID
		FROM NissanImportFreightAudit
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY NissanImportFreightAuditID

	SELECT @ErrorID = 0
	
	OPEN NissanFreightAuditCursor

	BEGIN TRAN

	FETCH NEXT FROM NissanFreightAuditCursor INTO @NissanImportFreightAuditID, @NMCBillOfLadingID, @InvoiceID
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM Vehicle V
		LEFT JOIN Billing B ON V.BillingID = B.BillingID
		WHERE V.CustomerIdentification = @NMCBillOfLadingID
		AND V.CustomerID = @CustomerID
		AND B.InvoiceNumber = @InvoiceID
		IF @@Error <> 0
		BEGIN
			SELECT @VehicleID = NULL
			SELECT @RecordStatus = 'ERROR GETTING VIN COUNT'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			SELECT @ErrorEncounteredInd = 1
			GOTO Do_Update
		END

		IF @VINCOUNT > 0
		BEGIN
			--get the vehicle id
			SELECT TOP 1 @VehicleID = V.VehicleID
			FROM Vehicle V
			LEFT JOIN Billing B ON V.BillingID = B.BillingID
			WHERE V.CustomerIdentification = @NMCBillOfLadingID
			AND V.CustomerID = @CustomerID
			AND B.InvoiceNumber = @InvoiceID
			ORDER BY VehicleID  DESC
			IF @@Error <> 0
			BEGIN
				SELECT @VehicleID = NULL
				SELECT @RecordStatus = 'ERROR GETTING VEHICLE ID'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				SELECT @ErrorEncounteredInd = 1
				GOTO Do_Update
			END
			SELECT @RecordStatus = 'Imported'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = CURRENT_TIMESTAMP
			SELECT @ImportedBy = @UserCode
		END
		ELSE
		BEGIN
			SELECT @VehicleID = NULL
			SELECT @RecordStatus = 'VIN NOT FOUND'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			SELECT @ErrorEncounteredInd = 1
		END
		--update logic here.
		
		Do_Update:
		UPDATE NissanImportFreightAudit
		SET VehicleID = @VehicleID,
		RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE NissanImportFreightAuditID = @NissanImportFreightAuditID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @ErrorEncounteredInd = 1
		END

		FETCH NEXT FROM NissanFreightAuditCursor INTO @NissanImportFreightAuditID, @NMCBillOfLadingID, @InvoiceID

	END

	Error_Encountered:
	IF @ErrorEncounteredInd = 0
	BEGIN
		COMMIT TRAN
		CLOSE NissanFreightAuditCursor
		DEALLOCATE NissanFreightAuditCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		COMMIT TRAN
		CLOSE NissanFreightAuditCursor
		DEALLOCATE NissanFreightAuditCursor
		SELECT @ReturnCode = 100000
		SELECT @ReturnMessage = 'Processing Completed, But With Errors'
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
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage

	RETURN
END
GO
