USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportGM900]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportGM900] (@BatchID int,
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	@loopcounter		int,
	@GMImport900ID		int,
	@VehicleID		int,
	@VIN			varchar(17),
	@StatusCode		varchar(1),
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
	*	spImportGM900							*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the GMImport900 table and	*
	*	assigns the vehicleid to the record				*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	10/28/2013 CMK    Initial version				*
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

	DECLARE GM900Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT GMImport900ID, VIN, StatusCode
		FROM GMImport900
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY GMImport900ID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN GM900Cursor

	BEGIN TRAN

	FETCH GM900Cursor INTO @GMImport900ID, @VIN, @StatusCode
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
			
			IF @StatusCode = 'A'
			BEGIN
				SELECT @RecordStatus = 'Imported'
			END
			ELSE IF @StatusCode = 'R'
			BEGIN
				SELECT @RecordStatus = 'REJECTED'
				SELECT @NeedsReviewInd = 1
			END
			ELSE IF @StatusCode = 'W'
			BEGIN
				SELECT @RecordStatus = 'WARNING'
				SELECT @NeedsReviewInd = 1
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
		UPDATE GMImport900
		SET VehicleID = @VehicleID,
		RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE GMImport900ID = @GMImport900ID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END
		
		FETCH GM900Cursor INTO @GMImport900ID, @VIN, @StatusCode
		
	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE GM900Cursor
		DEALLOCATE GM900Cursor
		PRINT 'GM Import 900 Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE GM900Cursor
		DEALLOCATE GM900Cursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			PRINT 'GM Import 900 Error_Encountered =' + STR(@ErrorID)
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
