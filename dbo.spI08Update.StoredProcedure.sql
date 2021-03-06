USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spI08Update]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spI08Update] (@BatchID int, @CustomerCode varchar(20),
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@ErrorEncountered		varchar(5000),
	@loopcounter			int,
	@ImportI08ID			int,
	@VIN				varchar(17),
	@RRWaybillNumber		varchar(6),
	@RailVendor			varchar(24),
	@RailcarIDNumber		varchar(10),
	@VINExteriorColor		varchar(4),
	@RampCode			varchar(5),
	@Destination			varchar(7),
	@DropShipFlag			varchar(1),
	@RevisedETA			datetime,
	@AuthorizationNumber		varchar(12),
	@RailShipDate			datetime,
	@VINCOUNT			int,
	@Status				varchar(50),
	@VehicleID			int,
	@OriginID			int,
	@VehicleOriginID		int,
	@DestinationID			int,
	@VehicleDestinationID		int,
	@RecordStatus			varchar(100),
	@ImportedInd			int,
	@NewImportedInd			int,
	@CustomerID			int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100)

	/************************************************************************
	*	spI08Update							*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the ImportI08 table and 	*
	*	updates the vehicle records with the rail information.		*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	08/20/2004 CMK    Initial version				*
	*									*
	************************************************************************/

	--get the customer id from the setting table
	SELECT @CustomerID = Value1
	FROM Code
	WHERE CodeType = 'ICLCustomerCode'
	AND Code = @CustomerCode
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

	DECLARE I08Update CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT ImportI08ID, VIN, RRWaybillNumber, RailVendor,
		RailcarIDNumber, VINExteriorColor, RampCode, Destination,
		DropShipFlag, RevisedETA, AuthorizationNumber, RailShipDate
		FROM ImportI08
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		AND Header = @CustomerCode
		ORDER BY ImportI08ID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN I08Update

	BEGIN TRAN

	FETCH I08Update INTO @ImportI08ID, @VIN, @RRWaybillNumber, @RailVendor,
		@RailcarIDNumber, @VINExteriorColor, @RampCode, @Destination,
		@DropShipFlag, @RevisedETA, @AuthorizationNumber, @RailShipDate
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		SELECT @NewImportedInd = 0
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM Vehicle
		WHERE VIN = @VIN
		--AND (AvailableForPickupDate IS NULL
		--OR BayLocation IS NULL
		--OR BayLocation = '')
		--AND VehicleStatus <> 'Delivered'
		AND CustomerID = @CustomerID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error getting vin count'
			GOTO Error_Encountered
		END
		
		IF @VINCOUNT = 1
		BEGIN
			--validate the origin and destination
			--make sure the vin is not en route or delivered
			SELECT TOP 1 @VehicleID = V.VehicleID,
			@VehicleOriginID = V.PickupLocationID,
			@VehicleDestinationID = V.DropoffLocationID
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			WHERE V.VIN = @VIN
			AND V.CustomerID = @CustomerID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING VEHICLE STATUS'
				GOTO Error_Encountered
			END
			
			-- check the origin
			SELECT @OriginID = convert(int,value1)
			FROM Code
			WHERE CodeType = 'ICL'+@CustomerCode+'LocationCode'
			AND Code = @RampCode
			IF @@Error <> 0
			BEGIN
				print 'in origin error'
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING ORIGIN LOCATION'
				GOTO Error_Encountered
			END
					
			IF @OriginID <> @VehicleOriginID
			BEGIN
				SELECT @RecordStatus = 'ORIGIN MISMATCH'
				GOTO Update_Record_Status
			END
						
			-- check the destination
			--get the destination.
			SELECT @DestinationID = LocationID
			FROM Location
			WHERE ParentRecordID = @CustomerID
			AND ParentRecordTable = 'Customer'
			AND CustomerLocationCode = @Destination
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING DESTINATION LOCATION'
				GOTO Error_Encountered
			END
						
			IF @DestinationID <> @VehicleDestinationID
			BEGIN
				SELECT @RecordStatus = 'DESTINATION MISMATCH'
				GOTO Update_Record_Status
			END
			
			--update logic here.
			UPDATE Vehicle
			SET RailcarNumber = @RailcarIDNumber,
			CustomerIdentification = @AuthorizationNumber,
			UpdatedBy = 'I08 IMPORT',
			UpdatedDate = CURRENT_TIMESTAMP,
			EstimatedReleaseDate = @RevisedETA
			WHERE VIN = @VIN
			--AND (AvailableForPickupDate IS NULL
			--OR BayLocation IS NULL
			--OR BayLocation = '')
			--AND VehicleStatus <> 'Delivered'
			AND CustomerID = @CustomerID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UPDATING VEHICLE RECORD'
				GOTO Error_Encountered
			END
					
			SELECT @NewImportedInd = 1
			SELECT @RecordStatus = 'Imported'
		END
		ELSE IF @VINCOUNT > 1
		BEGIN
			SELECT @RecordStatus = 'MULTIPLE MATCHES FOUND FOR VIN'
			GOTO Update_Record_Status
		END
		ELSE
		BEGIN
			SELECT @RecordStatus = 'VIN NOT FOUND'
			GOTO Update_Record_Status
			
		END

		--update logic here.
		Update_Record_Status:
		UPDATE ImportI08
		SET RecordStatus = @RecordStatus,
		ImportedInd = @NewImportedind,
		ImportedDate = CASE WHEN @NewImportedInd = 1 THEN GetDate() ELSE NULL END,
		ImportedBy = CASE WHEN @NewImportedInd = 1 THEN @UserCode ELSE NULL END
		WHERE ImportI08ID = @ImportI08ID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH I08Update INTO @ImportI08ID, @VIN, @RRWaybillNumber, @RailVendor,
			@RailcarIDNumber, @VINExteriorColor, @RampCode, @Destination,
			@DropShipFlag, @RevisedETA, @AuthorizationNumber, @RailShipDate

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE I08Update
		DEALLOCATE I08Update
		PRINT 'I08Update Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE I08Update
		DEALLOCATE I08Update
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			PRINT 'I08Update Error_Encountered =' + STR(@ErrorID)
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
