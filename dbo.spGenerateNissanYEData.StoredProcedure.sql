USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateNissanYEData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateNissanYEData] (@LocationID int, @Railhead varchar(3), @VPC varchar(2),@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--NissanExportYE table variables
	@NissanExportYEID		int,
	@BatchID			int,
	@VehicleID			int,
	@LoadNumber			varchar(20),
	@DepartureDate			datetime,
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
	*	spGenerateNissanYEData						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generate the vehicle yard exit export data for	*
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

	DECLARE NissanYECursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, L2.LoadNumber, L.PickupDate
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.PickupLocationID = @LocationID
		LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
		WHERE V.PickupLocationID = @LocationID
		AND V.CustomerID = @CustomerID
		AND V.VehicleStatus IN ('Delivered', 'EnRoute')
		AND V.CustomerIdentification IS NOT NULL
		AND V.CustomerIdentification <> ''
		AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
		AND V.VehicleID NOT IN (SELECT VehicleID FROM NissanExportYE)
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN NissanYECursor

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
	
	FETCH NissanYECursor INTO @VehicleID, @LoadNumber, @DepartureDate
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		INSERT INTO NissanExportYE(
			BatchID,
			VehicleID,
			VPC,
			Railhead,
			LoadNumber,
			DepartureDate,
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
			@LoadNumber,
			@DepartureDate,
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
			SELECT @Status = 'Error creating NissanExportYE record'
			GOTO Error_Encountered
		END
			
		FETCH NissanYECursor INTO @VehicleID, @LoadNumber, @DepartureDate

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE NissanYECursor
		DEALLOCATE NissanYECursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE NissanYECursor
		DEALLOCATE NissanYECursor
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
