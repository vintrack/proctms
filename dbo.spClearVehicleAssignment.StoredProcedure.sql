USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spClearVehicleAssignment]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spClearVehicleAssignment](
	@LegsID			int,
	@DriverID		int
	)
AS
BEGIN
	/************************************************************************
	*	spClearVehicleAssignment					*
	*									*
	*	Description							*
	*	-----------							*
	*	Remove assigned (or reserved) 	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	06/23/2005 JEP    Initial version, clone of spClearDriverReservations			*
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	@ReturnCode		int,
		@ReturnMessage		varchar(50),
		@ErrorID		int,
		@Msg			varchar(50)

	BEGIN TRAN
	
	--get the vehicleid
	UPDATE Legs
	SET ReservedByDriverInd = 0,
	ReservedByDriverID = NULL
	WHERE LegsID = @LegsID
	AND ReservedByDriverID = @DriverID

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered clearing the driver reservations'
		GOTO Error_Encountered
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
		SELECT @ReturnMessage = 'Reservation Cleared Successfully'		
	END

	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM'

	RETURN @ReturnCode
END

GO
