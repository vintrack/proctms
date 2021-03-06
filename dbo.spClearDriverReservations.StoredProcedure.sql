USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spClearDriverReservations]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spClearDriverReservations](
	@DriverID	int,
	@LoadID		int,
	@LocationID	int
	)
AS
BEGIN
	/************************************************************************
	*	spClearDriverReservations					*
	*									*
	*	Description							*
	*	-----------							*
	*	Clears any driver reservations after the driver is done loading	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/10/2005 CMK    Initial version				*
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	@ReturnCode		int,
		@ReturnMessage		varchar(50),
		@ReturnVehicleID	int,
		@ErrorID		int,
		@Msg			varchar(50),
		@ReservationCount	int,
		@VehicleReservationsID	int,
		@PoolID			int,
		@Units			int

	BEGIN TRAN
	
	
	--get the vehicleid
	UPDATE Legs
	SET ReservedByDriverInd = 0,
	ReservedByDriverID = NULL
	WHERE ReservedByDriverID = @DriverID
	AND PickupLocationID = @LocationID
	AND LoadID = @LoadID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered clearing the driver reservations'
		GOTO Error_Encountered
	END
	
	SELECT @ReservationCount = COUNT(*)
	FROM VehicleReservations VR, VehiclePool VP
	WHERE VR.PoolID = VP.VehiclePoolID
	AND VR.LoadsID = @LoadID
	AND VP.OriginID = @LocationID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the vehicle reservations'
		GOTO Error_Encountered
	END
	
	IF @ReservationCount > 0
	BEGIN
		DECLARE VehicleReservationCursor CURSOR
		LOCAL FORWARD_ONLY STATIC READ_ONLY
		FOR
			SELECT VR.VehicleReservationsID, VR.PoolID, VR.Units
			FROM VehicleReservations VR, VehiclePool VP
			WHERE VR.PoolID = VP.VehiclePoolID
			AND VR.LoadsID = @LoadID
			AND VP.OriginID = @LocationID
			
		OPEN VehicleReservationCursor
		
		FETCH VehicleReservationCursor INTO @VehicleReservationsID, @PoolID, @Units
		
		WHILE @@FETCH_STATUS = 0
		BEGIN
			UPDATE VehiclePool
			SET Reserved = Reserved - @Units,
			Available = Available + @Units
			WHERE VehiclePoolID = @PoolID
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating the vehicle pool'
				GOTO Close_Cursor
			END
			
			DELETE VehicleReservations
			WHERE VehicleReservationsID = @VehicleReservationsID
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered deleting the vehicle reservation'
				GOTO Close_Cursor
			END
			
			UPDATE Loads
			SET LoadSize = LoadSize - @Units
			WHERE LoadsID = @LoadID
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered changing load size'
				GOTO Close_Cursor
			END
			
			FETCH VehicleReservationCursor INTO @VehicleReservationsID, @PoolID, @Units
		END

		Close_Cursor:
		CLOSE VehicleReservationCursor
		DEALLOCATE VehicleReservationCursor
	END
	
	Error_Encountered:
	IF @ErrorID <> 0
	BEGIN
		ROLLBACK TRAN
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Msg
	END
	ELSE
	BEGIN
		COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Reservations Cleared Successfully'		
	END

	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM'

	RETURN @ReturnCode
END

GO
