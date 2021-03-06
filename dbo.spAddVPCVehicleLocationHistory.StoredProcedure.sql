USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spAddVPCVehicleLocationHistory]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO






CREATE  PROCEDURE [dbo].[spAddVPCVehicleLocationHistory](
	@VIN		varchar(17),
	@BayLocation	varchar(20),
	@LocationDate	datetime,
	@User		varchar(20)
	)
AS
BEGIN
	/************************************************************************
	*	spAddVPCVehicleLocationHistory					*
	*									*
	*	Description							*
	*	-----------							*
	*	Inserts the LocationDate and BayLocation in the 		*
	*	VPCVehicleLocationHistory table					*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/11/2013 CP    Initial version				*
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	@VPCVehicleID		int,
		@CreatedDate		datetime,
		@CreatedBy		varchar(20),
		@ReturnCode		int,
		@ReturnMessage		varchar(100),
		@ErrorID		int,
		@Msg			varchar(100),
		@Count			int

	SELECT @Count = 0
	SELECT @ErrorID = 0
	SELECT @CreatedDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = @User
	
	BEGIN TRAN
	
	IF DATALENGTH(@VIN)<1
	BEGIN
		SELECT @ErrorID = 100000
		SELECT @Msg = 'No VIN Number Entered.'
		GOTO Error_Encountered
	END
	
	
	IF DATALENGTH(ISNULL(@BayLocation,''))<1
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Msg = 'No Bay Location Entered.'
		GOTO Error_Encountered
	END
	
	IF @LocationDate IS NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Msg = 'No Location Date Entered.'
		GOTO Error_Encountered
	END
	--get the vpcvehicleid
	SELECT @Count = NULL
	
	SELECT @Count = COUNT(*)
	FROM VPCVehicle V
	WHERE V.FullVIN = @VIN
	AND V.DateOut IS NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting vehicle count'
		GOTO Error_Encountered
	END
	
	IF @Count IS NULL OR @Count = 0
	BEGIN
		SELECT @ErrorID = 100003
		SELECT @Msg = 'VIN not found in vpc vehicle table'
		GOTO Error_Encountered
	END
	IF @Count > 1
	BEGIN
		SELECT @ErrorID = 100004
		SELECT @Msg = 'Multiple matches found for VIN'
		GOTO Error_Encountered
	END
	
	SELECT @VPCVehicleID = VPCVehicleID
	FROM VPCVehicle V
	WHERE V.FullVIN = @VIN
	AND V.DateOut IS NULL
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the VPCVehicleID'
		GOTO Error_Encountered
	END		
	
	INSERT INTO VPCVehicleLocationHistory (VPCVehicleID, BayLocation, LocationDate, CreationDate, CreatedBy, UpdatedDate, UpdatedBy)
	VALUES (@VPCVehicleID, @BayLocation, @LocationDate, @CreatedDate, @CreatedBy, NULL, NULL)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered inserting the VPC Vehicle Location History Record'
		GOTO Error_Encountered
	END
	
	Error_Encountered:
	IF @ErrorID <> 0
	BEGIN
		ROLLBACK TRAN
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Msg
		GOTO Do_Return
	END
	ELSE
	BEGIN
		COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Bay Location Inserted Successfully'
		GOTO Do_Return
	END

	Do_Return:
	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM'

	RETURN @ReturnCode
END





GO
