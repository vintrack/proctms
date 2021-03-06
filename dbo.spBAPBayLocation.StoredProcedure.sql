USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spBAPBayLocation]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spBAPBayLocation](
	@VIN			varchar(20),
	@BayLocation	varchar(20),
	@User			varchar(20)
	)
AS
BEGIN
	/************************************************************************
	*	spBAPBayLocation
	*	
	*	Description
	*	-----------
	*	Updates the Bay Location of the BAP vehicle with the bay location
	*	passed in.
	*	
	*	Change History
	*	--------------
	*	Date       Init's Description
	*	---------- ------ ----------------------------------------
	*	07/30/2007 JEP    Initial version
	*	08/03/2007 JEP    insert new import record, check AutoportExportVehicles for existing....
	*	
	************************************************************************/	

	SET nocount on

	DECLARE	@AutoportExportVehiclesImportID	int,
		@UpdatedDate	datetime,
		@ReturnCode		int,
		@ReturnMessage	varchar(50),
		@ErrorID		int,
		@Msg			varchar(50),
		@Count			int

	BEGIN TRAN
	
	SELECT @Count = 0
	SELECT @ErrorID = 0
	SELECT @AutoportExportVehiclesImportID = 0
	SELECT @UpdatedDate = CURRENT_TIMESTAMP	
	
	IF DATALENGTH(@VIN)<1
	BEGIN
		SELECT @ErrorID = 100000
		SELECT @Msg = 'No VIN Number Entered.'
		GOTO Error_Encountered
	END
	
	--get the vehicle id
	SELECT @Count = NULL
	
	SELECT @Count = COUNT(*)
	FROM AutoportExportVehiclesImport V
	WHERE V.VIN LIKE '%'+@VIN+'%'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the AutoportExportVehiclesImport count'
		GOTO Error_Encountered
	END
	
	IF @Count IS NULL OR @Count = 0
	BEGIN
		SELECT @Count = COUNT(*)
		FROM AutoportExportVehicles V
		WHERE V.VIN LIKE '%'+@VIN+'%'
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the AutoportExportVehicles count'
			GOTO Error_Encountered
		END

		IF @Count IS NULL OR @Count = 0
		BEGIN
			SELECT @ErrorID = 100002
			SELECT @Msg = 'VIN not found in database'
			GOTO Error_Encountered
		END
	END
	
	INSERT INTO AutoportExportVehiclesImport( 
			VIN, 
			--DestinationName, 
			--BookingNumber, 
			BayLocation, 
			ImportedInd,
			RecordStatus,
			CreationDate,
			CreatedBy )
		VALUES( 
			@VIN, 
			--@DestinationName, 
			--@BookingNumber, 
			@BayLocation, 
			0, 					--ImportedInd,
			'ImportPending',	--RecordStatus,
			getdate(), 			--CreationDate,
			@User )				--CreatedBy
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered inserting the AutoportExportVehiclesImport Record'
		GOTO Error_Encountered
	END

	--get the AutoportExportVehiclesImportID
	SELECT @AutoportExportVehiclesImportID = @@Identity
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the AutoportExportVehiclesImport Record ID'
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
		SELECT @ReturnMessage = 'AutoportExportVehiclesImport BayLocation Created Successfully'
		GOTO Do_Return
	END

	Do_Return:
	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM', @AutoportExportVehiclesImportID as 'AutoportExportVehiclesImportID'

	RETURN @ReturnCode
END

GO
