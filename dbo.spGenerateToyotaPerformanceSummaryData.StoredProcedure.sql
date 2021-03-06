USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateToyotaPerformanceSummaryData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[spGenerateToyotaPerformanceSummaryData] (@ScheduleDate datetime)  
AS  
BEGIN  
 set nocount on  
 DECLARE  
 @ToyotaPerformanceSummaryID     int,  
 @StartDate    datetime,  
 @EndDate    datetime,  
 @CreationDate   datetime,  
 @CreatedBy   Varchar(50),  
 @ErrorID   int,  
 @ErrorEncountered  varchar(5000),  
 @ReturnCode   int,  
 @ReturnMessage   varchar(100),  
 @Status    varchar(100)  
   
  
  
 SELECT @StartDate = CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(@ScheduleDate)-1),@ScheduleDate),101)   
 SELECT @EndDate= CONVERT(VARCHAR(25),@ScheduleDate ,101)  
  
  
 /************************************************************************  
 * spGeneratespToyotaPerformanceSummaryData   *  
 *         *  
 * Description       *  
 * -----------       *  
 *       This procedure insert daily Data in ToyotaPerformanceSummary    *  
 * by LocationID       *  
 * Change History       *  
 * --------------       *  
 * Date       Init's Description     *  
 * ---------- ------ ---------------------------------------- *  
 * 10/15/2012 SS    Initial version    *  
 *         *  
 ************************************************************************/  
 
 
 BEGIN  
  --create the Toyota Performance Summary record  
  
  
  INSERT INTO ToyotaPerformanceSummary(  
  ScheduleDate,  
  LocationID,
  CreationDate,  
  CreatedBy,  
  OnTimePercentage  
    )  
 SELECT DATEADD(dd,-1,@ScheduleDate),TheLocationID, GetDate(),'Nightly',ROUND(convert(decimal(19,2),Sum(StatCount))/COUNT(*)*100 ,2)
 FROM(
 SELECT L1.PickupLocationID as TheLocationID,   
 CASE WHEN DATEDIFF(dy,L1.DateAvailable,L2.DropoffDate) - (SELECT COUNT(*) FROM Calendar WHERE CalendarDate Between L1.DateAvailable AND L2.DropoffDate AND DayName IN ('Saturday','Sunday'))
--Modified on Nov 11 2013 to fix Holidays/Weekends
--(DATEDIFF(dy,L1.DateAvailable,L2.DropoffDate)/7*2 +  
 --CASE WHEN DATEPART(dw,L1.DateAvailable)=1 and DATEDIFF(dy,L1.DateAvailable,L2.DropoffDate)%7<6 THEN 1  
-- WHEN DATEPART(dw,L1.DateAvailable)=1 and DATEDIFF(dy,L1.DateAvailable,L2.DropoffDate)%7=6 THEN 2  
-- WHEN DATEPART(dw,L1.DateAvailable)>1 and DATEPART(dw,L1.DateAvailable)+DATEDIFF(dy,L1.DateAvailable,L2.DropoffDate)=7 THEN 1  
-- WHEN DATEPART(dw,L1.DateAvailable)>1 and DATEPART(dw,L1.DateAvailable)+DATEDIFF(dy,L1.DateAvailable,L2.DropoffDate)>7 THEN 2  
-- ELSE 0 END)
 -(SELECT Count(*) FROM Holiday H Where HolidayDate Between L1.DateAvailable AND L2.DropoffDate)  <= LPS.StandardDays  THEN 1 ELSE 0 END StatCount  
 FROM   
 Vehicle V  
 LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID  
 AND L1.LegNumber = 1  
 LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID  
 AND L2.FinalLegInd = 1  
 LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID  
 AND V.PickupLocationID = LPS.OriginID  
 AND V.DropoffLocationID = LPS.DestinationID  
 WHERE V.CustomerID IN (SELECT CONVERT(int,ST.ValueDescription) FROM SettingTable ST WHERE ST.ValueKey = 'ToyotaCustomerID' )  
 AND L1.PickupLocationID IN (SELECT CONVERT(int,Value1) FROM Code WHERE CodeType='ToyotaLocationCode' AND RecordStatus='Active')  
 AND L1.PickupLocationID NOT IN (SELECT LocationID FROM ToyotaPerformanceSummary WHERE ScheduleDate = @ScheduleDate)  
 AND L2.DropoffDate 
--->= @StartDate 
BETWEEN @StartDate AND DATEADD(day,1,@EndDate)
 
 ---AND L2.DropoffDate < DATEADD(day,1,@EndDate)
)  
AS TempTable
Group By TheLocationID

  
  
  IF @@Error <> 0  
  BEGIN  
   SELECT @ErrorID = @@ERROR  
   SELECT @Status = 'ERROR CREATING TOYOTA PERFORMNACE  SUMMARY RECORD'  
   GOTO Error_Encountered  
  END  
  END  
   
  SELECT @ErrorID = 0  
  
  Error_Encountered:  
  IF @ErrorID = 0  
  BEGIN  
  PRINT 'GenerateToyotaPerformanceSummaryData Error_Encountered =' + STR(@ErrorID)  
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
  
  
GRANT  EXECUTE  ON [dbo].[spGenerateToyotaPerformanceSummaryData]  TO [db_sp_execute]
GO
