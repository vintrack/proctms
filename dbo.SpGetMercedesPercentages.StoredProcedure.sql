USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[SpGetMercedesPercentages]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[SpGetMercedesPercentages] (@LocationID int)
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
		SpGetMercedesPercentages					*
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

	---Mercedes Percendage Data
	
	---current quarter--;  AND V.PickupLocationID=12733
	
	 SELECT '1' as Sortorder,'Qtr        :' as TimePeriod ,ROUND(convert(decimal(19,2),Sum(OnTimePercentage))/COUNT(*)*100 ,2) as  OnTimePercentage
	 INTO #MercedesPercentages   
	 FROM(SELECT
	 CASE WHEN DATEDIFF(dy,L1.DateAvailable,L2.PickupDate)
	 -(SELECT COUNT(*) FROM Calendar WHERE CalendarDate Between L1.DateAvailable AND L2.PickupDate AND DayName IN ('Saturday','Sunday'))
	 - (SELECT Count(*) FROM Holiday H Where HolidayDate Between L1.DateAvailable AND L2.PickupDate) <= LPS.StandardDays  THEN 1 ELSE 0 END OnTimePercentage
	 FROM Vehicle V
	 LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
	 AND L1.LegNumber = 1
	 LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID
	 AND L2.FinalLegInd = 1
	 LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	 AND V.PickupLocationID = LPS.OriginID
	 AND V.DropoffLocationID = LPS.DestinationID
	 LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	 WHERE V.CustomerID = (SELECT TOP 1 CONVERT(int,ST.ValueDescription) FROM SettingTable ST WHERE ST.ValueKey = 'MercedesCustomerID' )
	 AND V.PickupLocationID IN (SELECT CONVERT(int,Value1) FROM Code WHERE CodeType='MercedesLocationCode' AND RecordStatus='Active')
	 AND (L1.PickupDate BETWEEN  DATEADD(qq,DATEDIFF(qq,0,current_timestamp),0) AND  DATEADD(qq,DATEDIFF(qq,-1,current_timestamp),-1))
	 AND LPS.StandardDays IS NOT NULL
	 AND V.PickupLocationID=@LocationID)  
	 AS TempTable
	UNION
	--;  ---current month
	
	 SELECT '2' as Sortorder,'Month      :' as TimePeriod ,ROUND(convert(decimal(19,2),Sum(OnTimePercentage))/COUNT(*)*100 ,2)
	 FROM(SELECT
	 CASE WHEN DATEDIFF(dy,L1.DateAvailable,L2.PickupDate)
	 -(SELECT COUNT(*) FROM Calendar WHERE CalendarDate Between L1.DateAvailable AND L2.PickupDate AND DayName IN ('Saturday','Sunday'))
	 - (SELECT Count(*) FROM Holiday H Where HolidayDate Between L1.DateAvailable AND L2.PickupDate) <= LPS.StandardDays  THEN 1 ELSE 0 END OnTimePercentage

	 FROM Vehicle V
	 LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
	 AND L1.LegNumber = 1
	 LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID
	 AND L2.FinalLegInd = 1
	 LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	 AND V.PickupLocationID = LPS.OriginID
	 AND V.DropoffLocationID = LPS.DestinationID
	 LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	 WHERE V.CustomerID = (SELECT TOP 1 CONVERT(int,ST.ValueDescription) FROM SettingTable ST WHERE ST.ValueKey = 'MercedesCustomerID' )
	 AND V.PickupLocationID IN (SELECT CONVERT(int,Value1) FROM Code WHERE CodeType='MercedesLocationCode' AND RecordStatus='Active')
	 AND L1.PickupDate>= CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(current_timestamp)-1),current_timestamp),101)
	 AND LPS.StandardDays IS NOT NULL
	 AND V.PickupLocationID=@LocationID)
	 AS TempTable
	UNION
	--; Current week
	 SELECT '3' as Sortorder,'Week       :' as TimePeriod ,ROUND(CONVERT(decimal(19,2),Sum(OnTimePercentage))/COUNT(*)*100 ,2)
	 FROM(SELECT
	 CASE WHEN DATEDIFF(dy,L1.DateAvailable,L2.PickupDate)
	 -(SELECT COUNT(*) FROM Calendar WHERE CalendarDate Between L1.DateAvailable AND L2.PickupDate AND DayName IN ('Saturday','Sunday'))
	 - (SELECT Count(*) FROM Holiday H Where HolidayDate Between L1.DateAvailable AND L2.PickupDate) <= LPS.StandardDays  THEN 1 ELSE 0 END OnTimePercentage
	 FROM Vehicle V
	 LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
	 AND L1.LegNumber = 1
	 LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID
	 AND L2.FinalLegInd = 1
	 LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	 AND V.PickupLocationID = LPS.OriginID
	 AND V.DropoffLocationID = LPS.DestinationID
	 LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	 WHERE V.CustomerID = (SELECT TOP 1 CONVERT(int,ST.ValueDescription) FROM SettingTable ST WHERE ST.ValueKey = 'MercedesCustomerID' )
	 AND L1.PickupLocationID IN (SELECT CONVERT(int,Value1) FROM Code WHERE CodeType='MercedesLocationCode' AND RecordStatus='Active')
	 AND (L1.PickupDate BETWEEN CONVERT(varchar, DATEADD(dd, -(DATEPART(dw, CURRENT_TIMESTAMP) - 1), CURRENT_TIMESTAMP), 101)
	 AND CONVERT(varchar, DATEADD(dd, (7 - DATEPART(dw, CURRENT_TIMESTAMP)), CURRENT_TIMESTAMP), 101))
	 AND LPS.StandardDays IS NOT NULL
	 AND V.PickupLocationID=@LocationID)
	 AS TempTable
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
		SELECT TimePeriod,OnTimePercentage from  #MercedesPercentages
	RETURN
END
GO
