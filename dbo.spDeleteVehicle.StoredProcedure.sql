USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spDeleteVehicle]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spDeleteVehicle] (@VehicleID int,
	@UserCode varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	--processing variables
	@VINCOUNT			int,
	@Status				varchar(100),
	@LoadID				int,
	@PoolID				int,
	@PoolRecordCount		int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@VehicleStatus			varchar(20),
	@LegsID				int,
	@LoadNumber			varchar(20),
	@UpdatedDate			datetime,
	@DamageIncidentReportCount	int,
	@DamageClaimCount		int

	/************************************************************************
	*	spDeleteVehicle							*
	*									*
	*	Description							*
	*	-----------							*
	*	This deletes the vehicle and leg records for the vehicleid that *
	*	is passed in.							*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	04/05/2012 CMK    Initial version				*
	*									*
	************************************************************************/
	
	SELECT @ErrorID = 0
	SELECT @UpdatedDate = CURRENT_TIMESTAMP
	
	BEGIN TRAN

	--get the vin, if it exists then just update anything that might have changed.
	SELECT @VINCOUNT = COUNT(*)
	FROM Vehicle
	WHERE VehicleID = @VehicleID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error getting vin count'
		GOTO Error_Encountered
	END
					
	IF @VINCOUNT = 1
	BEGIN
		--make sure the vin is not en route or delivered
		SELECT TOP 1 @VehicleStatus = V.VehicleStatus,
		@LoadNumber = L3.LoadNumber,
		@LoadID = L3.LoadsID,
		@PoolID = L.PoolID,
		@LegsID = L.LegsID
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		LEFT JOIN Location L2 ON V.DropoffLocationID = L2.LocationID
		LEFT JOIN Loads L3 ON L.LoadID = L3.LoadsID
		WHERE V.VehicleID = @VehicleID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR GETTING VEHICLE STATUS'
			GOTO Error_Encountered
		END
			
		IF @VehicleStatus = 'Delivered'
		BEGIN
			SELECT @ErrorID = 100000
			SELECT @Status = 'VEHICLE DELIVERED, CANNOT DELETE'
			GOTO Error_Encountered
		END
				
		IF @VehicleStatus = 'EnRoute'
		BEGIN
			SELECT @ErrorID = 100001
			SELECT @Status = 'VEHICLE ENROUTE, CANNOT DELETE'
			GOTO Error_Encountered
		END
		
		SELECT @Status = ''
		
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
				SELECT @Status = 'UNABLE TO REMOVE FROM LOAD'
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
							
			SELECT @Status = 'VEHICLE REMOVED FROM LOAD '+@LoadNumber+', '
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
		--see if there are any incident reports or claims on the vehicle
		SELECT @DamageIncidentReportCount = COUNT(*)
		FROM DamageIncidentReport
		WHERE VehicleID = @VehicleID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR GETTING INCIDENT REPORT COUNT'
			GOTO Error_Encountered
		END
			
		SELECT @DamageClaimCount = COUNT(*)
		FROM DamageClaim
		WHERE VehicleID = @VehicleID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'ERROR GETTING DAMAGE CLAIM COUNT'
			GOTO Error_Encountered
		END
				
		IF @DamageIncidentReportCount >0 OR @DamageClaimCount > 0
		BEGIN
			-- update the vehicle
			UPDATE Vehicle
			SET AvailableForPickupDate = NULL,
			VehicleStatus = 'Pending'
			WHERE VehicleID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UNRELEASING VEHICLE'
				GOTO Error_Encountered
			END
			-- update the leg
			UPDATE Legs
			SET DateAvailable = NULL,
			LegStatus = 'Pending',
			PoolID = NULL
			WHERE VehicleID = @VehicleID
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'ERROR UNRELEASING LEG'
				GOTO Error_Encountered
			END
										
			SELECT @ErrorID = 100002
			SELECT @Status = 'VEHICLE HAS INCIDENT/CLAIM, CANNOT BE DELETED'
		END
		ELSE
		BEGIN
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
		END
	END
	ELSE IF @VINCOUNT > 1
	BEGIN
		SELECT @ErrorID = 100003
		SELECT @Status = 'MULTIPLE MATCHES FOUND FOR VIN'
	END
	ELSE
	BEGIN
		SELECT @ErrorID = 100004
		SELECT @Status = 'VIN NOT FOUND'
	END
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Do_Return:
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage
	
	RETURN
END
GO
