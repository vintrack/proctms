USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[SpGetHondaPercentages]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[SpGetHondaPercentages] (@LocationID int)
AS
BEGIN
	set nocount on
	DECLARE
	@ErrorID		int,
	@ErrorEncountered	varchar(5000),
	@ResultCode		int,
	@ReturnCode		int,
	@Status			varchar(100),
	@ReturnMessage		varchar(100),
	@CreationDate		datetime
	
	
 
	/************************************************************************
	*	Note : have to generalize for main dashboard
		SpGetHondaPercentages					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure output the daily dash board pipeline 
		for terminal	*
	*									*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	05/29/2015 SS    Initial version				*
	*									*
	************************************************************************/



 	SELECT @ErrorID =0

	
	BEGIN TRAN

	---PipeLine Data
	SELECT '1' as sortorder, 'Prev-Month :' as TimePeriod ,ROUND(CONVERT(decimal(19,2),(SUM (CASE WHEN
	DATEDIFF(hh,DATEADD(hh,30,CONVERT(VARCHAR(10),L1.DateAvailable,101)),L1.DropoffDate) <= LPS.StandardDays  THEN 1 ELSE 0 END)))/
	COUNT(*)*100 ,2) as OnTimePercentage
	INTO #HondaPercentages
	FROM Vehicle V
	LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
	AND L1.LegNumber = 1
	LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID
	AND L2.FinalLegInd = 1
	LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	AND V.PickupLocationID = LPS.OriginID
	AND V.DropoffLocationID = LPS.DestinationID
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	WHERE V.CustomerID = (SELECT TOP 1 CONVERT(int,ST.ValueDescription) FROM SettingTable ST WHERE ST.ValueKey = 'HondaCustomerID' )
	AND L1.PickupLocationID IN (SELECT CONVERT(int,Value1) FROM Code WHERE CodeType='HondaLocationCode' AND RecordStatus='Active')
	AND (L2.DateAvailable BETWEEN DATEADD(MONTH, DATEDIFF(MONTH, 0, current_timestamp)-1, 0)
	AND DATEADD(MONTH, DATEDIFF(MONTH, -1, Current_Timestamp)-1, -1))
	AND L2.DropOffDate IS NOT NULL
	AND LPS.StandardDays IS NOT NULL
	AND V.PickupLocationID = @LocationID
	UNION
	  ---current month
	SELECT '2' as sortorder,'Cur-Month  :' as TimePeriod, ROUND(convert(decimal(19,2),(SUM (CASE WHEN
	DATEDIFF(hh,DATEADD(hh,30,CONVERT(VARCHAR(10),L1.DateAvailable,101)),L1.DropoffDate) <= LPS.StandardDays  THEN 1 ELSE 0 END)))/
	COUNT(*)*100 ,2) as OnTimePercentage
	FROM Vehicle V
	LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
	AND L1.LegNumber = 1
	LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID
	AND L2.FinalLegInd = 1
	LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	AND V.PickupLocationID = LPS.OriginID
	AND V.DropoffLocationID = LPS.DestinationID
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	WHERE V.CustomerID = (SELECT TOP 1 CONVERT(int,ST.ValueDescription) FROM SettingTable ST WHERE ST.ValueKey = 'HondaCustomerID' )
	AND L1.PickupLocationID IN (SELECT CONVERT(int,Value1) FROM Code WHERE CodeType='HondaLocationCode' AND RecordStatus='Active')
	AND L2.DateAvailable>= CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(current_timestamp)-1),current_timestamp),101)
	AND L2.DropOffDate IS NOT NULL
	AND LPS.StandardDays IS NOT NULL
	AND V.PickupLocationID = @LocationID
	UNION
	  ---current month counts
	SELECT '3' as sortorder,'Over 5 Days: ' as TimePeriod,Count(*) as Old5day
	FROM Vehicle V
	LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
	AND L1.LegNumber = 1
	LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID
	AND L2.FinalLegInd = 1
	LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	AND V.PickupLocationID = LPS.OriginID
	AND V.DropoffLocationID = LPS.DestinationID
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	WHERE V.CustomerID = (SELECT TOP 1 CONVERT(int,ST.ValueDescription) FROM SettingTable ST WHERE ST.ValueKey = 'HondaCustomerID' )
	AND V.PickupLocationID IN (SELECT CONVERT(int,Value1) FROM Code WHERE CodeType='HondaLocationCode' AND RecordStatus='Active')
	AND DATEDIFF(hh,DATEADD(hh,30,CONVERT(VARCHAR(10),L2.DateAvailable,101)),L2.DropoffDate)>=150
	AND L2.DropOffDate IS NOT NULL
	AND LPS.StandardDays IS NOT NULL
	AND V.PickupLocationID = @LocationID
	AND L2.DateAvailable>= CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(current_timestamp)-1),current_timestamp),101)
	ORDER By sortorder



	--print 'cursor opened'
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating PipeLine record'
			GOTO Error_Encountered
		END
			

	--print 'end of loop'
	Error_Encountered:
	
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
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
	--SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage
		SELECT TimePeriod,OnTimePercentage from  #HondaPercentages
	RETURN
END
GO
