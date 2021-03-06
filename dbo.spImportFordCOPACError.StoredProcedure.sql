USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportFordCOPACError]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportFordCOPACError] (@BatchID int, @UserCode varchar(20)) 
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@FordImportCOPACErrorID		int,
	@VIN				varchar(17),
	@VINCOUNT			int,
	@Status				varchar(50),
	@CustomerID			int,
	@RecordStatus			varchar(50),
	@VehicleID			int,
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@ErrorEncounteredInd		int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@NeedsReviewInd			int
	
	/************************************************************************
	*	spImportFordCOPACError						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the FordImportCOPACError  	*
	*	table and updates it with the vehicle id.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	07/28/2010 CMK    Initial version				*
	*									*
	************************************************************************/

	SELECT @CustomerID = NULL
	SELECT @ErrorEncounteredInd = 0
	SELECT @NeedsReviewInd = 0
	
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

	--declare the cursor
	DECLARE FordCOPACErrorCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT FICE.FordImportCOPACErrorID, FICE.VIN
		FROM FordImportCOPACError FICE
		WHERE FICE.BatchID = @BatchID
		
	SELECT @ErrorID = 0
	
	OPEN FordCOPACErrorCursor

	BEGIN TRAN

	FETCH NEXT FROM FordCOPACErrorCursor INTO @FordImportCOPACErrorID, @VIN
	
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM Vehicle
		WHERE VIN = @VIN
		AND CustomerID = @CustomerID
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting VIN Count'
			GOTO Error_Encountered
		END
		--need to get the vehicle id
		IF @VINCOUNT = 0
		BEGIN
			SELECT @VehicleID = NULL
			SELECT @RecordStatus = 'VIN NOT FOUND'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = CURRENT_TIMESTAMP
			SELECT @ImportedBy = @UserCode
			SELECT @ErrorEncounteredInd = 1
			GOTO Do_Update
		END
		ELSE IF @VINCOUNT = 1
		BEGIN
			SELECT @VehicleID = VehicleID
			FROM Vehicle
			WHERE VIN = @VIN
			AND CustomerID = @CustomerID
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Getting VIN Count'
				GOTO Error_Encountered
			END
		END
		ELSE IF @VINCOUNT > 1
		BEGIN
			--need to figure out which vin, if multiples
			--IF THIS OCCURS MORE CODE WILL HAVE TO BE ADDED TO FIND THE VEHICLE
			SELECT @VehicleID = NULL
			SELECT @RecordStatus = 'MULTIPLE MATCHES ON VIN'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = CURRENT_TIMESTAMP
			SELECT @ImportedBy = @UserCode
			SELECT @ErrorEncounteredInd = 1
			GOTO Do_Update
		END
		
		SELECT @RecordStatus = 'Imported'
		SELECT @ImportedInd = 1
		SELECT @ImportedDate = CURRENT_TIMESTAMP
		SELECT @ImportedBy = @UserCode
		
		--update logic here.
		Do_Update:
		UPDATE FordImportCOPACError
		SET VehicleID = @VehicleID,
		RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE FordImportCOPACErrorID = @FordImportCOPACErrorID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Updating Ford COPAC Error Import'
			GOTO Error_Encountered
		END
		
		FETCH NEXT FROM FordCOPACErrorCursor INTO @FordImportCOPACErrorID, @VIN
	END

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE FordCOPACErrorCursor
		DEALLOCATE FordCOPACErrorCursor
		IF @ErrorEncounteredInd = 0
		BEGIN
			SELECT @ReturnCode = 0
			SELECT @ReturnMessage = 'Processing Completed Successfully'
		END
		ELSE
		BEGIN
			SELECT @ReturnCode = 0
			SELECT @ReturnMessage = 'Processing Completed, But With Errors'
		END
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE FordCOPACErrorCursor
		DEALLOCATE FordCOPACErrorCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = 'Error Encountered'
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
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage, @NeedsReviewInd AS NeedsReviewInd

	RETURN
END
GO
