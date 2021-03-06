USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spCreateDriverLoad]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spCreateDriverLoad](
	@DriverID		int,		
	@Date			datetime,
	@User			varchar(20)	-- Can be either user name or application name
	)
AS
BEGIN
	/************************************************************************
	*	spCreateDriverLoad						*
	*		returns int: LoadID created							*
	*									*
	*	Description							*
	*	-----------							*
	*	Creates a new load record for a driver (used by phone to load unassigned work).	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	06/27/2005 JEP    initial version				*
	*	07/08/2005 JEP    removed explicit database-name 'DAIdev' from insert stmt. *
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	@LoadID		int,
		@LoadNumCounter	varchar(20),
		@LoadNumber		varchar(20),
		@rowcount		int,
		
		@CreationDate		datetime,
		@CreatedBy		varchar(20),
		@UpdatedDate		datetime,
		@UpdatedBy		varchar(20),
		@ReturnCode		int,
		@ReturnMessage		varchar(50),
		@ErrorID		int,
		@Msg			varchar(50),
		@LoadSizeAdjustment	int,
		@Count			int,
		@VehicleReservationID	int,
		@ReservationCount	int,
		@ReservationSize	int,
		@CustomerID		int

	/* CUSTOM ERRORS
	100001 DriverID is null or 0
	100002 DriverID is not found
	*/
	SELECT @Count = 0
	SELECT @ErrorID = 1
	--SELECT @LoadSizeAdjustment = 0
		
	BEGIN TRAN
	
	
	IF @DriverID IS NULL or @DriverID = 0
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Msg = 'DriverID is missing.'
		GOTO Error_Encountered
	END
	
	--validate the driverID
	SELECT @rowcount = count(*)
	FROM Driver
	WHERE DriverID = @DriverID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered validating the DriverID'
		GOTO Error_Encountered
	END
	
	IF @rowcount < 1
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Msg = 'DriverID is not valid'
		GOTO Error_Encountered
	END
	
	
	--get the loadnumber
	SELECT @LoadNumCounter = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'NextLoadNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the NextLoadNumber'
		GOTO Error_Encountered
	END
	
	--update the nextloadnumber
	UPDATE SettingTable
	SET ValueDescription = @LoadNumCounter + 1
	WHERE ValueKey = 'NextLoadNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered updating the NextLoadNumber'
		GOTO Error_Encountered
	END
	
	-- format load counter like: 'YYMMXXXXX'  (june 2005, 1st load num: '05060001')
	set @LoadNumber = left(convert(varchar(6),getdate(),12),4) + right(replicate('0',4) + convert(varchar(4),@LoadNumCounter), 4)

	--insert the new load record
	INSERT INTO Loads
		(DriverID, 
		LoadNumber, 
		LoadSize, 
		NumberLoaded, 
		OutsideCarrierLoadInd, 
		OutsideCarrierID, 
		ScheduledPickupDate, 
		LoadStatus, 
		CreationDate, 
		CreatedBy)
	VALUES
		(@DriverID, 
		@LoadNumber, 
		0, -- loadsize 
		0, -- NumberLoaded,int
		0, -- OutsideCarrierLoadInd,int
		null, -- OutsideCarrierID,int
		@Date, -- ScheduledPickupDate,datetime
		'Scheduled & Assigned', -- LoadStatus,varchar(20)
		getdate(), -- CreationDate,datetime
		@User ) -- CreatedBy,varchar(20)
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered inserting the load record'
		GOTO Error_Encountered
	END
	
	
	--get the loadid
	SELECT @LoadID = @@Identity
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting the New Load ID'
		GOTO Error_Encountered
	END
	

	--got through without any errors, so make sure the error id is zero
	SELECT @ErrorID = 0
	
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
		SELECT @ReturnMessage = 'New Load Created Successfully'
	END

	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM', @LoadID as 'LoadID'

	RETURN @ReturnCode
END

GO
