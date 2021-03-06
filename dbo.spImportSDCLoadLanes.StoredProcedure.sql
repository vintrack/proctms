USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportSDCLoadLanes]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportSDCLoadLanes] (@BatchID int, @UserCode varchar(20))
AS
BEGIN
	DECLARE	--SDCLoadLanesImport Table Variables
	@SDCLoadLanesImportID		int,
	@LaneGroup			varchar(20),
	@LaneNumber			varchar(20),
	@VehicleCapacity		int,
	@SortOrder			int,
	@RecordStatus			varchar(100),
	@ImportedInd			int,
	@ImportedDate			datetime,
	@ImportedBy			varchar(20),
	--SDCBayLocations
	@AvailableInd			int,
	@ActiveInd			int,
	@CreationDate			datetime,
	@CreatedBy			varchar(20),
	@UpdatedDate			datetime,
	@UpdatedBy			varchar(20),
	--Processing Variables
	@ErrorID			int,
	@ExceptionEncounteredInd	int,
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@RowCount			int,
	@loopcounter			int

	/************************************************************************
	*	spImportSDCLoadLanes						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the SDCLoadLanesImport	*
	*	table and creates/updates SDCLoadLanes records.			*
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
	DECLARE ImportLoadLanesCursor INSENSITIVE CURSOR
		FOR
		SELECT SDCLoadLanesImportID, LaneGroup, LaneNumber, VehicleCapacity, SortOrder
		FROM SDCLoadLanesImport
		WHERE BatchID = @BatchID
		AND ImportedInd = 0
		ORDER BY LaneGroup, LaneNumber

	SELECT @loopcounter = 0
	OPEN ImportLoadLanesCursor
	
	BEGIN TRAN
	
	SELECT @ErrorID = 0
	SELECT @ExceptionEncounteredInd = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = @UserCode
	SELECT @UpdatedDate = CURRENT_TIMESTAMP
	SELECT @UpdatedBy = @UserCode
	
	
	FETCH ImportLoadLanesCursor INTO @SDCLoadLanesImportID, @LaneGroup,
		@LaneNumber, @VehicleCapacity, @SortOrder
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--See if the Lane Group Exists
		SELECT @RowCount = Count(*)
		FROM Code
		WHERE CodeType = 'SDCLoadLaneGroup'
		AND CodeDescription = @LaneGroup
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @ReturnMessage = 'Error Validating Lane Group'
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
				'SDCLoadLaneGroup',	--CodeType
				@LaneGroup,		--Code,
				@LaneGroup,		--CodeDescription,
				'Active',		--RecordStatus,
				@SortOrder,
				@CreationDate,
				@CreatedBy
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				SELECT @ReturnMessage = 'Error Adding Lane Group'
				GOTO Error_Encountered
			END		
		END
				
		--see if the load lane exists
		SELECT @RowCount = Count(*)
		FROM SDCLoadLanes
		WHERE LaneNumber = @LaneNumber
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @ReturnMessage = 'Error Getting Lane Count'
			GOTO Error_Encountered
		END
				
		IF @RowCount = 0
		BEGIN
			--Insert the Load Lane
			INSERT INTO SDCLoadLanes (
				LaneGroup,
				LaneNumber,
				VehicleCapacity,
				AvailableInd,
				ActiveInd,
				SortOrder,
				CreationDate,
				CreatedBy
			)
			VALUES (
				@LaneGroup,
				@LaneNumber,
				@VehicleCapacity,
				1,		--AvailableInd
				0,		--ActiveInd
				@SortOrder,
				@CreationDate,
				@CreatedBy
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				SELECT @ReturnMessage = 'Error Adding Lane'
				GOTO Error_Encountered
			END
			
			SELECT @RecordStatus = 'Imported'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = @CreationDate
			SELECT @ImportedBy = @CreatedBy
		END
		ELSE IF @RowCount = 1
		BEGIN
			--Update the Lane
			UPDATE SDCLoadLanes
			SET LaneGroup = @LaneGroup,
			VehicleCapacity = @VehicleCapacity,
			SortOrder = @SortOrder,
			UpdatedDate = @UpdatedDate,
			UpdatedBy = @UpdatedBy
			WHERE LaneNumber = @LaneNumber
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@Error
				SELECT @ReturnMessage = 'Error Updating Lane'
				GOTO Error_Encountered
			END
			
			SELECT @RecordStatus = 'Lane Updated'
			SELECT @ImportedInd = 1
			SELECT @ImportedDate = @CreationDate
			SELECT @ImportedBy = @CreatedBy
		END
		ELSE
		BEGIN
			SELECT @ExceptionEncounteredInd = 1
			SELECT @RecordStatus = 'Multiple Matches For Lane'
			SELECT @ImportedInd = 0
			SELECT @ImportedDate = NULL
			SELECT @ImportedBy = NULL
		END
			
		End_Of_Loop:
		--update the import record
		UPDATE SDCLoadLanesImport
		SET RecordStatus = @RecordStatus,
		ImportedInd = @ImportedInd,
		ImportedDate = @ImportedDate,
		ImportedBy = @ImportedBy
		WHERE SDCLoadLanesImportID = @SDCLoadLanesImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @ReturnMessage = 'Error Updating Import Table'
			GOTO Error_Encountered
		END
		
		FETCH ImportLoadLanesCursor INTO @SDCLoadLanesImportID, @LaneGroup,
		@LaneNumber, @VehicleCapacity, @SortOrder
	END
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ImportLoadLanesCursor
		DEALLOCATE ImportLoadLanesCursor
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
		CLOSE ImportLoadLanesCursor
		DEALLOCATE ImportLoadLanesCursor
		SELECT @ReturnCode = @ErrorID
	END
	
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage
	
	RETURN
END
GO
