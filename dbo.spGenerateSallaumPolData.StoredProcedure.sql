USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateSallaumPolData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateSallaumPolData] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on
	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--SalumPOLExport table variables
	@BatchID			int,
	@Pol				varchar(5),
	@TerminalId			varchar(5),
	@Barcode			varchar(50),
	@ChassisNbr			varchar(25),
	@SallaumCustomerID		int,
	@CustomerId			varchar(9),
	@Make				varchar(3),
	@Model				varchar(4),
	@Description			varchar(50),
	@Color				varchar(3),
	@Location			varchar(4),
	@ReceivedOn			datetime,
	@ShippedOn			datetime,
	@Width1				varchar(10),
	@height1			varchar(10),
	@Length1			varchar(10),
	@Width2				varchar(10),
	@height2			varchar(10),
	@Length2			varchar(10),
	@Weight				varchar(10),
	@UnitType			varchar(50),
	@VoyageNbr			varchar(7),
	@VesselName			varchar(20),
	@POD				varchar(5),
	@Blocked			Bit,
	@Reason				varchar(40),
	@CustomsDocs			varchar(20),
	@CustomsRemarks			varchar(200),
	@CustomsStatus			varchar(2),
	@ClearedOn			datetime,
	@Shipper			varchar(20),
	@Damages			varchar(100),
	@HasRelatedItems		int,
	@RemovedFlag			Bit,
	@RemovedReason			varchar(200),
	@VehicleStatus			varchar(100),
	@ExportedInd			int,
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	--processing variables
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)

	/************************************************************************
	*	spGenerateSallaumPolData					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the Sallaum Line POL export data for	*
	*	vehicles that have been Landed.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	09/18/2014 SS    Initial version				*
	*									*
	************************************************************************/

	--get the SallaumCustomerID
	--From code table
	----------------------------
	--ClearedCustoms
	--CustomsException
	--Pending(?)
	--Received
	--ReceivedException(?)
	--Shipped
	--SubmittedCustoms
	--VoyageChangeHold(?)
	------------------------
	--From Sallaum DB
	--------------------
	--Received
	--SubmittedCustoms
	--ClearedCustoms
	--CustomsException
	--Shipped
----------------------------------------------------
	--DateReceived
	--ReceivedExceptionDate
	--DateSubmittedCustoms
	--CustomsExceptionDate
	--CustomsApprovedDate
	--DateShipped



	SELECT @SallaumCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SallaumCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting CustomerID'
		GOTO Error_Encountered2
	END
	
	--get the next batch id from the setting table
	--print 'getting batch id'

--------------------------------------------------------
	Select @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextSallaumExPortPOLBatchID'
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
----------------------------------------------------------------	

--set the next batch id in the setting table
			
			UPDATE SettingTable
			SET ValueDescription = @BatchID+1	
			WHERE ValueKey = 'NextSallaumExPortPOLBatchID'
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Setting BatchID'
				GOTO Error_Encountered2
			END
			
