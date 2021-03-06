USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateMercedesETAData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateMercedesETAData] 
AS
BEGIN
DECLARE
	@MercedesStartDate 		datetime,
	@CreationDate			datetime,
	@CreatedBy			Varchar(50),
	@ErrorID			int,
	@ErrorEncountered		varchar(5000),
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@Status				varchar(100)

	/************************************************************************
	*	spGenerateFordStatusChangeData					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the status change export data for Fords*
	*	that have been put on hold.					*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	12/12/2012 Saad   Initial version				*
	*	06/19/2017 CMK	  Modified the procdure to use			*
	*			  Vehicle.DateMadeAvailable instead of doing the*
	*			  lookups to the rail/Mercedes files to get the *
	*			  date and time that the units were released	*
	*									*
	************************************************************************/

	SELECT @MercedesStartDate =DATEADD(m, -6, current_timestamp)

	TRUNCATE TABLE MercedesETA


	INSERT INTO MercedesETA(OriginID,DestinationID,ETAHours,CreationDate,CreatedBy)
		SELECT L.PickupLocationID as OriginID,L.DropoffLocationID as DestinationID,
		Avg(DATEDIFF(hour,V.DateMadeAvailable,L.DropOffdate)) as ETAHours,	--06/19/2017 - CMK - 
		--Avg(DATEDIFF(hour,
		--ISNULL(ISNULL(CONVERT(varchar(10),NS.ActionDate,101)+' '+SUBSTRING(NS.TransmitTime,1,2)+':'+SUBSTRING(NS.TransmitTime,3,2)   
		--,CONVERT(varchar(10),CSX.UnloadDate,101) +' '+SUBSTRING(CSX.UnloadTime,1,2)+':'+SUBSTRING(CSX.UnloadTime,3,2)),MI.CreationDate),L.DropOffdate))as ETAHours,
		GetDate(),'Nightly'
		FROM Legs L
		LEFT JOIN Vehicle V ON L.VehicleID = V.VehicleID
		--LEFT JOIN MercedesImport MI ON  V.VIN = MI.VIN 
		--LEFT JOIN NSTruckerNotificationImport NS ON  V.VIN = NS.VIN AND V.CustomerId=NS.CustomerID
		--LEFT JOIN  CSXRailheadFeedImport CSX   ON    V.VIN =CSX.VIN AND CSX.Manufacturer='mercedes'
		WHERE L.DropoffDate > @MercedesStartDate
		AND V.CustomerID = (SELECT CONVERT(int,ST.ValueDescription) FROM SettingTable ST WHERE ST.ValueKey = 'MercedesCustomerID')
		--AND (NS.VIN IS NOT NULL OR CSX.VIN IS NOT NULL OR MI.VIN IS NOT NULL)
		--AND DATEDIFF(hour,
		--ISNULL(ISNULL(CONVERT(varchar(10),NS.ActionDate,101)+' '+SUBSTRING(NS.TransmitTime,1,2)+':'+SUBSTRING(NS.TransmitTime,3,2)   
		--,CONVERT(varchar(10),CSX.UnloadDate,101) +' '+SUBSTRING(CSX.UnloadTime,1,2)+':'+SUBSTRING(CSX.UnloadTime,3,2)),MI.CreationDate),L.DropOffdate) < 288
		AND V.DateMadeAvailable IS NOT NULL
		AND (SELECT COUNT(*) FROM VehicleHolds VH WHERE VH.VehicleID = V.VehicleID) = 0
		Group by L.PickupLocationID ,L.DropoffLocationID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'ERROR CREATING MERCEDES ETA RECORDS'
		GOTO Error_Encountered
	END
	
	SELECT @ErrorID = 0
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		PRINT 'Generate Mercedes ETA DATA =' + STR(@ErrorID)
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
