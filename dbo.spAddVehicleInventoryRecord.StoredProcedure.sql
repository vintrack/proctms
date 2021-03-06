USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spAddVehicleInventoryRecord]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spAddVehicleInventoryRecord](
		@VIN		varchar(20), 
		@CreatedBy	varchar(20),
		@CreationDate	datetime
	)
AS
BEGIN
	/************************************************************************
	*	spAddVehicleInventoryRecord					*
	*									*
	*	Description							*
	*	-----------							*
	*	Adds a new VehicleInventory record.			 	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	09/16/2005 CMK    Initial version				*
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	
	@ReturnCode	int,
	@ReturnMessage	varchar(50),
	@ErrorID	int,
	@Msg		varchar(50),
	@Count		int

	BEGIN TRAN

	INSERT INTO VehicleInventory(
		VIN,
		CreationDate,
		CreatedBy
	)
	VALUES(
		@VIN,
		@CreationDate,
		@CreatedBy
	)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered inseting the VehicleInveroty Record'
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
		SELECT @ReturnMessage = 'VehicleInventory Created Successfully'
	END

	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM'

	RETURN @ReturnCode
END

GRANT  EXECUTE  ON [dbo].[spAddVehicleInventoryRecord]  TO [db_sp_execute]
GO
