USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportPortStorageLocations]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportPortStorageLocations] (@BatchID int, @UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@ErrorEncountered		varchar(5000),
	@loopcounter		int,
	-- ImportPortStorageVehicles Variables
	@PortStorageVehicleLocationImportID	int,
	@VIN				varchar(17),
	@Location			varchar(20),
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@RecordStatus			varchar(100),
	-- PortStorageVehicles Variables
	@UpdatedDate			datetime,
	@UpdatedBy			varchar(20),
	-- Other Processing Variables
	@VINCount			int,
	@VehicleID			int,
	@OldBayLocation			varchar(20),
	@OldVehicleStatus		varchar(20),
	@OldDateRequested		datetime,
	@OldEstimatedPickupDate		datetime,
	@OldRequestPrintedInd		int,
	@OldDealerPrintDate		datetime,
	@OldDealerPrintBy		varchar(20),
	@OldRequestedBy			varchar(20),
	@Status				varchar(1000),
	@ReturnCode			int,
	@ReturnMessage			varchar(1000),
	@ErrorEncounteredInd		int

	/************************************************************************
	*	spImportPortStorageLocations					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the location data from the			*
	*	PortStorageVehicleLocationImport table and updates the Bay	*
	*	Location field in the PortStorageVehicles table.		*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	11/06/2006 CMK    Initial version				*
	*									*
	************************************************************************/
	
	DECLARE ImportPortStorageLocations CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT PortStorageVehicleLocationImportID, VIN, Location
		FROM PortStorageVehicleLocationImport
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY PortStorageVehicleLocationImportID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	SELECT @UpdatedDate = CURRENT_TIMESTAMP
	SELECT @UpdatedBy = @UserCode
	SELECT @ErrorEncounteredInd = 0
	
	OPEN ImportPortStorageLocations

	BEGIN TRAN

	FETCH ImportPortStorageLocations into @PortStorageVehicleLocationImportID, @VIN, @Location

	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		--see if the vin already exists as an open record.
		SELECT @VINCOUNT = COUNT(*)
		FROM PortStorageVehicles
		WHERE VIN = @VIN
		AND DateOut IS NULL
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error getting vin count'
			GOTO Error_Encountered
		END

		IF @VINCount = 0
		BEGIN
			SELECT @RecordStatus = 'VIN Not Found'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			SELECT @ErrorEncounteredInd = 1
			GOTO Update_Record
		END
		ELSE IF @VINCount = 1
		BEGIN	
			SELECT TOP 1 @VehicleID = PortStorageVehiclesID,
			@OldBayLocation = BayLocation,
			@OldVehicleStatus = VehicleStatus,
			@OldDateRequested = DateRequested,
			@OldEstimatedPickupDate = EstimatedPickupDate,
			@OldRequestPrintedInd = RequestPrintedInd,
			@OldDealerPrintDate = DealerPrintDate,
			@OldDealerPrintBy = DealerPrintBy,
			@OldRequestedBy = RequestedBy
			FROM PortStorageVehicles PSV
			WHERE PSV.VIN LIKE '%'+@VIN+'%'
			AND PSV.DateOut IS NULL
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the VehicleID'
				GOTO Error_Encountered
			END
	
			IF @OldBayLocation = 'GAT' AND @OldBayLocation <> @Location
			BEGIN
				SELECT @OldVehicleStatus = 'InInventory'
				SELECT @OldDateRequested = NULL
				SELECT @OldEstimatedPickupDate = NULL
				SELECT @OldRequestPrintedInd = NULL
				SELECT @OldDealerPrintDate = NULL
				SELECT @OldDealerPrintBy = NULL
				SELECT @OldRequestedBy = NULL
			END
			
			--and now do the vehicle
			UPDATE PortStorageVehicles
			SET BayLocation = @Location,
			VehicleStatus = @OldVehicleStatus,
			DateRequested = @OldDateRequested,
			EstimatedPickupDate = @OldEstimatedPickupDate,
			UpdatedDate = @UpdatedDate,
			UpdatedBy = @UpdatedBy
			WHERE PortStorageVehiclesID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
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
		UPDATE PortStorageVehicleLocationImport
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE PortStorageVehicleLocationImportID = @PortStorageVehicleLocationImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH ImportPortStorageLocations into @PortStorageVehicleLocationImportID, @VIN, @Location

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ImportPortStorageLocations
		DEALLOCATE ImportPortStorageLocations
		--PRINT 'ImportPortStorageVehicles Error_Encountered =' + STR(@ErrorID)
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
		CLOSE ImportPortStorageLocations
		DEALLOCATE ImportPortStorageLocations
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			--PRINT 'ImportPortStorageVehicles Error_Encountered =' + STR(@ErrorID)
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
