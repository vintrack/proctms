USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateNissanVDData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateNissanVDData] (@LocationID int, @Railhead varchar(3), @VPC varchar(2),@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--NissanExportVD table variables
	@NissanExportVDID		int,
	@BatchID			int,
	@VehicleID			int,
	@AttendedInd			varchar(1),
	@DeliveryDate			datetime,
	@CleanVehicleFlag		varchar(1),
	@STIFlag			varchar(1),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(20),
	@CreationDate			datetime,
	--processing variables
	@CustomerID			int,
	@DamageCode			varchar(5),
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateNissanVDData						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generate the vehicle delivery export data for	*
	*	Nissans that have been picked up.				*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/29/2005 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the customer id from the setting table
	Select @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NissanCustomerID'
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

	--get the next batch id from the setting table
	Select @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextNissan'+@Railhead+'ExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting BatchID'
		GOTO Error_Encountered2
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'BatchID Not Found'
		GOTO Error_Encountered2
	END

	DECLARE NissanVDCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, L.DropoffDate, CASE WHEN VI.AttendedInd = 1 THEN 'A' ELSE 'U' END,
		CASE WHEN VI.CleanVehicleInd = 0 THEN 'N' ELSE 'Y' END,
		CASE WHEN VI.SubjectToInspectionInd = 1 THEN 'Y' ELSE 'N' END
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.FinalLegInd = 1
		LEFT JOIN VehicleInspection VI ON L.VehicleID = VI.VehicleID
		AND VI.InspectionType = 3
		WHERE V.PickupLocationID = @LocationID
		AND V.CustomerID = @CustomerID
		AND L.DropoffDate > L.PickupDate
		AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
		AND V.CustomerIdentification IS NOT NULL
		AND V.CustomerIdentification <> ''
		AND V.VehicleStatus = 'Delivered'
		AND V.VehicleID NOT IN (SELECT VehicleID FROM NissanExportVD)
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN NissanVDCursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextNissan'+@Railhead+'ExportBatchID'
	IF @@ERROR <> 0
	BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Setting BatchID'
			GOTO Error_Encountered
	END

	--set the default values
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	FETCH NissanVDCursor INTO @VehicleID, @DeliveryDate, @AttendedInd, @CleanVehicleFlag, @STIFlag
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		INSERT INTO NissanExportVD(
			BatchID,
			VehicleID,
			VPC,
			Railhead,
			DeliveryDate,
			AttendedInd,
			CleanVehicleFlag,
			STIFlag,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@VPC,
			@Railhead,
			@DeliveryDate,
			@AttendedInd,
			@CleanVehicleFlag,
			@STIFlag,
			@ExportedInd,
			@ExportedDate,
			@ExportedBy,
			@RecordStatus,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating NissanExportVD record'
			GOTO Error_Encountered
		END
			
		FETCH NissanVDCursor INTO @VehicleID, @DeliveryDate, @AttendedInd, @CleanVehicleFlag, @STIFlag

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE NissanVDCursor
		DEALLOCATE NissanVDCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE NissanVDCursor
		DEALLOCATE NissanVDCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
		BEGIN
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
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage, @BatchID AS BatchID
	
	RETURN
END
GO
