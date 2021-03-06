USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportHondaPayment]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportHondaPayment] (@BatchID int, @UserCode varchar(20)) 
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@HondaImportPaymentID		int,
	@VIN				varchar(17),
	@CarrierInvoiceNumber		varchar(20),
	@VINCOUNT			int,
	@Status				varchar(50),
	@CustomerID			int,
	--@ManualCustomerID		int,
	@RecordStatus			varchar (50),
	@VehicleID			int,
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@ErrorEncounteredInd		int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100)

	/************************************************************************
	*	spImportHondaPayment						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the HondaImportPayment  	*
	*	table and updates it with the vehicle id.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/18/2010 CMK    Initial version				*
	*									*
	************************************************************************/

	SELECT @CustomerID = NULL
	SELECT @ErrorEncounteredInd = 0
	
	--get the Honda customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'HondaCustomerID'
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

	/*
	--get the Honda Manual customer id from the setting table
	SELECT @ManualCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NissanManualCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting CustomerID'
		GOTO Error_Encountered2
	END
	IF @ManualCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'CustomerID Not Found'
		GOTO Error_Encountered2
	END
	*/

	DECLARE HondaPaymentCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT HondaImportPaymentID, VIN, CarrierInvoiceNumber
		FROM HondaImportPayment
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY HondaImportPaymentID

	SELECT @ErrorID = 0
	
	OPEN HondaPaymentCursor

	BEGIN TRAN

	FETCH NEXT FROM HondaPaymentCursor INTO @HondaImportPaymentID, @VIN, @CarrierInvoiceNumber
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM Vehicle V
		LEFT JOIN Billing B ON V.BillingID = B.BillingID
		WHERE V.VIN = @VIN
		AND V.CustomerID = @CustomerID --IN (@CustomerID,@ManualCustomerID)
		AND B.InvoiceNumber = @CarrierInvoiceNumber
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
			WHERE V.VIN = @VIN
			AND V.CustomerID = @CustomerID --IN (@CustomerID,@ManualCustomerID)
			AND B.InvoiceNumber = @CarrierInvoiceNumber
			ORDER BY V.VehicleID  DESC
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
		UPDATE HondaImportPayment
		SET VehicleID = @VehicleID,
		RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE HondaImportPaymentID = @HondaImportPaymentID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @ErrorEncounteredInd = 1
		END

		FETCH NEXT FROM HondaPaymentCursor INTO @HondaImportPaymentID, @VIN, @CarrierInvoiceNumber

	END

	Error_Encountered:
	IF @ErrorEncounteredInd = 0
	BEGIN
		COMMIT TRAN
		CLOSE HondaPaymentCursor
		DEALLOCATE HondaPaymentCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		COMMIT TRAN
		CLOSE HondaPaymentCursor
		DEALLOCATE HondaPaymentCursor
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
