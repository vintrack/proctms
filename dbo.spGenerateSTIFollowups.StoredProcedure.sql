USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateSTIFollowups]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateSTIFollowups]
AS
BEGIN
	set nocount on

	DECLARE
	@CustomerID		int,
	@RunID			int,
	@LoadID			int,
	@PickupLocationID	int,
	@DropoffLocationID	int,
	@DropoffDate		datetime,
	@CreationDate		datetime,
	@CreatedBy		varchar(20),
	@ErrorID		int,
	@ErrorEncountered	varchar(5000),
	@loopcounter		int,
	@ResultCode		int,
	@ReturnCode		int,
	@Status			varchar(100),
	@ReturnMessage		varchar(100)

	/************************************************************************
	*	spGenerateSTIFollowups						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure writes records for each Run/Location combination	*
	*	for vehicles that are delivered STI.				*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	10/16/2008 CMK    Initial version				*
	*									*
	************************************************************************/

	DECLARE STIDeliveryCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT DISTINCT C.CustomerID, L.RunID, L.LoadID, L.PickupLocationID, L.DropoffLocationID, CONVERT(varchar(10),L.DropoffDate,101)
		FROM Legs L
		LEFT JOIN Vehicle V ON L.VehicleID = V.VehicleID
		LEFT JOIN Customer C ON V.CustomerID = C.CustomerID
		WHERE C.STIFollowupRequiredInd = 1
		AND L.DropoffDate IS NOT NULL
		AND L.DropoffDate > DATEADD(day,-5,CURRENT_TIMESTAMP) 
		AND V.VehicleID IN (SELECT VI.VehicleID FROM VehicleInspection VI
		WHERE VI.VehicleID = V.VehicleID AND VI.SubjectToInspectionInd = 1
		AND VI.InspectionType = 3)
		AND (SELECT COUNT(*) FROM STIFollowups S 
		WHERE S.RunID = L.RunID
		AND S.PickupLocationID = L.PickupLocationID
		AND S.DropoffLocationID = L.DropoffLocationID) = 0
		
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = 'SYSTEM'
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	
	OPEN STIDeliveryCursor
	--print 'cursor open'

	IF @@CURSOR_ROWS = 0
	BEGIN
		SELECT @ErrorID = 0
		GOTO Error_Encountered2
	END
	
	BEGIN TRAN

	FETCH STIDeliveryCursor INTO @CustomerID, @RunID, @LoadID, @PickupLocationID, @DropoffLocationID, @DropoffDate
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--insert the record into the STIFollowups table
		INSERT INTO STIFollowups(
			CustomerID,
			RunID,
			LoadID,
			PickupLocationID,
			DropoffLocationID,
			DropoffDate,
			DealerContactedInd,
			SignedCopyReceivedInd,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@CustomerID,
			@RunID,
			@LoadID,
			@PickupLocationID,
			@DropoffLocationID,
			@DropoffDate,
			0,		--DealerContactedInd,
			0,		--SignedCopyReceivedInd,
			@CreationDate,
			@CreatedBy
		)
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Creating STI Followups Record'
			GOTO Error_Encountered
		END
		
		FETCH STIDeliveryCursor INTO @CustomerID, @RunID, @LoadID, @PickupLocationID, @DropoffLocationID, @DropoffDate

	END --end of loop
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE STIDeliveryCursor
		DEALLOCATE STIDeliveryCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE STIDeliveryCursor
		DEALLOCATE STIDeliveryCursor
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
