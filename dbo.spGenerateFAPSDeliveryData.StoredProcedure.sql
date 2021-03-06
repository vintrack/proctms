USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateFAPSDeliveryData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[spGenerateFAPSDeliveryData] (@CreatedBy varchar(20))  
AS  
BEGIN  
set nocount on  
  
 DECLARE  
 @ErrorID  int,  
 @loopcounter  int,  
 --FAPSDelivery table variables  
 @BatchID  int,
 @VehicleID  int, 
 @VIN   varchar(17),  
 @LoadNumber  varchar(10),  
 @DeliveryDateTime datetime,  
 @DealerCode  varchar(10),  
 @ExportedInd  int,  
 @RecordStatus  varchar(40),  
 @CreationDate  datetime,  
 --processing variables  
 @Status   varchar(100),  
 @ReturnCode  int,  
 @ReturnMessage  varchar(100),  
 @ReturnBatchID  int  
  
 /************************************************************************  
 * spGenerateFAPSDeliveryData
 * Description       *  
 * -----------       *  
 * This procedure generate the delivered vehicle data for FAPS *  
 * that have been delivered from FAPSLocation.     *  
 *         *  
 * Change History       *  
 * --------------       *  
 * Date       Init's Description     *  
 * ---------- ------ ---------------------------------------- *  
 * 06/15/2015 Saad    Initial version    *  
 *         *  
 ************************************************************************/  
   
  
 --get the next batch id from the setting table  
 SELECT @BatchID = CONVERT(int,ValueDescription)  
 FROM SettingTable  
 WHERE ValueKey = 'NextFAPSExportDeliveryBatchID'  
 IF @@ERROR <> 0  
 BEGIN  
  SELECT @ErrorID = @@ERROR  
  SELECT @Status = 'Error Getting BatchID'  
  GOTO Error_Encountered2  
 END  
 IF @BatchID IS NULL  
 BEGIN  
  SELECT @ErrorID = 100001  
  SELECT @Status = 'BatchID Not Found'  
  GOTO Error_Encountered2  
 END  
  
--' ' as 'std_del_tm',' ' as 'std_so#',as 'std_VIN',as 'std_Load#',as 'st_del_dt',
DECLARE FAPSDeliveryCursor CURSOR  
LOCAL FORWARD_ONLY STATIC READ_ONLY  
FOR  
SELECT V.VehicleID,V.VIN ,L2.LoadNumber,L.DropoffDate,
--CASE WHEN DATALENGTH(L3.CustomerLocationCode) > 0 THEN CASE WHEN CHARINDEX('-',L3.CustomerLocationCode) > 0 THEN SUBSTRING(L3.CustomerLocationCode,CHARINDEX('-',L3.CustomerLocationCode)+1,DATALENGTH(L3.CustomerLocationCode) - CHARINDEX('-',L3.CustomerLocationCode)) ELSE L3.CustomerLocationCode END ELSE '' END  as 'std_dealer',
L3.CustomerLocationCode
FROM Vehicle V  
LEFT JOIN Legs L ON V.VehicleID = L.VehicleID  
AND L.FinalLegInd = 1  
LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID  
LEFT JOIN Location L3 ON V.DropoffLocationID = L3.LocationID  
WHERE 
L.DropoffDate > L.PickupDate  AND
L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)  
AND V.VehicleStatus = 'Delivered'  
AND V.VehicleID NOT IN (SELECT VehicleID FROM FAPSExportDelivery)  
AND V.PickupLocationID IN 
(SELECT CONVERT(int,C.Code) FROM Code C WHERE C.CodeType = 'FAPSLocationCode')  
AND L.DropoffDate >= '06/01/2015' -- CAN BE REMOVED IN PROD  
ORDER BY V.VehicleID  
  
 SELECT @ErrorID = 0  
 SELECT @loopcounter = 0  
  
 OPEN FAPSDeliveryCursor  
  

 BEGIN TRAN  
   
 --set the default values  
 SELECT @ExportedInd = 0  
 SELECT @RecordStatus = 'Export Pending'  
 SELECT @CreationDate = CURRENT_TIMESTAMP  
   
 FETCH FAPSDeliveryCursor INTO @VehicleID,@VIN,@LoadNumber,@DeliveryDateTime,@DealerCode  
    
 --print 'about to enter loop'  
 WHILE @@FETCH_STATUS = 0  
 BEGIN  
  --insert the record  
  INSERT INTO FAPSExportDelivery(  
   BatchID,  
   VehicleID,  
   std_Vin,
   std_LoadNumber,  
   std_del_dt_tm,  
   std_dealer,  
   ExportedInd,
   RecordStatus,  
   CreationDate,  
   CreatedBy  
  )  
  VALUES(  
   @BatchID,  
   @VehicleID,  
   @VIN,
   @LoadNumber,    
   @DeliveryDateTime,  
   @DealerCode,  
   @ExportedInd,  
   @RecordStatus,  
   @CreationDate,  
   @CreatedBy  
  )  
   

  IF @@Error <> 0  
  BEGIN  
   SELECT @ErrorID = @@ERROR  
   SELECT @Status = 'Error creating FAPSExportDelivery record'  
   GOTO Error_Encountered  
  END  
    
  --End_Of_Loop:  
 FETCH FAPSDeliveryCursor INTO @VehicleID,@VIN,@LoadNumber,@DeliveryDateTime,@DealerCode  
 
  
 END --end of loop  
  
 --set the next batch id in the setting table  
 UPDATE SettingTable  
 SET ValueDescription = @BatchID+1   
 WHERE ValueKey = 'NextFAPSExportDeliveryBatchID'  
 IF @@ERROR <> 0  
 BEGIN  
   SELECT @ErrorID = @@ERROR  
   SELECT @Status = 'Error Setting BatchID'  
   GOTO Error_Encountered  
 END  
   
 Error_Encountered:  
 IF @ErrorID = 0  
 BEGIN  
  COMMIT TRAN  
  CLOSE FAPSDeliveryCursor  
  DEALLOCATE FAPSDeliveryCursor  
  SELECT @ReturnCode = 0  
  SELECT @ReturnMessage = 'Processing Completed Successfully'  
  SELECT @ReturnBatchID = @BatchID  
  GOTO Do_Return  
 END  
 ELSE  
 BEGIN  
  ROLLBACK TRAN  
  CLOSE FAPSDeliveryCursor  
  DEALLOCATE FAPSDeliveryCursor  
  SELECT @ReturnCode = @ErrorID  
  SELECT @ReturnMessage = @Status  
  SELECT @ReturnBatchID = NULL  
  GOTO Do_Return  
 END  
  
 Error_Encountered2:  
 IF @ErrorID = 0  
 BEGIN  
  SELECT @ReturnCode = 0  
  SELECT @ReturnMessage = 'Processing Completed Successfully'  
  SELECT @ReturnBatchID = @BatchID  
  GOTO Do_Return  
 END  
 ELSE  
 BEGIN  
  SELECT @ReturnCode = @ErrorID  
  SELECT @ReturnMessage = @Status  
  SELECT @ReturnBatchID = NULL  
  GOTO Do_Return  
 END  
   
 Do_Return:  
 SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage, @ReturnBatchID AS ReturnBatchID  
   
 RETURN  
END
GO
