USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spAddReload]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spAddReload](
	@RunID		int,
	@LocationID	int,
	@LegID		int,
	@Who		varchar(20)	-- Can be either user name or application name
	)
AS
BEGIN
	/************************************************************************
	*	spAddReload							*
	*									*
	*	Description							*
	*	-----------							*
	*	Adds a record to the RunReloads table for the specified Run,	*
	*	Location and Leg.						*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	09/29/2008 CMK    Initial Version				*
	*									*
	************************************************************************/

	SET nocount on

	DECLARE	
		@CreationDate		datetime,
		@CreatedBy		varchar(20),
		@LegPickupLocationID	int,
		@LegDropoffLocationID	int,
		@RunReloadsID		int,
		--procedure control
		@ReturnCode		int,
		@ReturnMessage		varchar(100),
		@ErrorID		int,
		@Msg			varchar(100),
		@Count			int

	SELECT @Count = 0
	SELECT @ErrorID = 0
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @CreatedBy = @Who
	
	BEGIN TRAN
	
	IF @RunID IS NULL
	BEGIN
		SELECT @ErrorID = 100000
		SELECT @Msg = 'RunID IS NULL'
		GOTO Error_Encountered
	END
	IF @LocationID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Msg = 'LocationID IS NULL'
		GOTO Error_Encountered
	END
	IF @LegID IS NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Msg = 'LegID IS NULL'
		GOTO Error_Encountered
	END
	--validate that the reload location is not the same as the leg delivery location
	SELECT @LegPickupLocationID = L.PickupLocationID,
	@LegDropoffLocationID = L.DropoffLocationID
	FROM Legs L
	WHERE L.LegsID = @LegID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the Leg Info'
		GOTO Error_Encountered
	END
	
	IF @LegPickupLocationID = @LocationID
	BEGIN
		SELECT @ErrorID = 100003
		SELECT @Msg = 'Invalid Reload, Leg Origin and Reload Location are the same.'
		GOTO Error_Encountered
	END
	/*
	IF @LegDropoffLocationID = @LocationID
	BEGIN
		SELECT @ErrorID = 100004
		SELECT @Msg = 'Invalid Reload, Leg Destination and Reload Location are the same.
		GOTO Error_Encountered'
	END
	*/
	--validate that there is not already a reload for this leg at this location
	SELECT @Count = count(*)
	FROM RunReloads
	WHERE RunID = @RunID
	AND LocationID = @LocationID
	AND LegsID = @LegID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the Duplicate Reload Count'
		GOTO Error_Encountered
	END
	
	IF @Count >= 1
	BEGIN
		SELECT @ErrorID = 100005
		SELECT @Msg = 'Duplicate Run Reloads Records found!'
		GOTO Error_Encountered
	END
	
	-- add the run reload record
	INSERT INTO RunReloads(
		RunID,
		LocationID,
		LegsID,
		CreationDate,
		CreatedBy
	)
	VALUES(
		@RunID,
		@LocationID,
		@LegID,
		@CreationDate,
		@CreatedBy
	)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered creating Run Reloads Record'
		GOTO Error_Encountered
	END
	SELECT @RunReloadsID = @@IDENTITY

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
		SELECT @ReturnMessage = 'RunStop Updated Successfully'
	END

	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM', @RunReloadsID AS 'ID'

	RETURN @ReturnCode
END

GRANT  EXECUTE  ON [dbo].[spAddReload]  TO [db_sp_execute]
GO
