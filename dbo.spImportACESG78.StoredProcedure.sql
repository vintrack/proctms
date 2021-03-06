USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportACESG78]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportACESG78] (@BatchID int, @CustomerCode varchar(20),
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@ErrorEncountered		varchar(5000),
	@loopcounter			int,
	@ACESImportG78ID		int,
	@VIN				varchar(17),
	@CancellationDate		datetime,
	@AllocationDealer		varchar(7),
	@ExistingAllocationNumber	varchar(12),
	@StatusCode			varchar(3),
	@DestinationID			int,
	@VINCOUNT			int,
	@Status				varchar(50),
	@VehicleID			int,
	--@DestinationID			int,
	@VehicleDestinationID		int,
	@DestinationLocationCode	varchar(10),
	@AllocationNumber		varchar(20),
	@VehicleStatus			varchar(20),
	@DropoffLocationName		varchar(50),
	@LoadID				int,
	@LoadNumber			varchar(20),
	@LegsID				int,
	@PoolID				int,
	@RecordStatus			varchar(100),
	@UpdatedDate			datetime,
	@ImportedInd			int,
	@NewImportedInd			int,
	@CustomerID			int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100)

	/************************************************************************
	*	spImportACESG78							*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the ACESImportG78 table and 	*
	*	uses it to delete orders for the specified vehicles.		*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	02/05/2009 CMK    Initial version				*
	*									*
	************************************************************************/

	--get the customer id from the setting table
	SELECT @CustomerID = Value1
	FROM Code
	WHERE CodeType = 'ACESCustomerCode'
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

	SELECT @UpdatedDate = CURRENT_TIMESTAMP
	DECLARE G78Update CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT ACESImportG78ID, VIN, CancellationDate,
		AllocationDealer, ExistingAllocationNumber, StatusCode
		FROM ACESImportG78
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		AND Header = @CustomerCode
		ORDER BY ACESImportG78ID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN G78Update

	BEGIN TRAN

	FETCH G78Update INTO @ACESImportG78ID, @VIN, @CancellationDate,
		@AllocationDealer, @ExistingAllocationNumber, @StatusCode
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		SELECT @NewImportedInd = 0
		--get the vin, if it exists then just update anything that might have changed.
		SELECT @VINCOUNT = COUNT(*)
		FROM Vehicle
		WHERE VIN = @VIN
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
			@VehicleDestinationID = V.DropoffLocationID,
			@AllocationNumber = V.CustomerIdentification,
			@DestinationLocationCode = L2.CustomerLocationCode,
			@DropoffLocationName = L2.LocationName,
			@VehicleStatus = V.VehicleStatus,
			@LoadNumber = L3.LoadNumber,
			@LoadID = L3.LoadsID,
			@PoolID = L.PoolID,
			@LegsID = L.LegsID
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			LEFT JOIN Location L2 ON V.DropoffLocationID = L2.LocationID
			LEFT JOIN Loads L3 ON L.LoadID = L3.LoadsID
			WHERE V.VIN = @VIN
			AND V.CustomerID = @CustomerID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR GETTING VEHICLE STATUS'
				GOTO Error_Encountered
			END
			
			/*-- check the destination
			--get the destination.
			SELECT @DestinationID = LocationID,
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
			*/			
			IF @AllocationDealer <> @DestinationLocationCode OR @AllocationNumber <> @ExistingAllocationNumber
			BEGIN
				SELECT @RecordStatus = 'ALLOCATION DEALER = '+@DestinationLocationCode+', ALLOCATION NUMBER = '+@AllocationNumber
				GOTO Update_Record_Status
			END
			
			IF @VehicleStatus = 'Delivered'
			BEGIN
				SELECT @RecordStatus = 'VEHICLE DELIVERED TO '+ @DropoffLocationName
				GOTO Update_Record_Status
			END
			
			IF @VehicleStatus = 'EnRoute'
			BEGIN
				SELECT @RecordStatus = 'VEHICLE ENROUTE TO '+ @DropoffLocationName+' ON LOAD '+@LoadNumber
				GOTO Update_Record_Status
			END
			
			IF @LoadID IS NOT NULL
			BEGIN
				SELECT @RecordStatus = 'VEHICLE IN LOAD '+@LoadNumber
				GOTO Update_Record_Status
			END
			
			IF @VehicleStatus = 'OnHold'
			BEGIN
				SELECT @RecordStatus = 'VEHICLE IS ON HOLD'
				GOTO Update_Record_Status
			END
			
			SELECT @RecordStatus = ''
			
			-- got this far so we should be able to delete the vehicle
			
			-- if the vehicle is in a load remove it from the load
			IF @LoadID IS NOT NULL
			BEGIN
				SELECT @ReturnCode = 1
				EXEC spRemoveVehicleFromLoad @LegsID, @LoadID, @UpdatedDate,
				@UserCode, @rReturnCode = @ReturnCode OUTPUT
				IF @ReturnCode <> 0
				BEGIN
					SELECT @ErrorID = @ReturnCode
					GOTO Error_Encountered
				END
				
				--since we removed the vehicle from a load, ot should now have a pool id
				SELECT @PoolID = PoolID
				FROM Legs
				WHERE LegsID = @LegsID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR GETTING POOL ID'
					GOTO Error_Encountered
				END
				
				SELECT @RecordStatus = 'VEHICLE REMOVED FROM LOAD '+@LoadNumber+', '
			END
			
			-- if there is a pool id reduce the pool size
			IF @PoolID IS NOT NULL
			BEGIN
				UPDATE VehiclePool
				SET PoolSize = PoolSize - 1,
				Available = Available - 1
				WHERE VehiclePoolID = @PoolID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'ERROR UPDATING POOL'
					GOTO Error_Encountered
				END
			END
			-- delete the vehicle
			DELETE Vehicle
			WHERE VehicleID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR DELETING VEHICLE'
				GOTO Error_Encountered
			END
			-- delete the leg
			DELETE Legs
			WHERE VehicleID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR DELETING LEG'
				GOTO Error_Encountered
			END
					
			SELECT @NewImportedInd = 1
			SELECT @RecordStatus = @RecordStatus +'VEHICLE DELETED'
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
		UPDATE ACESImportG78
		SET RecordStatus = @RecordStatus,
		ImportedInd = @NewImportedind,
		ImportedDate = CASE WHEN @NewImportedInd = 1 THEN GetDate() ELSE NULL END,
		ImportedBy = CASE WHEN @NewImportedInd = 1 THEN @UserCode ELSE NULL END
		WHERE ACESImportG78ID = @ACESImportG78ID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error setting Imported status'
			GOTO Error_Encountered
		END

		FETCH G78Update INTO @ACESImportG78ID, @VIN, @CancellationDate,
			@AllocationDealer, @ExistingAllocationNumber, @StatusCode

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE G78Update
		DEALLOCATE G78Update
		PRINT 'G78Update Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE G78Update
		DEALLOCATE G78Update
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
			PRINT 'G78Update Error_Encountered =' + STR(@ErrorID)
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
