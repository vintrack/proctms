USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportAutoportExportVoyageLoadList]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportAutoportExportVoyageLoadList] (@BatchID int, @UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@ErrorEncountered		varchar(5000),
	@loopcounter			int,
	--AEVoyageLoadListImport variables
	@CustomerID			int,
	@VoyageID			int,
	@AEVoyageLoadListImportID	int,
	@VIN				varchar(17),
	--processing variables
	@NextVoyageID			int,
	@DestinationName		varchar(20),
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@VehicleDestinationName		varchar(100),
	@VehicleCustomerID		int,
	@VehicleVoyageID		int,
	@VehicleCustomsApprovedDate	datetime,
	@VehicleDateShipped		datetime,
	@VINCount			int,
	@VehicleID			int,
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	@CreatedBy			varchar(20),
	@Status				varchar(1000),
	@ReturnCode			int,
	@ReturnMessage			varchar(1000),
	@ErrorEncounteredInd		int

	/****************************************************************************************
	*	spImportAutoportExportVoyageLoadList						*
	*											*
	*	Description									*
	*	-----------									*
	*	This procedure takes the data from the ImportAutoportExportVoyageLoadList	*
	*	table and makes sure that all of the vehicles from the list are on the voyage	*
	*	and that any vehicles that are not in the list are moved to the next voayge.	*
	*											*
	*	Change History									*
	*	--------------									*
	*	Date       Init's Description							*
	*	---------- ------ ----------------------------------------			*
	*	03/02/2010 CMK    Initial version						*
	*											*
	****************************************************************************************/
	
	SELECT TOP 1 @CustomerID = CustomerID, @VoyageID = VoyageID
	FROM AEVoyageLoadListImport
	WHERE BatchID = @BatchID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Customer ID'
		GOTO Error_Encountered
	END

	-- cursor for vehicles that should be on the voyage
	DECLARE LoadListCursor CURSOR
		LOCAL FORWARD_ONLY STATIC READ_ONLY
		FOR
			SELECT I.AEVoyageLoadListImportID, I.VIN, AEV.AutoportExportVehiclesID,
			I.DestinationName, AEV.DestinationName, AEV.CustomerID, AEV.VoyageID,
			AEV.CustomsApprovedDate
			FROM AEVoyageLoadListImport I
			LEFT JOIN AutoportExportVehicles AEV ON I.VIN = AEV.VIN
			AND AEV.DateShipped IS NULL
			WHERE I.BatchID = @BatchID
			ORDER BY AEVoyageLoadListImportID
	
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = @UserCode
	SELECT @ErrorEncounteredInd = 0
	
	OPEN LoadListCursor
	
	BEGIN TRAN

	FETCH LoadListCursor INTO @AEVoyageLoadListImportID, @VIN,
		@VehicleID, @DestinationName, @VehicleDestinationName, @VehicleCustomerID,
		@VehicleVoyageID, @VehicleCustomsApprovedDate
		
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @VehicleID IS NULL
		BEGIN
			SELECT @ErrorEncounteredInd = 1
			SELECT @RecordStatus = 'VIN NOT FOUND'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			GOTO Update_Record
		END
		
		IF @CustomerID <> @VehicleCustomerID
		BEGIN
			SELECT @ErrorEncounteredInd = 1
			SELECT @RecordStatus = 'CUSTOMER MISMATCH'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			GOTO Update_Record
		END
		
		IF @DestinationName <> @VehicleDestinationName
		BEGIN
			SELECT @ErrorEncounteredInd = 1
			SELECT @RecordStatus = 'DESTINATION MISMATCH'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			GOTO Update_Record
		END
		
		IF @VehicleCustomsApprovedDate IS NULL
		BEGIN
			SELECT @ErrorEncounteredInd = 1
			SELECT @RecordStatus = 'VEHICLE IS NOT APPROVED'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			GOTO Update_Record
		END
		
		IF @VoyageID <> @VehicleVoyageID
		BEGIN
			UPDATE AutoportExportVehicles
			SET VoyageID = @VoyageID
			WHERE VIN = @VIN
			AND AutoportExportVehiclesID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Updating Vehicle Record'
				GOTO Error_Encountered
			END
			
			SELECT @RecordStatus = 'Voyage Updated'
			
			GOTO Update_Record				
		END
		ELSE
		BEGIN
			SELECT @RecordStatus = 'Imported'
		END
		
		SELECT @ImportedInd = 1
		SELECT @ImportedDate = CURRENT_TIMESTAMP
		SELECT @ImportedBy = @UserCode
		
		--update logic here.
		Update_Record:
		UPDATE AEVoyageLoadListImport
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedBy = @ImportedBy,
		ImportedDate = @ImportedDate
		WHERE AEVoyageLoadListImportID = @AEVoyageLoadListImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH LoadListCursor INTO @AEVoyageLoadListImportID, @VIN,
			@VehicleID, @DestinationName, @VehicleDestinationName, @VehicleCustomerID,
			@VehicleVoyageID, @VehicleCustomsApprovedDate

	END --end of loop
	
	CLOSE LoadListCursor
	DEALLOCATE LoadListCursor

	-- cursor for vehicles were not in the voyage load list, but are on the voyage
	DECLARE LoadListCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT AEV.AutoportExportVehiclesID, AEV.VIN, AEV.DestinationName, AEV.CustomsApprovedDate,
			AEV.DateShipped
		FROM AutoportExportVehicles AEV
		WHERE AEV.VoyageID = @VoyageID
		AND AEV.CustomerID = @CustomerID
		AND AEV.VIN NOT IN (SELECT I.VIN FROM AEVoyageLoadListImport I WHERE I.BatchID = @BatchID)
		ORDER BY AEV.VIN
		
	OPEN LoadListCursor
		
	FETCH LoadListCursor INTO @VehicleID, @VIN, @VehicleDestinationName, @VehicleCustomsApprovedDate,
		@VehicleDateShipped
			
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @NextVoyageID = NULL
		
		IF @VehicleDateShipped IS NOT NULL
		BEGIN
			SELECT @ErrorEncounteredInd = 1
			SELECT @RecordStatus = 'VEHICLE SHOWS AS SHIPPED'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			GOTO Insert_Record
		END
			
		IF @VehicleCustomsApprovedDate IS NOT NULL
		BEGIN
			SELECT @ErrorEncounteredInd = 1
			SELECT @RecordStatus = 'APPROVED VEHICLE NOT IN LOAD LIST'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			GOTO Insert_Record
		END
			
		SELECT TOP 1 @NextVoyageID = AEV.AEVoyageID
		FROM AEVoyage AEV
		LEFT JOIN AEVoyageDestination AEVD ON AEV.AEVoyageID = AEVD.AEVoyageID
		LEFT JOIN AEVoyageCustomer AEVC ON AEV.AEVoyageID = AEVC.AEVoyageID
		WHERE AEV.VoyageClosedInd = 0
		AND AEV.AEVoyageID <> @VoyageID
		AND AEV.VoyageDate >= CONVERT(varchar(10),CURRENT_TIMESTAMP,101)
		AND AEVD.DestinationName = @VehicleDestinationName
		AND AEVC.CustomerID = @CustomerID
		ORDER BY AEV.VoyageDate
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Customer ID'
			GOTO Error_Encountered
		END
								
		IF @NextVoyageID IS NULL
		BEGIN
			SELECT @ErrorEncounteredInd = 1
			SELECT @RecordStatus = 'NEXT VOYAGE NOT FOUND'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			GOTO Insert_Record
		END
		
		UPDATE AutoportExportVehicles
		SET VoyageID = @NextVoyageID
		WHERE VIN = @VIN
		AND AutoportExportVehiclesID = @VehicleID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Updating Vehicle Record'
			GOTO Error_Encountered
		END
			
		SELECT @RecordStatus = 'VOYAGE CHANGED'
		SELECT @ImportedInd = 1
		SELECT @ImportedDate = CURRENT_TIMESTAMP
		SELECT @ImportedBy = @UserCode
		
		--update logic here.
		Insert_Record:
		INSERT INTO AEVoyageLoadListImport(
			BatchID,
			CustomerID,
			VoyageID,
			DestinationName,
			VIN,
			ImportedInd,
			ImportedDate,
			ImportedBy,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@CustomerID,
			@VoyageID,
			@VehicleDestinationName,
			@VIN,
			@ImportedInd,
			@ImportedDate,
			@ImportedBy,
			@RecordStatus,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END
	
		FETCH LoadListCursor INTO @VehicleID, @VIN, @VehicleDestinationName, @VehicleCustomsApprovedDate,
			@VehicleDateShipped
	
	END --end of loop
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE LoadListCursor
		DEALLOCATE LoadListCursor
		--PRINT 'ImportAutoportExportVoyageLoadList Error_Encountered =' + STR(@ErrorID)
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
		CLOSE LoadListCursor
		DEALLOCATE LoadListCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			--PRINT 'ImportAutoportExportVoyageLoadList Error_Encountered =' + STR(@ErrorID)
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
