USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportACL315]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportACL315] (@BatchID int, @UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@ErrorEncountered		varchar(5000),
	@loopcounter			int,
	--ACL 315 variables
	@ImportACL315ID			int,
	@ShipmentStatusCode		varchar(2),
	@VIN		varchar(30),
	@VesselCode			varchar(8),
	@VoyageNumber			varchar(10),
	@VesselName			varchar(28),
	@DischargePortQualifier		varchar(2),
	@DischargePortIdentifier	varchar(30),
	@TransshipPortQualifier		varchar(2),
	@TransshipPortIdentifier	varchar(30),
	--processing variables
	@VoyageID			int,
	@DestinationName		varchar(20),
	@TransshipPortName		varchar(20),
	@CustomerID			int,
	@CreationDate			datetime,
	@CreatedBy			varchar(20),
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	@VehicleDestinationName		varchar(100),
	@VehicleCustomerID		int,
	@VINCount			int,
	@RecordStatus			varchar(100),
	@Status				varchar(1000),
	@ReturnCode			int,
	@ReturnMessage			varchar(1000),
	@ErrorEncounteredInd		int

	/********************************************************************************
	*	spImportACL315								*
	*										*
	*	Description								*
	*	-----------								*
	*	This procedure takes the data from the AutoportExportVehiclesImport	*
	*	table and creates the new autoport import vehicle records.		*
	*										*
	*	Change History								*
	*	--------------								*
	*	Date       Init's Description						*
	*	---------- ------ ----------------------------------------		*
	*	03/30/2009 CMK    Initial version					*
	*										*
	********************************************************************************/
	
	DECLARE ImportACL315 CURSOR
		LOCAL FORWARD_ONLY STATIC READ_ONLY
		FOR
			SELECT ImportACL315ID, ShipmentStatusCode, MotorVehicleIDNumber,
			VesselCode, VoyageNumber, VesselName, DischargePortLocationQualifier,
			DischargePortLocationIdentifier, TransshipmentPortLocationQualifier,
			TransshipmentPortLocationIdentifier
			FROM ImportACL315
			WHERE BatchID = @BatchID
			ORDER BY ImportACL315ID
	
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = @UserCode
	SELECT @ErrorEncounteredInd = 0
	
	OPEN ImportACL315
	
	BEGIN TRAN

	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ACLCustomerID'
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Customer ID'
		GOTO Error_Encountered
	END

	FETCH ImportACL315 into @ImportACL315ID, @ShipmentStatusCode, @VIN,
		@VesselCode, @VoyageNumber, @VesselName, @DischargePortQualifier,
		@DischargePortIdentifier, @TransshipPortQualifier, @TransshipPortIdentifier
		
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @RecordStatus = 'Imported'
		SELECT @DestinationName = ''
		
		IF @ShipmentStatusCode = 'L'
		BEGIN
			--print 'shipment status code is L'
			IF @DischargePortQualifier = 'D'
			BEGIN
				SELECT TOP 1 @DestinationName = CodeDescription
				FROM Code
				WHERE CodeType = 'ScheduleDCode'
				AND Code = @DischargePortIdentifier
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Getting Destination Name'
					GOTO Error_Encountered
				END
				IF ISNULL(@DestinationName,'') = ''
				BEGIN
					SELECT @RecordStatus = 'IMPORTED, DEST NEEDED. Sched D Code '+@DischargePortIdentifier+ ' not found!'
					SELECT @ErrorEncounteredInd = 1
				END
			END
			ELSE IF @DischargePortQualifier = 'K'
			BEGIN
				SELECT TOP 1 @DestinationName = CodeDescription
				FROM Code
				WHERE CodeType = 'ScheduleKCode'
				AND Code = @DischargePortIdentifier
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Getting Destination Name'
					GOTO Error_Encountered
				END
				IF ISNULL(@DestinationName,'') = ''
				BEGIN
					SELECT @RecordStatus = 'IMPORTED, DEST NEEDED. Sched K Code '+@DischargePortIdentifier+ ' not found!'
					SELECT @ErrorEncounteredInd = 1
				END
			END
			ELSE
			BEGIN
				SELECT @DestinationName = ''
				SELECT @RecordStatus = 'IMPORTED, DEST NEEDED.'
				SELECT @ErrorEncounteredInd = 1
			END
			
			-- if there is a transship port, get its details
			IF DATALENGTH(ISNULL(@TransshipPortQualifier,'')) > 0
			BEGIN
				IF @TransshipPortQualifier = 'D'
				BEGIN
					SELECT TOP 1 @TransshipPortName = CodeDescription
					FROM Code
					WHERE CodeType = 'ScheduleDCode'
					AND Code = @TransshipPortIdentifier
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'Error Getting Destination Name'
						GOTO Error_Encountered
					END
					IF ISNULL(@DestinationName,'') = ''
					BEGIN
						SELECT @RecordStatus = 'IMPORTED, DEST NEEDED. Sched D Code '+@TransshipPortIdentifier+ ' not found!'
						SELECT @ErrorEncounteredInd = 1
					END
				END
				ELSE IF @TransshipPortQualifier = 'K'
				BEGIN
					SELECT TOP 1 @TransshipPortName = CodeDescription
					FROM Code
					WHERE CodeType = 'ScheduleKCode'
					AND Code = @TransshipPortIdentifier
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'Error Getting Destination Name'
						GOTO Error_Encountered
					END
					IF ISNULL(@TransshipPortName,'') = ''
					BEGIN
						SELECT @RecordStatus = 'IMPORTED, DEST NEEDED. Sched K Code '+@TransshipPortIdentifier+ ' not found!'
						SELECT @ErrorEncounteredInd = 1
					END
				END
				ELSE
				BEGIN
					SELECT @DestinationName = ''
					SELECT @RecordStatus = 'IMPORTED, DEST NEEDED.'
					SELECT @ErrorEncounteredInd = 1
				END
			END
			ELSE
			BEGIN
				SELECT @TransshipPortName = NULL
			END
			
			--print 'Inside the while loop first time through'
			--get the next vesselid/voyage number
			SELECT @VoyageID = NULL
			SELECT TOP 1 @VoyageID = AEV.AEVoyageID
			FROM AEVoyage AEV
			LEFT JOIN AEVoyageDestination AEVD ON AEV.AEVoyageID = AEVD.AEVoyageID
			LEFT JOIN AEVoyageCustomer AEVC ON AEV.AEVoyageID = AEVC.AEVoyageID
			WHERE AEV.VoyageDate >= CONVERT(varchar(10),CURRENT_TIMESTAMP,101)
			AND AEV.VoyageNumber = @VoyageNumber
			AND AEVD.DestinationName = @DestinationName
			AND AEVC.CustomerID = @CustomerID
			ORDER BY AEV.VoyageDate
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Getting Voyage ID'
				GOTO Error_Encountered
			END
			--print 'voyage id = '+ convert(varchar(20),@voyageid)
			IF @VoyageID IS NULL
			BEGIN
				SELECT @RecordStatus = 'VOYAGE NOT FOUND'
				SELECT @ErrorEncounteredInd = 1
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Record
			END
			--print 'vin = '+@vin
			--see if the vin already exists as an open record.
			SELECT @VINCOUNT = COUNT(*)
			FROM AutoportExportVehicles
			WHERE VIN = @VIN
			--AND CustomerID = @CustomerID
			AND DateShipped IS NULL
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting vin count'
				GOTO Error_Encountered
			END
					
			IF @VINCOUNT = 1
			BEGIN
				--print 'vin count is one'
				SELECT @VehicleCustomerID = CustomerID,
				@VehicleDestinationName = DestinationName
				FROM AutoportExportVehicles
				WHERE VIN = @VIN
				--AND CustomerID = @CustomerID
				AND DateShipped IS NULL
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error getting vin count'
					GOTO Error_Encountered
				END
					
				--validate the destination
				IF DATALENGTH(@DestinationName)>0
				BEGIN
					IF @VehicleDestinationName <> @DestinationName
					BEGIN
						SELECT @ErrorEncounteredInd = 1
						SELECT @RecordStatus = 'DESTINATION UPDATED'
					END
				END
					
				--validate the customer
				IF @VehicleCustomerID <> @CustomerID
				BEGIN
					SELECT @ErrorEncounteredInd = 1
					SELECT @RecordStatus = 'CUSTOMER MISMATCH'
					SELECT @ImportedInd = 0
					SELECT @ImportedDate = NULL
					SELECT @ImportedBy = NULL
					GOTO Update_Record
				END
				--print 'about to update vehicle'
				UPDATE AutoportExportVehicles
				SET DestinationName = @DestinationName,
				TransshipPortName = @TransshipPortName,
				VoyageID = @VoyageID
				WHERE VIN = @VIN
				AND CustomerID = @CustomerID
				AND DateShipped IS NULL
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Updating Vehicle Record'
					GOTO Error_Encountered
				END
				SELECT @ImportedInd = 1
				SELECT @ImportedDate = CURRENT_TIMESTAMP
				SELECT @ImportedBy = @UserCode
				GOTO Update_Record				
			END
			ELSE IF @VINCOUNT > 1
			BEGIN
				SELECT @ErrorEncounteredInd = 1
				SELECT @RecordStatus = 'Multiple Matches For VIN'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Record
			END
			ELSE
			BEGIN
				SELECT @ErrorEncounteredInd = 1
				SELECT @RecordStatus = 'VIN NOT FOUND'
				SELECT @ImportedInd = 0
				SELECT @ImportedDate = NULL
				SELECT @ImportedBy = NULL
				GOTO Update_Record
			END
			
		END
		ELSE
		BEGIN
			SELECT @RecordStatus = 'INVALID STATUS CODE'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
			SELECT @ErrorEncounteredInd = 1
		END
		
		--update logic here.
		Update_Record:
		UPDATE ImportACL315
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedBy = @ImportedBy,
		ImportedDate = @ImportedDate
		WHERE ImportACL315ID = @ImportACL315ID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH ImportACL315 into @ImportACL315ID, @ShipmentStatusCode, @VIN,
			@VesselCode, @VoyageNumber, @VesselName, @DischargePortQualifier,
			@DischargePortIdentifier, @TransshipPortQualifier, @TransshipPortIdentifier

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ImportACL315
		DEALLOCATE ImportACL315
		--PRINT 'ImportACL315 Error_Encountered =' + STR(@ErrorID)
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
		CLOSE ImportACL315
		DEALLOCATE ImportACL315
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			--PRINT 'ImportACL315 Error_Encountered =' + STR(@ErrorID)
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
