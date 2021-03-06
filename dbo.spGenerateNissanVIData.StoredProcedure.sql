USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateNissanVIData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateNissanVIData] (@LocationID int, @Railhead varchar(3), @VPC varchar(2),@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--NissanExportVI table variables
	@NissanExportVIID		int,
	@BatchID			int,
	@VehicleID			int,
	@InspectionType			varchar(20),
	@InspectionDate			datetime,
	@DamageCode1			varchar(5),
	@DamageCode2			varchar(5),
	@DamageCode3			varchar(5),
	@DamageCode4			varchar(5),
	@DamageCode5			varchar(5),
	@DamageCode6			varchar(5),
	@DamageCode7			varchar(5),
	@DamageCode8			varchar(5),
	@DamageCode9			varchar(5),
	@DamageCode10			varchar(5),
	@DamageComment			varchar(17),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(20),
	@CreationDate			datetime,
	--processing variables
	@CurrentVehicleID		int,
	@LoopCount			int,
	@CustomerID			int,
	@DamageCode			varchar(5),
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateNissanVIData						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generate the vehicle inspection export data for	*
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
	
	DECLARE NissanVICursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, VI.InspectionDate, VDD.DamageCode
		FROM Vehicle V
		LEFT JOIN VehicleInspection VI ON V.VehicleID = VI.VehicleID
		AND VI.InspectionType = 2
		LEFT JOIN VehicleDamageDetail VDD ON VI.VehicleInspectionID = VDD.VehicleInspectionID
		WHERE V.PickupLocationID = @LocationID
		AND V.CustomerID = @CustomerID
		AND VDD.VehicleInspectionID IS NOT NULL
		AND V.VehicleStatus IN ('Delivered', 'EnRoute')
		AND V.VehicleID NOT IN (SELECT VehicleID FROM NissanExportVI)
		ORDER BY V.VehicleID, VDD.DamageCode

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN NissanVICursor

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
	SELECT @InspectionType = '01'
	SELECT @DamageCode1 = ''
	SELECT @DamageCode2 = ''
	SELECT @DamageCode3 = ''
	SELECT @DamageCode4 = ''
	SELECT @DamageCode5 = ''
	SELECT @DamageCode6 = ''
	SELECT @DamageCode7 = ''
	SELECT @DamageCode8 = ''
	SELECT @DamageCode9 = ''
	SELECT @DamageCode10 = ''
	SELECT @DamageComment = ''
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	FETCH NissanVICursor INTO @VehicleID, @InspectionDate, @DamageCode
	
	SELECT @LoopCount = 1
	SELECT @CurrentVehicleID = @VehicleID

	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		IF @CurrentVehicleID <> @VehicleID
		BEGIN
			--vehicle changing, so create record
			INSERT INTO NissanExportVI(
				BatchID,
				VehicleID,
				InspectionType,
				InspectionDate,
				VPC,
				Railhead,
				DamageCode1,
				DamageCode2,
				DamageCode3,
				DamageCode4,
				DamageCode5,
				DamageCode6,
				DamageCode7,
				DamageCode8,
				DamageCode9,
				DamageCode10,
				DamageComment,
				ExportedInd,
				ExportedDate,
				ExportedBy,
				RecordStatus,
				CreationDate,
				CreatedBy
			)
			VALUES(
				@BatchID,
				@CurrentVehicleID,
				@InspectionType,
				@InspectionDate,
				@VPC,
				@Railhead,
				@DamageCode1,
				@DamageCode2,
				@DamageCode3,
				@DamageCode4,
				@DamageCode5,
				@DamageCode6,
				@DamageCode7,
				@DamageCode8,
				@DamageCode9,
				@DamageCode10,
				@DamageComment,
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
				SELECT @Status = 'Error creating NissanExportVI record'
				GOTO Error_Encountered
			END
			
			--reset the variables
			SELECT @DamageCode1 = ''
			SELECT @DamageCode2 = ''
			SELECT @DamageCode3 = ''
			SELECT @DamageCode4 = ''
			SELECT @DamageCode5 = ''
			SELECT @DamageCode6 = ''
			SELECT @DamageCode7 = ''
			SELECT @DamageCode8 = ''
			SELECT @DamageCode9 = ''
			SELECT @DamageCode10 = ''
			SELECT @LoopCount = 1
		END
		-- figure out which damage code we should be setting the value of
		IF @LoopCount = 1
		BEGIN
			SELECT @DamageCode1 = @DamageCode
		END
		ELSE IF @LoopCount = 2
		BEGIN
			SELECT @DamageCode2 = @DamageCode
		END
		ELSE IF @LoopCount = 3
		BEGIN
			SELECT @DamageCode3 = @DamageCode
		END
		ELSE IF @LoopCount = 4
		BEGIN
			SELECT @DamageCode4 = @DamageCode
		END
		ELSE IF @LoopCount = 5
		BEGIN
			SELECT @DamageCode5 = @DamageCode
		END
		ELSE IF @LoopCount = 6
		BEGIN
			SELECT @DamageCode6 = @DamageCode
		END
		ELSE IF @LoopCount = 7
		BEGIN
			SELECT @DamageCode7 = @DamageCode
		END
		ELSE IF @LoopCount = 8
		BEGIN
			SELECT @DamageCode8 = @DamageCode
		END
		ELSE IF @LoopCount = 9
		BEGIN
			SELECT @DamageCode9 = @DamageCode
		END
		ELSE IF @LoopCount = 10
		BEGIN
			SELECT @DamageCode10 = @DamageCode
		END
		
		SELECT @LoopCount = @LoopCount + 1
		SELECT @CurrentVehicleID = @VehicleID

		FETCH NissanVICursor INTO @VehicleID, @InspectionDate, @DamageCode

	END --end of loop

	--save off the last record
	INSERT INTO NissanExportVI(
		BatchID,
		VehicleID,
		InspectionType,
		InspectionDate,
		VPC,
		Railhead,
		DamageCode1,
		DamageCode2,
		DamageCode3,
		DamageCode4,
		DamageCode5,
		DamageCode6,
		DamageCode7,
		DamageCode8,
		DamageCode9,
		DamageCode10,
		DamageComment,
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
		@InspectionType,
		@InspectionDate,
		@VPC,
		@Railhead,
		@DamageCode1,
		@DamageCode2,
		@DamageCode3,
		@DamageCode4,
		@DamageCode5,
		@DamageCode6,
		@DamageCode7,
		@DamageCode8,
		@DamageCode9,
		@DamageCode10,
		@DamageComment,
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
		SELECT @Status = 'Error creating NissanExportVI record'
		GOTO Error_Encountered
	END
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE NissanVICursor
		DEALLOCATE NissanVICursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE NissanVICursor
		DEALLOCATE NissanVICursor
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
