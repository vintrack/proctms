USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spAddBAPExportVehicle]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spAddBAPExportVehicle](
		@VIN				varchar(20), 
		@DestinationName	varchar(100), 
		@BookingNumber		varchar(20), 
		@BayLocation		varchar(20), 
		@CreatedBy			varchar(20) 
	)
AS
BEGIN
	/************************************************************************
	*	spAddBAPExportVehicle
	*	
	*	Description
	*	-----------
	*	Adds a new AutoportExportVehiclesImport record.
	*	
	*	Change History
	*	--------------
	*	Date       Init's Description
	*	---------- ------ ----------------------------------------
	*	07/20/2005 JEP    Initial version
	*	08/03/2007 JEP    ok if already exists....
	*	
	************************************************************************/	

	SET nocount on

	DECLARE	
		@AutoportExportVehiclesImportID	int,
		@ReturnCode			int,
		@ReturnMessage		varchar(50),
		@ReturnRunID		int,
		@ErrorID			int,
		@Msg				varchar(50),
		@Count				int

	SET @AutoportExportVehiclesImportID = 0
	
	BEGIN TRAN

	INSERT INTO AutoportExportVehiclesImport( 
			VIN, 
			DestinationName, 
			BookingNumber, 
			BayLocation, 
			ImportedInd,
			RecordStatus,
			CreationDate,
			CreatedBy )
		VALUES( 
			@VIN, 
			@DestinationName, 
			@BookingNumber, 
			@BayLocation, 
			0, 					--ImportedInd,
			'ImportPending',	--RecordStatus,
			getdate(), 			--CreationDate,
			@CreatedBy )
	
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
	END
	ELSE
	BEGIN
		COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'AutoportExportVehiclesImport Created Successfully'
	END

	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM', @AutoportExportVehiclesImportID AS 'ID'

	RETURN @ReturnCode
END


GO
