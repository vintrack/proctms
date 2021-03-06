USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateMercedesPerformanceSummaryData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[spGenerateMercedesPerformanceSummaryData] (@ScheduleDate datetime)  
AS  BEGIN  
set nocount on  
 DECLARE  
 @MercedesPerformanceSummaryID     int,  
 @StartDate    datetime,  
 @CreationDate   datetime,  
 @CreatedBy   Varchar(50),  
 @ErrorID   int,  
 @ErrorEncountered  varchar(5000),  
 @ReturnCode   int,  
 @ReturnMessage   varchar(100),  
 @Status    varchar(100)  
   


 --SELECT @StartDate = CONVERT(VARCHAR(10),DATEADD(dd,-(DAY(@ScheduleDate)-1),@ScheduleDate),101)   
 SELECT @StartDate = CONVERT(VARCHAR(10),DATEADD(dd,-1,@ScheduleDate),101)   
  


 BEGIN  
  --create the Toyota Performance Summary record  
 INSERT INTO MercedesPerformanceSummary(  
 ScheduleDate,  
 LocationID,
 TotalShipped,
 OnTimeCounts,
 CreationDate,  
 CreatedBy 
    )  
 SELECT @StartDate,TheLocationID,COUNT(*) as TotalShipped,Sum(StatCount) as OnTimeCounts,GetDate(),'Nightly'
-- GetDate(),'Nightly',ROUND(convert(decimal(19,2),Sum(StatCount))/COUNT(*)*100 ,2)
 FROM(
 SELECT L1.PickupLocationID as TheLocationID,   
 --CASE WHEN DATEDIFF(dy,L1.DateAvailable,L2.DropoffDate) - 
 CASE WHEN DATEDIFF(dy,L1.DateAvailable,L2.PickupDate)
-(SELECT COUNT(*) FROM Calendar WHERE CalendarDate Between L1.DateAvailable AND L2.PickupDate AND DayName IN ('Saturday','Sunday'))
- (SELECT Count(*) FROM Holiday H Where HolidayDate Between L1.DateAvailable AND L2.PickupDate) <= LPS.StandardDays  THEN 1 ELSE 0 END StatCount FROM   
 Vehicle V  
 LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID  
 AND L1.LegNumber = 1  
 LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID  
 AND L2.FinalLegInd = 1  
 LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID  
 AND V.PickupLocationID = LPS.OriginID  
 AND V.DropoffLocationID = LPS.DestinationID  
 LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID

WHERE V.CustomerID IN (SELECT CONVERT(int,ST.ValueDescription) FROM SettingTable ST WHERE ST.ValueKey = 'MercedesCustomerID' )  
AND L1.PickupLocationID IN (SELECT CONVERT(int,Value1) FROM Code WHERE CodeType='MercedesLocationCode' AND RecordStatus='Active')  
AND L1.PickupLocationID NOT IN (SELECT LocationID FROM MercedesPerformanceSummary WHERE ScheduleDate = @StartDate)  
AND Convert(Varchar(10),L1.PickupDate,101) = @StartDate 
AND LPS.StandardDays IS NOT NULL
)  
AS TempTable
Group By TheLocationID






  IF @@Error <> 0  
  BEGIN  
   SELECT @ErrorID = @@ERROR  
   SELECT @Status = 'ERROR CREATING Mercedes PERFORMNACE  SUMMARY RECORD'  
   GOTO Error_Encountered  
  END  
  END  
  SELECT @ErrorID = 0  
  Error_Encountered:  
  IF @ErrorID = 0  
  BEGIN  
  PRINT 'GenerateMercedesPerformanceSummaryData Error_Encountered =' + STR(@ErrorID)  
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
GRANT  EXECUTE  ON [dbo].[spGenerateMercedesPerformanceSummaryData]  TO [db_sp_execute]
GO
