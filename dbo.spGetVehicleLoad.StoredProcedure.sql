USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetVehicleLoad]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spGetVehicleLoad]
AS
BEGIN
	/************************************************************************
	*	spGetVehicleLoad						*
	*									*
	*	Description							*
	*	-----------							*
	*	This returns a list of VIN's for a current user's load		*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	06/07/2004 RSK    Initial version				*
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	@ReturnCode	int,
	@ErrorID		int

	SELECT @ErrorID = 0

	SELECT VIN 
	FROM Vehicle

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		GOTO Error_Encountered
	END


	Error_Encountered:
	IF @ErrorID <> 0
	BEGIN
		SELECT @ReturnCode = @ErrorID
	END
	ELSE
	BEGIN
		SELECT @ReturnCode = 0
	END

	RETURN @ReturnCode
END
GO
