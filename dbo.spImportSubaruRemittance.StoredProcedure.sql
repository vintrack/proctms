USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportSubaruRemittance]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportSubaruRemittance] (@BatchID int, @UserCode varchar(20)) 
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@SubaruRemittanceImportID	int,
	@VINKey				varchar(8),
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
	*	spImportSubaruRemittance					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the SubaruRemittanceImport  	*
	*	table and updates it with the vehicle id.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	05/16/2005 CMK    Initial version				*
	*									*
	************************************************************************/

	SELECT @CustomerID = NULL
	SELECT @ErrorEncounteredInd = 0
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SOACustomerID'
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

	DECLARE SubaruRemittanceCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT SubaruRemittanceImportID, VINKey
		FROM SubaruRemittanceImport
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY SubaruRemittanceImportID

	SELECT @ErrorID = 0
	
	OPEN SubaruRemittanceCursor

	BEGIN TRAN

	FETCH NEXT FROM SubaruRemittanceCursor INTO @SubaruRemittanceImportID, @VINKey
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM Vehicle
		WHERE RIGHT(VIN,8) = @VINKey
		AND CustomerID = @CustomerID
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
			SELECT @VehicleID = VehicleID
			FROM Vehicle
			WHERE RIGHT(VIN,8) = @VINKey
			AND CustomerID = @CustomerID
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
		UPDATE SubaruRemittanceImport
		SET VehicleID = @VehicleID,
		RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE SubaruRemittanceImportID = @SubaruRemittanceImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @ErrorEncounteredInd = 1
		END

		FETCH NEXT FROM SubaruRemittanceCursor INTO @SubaruRemittanceImportID, @VINKey

	END

	Error_Encountered:
	IF @ErrorEncounteredInd = 0
	BEGIN
		COMMIT TRAN
		CLOSE SubaruRemittanceCursor
		DEALLOCATE SubaruRemittanceCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		COMMIT TRAN
		CLOSE SubaruRemittanceCursor
		DEALLOCATE SubaruRemittanceCursor
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
