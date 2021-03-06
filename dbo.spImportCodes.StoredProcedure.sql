USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportCodes]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportCodes]
AS
BEGIN
	DECLARE	--ImportCode Table Variables
	@ImportCodeID			int,
	@CodeType			varchar(30),
	@Code				varchar(40),
	@CodeDescription		varchar(255),
	@Value1				varchar(255),
	@Value1Description		varchar(255),
	@Value2				varchar(255),
	@Value2Description		varchar(255),
	@SortOrder			int,
	@Status				varchar(100),
	--Code Table Variables
	@RecordStatus			varchar(15),
	@CreationDate			datetime,
	@CreatedBy			varchar(20),
	@UpdatedDate			datetime,
	@UpdatedBy			varchar(20),
	--Processing Variables
	@AddEditInd			int,		-- 1= add location, 0 = edit location
	@ICLCustomerCode		varchar(20),
	@ErrorID			int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@ExceptionEncounteredInd	int,
	@RowCount			int,
	@loopcounter			int

	/************************************************************************
	*	spImportCodes							*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the ImportCode table 	*
	*	and creates new code records.					*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	08/23/2005 CMK    Initial version				*
	*									*
	************************************************************************/
	
	set nocount on
	/* Declare the main processing cursor */
	DECLARE ImportCodesCursor INSENSITIVE CURSOR
		FOR
		SELECT ImportCodeID, CodeType, Code, CodeDescription, Value1,
		Value1Description, Value2, Value2Description, SortOrder
		FROM ImportCode
	ORDER BY CodeType, SortOrder, Code

	SELECT @loopcounter = 0
	OPEN ImportCodesCursor
	
	BEGIN TRAN
	
	SELECT @RowCount = @@cursor_rows
	SELECT @ExceptionEncounteredInd = 0
	SELECT @RecordStatus = 'Active'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = 'IMPORT'
	
	
	FETCH ImportCodesCursor INTO @ImportCodeID, @CodeType, @Code, @CodeDescription, @Value1,
		@Value1Description, @Value2, @Value2Description, @SortOrder
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--Reset the Processing Variables
		SELECT @ErrorID = 0
		
		
		--See if the Code Exists
		SELECT @RowCount = Count(*)
		FROM Code
		WHERE CodeType = @CodeType
		AND Code = @Code
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			GOTO Error_Encountered
		END
		ELSE IF @RowCount > 0
		BEGIN
			SELECT @ErrorID = 100000
			GOTO End_Of_Loop
		END
				
		--Insert the Code
		INSERT INTO Code (
			CodeType,
			Code,
			CodeDescription,
			Value1,
			Value1Description,
			Value2,
			Value2Description,
			RecordStatus,
			SortOrder,
			CreationDate,
			CreatedBy,
			UpdatedDate,
			UpdatedBy
		)
		VALUES (
			@CodeType,
			@Code,
			@CodeDescription,
			@Value1,
			@Value1Description,
			@Value2,
			@Value2Description,
			@RecordStatus,
			@SortOrder,
			@CreationDate,
			@CreatedBy,
			@UpdatedDate,
			@UpdatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			GOTO Error_Encountered
		END
			
		SELECT @Status = 'Imported'
		
		End_Of_Loop:
		IF @ErrorID = 100000
		BEGIN
			SELECT @Status = 'Duplicate Code'
			SELECT @ExceptionEncounteredInd = 1
		END
					
		--update the import record
		UPDATE ImportCode
		SET Status = @Status
		WHERE ImportCodeID = @ImportCodeID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			GOTO Error_Encountered
		END
		
		FETCH ImportCodesCursor INTO @ImportCodeID, @CodeType, @Code, @CodeDescription, @Value1,
		@Value1Description, @Value2, @Value2Description, @SortOrder
	END
	SELECT @ErrorID = 0 --if we got to this point this should be fine
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ImportCodesCursor
		DEALLOCATE ImportCodesCursor
		SELECT @ReturnCode = 0
		IF @ExceptionEncounteredInd = 0
		BEGIN
			SELECT @ReturnMessage = 'Processing Completed Successfully'
		END
		ELSE
		BEGIN
			SELECT @ReturnMessage = 'Processing Completed Successfully, but with exceptions'
		END
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ImportCodesCursor
		DEALLOCATE ImportCodesCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
	END
	
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage
	
	RETURN
END
GO