-----------------------------------------------------------------





	DECLARE SallaumPolCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR


		SELECT 'USBOS' as Pol,40 as TerminalID,VIN as BarCode,VIN as ChasisNbr,'' as CustomerID,LEFT(Make,3) as Make,LEFT(Model,4) as Model,Make + ' '+ Model as Description,
		LEFT(Color,3) as Color, LEFT(BayLocation,4) as Location,DateReceived as ReceivedOn,DateShipped as ShippedOn,VehicleWidth as Width1,VehicleHeight as Height1,VehicleLength as Length1,'' as Width2,
		'' as Height2,'' as Length2,VehicleWeight as Weight,''as Unittype,
		AEV1.VoyageNumber as VoyageNbr,
		AEV2.VesselName as VesselName ,
		LEFT(C.CodeDescription,5) as POD,'' as Blocked,'' as Reason,'' as CustomsDocs,
		'' as CustomsRemarks,'' as CustomsStatus,CustomsApprovedDate as ClearedOn,'' as Shipper,'' as Damages,'' as HasRelatedItems,
		CASE WHEN VesselName ='Sallaum Out By Truck' THEN 1 ELSE 0 END RemovedFlag,CASE WHEN VesselName = 'Sallaum Out By Truck' THEN AEV.Note ElSE '' END RemovedReason
		FROM AutoportExportVehicles AEV
		LEFT JOIN AEVoyage AEV1 ON AEV.VoyageID=AEV1.AEVoyageID
		LEFT JOIN AEVessel  AEV2 ON AEV1.AEVesselID=AEV2.AEVesselID
		LEFT JOIN Code C ON AEV.Destinationname = C.Code
		AND C.CodeType='UNLOCODE'
		WHERE CustomerID=@SallaumCustomerID
		AND AEV.VehicleStatus ='Received' AND AEV.DateReceived IS NOT NULL
		AND (AEV.VIN NOT IN (SELECT SPE.BarCode FROM SallaumPolExport SPE WHERE SPE.VehicleStatus='Received'))
		AND AEV.DateReceived >='01/23/2015' --(Cutoff date)
		ORDER BY AutoportExportVehiclesID Desc


 





	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN SallaumPolCursor
	
 BEGIN TRAN	
	
	
		
	SELECT @ExportedInd = 0
	SELECT @VehicleStatus ='Received'
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	FETCH SallaumPolCursor INTO @Pol,@TerminalId,@Barcode,@ChassisNbr,@CustomerId,@Make,@Model,@Description,@Color,
	@Location,@ReceivedOn,@ShippedOn,@Width1,@height1,@Length1,@Width2,@height2,@Length2,@Weight,@UnitType,@VoyageNbr,
	@VesselName,@POD,@Blocked,@Reason,@CustomsDocs,@CustomsRemarks,@CustomsStatus,@ClearedOn,@Shipper,@Damages,@HasRelatedItems,@RemovedFlag,@RemovedReason
	

	WHILE @@FETCH_STATUS = 0
	BEGIN

		INSERT INTO SallaumPolExport(
			BatchID,
			Pol,
			TerminalId,
			Barcode,
			ChassisNbr,
			CustomerId,
			Make,
			Model,
			Description,
			Color,
			Location,
			ReceivedOn,
			ShippedOn,
			Width1,
			height1,
			Length1,
			Width2,
			height2,
			Length2,
			Weight,
			UnitType,
			VoyageNbr,
			VesselName,
			POD,
			Blocked,
			Reason,
			CustomsDocs,
			CustomsRemarks,
			CustomsStatus,
			ClearedOn,
			Shipper,
			Damages,
			HasRelatedItems,
			RemovedFlag,
			RemovedReason,
			VehicleStatus,
			ExportedInd,
			RecordStatus,
			CreationDate
		)
		VALUES(
			@BatchID,
			@Pol,
			@TerminalId,
			@Barcode,
			@ChassisNbr,
			@CustomerId,
			@Make,
			@Model,
			@Description,
			@Color,
			@Location,
			@ReceivedOn,
			@ShippedOn,
			@Width1,
			@height1,
			@Length1,
			@Width2,
			@height2,
			@Length2,
			@Weight,
			@UnitType,
			@VoyageNbr,
			@VesselName,
			@POD,
			@Blocked,
			@Reason,
			@CustomsDocs,
			@CustomsRemarks,
			@CustomsStatus,
			@ClearedOn,
			@Shipper,
			@Damages,
			@HasRelatedItems,
			@RemovedFlag,
			@RemovedReason,
			@VehicleStatus,
			@ExportedInd,
			@RecordStatus,
			@CreationDate
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating Sallaum Line POL record'
			GOTO Error_Encountered
		END
		
		
		FETCH SallaumPolCursor INTO @Pol,@TerminalId,@Barcode,@ChassisNbr,@CustomerId,@Make,@Model,@Description,@Color,
		@Location,@ReceivedOn,@ShippedOn,@Width1,@height1,@Length1,@Width2,@height2,@Length2,@Weight,@UnitType,@VoyageNbr,
		@VesselName,@POD,@Blocked,@Reason,@CustomsDocs,@CustomsRemarks,@CustomsStatus,@ClearedOn,@Shipper,@Damages,@HasRelatedItems,@RemovedFlag,@RemovedReason

	
	END 
	
	
		CLOSE SallaumPolCursor
		DEALLOCATE SallaumPolCursor


--2nd CURSOR
		DECLARE SallaumPolCursor CURSOR
		LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		
		SELECT 'USBOS' as Pol,40 as TerminalID,VIN as BarCode,VIN as ChasisNbr,'' as CustomerID,LEFT(Make,3) as Make,LEFT(Model,4) as Model,Make + ' '+ Model as Description,
		LEFT(Color,3) as Color, LEFT(BayLocation,4) as Location,DateReceived as ReceivedOn,DateShipped as ShippedOn,VehicleWidth as Width1,VehicleHeight as Height1,VehicleLength as Length1,'' as Width2,
		'' as Height2,'' as Length2,VehicleWeight as Weight,''as Unittype,
		AEV1.VoyageNumber as VoyageNbr,
		AEV2.VesselName as VesselName ,
		LEFT(C.CodeDescription,5) as POD,'' as Blocked,'' as Reason,'' as CustomsDocs,
		'' as CustomsRemarks,'' as CustomsStatus,CustomsApprovedDate as ClearedOn,'' as Shipper,'' as Damages,'' as HasRelatedItems,
		CASE WHEN VesselName ='Sallaum Out By Truck' THEN 1 ELSE 0 END RemovedFlag,CASE WHEN VesselName = 'Sallaum Out By Truck' THEN AEV.Note ElSE '' END RemovedReason
		FROM AutoportExportVehicles AEV
		LEFT JOIN AEVoyage AEV1 ON AEV.VoyageID=AEV1.AEVoyageID
		LEFT JOIN AEVessel  AEV2 ON AEV1.AEVesselID=AEV2.AEVesselID
		LEFT JOIN Code C ON AEV.Destinationname = C.Code
		AND C.CodeType='UNLOCODE'
		WHERE CustomerID=@SallaumCustomerID
		AND AEV.VehicleStatus ='SubmittedCustoms' AND AEV.DateSubmittedCustoms IS NOT NULL
		AND (AEV.VIN NOT IN (SELECT SPE.BarCode FROM SallaumPolExport SPE WHERE SPE.VehicleStatus='SubmittedCustoms'))
		AND AEV.DateSubmittedCustoms >='01/23/2015' --(Cutoff date)
		ORDER BY AutoportExportVehiclesID Desc
	
	
	
	
	
	OPEN SallaumPolCursor

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	--new
	--SELECT @@ERROR = ''
	--NEW
	
	SELECT @ExportedInd = 0
	SELECT @VehicleStatus ='SubmittedCustoms'
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP


	FETCH SallaumPolCursor INTO @Pol,@TerminalId,@Barcode,@ChassisNbr,@CustomerId,@Make,@Model,@Description,@Color,
	@Location,@ReceivedOn,@ShippedOn,@Width1,@height1,@Length1,@Width2,@height2,@Length2,@Weight,@UnitType,@VoyageNbr,
	@VesselName,@POD,@Blocked,@Reason,@CustomsDocs,@CustomsRemarks,@CustomsStatus,@ClearedOn,@Shipper,@Damages,@HasRelatedItems,@RemovedFlag,@RemovedReason




	WHILE @@FETCH_STATUS = 0

	BEGIN

		INSERT INTO SallaumPolExport(
					BatchID,
					Pol,
					TerminalId,
					Barcode,
					ChassisNbr,
					CustomerId,
					Make,
					Model,
					Description,
					Color,
					Location,
					ReceivedOn,
					ShippedOn,
					Width1,
					height1,
					Length1,
					Width2,
					height2,
					Length2,
					Weight,
					UnitType,
					VoyageNbr,
					VesselName,
					POD,
					Blocked,
					Reason,
					CustomsDocs,
					CustomsRemarks,
					CustomsStatus,
					ClearedOn,
					Shipper,
					Damages,
					HasRelatedItems,
					RemovedFlag,
					RemovedReason,
					VehicleStatus,
					ExportedInd,
					RecordStatus,
					CreationDate
				)
				VALUES(
					@BatchID,
					@Pol,
					@TerminalId,
					@Barcode,
					@ChassisNbr,
					@CustomerId,
					@Make,
					@Model,
					@Description,
					@Color,
					@Location,
					@ReceivedOn,
					@ShippedOn,
					@Width1,
					@height1,
					@Length1,
					@Width2,
					@height2,
					@Length2,
					@Weight,
					@UnitType,
					@VoyageNbr,
					@VesselName,
					@POD,
					@Blocked,
					@Reason,
					@CustomsDocs,
					@CustomsRemarks,
					@CustomsStatus,
					@ClearedOn,
					@Shipper,
					@Damages,
					@HasRelatedItems,
					@RemovedFlag,
					@RemovedReason,
					@VehicleStatus,
					@ExportedInd,
					@RecordStatus,
					@CreationDate
				)
		
--testing






		IF @@Error <> 0
		BEGIN

			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating Sallaum Line POL record'
			GOTO Error_Encountered
		END
			

		FETCH SallaumPolCursor INTO @Pol,@TerminalId,@Barcode,@ChassisNbr,@CustomerId,@Make,@Model,@Description,@Color,
		@Location,@ReceivedOn,@ShippedOn,@Width1,@height1,@Length1,@Width2,@height2,@Length2,@Weight,@UnitType,@VoyageNbr,
		@VesselName,@POD,@Blocked,@Reason,@CustomsDocs,@CustomsRemarks,@CustomsStatus,@ClearedOn,@Shipper,@Damages,@HasRelatedItems,@RemovedFlag,@RemovedReason

	
		

	END 


		CLOSE SallaumPolCursor
		DEALLOCATE SallaumPolCursor


	
--Third Cursor


	DECLARE SallaumPolCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR

--to fill Blocked as 1 and Note as Reason (since it is cutom exception)


		SELECT 'USBOS' as Pol,40 as TerminalID,VIN as BarCode,VIN as ChasisNbr,'' as CustomerID,LEFT(Make,3) as Make,LEFT(Model,4) as Model,Make + ' '+ Model as Description,
		LEFT(Color,3) as Color, LEFT(BayLocation,4) as Location,DateReceived as ReceivedOn,DateShipped as ShippedOn,VehicleWidth as Width1,VehicleHeight as Height1,VehicleLength as Length1,'' as Width2,
		'' as Height2,'' as Length2,VehicleWeight as Weight,''as Unittype,
		AEV1.VoyageNumber as VoyageNbr,
		AEV2.VesselName as VesselName ,
		LEFT(C.CodeDescription,5) as POD,1 as Blocked,Note as Reason,'' as CustomsDocs, --(Important as 1 as blocked for customs exception)
		'' as CustomsRemarks,'' as CustomsStatus,CustomsApprovedDate as ClearedOn,'' as Shipper,'' as Damages,'' as HasRelatedItems,
		CASE WHEN VesselName ='Sallaum Out By Truck' THEN 1 ELSE 0 END RemovedFlag,CASE WHEN VesselName = 'Sallaum Out By Truck' THEN AEV.Note ElSE '' END RemovedReason
		FROM AutoportExportVehicles AEV
		LEFT JOIN AEVoyage AEV1 ON AEV.VoyageID=AEV1.AEVoyageID
		LEFT JOIN AEVessel  AEV2 ON AEV1.AEVesselID=AEV2.AEVesselID
		LEFT JOIN Code C ON AEV.Destinationname = C.Code
		AND C.CodeType='UNLOCODE'
		WHERE CustomerID=@SallaumCustomerID
		AND AEV.VehicleStatus ='CustomsException' AND AEV.CustomsExceptionDate IS NOT NULL
		AND (AEV.VIN NOT IN (SELECT SPE.BarCode FROM SallaumPolExport SPE WHERE SPE.VehicleStatus='CustomsException'))
		AND AEV.CustomsExceptionDate >='01/23/2015' --(Cutoff date)
		ORDER BY AutoportExportVehiclesID Desc




	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN SallaumPolCursor
	
--- BEGIN TRAN	
	
	
		
	SELECT @ExportedInd = 0
	SELECT @VehicleStatus ='CustomsException'
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	FETCH SallaumPolCursor INTO @Pol,@TerminalId,@Barcode,@ChassisNbr,@CustomerId,@Make,@Model,@Description,@Color,
	@Location,@ReceivedOn,@ShippedOn,@Width1,@height1,@Length1,@Width2,@height2,@Length2,@Weight,@UnitType,@VoyageNbr,
	@VesselName,@POD,@Blocked,@Reason,@CustomsDocs,@CustomsRemarks,@CustomsStatus,@ClearedOn,@Shipper,@Damages,@HasRelatedItems,@RemovedFlag,@RemovedReason

	WHILE @@FETCH_STATUS = 0
	BEGIN

		INSERT INTO SallaumPolExport(
			BatchID,
			Pol,
			TerminalId,
			Barcode,
			ChassisNbr,
			CustomerId,
			Make,
			Model,
			Description,
			Color,
			Location,
			ReceivedOn,
			ShippedOn,
			Width1,
			height1,
			Length1,
			Width2,
			height2,
			Length2,
			Weight,
			UnitType,
			VoyageNbr,
			VesselName,
			POD,
			Blocked,
			Reason,
			CustomsDocs,
			CustomsRemarks,
			CustomsStatus,
			ClearedOn,
			Shipper,
			Damages,
			HasRelatedItems,
			RemovedFlag,
			RemovedReason,
			VehicleStatus,
			ExportedInd,
			RecordStatus,
			CreationDate
		)
		VALUES(
			@BatchID,
			@Pol,
			@TerminalId,
			@Barcode,
			@ChassisNbr,
			@CustomerId,
			@Make,
			@Model,
			@Description,
			@Color,
			@Location,
			@ReceivedOn,
			@ShippedOn,
			@Width1,
			@height1,
			@Length1,
			@Width2,
			@height2,
			@Length2,
			@Weight,
			@UnitType,
			@VoyageNbr,
			@VesselName,
			@POD,
			@Blocked,
			@Reason,
			@CustomsDocs,
			@CustomsRemarks,
			@CustomsStatus,
			@ClearedOn,
			@Shipper,
			@Damages,
			@HasRelatedItems,
			@RemovedFlag,
			@RemovedReason,
			@VehicleStatus,
			@ExportedInd,
			@RecordStatus,
			@CreationDate
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating Sallaum Line POL record'
			GOTO Error_Encountered
		END
		
		
		FETCH SallaumPolCursor INTO @Pol,@TerminalId,@Barcode,@ChassisNbr,@CustomerId,@Make,@Model,@Description,@Color,
		@Location,@ReceivedOn,@ShippedOn,@Width1,@height1,@Length1,@Width2,@height2,@Length2,@Weight,@UnitType,@VoyageNbr,
		@VesselName,@POD,@Blocked,@Reason,@CustomsDocs,@CustomsRemarks,@CustomsStatus,@ClearedOn,@Shipper,@Damages,@HasRelatedItems,@RemovedFlag,@RemovedReason

	
	END 
	
	
		CLOSE SallaumPolCursor
		DEALLOCATE SallaumPolCursor		

---4th cursor--ClearedCustoms

	DECLARE SallaumPolCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR


		
		SELECT 'USBOS' as Pol,40 as TerminalID,VIN as BarCode,VIN as ChasisNbr,'' as CustomerID,LEFT(Make,3) as Make,LEFT(Model,4) as Model,Make + ' '+ Model as Description,
		LEFT(Color,3) as Color, LEFT(BayLocation,4) as Location,DateReceived as ReceivedOn,DateShipped as ShippedOn,VehicleWidth as Width1,VehicleHeight as Height1,VehicleLength as Length1,'' as Width2,
		'' as Height2,'' as Length2,VehicleWeight as Weight,''as Unittype,
		AEV1.VoyageNumber as VoyageNbr,
		AEV2.VesselName as VesselName ,
		LEFT(C.CodeDescription,5) as POD,'' as Blocked,'' as Reason,'' as CustomsDocs,
		'' as CustomsRemarks,'' as CustomsStatus,CustomsApprovedDate as ClearedOn,'' as Shipper,'' as Damages,'' as HasRelatedItems,
		CASE WHEN VesselName ='Sallaum Out By Truck' THEN 1 ELSE 0 END RemovedFlag,CASE WHEN VesselName = 'Sallaum Out By Truck' THEN AEV.Note ElSE '' END RemovedReason
		FROM AutoportExportVehicles AEV
		LEFT JOIN AEVoyage AEV1 ON AEV.VoyageID=AEV1.AEVoyageID
		LEFT JOIN AEVessel  AEV2 ON AEV1.AEVesselID=AEV2.AEVesselID
		LEFT JOIN Code C ON AEV.Destinationname = C.Code
		AND C.CodeType='UNLOCODE'
		WHERE CustomerID=@SallaumCustomerID
		AND AEV.VehicleStatus ='ClearedCustoms' AND AEV.CustomsApprovedDate IS NOT NULL
		AND (AEV.VIN NOT IN (SELECT SPE.BarCode FROM SallaumPolExport SPE WHERE SPE.VehicleStatus='ClearedCustoms'))
		AND AEV.CustomsApprovedDate >='01/23/2015' --(Cutoff date)
		ORDER BY AutoportExportVehiclesID Desc




	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN SallaumPolCursor
	
--- BEGIN TRAN	
	
	
		
	SELECT @ExportedInd = 0
	SELECT @VehicleStatus ='ClearedCustoms'
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	FETCH SallaumPolCursor INTO @Pol,@TerminalId,@Barcode,@ChassisNbr,@CustomerId,@Make,@Model,@Description,@Color,
	@Location,@ReceivedOn,@ShippedOn,@Width1,@height1,@Length1,@Width2,@height2,@Length2,@Weight,@UnitType,@VoyageNbr,
	@VesselName,@POD,@Blocked,@Reason,@CustomsDocs,@CustomsRemarks,@CustomsStatus,@ClearedOn,@Shipper,@Damages,@HasRelatedItems,@RemovedFlag,@RemovedReason

	WHILE @@FETCH_STATUS = 0
	BEGIN

	INSERT INTO SallaumPolExport(
			BatchID,
			Pol,
			TerminalId,
			Barcode,
			ChassisNbr,
			CustomerId,
			Make,
			Model,
			Description,
			Color,
			Location,
			ReceivedOn,
			ShippedOn,
			Width1,
			height1,
			Length1,
			Width2,
			height2,
			Length2,
			Weight,
			UnitType,
			VoyageNbr,
			VesselName,
			POD,
			Blocked,
			Reason,
			CustomsDocs,
			CustomsRemarks,
			CustomsStatus,
			ClearedOn,
			Shipper,
			Damages,
			HasRelatedItems,
			RemovedFlag,
			RemovedReason,
			VehicleStatus,
			ExportedInd,
			RecordStatus,
			CreationDate
		)
		VALUES(
			@BatchID,
			@Pol,
			@TerminalId,
			@Barcode,
			@ChassisNbr,
			@CustomerId,
			@Make,
			@Model,
			@Description,
			@Color,
			@Location,
			@ReceivedOn,
			@ShippedOn,
			@Width1,
			@height1,
			@Length1,
			@Width2,
			@height2,
			@Length2,
			@Weight,
			@UnitType,
			@VoyageNbr,
			@VesselName,
			@POD,
			@Blocked,
			@Reason,
			@CustomsDocs,
			@CustomsRemarks,
			@CustomsStatus,
			@ClearedOn,
			@Shipper,
			@Damages,
			@HasRelatedItems,
			@RemovedFlag,
			@RemovedReason,
			@VehicleStatus,
			@ExportedInd,
			@RecordStatus,
			@CreationDate
		)
			IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating Sallaum Line POL record'
			GOTO Error_Encountered
		END
		
		
		FETCH SallaumPolCursor INTO @Pol,@TerminalId,@Barcode,@ChassisNbr,@CustomerId,@Make,@Model,@Description,@Color,
		@Location,@ReceivedOn,@ShippedOn,@Width1,@height1,@Length1,@Width2,@height2,@Length2,@Weight,@UnitType,@VoyageNbr,
		@VesselName,@POD,@Blocked,@Reason,@CustomsDocs,@CustomsRemarks,@CustomsStatus,@ClearedOn,@Shipper,@Damages,@HasRelatedItems,@RemovedFlag,@RemovedReason

	
	END 
	

		CLOSE SallaumPolCursor
		DEALLOCATE SallaumPolCursor		



---5th cursor(Shipped)

	DECLARE SallaumPolCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR


	SELECT 'USBOS' as Pol,40 as TerminalID,VIN as BarCode,VIN as ChasisNbr,'' as CustomerID,LEFT(Make,3) as Make,LEFT(Model,4) as Model,Make + ' '+ Model as Description,
	LEFT(Color,3) as Color, LEFT(BayLocation,4) as Location,DateReceived as ReceivedOn,DateShipped as ShippedOn,VehicleWidth as Width1,VehicleHeight as Height1,VehicleLength as Length1,'' as Width2,
	'' as Height2,'' as Length2,VehicleWeight as Weight,''as Unittype,
	AEV1.VoyageNumber as VoyageNbr,
	AEV2.VesselName as VesselName ,
	LEFT(C.CodeDescription,5) as POD,'' as Blocked,'' as Reason,'' as CustomsDocs,
	'' as CustomsRemarks,'' as CustomsStatus,CustomsApprovedDate as ClearedOn,'' as Shipper,'' as Damages,'' as HasRelatedItems,
	CASE WHEN VesselName ='Sallaum Out By Truck' THEN 1 ELSE 0 END RemovedFlag,CASE WHEN VesselName = 'Sallaum Out By Truck' THEN AEV.Note ElSE '' END RemovedReason
	FROM AutoportExportVehicles AEV
	LEFT JOIN AEVoyage AEV1 ON AEV.VoyageID=AEV1.AEVoyageID
	LEFT JOIN AEVessel  AEV2 ON AEV1.AEVesselID=AEV2.AEVesselID
	LEFT JOIN Code C ON AEV.Destinationname = C.Code
	AND C.CodeType='UNLOCODE'
	WHERE CustomerID=@SallaumCustomerID
	--WHERE CustomerID=6124
	AND AEV.DateReceived >= '10/01/2014' --??Why its is here-For time being (Real one would be (10/01/2014)
	AND AEV.VehicleStatus ='Shipped' AND AEV.DateShipped IS NOT NULL
	AND (AEV.VIN NOT IN (SELECT SPE.BarCode FROM SallaumPolExport SPE WHERE SPE.VehicleStatus='Shipped'))
	AND AEV.DateShipped >='01/23/2015' --(Cutoff date)
	ORDER BY AutoportExportVehiclesID Desc





		




	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN SallaumPolCursor
	
--- BEGIN TRAN	
	
	
		
	SELECT @ExportedInd = 0
	SELECT @VehicleStatus ='Shipped'
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	FETCH SallaumPolCursor INTO @Pol,@TerminalId,@Barcode,@ChassisNbr,@CustomerId,@Make,@Model,@Description,@Color,
	@Location,@ReceivedOn,@ShippedOn,@Width1,@height1,@Length1,@Width2,@height2,@Length2,@Weight,@UnitType,@VoyageNbr,
	@VesselName,@POD,@Blocked,@Reason,@CustomsDocs,@CustomsRemarks,@CustomsStatus,@ClearedOn,@Shipper,@Damages,@HasRelatedItems,@RemovedFlag,@RemovedReason

	WHILE @@FETCH_STATUS = 0
	BEGIN

		INSERT INTO SallaumPolExport(
					BatchID,
					Pol,
					TerminalId,
					Barcode,
					ChassisNbr,
					CustomerId,
					Make,
					Model,
					Description,
					Color,
					Location,
					ReceivedOn,
					ShippedOn,
					Width1,
					height1,
					Length1,
					Width2,
					height2,
					Length2,
					Weight,
					UnitType,
					VoyageNbr,
					VesselName,
					POD,
					Blocked,
					Reason,
					CustomsDocs,
					CustomsRemarks,
					CustomsStatus,
					ClearedOn,
					Shipper,
					Damages,
					HasRelatedItems,
					RemovedFlag,
					RemovedReason,
					VehicleStatus,
					ExportedInd,
					RecordStatus,
					CreationDate
				)
				VALUES(
					@BatchID,
					@Pol,
					@TerminalId,
					@Barcode,
					@ChassisNbr,
					@CustomerId,
					@Make,
					@Model,
					@Description,
					@Color,
					@Location,
					@ReceivedOn,
					@ShippedOn,
					@Width1,
					@height1,
					@Length1,
					@Width2,
					@height2,
					@Length2,
					@Weight,
					@UnitType,
					@VoyageNbr,
					@VesselName,
					@POD,
					@Blocked,
					@Reason,
					@CustomsDocs,
					@CustomsRemarks,
					@CustomsStatus,
					@ClearedOn,
					@Shipper,
					@Damages,
					@HasRelatedItems,
					@RemovedFlag,
					@RemovedReason,
					@VehicleStatus,
					@ExportedInd,
					@RecordStatus,
					@CreationDate
				)
		
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating Sallaum Line POL record'
			GOTO Error_Encountered
		END
		
		
		FETCH SallaumPolCursor INTO @Pol,@TerminalId,@Barcode,@ChassisNbr,@CustomerId,@Make,@Model,@Description,@Color,
		@Location,@ReceivedOn,@ShippedOn,@Width1,@height1,@Length1,@Width2,@height2,@Length2,@Weight,@UnitType,@VoyageNbr,
		@VesselName,@POD,@Blocked,@Reason,@CustomsDocs,@CustomsRemarks,@CustomsStatus,@ClearedOn,@Shipper,@Damages,@HasRelatedItems,@RemovedFlag,@RemovedReason

	
	END 
	

	
	Error_Encountered:
	
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE SallaumPolCursor
		DEALLOCATE SallaumPolCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE SallaumPolCursor
		DEALLOCATE SallaumPolCursor
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
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage, @BatchID AS BatchID
	
	RETURN
END

GO
