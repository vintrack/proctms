USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spAddExportVPCComplete_Disch_Phy]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





CREATE    Procedure [dbo].[spAddExportVPCComplete_Disch_Phy](
	@VIN VARCHAR(20),
	@DischargeDate datetime,
	@PhysicalDate datetime,
	@BayLocation varchar(20),
	@UserCode varchar(20)
	)
AS
BEGIN
	/************************************************************************
	*	spAddExportVPCComplete_Disch_Phy				*
	*									*
	*	Description							*
	*	-----------							*
	*	Inserts the DischargeDate or the PhysicalDate in the 		*
	*	ExportVPCComplete table						*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/11/2013 CP    Initial version				*
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	@CreatedDate		datetime,
		@CreatedBy		varchar(20),
		@ReturnCode		int,
		@ReturnMessage		varchar(200),
		@ErrorID		int,
		@Msg			varchar(100)

	DECLARE @VinKey varchar(8)

	SET @CreatedDate = current_timestamp
	SET @CreatedBy = @UserCode

	SET @VIN = rtrim(ltrim(@VIN))

	if len(@VIN) > 8
	begin
		SET @VinKey = SUBSTRING(@VIN, len(@VIN) - 7, 8)
	end
	else
	begin
		SET @VinKey = @VIN
	end

	BEGIN TRAN

	IF @DischargeDate IS NULL AND @PhysicalDate IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Msg = 'No DischargeDate nor PhysicalDate Entered.'
		GOTO Error_Encountered
	END

	IF @DischargeDate IS NOT NULL AND @PhysicalDate IS NOT NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Msg = 'Both DischargeDate and PhysicalDate Entered. Only one of them should be entered at a time.'
		GOTO Error_Encountered
	END

	IF @PhysicalDate IS NOT NULL AND DATALENGTH(@BayLocation) < 1
	BEGIN
		SELECT @ErrorID = 100003
		SELECT @Msg = 'No BayLocation Entered.'
		GOTO Error_Encountered
	END

	IF @PhysicalDate IS NOT NULL
	BEGIN
		INSERT INTO [dbo].[ExportVPCComplete]([VINKey], [BayLocation], [ExportedInd], [RecordStatus], [CreationDate], [CreatedBy], [UpdateType], [PhysicalDate])
		VALUES(@VinKey, @BayLocation, 0, 'Export Pending', @CreatedDate, @CreatedBy, 'Physical', @PhysicalDate)
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(VARCHAR(10),@ErrorID)+' encountered inserting ExportVPCComplete record.'
			GOTO Error_Encountered
		END
	END

	IF @DischargeDate IS NOT NULL
	BEGIN
		INSERT INTO [dbo].[ExportVPCComplete]([VINKey], [ExportedInd], [RecordStatus], [CreationDate], [CreatedBy], [UpdateType], [DischargeDate])
		VALUES(@VinKey, 0, 'Export Pending', @CreatedDate, @CreatedBy, 'Discharge', @DischargeDate)
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(VARCHAR(10),@ErrorID)+' encountered inserting ExportVPCComplete record.'
			GOTO Error_Encountered
		END
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
		SELECT @ReturnMessage = 'ExportVPCComplete Discharge/Physical Date added successfully.'
		GOTO Do_Return
	END

	Do_Return:
	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM'

	RETURN @ReturnCode
END





GO
