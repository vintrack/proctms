USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportGM915]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportGM915] (@BatchID int,
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	@loopcounter		int,
	@GMImport915ID		int,
	@VehicleID		int,
	@VIN			varchar(17),
	@GMStatusCode		varchar(1),
	@ImportedInd		int,
	@ImportedDate		datetime,
	@ImportedBy		varchar(20),
	@RecordStatus		varchar(100),
	@CreationDate		datetime,
	@CreatedBy		varchar(20),
	@CustomerID		int,
	@ReturnCode		int,
	@ReturnMessage		varchar(100),
	@NeedsReviewInd		int,
	@Count			int,
	@Status			varchar(100)

	/************************************************************************
	*	spImportGM915							*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the GMImport915 table and	*
	*	assigns the vehicleid to the record				*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	11/19/2013 CMK    Initial version				*
	*									*
	************************************************************************/
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @NeedsReviewInd = 0
	
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

	DECLARE GM915Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT GMImport915ID, VIN, GMStatusCode
		FROM GMImport915
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY GMImport915ID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN GM915Cursor

	BEGIN TRAN

	FETCH GM915Cursor INTO @GMImport915ID, @VIN, @GMStatusCode

	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @Count = COUNT(*)
		FROM Vehicle
		WHERE VIN = @VIN
		AND CustomerID = @CustomerID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error getting vin count'
			GOTO Error_Encountered
		END
	
		IF @Count > 0
		BEGIN
			--see if there are any changes to the origin/destination
			SELECT TOP 1 @VehicleID = V.VehicleID
			FROM Vehicle V
			WHERE V.VIN = @VIN
			AND V.CustomerID = @CustomerID
			ORDER BY V.VehicleID DESC	--want the most recent vehicle if multiples
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING VEHICLE STATUS'
				GOTO Error_Encountered
			END
			
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = GetDate()
			SELECT @ImportedBy = @UserCode
			
			IF @GMStatusCode = 'R'
			BEGIN
				SELECT @RecordStatus = 'REJECTED'
				SELECT @NeedsReviewInd = 1
			END
			ELSE IF @GMStatusCode = 'W'
			BEGIN
				SELECT @RecordStatus = 'WARNING'
				SELECT @NeedsReviewInd = 1
			END
			ELSE
			BEGIN
				SELECT @RecordStatus = 'Imported'
			END
		END
		ELSE
		BEGIN
			SELECT @NeedsReviewInd = 1
			SELECT @VehicleID = NULL
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			SELECT @RecordStatus = 'VIN NOT FOUND'
		END
			
		--update logic here.
		Update_Record_Status:
		UPDATE GMImport915
		SET VehicleID = @VehicleID,
		RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE GMImport915ID = @GMImport915ID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END
		
		FETCH GM915Cursor INTO @GMImport915ID, @VIN, @GMStatusCode

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE GM915Cursor
		DEALLOCATE GM915Cursor
		PRINT 'GM Import 915 Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE GM915Cursor
		DEALLOCATE GM915Cursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			PRINT 'GM Import 915 Error_Encountered =' + STR(@ErrorID)
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
