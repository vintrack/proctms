USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateGMPerformanceSummaryData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[spGenerateGMPerformanceSummaryData] (@ScheduleDate datetime)  
AS  
BEGIN  
 set nocount on  
 DECLARE  
 @GMPerformanceSummaryID     int,  
 @StartDate    datetime,  
 @EndDate    datetime,  
 @CreationDate   datetime,  
 @CreatedBy   Varchar(50),  
 @ErrorID   int,  
 @ErrorEncountered  varchar(5000),  
 @ReturnCode   int,  
 @ReturnMessage   varchar(100),  
 @Status    varchar(100)

--The below one is for toyota that covers month data'
--SELECT @StartDate = CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(@ScheduleDate)-1),@ScheduleDate),101)   

--The below one is for GM that covers each day data and perform separate Month  and week from omnis'

SELECT @StartDate = CONVERT(VARCHAR(10),DATEADD(dd,-1,@ScheduleDate),101)   
  

--Declare @StartDate as datetime
--Set @StartDate ='07/01/2015'  
--SELECT @StartDate = CONVERT(VARCHAR(10),DATEADD(dd,-1,@StartDate),101)   

--Print @StartDate

 /************************************************************************  
 * spGenerateGMPerformanceSummaryData					  *  
 *         *  
 * Description       *  
 * -----------       *  
 * This procedure insert daily Data in GMPerformanceSummary    		*  
 * by LocationID       *  
 * Change History       *  
 * --------------       *  
 * Date       Init's Description     *  
 * ---------- ------ ---------------------------------------- *  
 * 07/01/2015 Saad Salam    Initial version    *  
 *         *  
 ************************************************************************/  
 
 
 BEGIN  

 INSERT INTO GMPerformanceSummary(  
 ScheduleDate,  
 LocationID,
 TotalShipped,
 OnTimeCounts,
 CreationDate,  
 CreatedBy )

--Declare @StartDate as datetime
--Set @StartDate ='07/06/2015'

  
SELECT @StartDate,TheLocationID,COUNT(*) as TotalShipped,Sum(StatCount) as OnTimeCounts,GetDate(),'Nightly'
FROM(
SELECT L1.PickupLocationID as TheLocationID,CASE WHEN DATEDIFF(dy,L1.DateAvailable,L2.PickupDate)
-(SELECT COUNT(*) FROM Calendar WHERE CalendarDate Between L1.DateAvailable AND L2.PickupDate AND DayName IN ('Saturday','Sunday'))
-(SELECT COUNT(*) FROM Holiday H Where HolidayDate Between L1.DateAvailable AND L2.PickupDate) <= LPS.StandardDays  THEN 1 ELSE 0 END StatCount
FROM Vehicle V
LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
AND L1.LegNumber = 1
LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID
AND L2.FinalLegInd = 1
LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
AND V.PickupLocationID = LPS.OriginID
AND V.DropoffLocationID = LPS.DestinationID
LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
WHERE V.CustomerID = (SELECT TOP 1 CONVERT(int,ST.ValueDescription) FROM SettingTable ST WHERE ST.ValueKey = 'GMCustomerID' )
AND V.PickupLocationID IN (SELECT CONVERT(int,Value1) FROM Code WHERE CodeType='GMLocationCode' AND RecordStatus='Active')
AND L1.PickupLocationID NOT IN (SELECT LocationID FROM GMPerformanceSummary WHERE ScheduleDate = @StartDate)  
AND CONVERT(varchar(10),L1.PickupDate,101) = @StartDate
AND LPS.StandardDays IS NOT NULL)
AS TempTable
Group By TheLocationID







  
  IF @@Error <> 0  
  BEGIN  
   SELECT @ErrorID = @@ERROR  
   SELECT @Status = 'ERROR CREATING GM PERFORMNACE  SUMMARY RECORD'  
   GOTO Error_Encountered  
  END  
  END  
   
  SELECT @ErrorID = 0  
  
  Error_Encountered:  
  IF @ErrorID = 0  
  BEGIN  
  PRINT 'GenerateGMPerformanceSummaryData Error_Encountered =' + STR(@ErrorID)  
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
  
  
GRANT  EXECUTE  ON [dbo].[spGMPerformanceSummaryData]  TO [db_sp_execute]
GO
