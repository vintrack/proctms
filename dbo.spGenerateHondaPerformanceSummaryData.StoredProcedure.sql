USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateHondaPerformanceSummaryData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[spGenerateHondaPerformanceSummaryData] (@ScheduleDate datetime)  
AS  
BEGIN  
 set nocount on  
 DECLARE  
 @HondaPerformanceSummaryID     int,  
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

--The below one is for Honda that covers each day data and perform separate Month  and week from omnis'
--SELECT @StartDate = CONVERT(VARCHAR(10),DATEADD(DAY,-1,@ScheduleDate),101)   

SELECT @StartDate = CONVERT(VARCHAR(10),DATEADD(dd,-1,@ScheduleDate),101)   
  


--SELECT @StartDate = CONVERT(VARCHAR(10),@ScheduleDate,101)   


--Print @StartDate


-- SELECT @EndDate= CONVERT(VARCHAR(25),@ScheduleDate ,101)  
  
  
 /************************************************************************  
 * spGenerateHondaPerformanceSummaryData					  *  
 *         *  
 * Description       *  
 * -----------       *  
 * This procedure insert daily Data in HondaPerformanceSummary    		*  
 * by LocationID       *  
 * Change History       *  
 * --------------       *  
 * Date       Init's Description     *  
 * ---------- ------ ---------------------------------------- *  
 * 07/02/2015 Saad Salam    Initial version    *  
 *         *  
 ************************************************************************/  
 
 
 BEGIN  



 INSERT INTO HondaPerformanceSummary(  
 ScheduleDate,  
 LocationID,
 TotalShipped,
 OnTimeCounts,
 CreationDate,  
 CreatedBy )

--Declare @StartDate as datetime
--Set @StartDate ='07/06/2015'

SELECT @StartDate,L1.PickupLocationID,
COUNT(*) as TotalShipped,
SUM(CASE WHEN DATEDIFF(hh,DATEADD(hh,30,CONVERT(VARCHAR(10),L1.DateAvailable,101)),L1.DropoffDate) <= LPS.StandardDays  THEN 1 ELSE 0 END) as OnTimeCounts
  ---Add 30 hours to get the car available
,GetDate() as Creationdate,'Nightly' as CreatedBy
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
AND L1.PickupLocationID NOT IN (SELECT LocationID FROM HondaPerformanceSummary WHERE ScheduleDate = @StartDate)  
AND (Convert(Varchar(10),L1.DropoffDate,101) = @StartDate
AND L2.DropOffDate IS NOT NULL
AND LPS.StandardDays IS NOT NULL)
GROUP BY L1.PickupLocationID



  
  IF @@Error <> 0  
  BEGIN  
   SELECT @ErrorID = @@ERROR  
   SELECT @Status = 'ERROR CREATING Honda PERFORMNACE  SUMMARY RECORD'  
   GOTO Error_Encountered  
  END  
  END  
   
  SELECT @ErrorID = 0  
  
  Error_Encountered:  
  IF @ErrorID = 0  
  BEGIN  
  PRINT 'GenerateHondaPerformanceSummaryData Error_Encountered =' + STR(@ErrorID)  
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
  
  
GRANT  EXECUTE  ON [dbo].[spHondaPerformanceSummaryData]  TO [db_sp_execute]
GO
