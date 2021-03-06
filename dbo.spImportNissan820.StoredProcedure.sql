USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportNissan820]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROC [dbo].[spImportNissan820] (@BatchID int, @UserCode varchar(20)) 
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@ImportNissan820ID		int,
	@VehicleReferenceIdentification	varchar(17),
	@SellersInvoiceNumber		varchar(20),
	@ChargeType			varchar(3),
	@ChargePaymentAmount		decimal(19,2),
	@VINCOUNT			int,
	@Status				varchar(50),
	@RecordStatus			varchar (50),
	@VehicleID			int,
	@NissanCustomerID		int,
	@NissanManualCustomerID		int,
	@NissanExportWWLInvoiceID	int,
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@ErrorEncounteredInd		int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100)

	/************************************************************************
	*	spImportNissan820						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the NissanImport820  	*
	*	table and updates it with the vehicle id.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/18/2008 CMK    Initial version				*
	*									*
	************************************************************************/

	SELECT @ErrorEncounteredInd = 0
	
	SELECT @NissanCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NissanCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Nissan CustomerID'
		GOTO Error_Encountered2
	END
	IF @NissanCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Nissan CustomerID Not Found'
		GOTO Error_Encountered2
	END

	SELECT @NissanManualCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NissanManualCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Nissan Manual CustomerID'
		GOTO Error_Encountered2
	END
	IF @NissanManualCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Nissan Manual CustomerID Not Found'
		GOTO Error_Encountered2
	END

	DECLARE Nissan820Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT ImportNissan820ID, VehicleReferenceIdentification, SellersInvoiceNumber, ChargeType, ChargePaymentAmount
		FROM ImportNissan820
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY ImportNissan820ID

	SELECT @ErrorID = 0
	
	OPEN Nissan820Cursor

	BEGIN TRAN

	FETCH NEXT FROM Nissan820Cursor INTO @ImportNissan820ID, @VehicleReferenceIdentification, @SellersInvoiceNumber, @ChargeType, @ChargePaymentAmount
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @VINCount = 0
		SELECT @VehicleID = NULL
		SELECT @NissanExportWWLInvoiceID = NULL
		
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM NissanExportWWLInvoice N
		WHERE N.VIN = @VehicleReferenceIdentification
		AND N.InvoiceNumber = @SellersInvoiceNumber
		AND N.ExpenseType = CASE WHEN @ChargeType = 'F10' THEN 'FREIGHT' WHEN @ChargeType = 'F11' THEN 'FUELSUR' ELSE 'ERROR' END
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

		IF @VINCOUNT = 1
		BEGIN
			--get the vehicle id
			SELECT TOP 1 @VehicleID = VehicleID,
			@NissanExportWWLInvoiceID = NissanExportWWLInvoiceID
			FROM NissanExportWWLInvoice N
			WHERE N.VIN = @VehicleReferenceIdentification
			AND N.InvoiceNumber = @SellersInvoiceNumber
			AND N.ExpenseType = CASE WHEN @ChargeType = 'F10' THEN 'FREIGHT' WHEN @ChargeType = 'F11' THEN 'FUELSUR' ELSE 'ERROR' END
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
		ELSE IF @VINCOUNT > 1
		BEGIN
			SELECT @VehicleID = NULL
			SELECT @RecordStatus = 'MULTIPLE MATCHES FOR VIN'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			SELECT @ErrorEncounteredInd = 1
			GOTO Do_Update
		END
		ELSE
		BEGIN
			--see if we can find the vin without the invoice number
			IF @ChargeType = 'F10'
			BEGIN
				SELECT @VINCOUNT = COUNT(*)
				FROM Vehicle
				WHERE VIN = @VehicleReferenceIdentification
				AND VehicleStatus = 'Delivered'
				AND BilledInd = 1
				AND CustomerID IN (@NissanCustomerID, @NissanManualCustomerID)
				AND ChargeRate = @ChargePaymentAmount
				/*
				FROM NissanExportWWLInvoice N
				WHERE N.VIN = @VehicleReferenceIdentification
				AND N.ExpenseType = CASE WHEN @ChargeType = 'F10' THEN 'FREIGHT' WHEN @ChargeType = 'F11' THEN 'FUELSUR' ELSE 'ERROR' END
				*/
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
				IF @VINCOUNT = 1
				BEGIN
					--get the vehicle id
					SELECT TOP 1 @VehicleID = VehicleID --,
					--@NissanExportWWLInvoiceID = NissanExportWWLInvoiceID
					FROM Vehicle
					WHERE VIN = @VehicleReferenceIdentification
					AND VehicleStatus = 'Delivered'
					AND BilledInd = 1
					AND CustomerID IN (@NissanCustomerID, @NissanManualCustomerID)
					AND ChargeRate = @ChargePaymentAmount
					/*
					FROM NissanExportWWLInvoice N
					WHERE N.VIN = @VehicleReferenceIdentification
					AND N.ExpenseType = CASE WHEN @ChargeType = 'F10' THEN 'FREIGHT' WHEN @ChargeType = 'F11' THEN 'FUELSUR' ELSE 'ERROR' END
					*/
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
				ELSE IF @VINCOUNT > 1
				BEGIN
					SELECT @VehicleID = NULL
					SELECT @RecordStatus = 'MULTIPLE MATCHES FOR VIN'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					SELECT @ErrorEncounteredInd = 1
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
		END
		--update logic here.
		
		Do_Update:
		UPDATE ImportNissan820
		SET VehicleID = @VehicleID,
		NissanExportWWLInvoiceID = @NissanExportWWLInvoiceID,
		RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE ImportNissan820ID = @ImportNissan820ID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @ErrorEncounteredInd = 1
		END

		FETCH NEXT FROM Nissan820Cursor INTO @ImportNissan820ID, @VehicleReferenceIdentification, @SellersInvoiceNumber, @ChargeType, @ChargePaymentAmount

	END

	Error_Encountered:
	IF @ErrorEncounteredInd = 0
	BEGIN
		COMMIT TRAN
		CLOSE Nissan820Cursor
		DEALLOCATE Nissan820Cursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		COMMIT TRAN
		CLOSE Nissan820Cursor
		DEALLOCATE Nissan820Cursor
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
