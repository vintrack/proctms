USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportSDCBayLocations]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportSDCBayLocations] (@BatchID int, @UserCode varchar(20))
AS
BEGIN
	DECLARE	--SDCBayLocationsImport Table Variables
	@SDCBayLocationsImportID	int,
	@BayGroup			varchar(20),
	@Lane				varchar(20),
	@LanePosition			varchar(20),
	@SortOrder			int,
	@RecordStatus			varchar(100),
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	--SDCBayLocations
	@BayNumber			varchar(20),
	@AvailableInd			int,
	@ActiveInd			int,
	@CreationDate			datetime,
	@CreatedBy			varchar(20),
	@UpdatedDate			datetime,
	@UpdatedBy			varchar(20),
	--Processing Variables
	@ErrorID			int,
	@ExceptionEncounteredInd		int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@RowCount			int,
	@loopcounter			int

	/************************************************************************
	*	spImportSDCBayLocations						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the SDCBayLocationsImport	*
	*	table and creates/updates SDCBayLocations records.		*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	06/20/2013 CMK    Initial version				*
	*									*
	************************************************************************/
	
	set nocount on
	/* Declare the main processing cursor */
	DECLARE ImportBayLocationsCursor INSENSITIVE CURSOR
		FOR
		SELECT SDCBayLocationsImportID, BayGroup, Lane, LanePosition, SortOrder
		FROM SDCBayLocationsImport
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
	ORDER BY BayGroup, Lane, LanePosition

	SELECT @loopcounter = 0
	OPEN ImportBayLocationsCursor
	
	BEGIN TRAN
	
	SELECT @ErrorID = 0
	SELECT @ExceptionEncounteredInd = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = @UserCode
	SELECT @UpdatedDate = CURRENT_TIMESTAMP
	SELECT @UpdatedBy = @UserCode
	
	
	FETCH ImportBayLocationsCursor INTO @SDCBayLocationsImportID, @BayGroup,
		@Lane, @LanePosition, @SortOrder
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--See if the Bay Group Exists
		SELECT @RowCount = Count(*)
		FROM Code
		WHERE CodeType = 'SDCBayLocationGroup'
		AND CodeDescription = @BayGroup
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @ReturnMessage = 'Error Validating Bay Group'
			GOTO Error_Encountered
		END
		
		IF @RowCount = 0
		BEGIN
			--new group, so add it
			INSERT INTO Code (
				CodeType,
				Code,
				CodeDescription,
				RecordStatus,
				SortOrder,
				CreationDate,
				CreatedBy
			)
			VALUES (
				'SDCBayLocationGroup',	--CodeType
				@BayGroup,		--Code,
				@BayGroup,		--CodeDescription,
				'Active',		--RecordStatus,
				@SortOrder,
				@CreationDate,
				@CreatedBy
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				SELECT @ReturnMessage = 'Error Adding Bay Group'
				GOTO Error_Encountered
			END		
		END
				
		SELECT @BayNumber = @Lane+CASE WHEN DATALENGTH(@LanePosition) = 1 THEN ' 0'+@LanePosition WHEN DATALENGTH(@LanePosition) = 2 THEN ' '+@LanePosition ELSE '' END
		
		--see if the bay location exists
		SELECT @RowCount = Count(*)
		FROM SDCBayLocations
		WHERE BayNumber = @BayNumber
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @ReturnMessage = 'Error Getting Bay Count'
			GOTO Error_Encountered
		END
				
		IF @RowCount = 0
		BEGIN
			--Insert the Bay
			INSERT INTO SDCBayLocations (
				BayGroup,
				BayNumber,
				AvailableInd,
				ActiveInd,
				SortOrder,
				CreationDate,
				CreatedBy
			)
			VALUES (
				@BayGroup,
				@BayNumber,
				1,		--AvailableInd
				0,		--ActiveInd
				@SortOrder,
				@CreationDate,
				@CreatedBy
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				SELECT @ReturnMessage = 'Error Adding Bay'
				GOTO Error_Encountered
			END
			
			SELECT @RecordStatus = 'Imported'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = @CreationDate
			SELECT @ImportedBy = @CreatedBy
		END
		ELSE IF @RowCount = 1
		BEGIN
			--Update the Bay
			UPDATE SDCBayLocations
			SET BayGroup = @BayGroup,
			SortOrder = @SortOrder,
			UpdatedDate = @UpdatedDate,
			UpdatedBy = @UpdatedBy
			WHERE BayNumber = @BayNumber
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				SELECT @ReturnMessage = 'Error Updating Bay'
				GOTO Error_Encountered
			END
			
			SELECT @RecordStatus = 'Bay Updated'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = @CreationDate
			SELECT @ImportedBy = @CreatedBy
		END
		ELSE
		BEGIN
			SELECT @ExceptionEncounteredInd = 1
			SELECT @RecordStatus = 'Multiple Matches For Bay'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
		END
			
		End_Of_Loop:
		--update the import record
		UPDATE SDCBayLocationsImport
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE SDCBayLocationsImportID = @SDCBayLocationsImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @ReturnMessage = 'Error Updating Import Table'
			GOTO Error_Encountered
		END
		
		FETCH ImportBayLocationsCursor INTO @SDCBayLocationsImportID, @BayGroup,
		@Lane, @LanePosition, @SortOrder
	END
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ImportBayLocationsCursor
		DEALLOCATE ImportBayLocationsCursor
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
		CLOSE ImportBayLocationsCursor
		DEALLOCATE ImportBayLocationsCursor
		SELECT @ReturnCode = @ErrorID
	END
	
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage
	
	RETURN
END
GO
