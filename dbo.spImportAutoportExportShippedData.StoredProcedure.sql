USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportAutoportExportShippedData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportAutoportExportShippedData] (@BatchID int, @UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@ErrorEncountered		varchar(5000),
	@loopcounter		int,
	-- ImportPortStorageVehicles Variables
	@AutoportExportShippedVehiclesImportID	int,
	@VIN				varchar(17),
	@DateShipped			datetime,
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@RecordStatus			varchar(100),
	-- AutoportExportVehicles Variables
	@UpdatedDate			datetime,
	@UpdatedBy			varchar(20),
	-- Other Processing Variables
	@AutoportExportVehiclesID	int,
	@VINCount			int,
	@Status				varchar(1000),
	@ReturnCode			int,
	@ReturnMessage			varchar(1000),
	@ErrorEncounteredInd		int

	/************************************************************************
	*	spImportAutoportExportShippedData				*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the vin data from the			*
	*	AutoportExportShippedVehiclesImport table and updates the Date	*
	*	Shipped field in the AutoportExportVehicles table.		*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	07/31/2007 CMK    Initial version				*
	*									*
	************************************************************************/
	
	DECLARE ImportAutoportExportShippedData CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT AutoportExportShippedVehiclesImportID, VIN, DateShipped
		FROM AutoportExportShippedVehiclesImport
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY VIN

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	SELECT @UpdatedDate = CURRENT_TIMESTAMP
	SELECT @UpdatedBy = @UserCode
	SELECT @ErrorEncounteredInd = 0
	
	OPEN ImportAutoportExportShippedData

	BEGIN TRAN

	FETCH ImportAutoportExportShippedData into @AutoportExportShippedVehiclesImportID, @VIN, @DateShipped

	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		--see if the vin already exists as an open record.
		SELECT @VINCOUNT = COUNT(*)
		FROM AutoportExportVehicles
		WHERE VIN = @VIN
		AND DateShipped IS NULL
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error getting vin count'
			GOTO Error_Encountered
		END

		IF @VINCount = 0
		BEGIN
			SELECT @VINCOUNT = COUNT(*)
			FROM AutoportExportVehicles
			WHERE VIN = @VIN
			AND DateShipped IS NOT NULL
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting vin count'
				GOTO Error_Encountered
			END
			
			IF @VINCOUNT > 0
			BEGIN
				SELECT @RecordStatus = 'Already Shows as Shipped'
			END
			ELSE
			BEGIN
				SELECT @RecordStatus = 'VIN Not Found'
			END
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			SELECT @ErrorEncounteredInd = 1
			GOTO Update_Record
		END
		ELSE IF @VINCount = 1
		BEGIN	
			SELECT @VINCOUNT = COUNT(*)
			FROM AutoportExportVehicles
			WHERE VIN = @VIN
			AND CustomsApprovedDate IS NOT NULL
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting vin count'
				GOTO Error_Encountered
			END
			
			IF @VINCOUNT = 0
			BEGIN
				SELECT @RecordStatus = 'CUSTOMS CLEARED DATE IS BLANK'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				SELECT @ErrorEncounteredInd = 1
				GOTO Update_Record
			END
			
			SELECT @AutoportExportVehiclesID = AutoportExportVehiclesID
			FROM AutoportExportVehicles
			WHERE VIN = @VIN
			AND CustomsApprovedDate IS NOT NULL
			AND DateShipped IS NULL
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting vin count'
				GOTO Error_Encountered
			END
			
			--and now do the vehicle
			UPDATE AutoportExportVehicles
			SET DateShipped = @DateShipped,
			VehicleStatus = 'Shipped',
			UpdatedDate = @UpdatedDate,
			UpdatedBy = @UpdatedBy
			WHERE AutoportExportVehiclesID = @AutoportExportVehiclesID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
				GOTO Error_Encountered
			END
			
			INSERT INTO AEVehicleStatusHistory(
				AutoportExportVehiclesID,
				VehicleStatus,
				StatusDate,
				CreationDate,
				CreatedBy
			)
			VALUES(
				@AutoportExportVehiclesID,
				'Shipped',
				@DateShipped,
				@UpdatedDate,
				@UserCode
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error adding Status History Record'
				GOTO Error_Encountered
			END
			
			SELECT @RecordStatus = 'Imported'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = GetDate()
			SELECT @ImportedBy = @UserCode
		END
		ELSE
		BEGIN
			SELECT @RecordStatus = 'Multiple Matches On VIN'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			SELECT @ErrorEncounteredInd = 1
			GOTO Update_Record
		END

		--update logic here.
		Update_Record:
		UPDATE AutoportExportShippedVehiclesImport
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE AutoportExportShippedVehiclesImportID = @AutoportExportShippedVehiclesImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH ImportAutoportExportShippedData INTO @AutoportExportShippedVehiclesImportID, @VIN, @DateShipped

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ImportAutoportExportShippedData
		DEALLOCATE ImportAutoportExportShippedData
		--PRINT 'ImportAutoportExportShippedData Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		IF @ErrorEncounteredInd = 0
		BEGIN
			SELECT @ReturnMessage = 'Processing Completed Successfully'
		END
		ELSE
		BEGIN
			SELECT @ReturnMessage = 'Processing Completed, But With Errors'
		END
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ImportAutoportExportShippedData
		DEALLOCATE ImportAutoportExportShippedData
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			--PRINT 'ImportAutoportExportShippedData Error_Encountered =' + STR(@ErrorID)
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
