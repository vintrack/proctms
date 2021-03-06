USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateNissanLCData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateNissanLCData] (@LocationID int, @Railhead varchar(3), @CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--NissanExportLC table variables
	@NissanExportLCID		int,
	@BatchID			int,
	@VehicleID			int,
	@RecordType			varchar(2),
	@VIN				varchar(17),
	@ActionCode			varchar(1),
	@DAILoadNumber			varchar(10),
	@ConfigurationDate		datetime,
	@Filler				varchar(4),
	@RateClass			varchar(1),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(50),
	@CreationDate			datetime,
	--processing variables
	@CustomerID			int,
	@CustomerLocationCode		varchar(20),
	@DamageCode			varchar(5),
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateNissanLCData						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generate the vehicle load config export data for	*
	*	Nissans.							*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	05/09/2005 CMK    Initial version				*
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

	DECLARE NissanLCCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, V.VIN, V.SizeClass, L2.CustomerLocationCode
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.PickupLocationID = @LocationID
		LEFT JOIN Location L2 ON L.DropoffLocationID = L2.LocationID
		WHERE V.PickupLocationID = @LocationID
		AND V.CustomerID = @CustomerID
		AND V.AvailableForPickupDate IS NOT NULL
		AND V.VehicleID NOT IN (SELECT VehicleID FROM NissanExportLC)
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN NissanLCCursor

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
	SELECT @RecordType = 'LC'
	SELECT @ActionCode = 'A'
	SELECT @ConfigurationDate = CURRENT_TIMESTAMP
	SELECT @Filler = '    '
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	FETCH NissanLCCursor INTO @VehicleID, @VIN, @RateClass, @CustomerLocationCode
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		SELECT @DAILoadNumber = CONVERT(varchar(10),DATEPART(mm,@ConfigurationDate))+CONVERT(varchar(10),DATEPART(yy,@ConfigurationDate))+ISNULL(@CustomerLocationCode,'')
		
		INSERT INTO NissanExportLC(
			BatchID,
			VehicleID,
			RecordType,
			VIN,
			ActionCode,
			DAILoadNumber,
			ConfigurationDate,
			Filler,
			RateClass,
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
			@RecordType,
			@VIN,
			@ActionCode,
			@DAILoadNumber,
			@ConfigurationDate,
			@Filler,
			@RateClass,
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
			SELECT @Status = 'Error creating NissanExportLC record'
			GOTO Error_Encountered
		END
			
		FETCH NissanLCCursor INTO @VehicleID, @VIN, @RateClass, @CustomerLocationCode

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE NissanLCCursor
		DEALLOCATE NissanLCCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE NissanLCCursor
		DEALLOCATE NissanLCCursor
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
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage
	
	RETURN
END
GO
