USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateHondaVTREventData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateHondaVTREventData] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	@loopcounter		int,
	--ExportICLR41 table variables
	@BatchID		int,
	@VehicleID		int,
	@SenderID		varchar(3),
	@SenderName		varchar(30),
	@ShipmentType		varchar(10),
	@EventCode		varchar(5),
	@EventDateTime		datetime,
	@RailEquipmentType	varchar(10),
	@RailEquipmentInitial	varchar(10),
	@RailEquipmentNumber	varchar(10),
	@OriginCode		varchar(3),
	@DestinationCode	varchar(6),
	@EventCity		varchar(30),
	@EventState		varchar(2),
	@EventProvince		varchar(2),
	@EventCountry		varchar(10),
	@EventPostalCode	varchar(14),
	@EventSPLCCode		varchar(10),
	@EventLatitude		varchar(20),
	@EventLongitude		varchar(20),
	@ExportedInd		int,
	@RecordStatus		varchar(20),
	@CreationDate		datetime,
	--processing variables
	@HondaCustomerID	int,
	@LocationSubType	varchar(20),
	@Status			varchar(100),
	@ReturnCode		int,
	@ReturnMessage		varchar(100),
	@ReturnBatchID		int

	/************************************************************************
	*	spGenerateHondaVTREventData					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the Rail Release, Pickup and Delivery	*
	*	data to be reported to the Honda VTR system.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	02/01/2010 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the next batch id from the setting table
	Select @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextHondaVTREventExportBatchID'
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

	--get Hondas CustomerID
	Select @HondaCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'HondaCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting BatchID'
		GOTO Error_Encountered2
	END
	IF @HondaCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Status = 'CustomerID Not Found'
		GOTO Error_Encountered2
	END

	--get the honda carrier number from the setting table
	Select @SenderID = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'HondaCarrierNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting BatchID'
		GOTO Error_Encountered2
	END
	IF @SenderID IS NULL
	BEGIN
		SELECT @ErrorID = 100003
		SELECT @Status = 'Carrier Number Not Found'
		GOTO Error_Encountered2
	END

	--cursor for the release records
	DECLARE HondaVTREventCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, ISNULL((SELECT TOP 1 NSTN.CreationDate FROM NSTruckerNotificationImport NSTN WHERE NSTN.VIN = V.VIN
		ORDER BY NSTN.CreationDate),ISNULL((SELECT TOP 1 CSX.CreationDate FROM CSXRailheadfeedImport CSX WHERE CSX.VIN = V.VIN
		ORDER BY CSX.CreationDate),V.AvailableForPickupDate)) EventDateTime, C.Code, L4.CustomerLocationCode, L3.City,
		L3.State, L3.Zip, C.Value2
		FROM Vehicle V
		LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
		LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
		LEFT JOIN Code C ON V.PickupLocationID = C.Value1
		AND C.CodeType = 'HondaLocationCode'
		WHERE V.CustomerID = @HondaCustomerID
		AND V.AvailableForPickupDate IS NOT NULL
		AND V.VehicleID NOT IN (SELECT H.VehicleID FROM HondaExportVTREvent H WHERE H.VehicleID = V.VehicleID AND H.EventCode = 'CRCPT')
		ORDER BY C.Code, L4.CustomerLocationCode, EventDateTime

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN HondaVTREventCursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextHondaVTREventExportBatchID'
	IF @@ERROR <> 0
	BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Setting BatchID'
			GOTO Error_Encountered
	END

	--set the default values
	SELECT @SenderName = 'Diversified Automotive'
	SELECT @ShipmentType = 'TRUCK'
	SELECT @EventCode = 'CRCPT'
	SELECT @RailEquipmentType = ''
	SELECT @RailEquipmentInitial = ''
	SELECT @RailEquipmentNumber = ''
	SELECT @EventProvince = ''
	SELECT @EventCountry = 'USA'
	SELECT @EventLatitude = ''
	SELECT @EventLongitude = ''
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	FETCH HondaVTREventCursor INTO @VehicleID, @EventDateTime, @OriginCode, @DestinationCode, @EventCity,
		@EventState, @EventPostalCode, @EventSPLCCode
	
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		INSERT INTO HondaExportVTREvent(
			BatchID,
			VehicleID,
			SenderID,
			SenderName,
			ShipmentType,
			EventCode,
			EventDateTime,
			RailEquipmentType,
			RailEquipmentInitial,
			RailEquipmentNumber,
			OriginCode,
			DestinationCode,
			EventCity,
			EventState,
			EventProvince,
			EventCountry,
			EventPostalCode,
			EventSPLCCode,
			EventLatitude,
			EventLongitude,
			ExportedInd,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@SenderID,
			@SenderName,
			@ShipmentType,
			@EventCode,
			@EventDateTime,
			@RailEquipmentType,
			@RailEquipmentInitial,
			@RailEquipmentNumber,
			@OriginCode,
			@DestinationCode,
			@EventCity,
			@EventState,
			@EventProvince,
			@EventCountry,
			@EventPostalCode,
			@EventSPLCCode,
			@EventLatitude,
			@EventLongitude,
			@ExportedInd,
			@RecordStatus,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating CRCPT record'
			GOTO Error_Encountered
		END
			
		FETCH HondaVTREventCursor INTO @VehicleID, @EventDateTime, @OriginCode, @DestinationCode, @EventCity,
			@EventState, @EventPostalCode, @EventSPLCCode

	END --end of loop
	
	CLOSE HondaVTREventCursor
	DEALLOCATE HondaVTREventCursor
	--COMMIT TRAN
		
	--cursor for the pickup records
	DECLARE HondaVTREventCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, L.PickupDate, C.Code, L3.CustomerLocationCode, L2.City,
		L2.State, L2.Zip, C.Value2
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.LegNumber = 1
		LEFT JOIN Location L2 ON V.PickupLocationID = L2.LocationID
		LEFT JOIN Location L3 ON V.DropoffLocationID = L3.LocationID
		LEFT JOIN Code C ON V.PickupLocationID = C.Value1
		AND C.CodeType = 'HondaLocationCode'
		WHERE V.CustomerID = @HondaCustomerID
		AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
		AND V.VehicleStatus IN ('EnRoute','Delivered')
		AND V.VehicleID NOT IN (SELECT H.VehicleID FROM HondaExportVTREvent H WHERE V.VehicleID = H.VehicleID AND H.EventCode = 'TTOUT')
		ORDER BY C.Code, L3.CustomerLocationCode, L.PickupDate

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN HondaVTREventCursor
	
	--BEGIN TRAN

	--set the default values
	SELECT @EventCode = 'TTOUT'
	
	FETCH HondaVTREventCursor INTO @VehicleID, @EventDateTime, @OriginCode, @DestinationCode, @EventCity,
		@EventState, @EventPostalCode, @EventSPLCCode
	
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		INSERT INTO HondaExportVTREvent(
			BatchID,
			VehicleID,
			SenderID,
			SenderName,
			ShipmentType,
			EventCode,
			EventDateTime,
			RailEquipmentType,
			RailEquipmentInitial,
			RailEquipmentNumber,
			OriginCode,
			DestinationCode,
			EventCity,
			EventState,
			EventProvince,
			EventCountry,
			EventPostalCode,
			EventSPLCCode,
			EventLatitude,
			EventLongitude,
			ExportedInd,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@SenderID,
			@SenderName,
			@ShipmentType,
			@EventCode,
			@EventDateTime,
			@RailEquipmentType,
			@RailEquipmentInitial,
			@RailEquipmentNumber,
			@OriginCode,
			@DestinationCode,
			@EventCity,
			@EventState,
			@EventProvince,
			@EventCountry,
			@EventPostalCode,
			@EventSPLCCode,
			@EventLatitude,
			@EventLongitude,
			@ExportedInd,
			@RecordStatus,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating TTOUT record'
			GOTO Error_Encountered
		END
			
		FETCH HondaVTREventCursor INTO @VehicleID, @EventDateTime, @OriginCode, @DestinationCode, @EventCity,
			@EventState, @EventPostalCode, @EventSPLCCode

	END --end of loop
	
	CLOSE HondaVTREventCursor
	DEALLOCATE HondaVTREventCursor
	
	--COMMMIT TRAN
		
	--cursor for the delivery records
	DECLARE HondaVTREventCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, L.DropoffDate, C.Code, L2.CustomerLocationCode, L2.City,
		L2.State, L2.Zip, L2.SPLCCode
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.FinalLegInd = 1
		LEFT JOIN Location L2 ON V.DropoffLocationID = L2.LocationID
		LEFT JOIN Code C ON V.PickupLocationID = C.Value1
		AND C.CodeType = 'HondaLocationCode'
		WHERE V.CustomerID = @HondaCustomerID
		AND L.DropoffDate > L.PickupDate
		AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
		AND V.VehicleStatus = 'Delivered'
		AND V.VehicleID NOT IN (SELECT H.VehicleID FROM HondaExportVTREvent H WHERE V.VehicleID = H.VehicleID AND H.EventCode = 'TDELV')
		ORDER BY C.Code, L2.CustomerLocationCode, L.DropoffDate

	OPEN HondaVTREventCursor
	
	--BEGIN TRAN

	SELECT @EventCode = 'TDELV'
	
	FETCH HondaVTREventCursor INTO @VehicleID, @EventDateTime, @OriginCode, @DestinationCode, @EventCity,
		@EventState, @EventPostalCode, @EventSPLCCode
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		INSERT INTO HondaExportVTREvent(
			BatchID,
			VehicleID,
			SenderID,
			SenderName,
			ShipmentType,
			EventCode,
			EventDateTime,
			RailEquipmentType,
			RailEquipmentInitial,
			RailEquipmentNumber,
			OriginCode,
			DestinationCode,
			EventCity,
			EventState,
			EventProvince,
			EventCountry,
			EventPostalCode,
			EventSPLCCode,
			EventLatitude,
			EventLongitude,
			ExportedInd,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@SenderID,
			@SenderName,
			@ShipmentType,
			@EventCode,
			@EventDateTime,
			@RailEquipmentType,
			@RailEquipmentInitial,
			@RailEquipmentNumber,
			@OriginCode,
			@DestinationCode,
			@EventCity,
			@EventState,
			@EventProvince,
			@EventCountry,
			@EventPostalCode,
			@EventSPLCCode,
			@EventLatitude,
			@EventLongitude,
			@ExportedInd,
			@RecordStatus,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating TDELV record'
			GOTO Error_Encountered
		END
			
		FETCH HondaVTREventCursor INTO @VehicleID, @EventDateTime, @OriginCode, @DestinationCode, @EventCity,
			@EventState, @EventPostalCode, @EventSPLCCode

	END --end of loop


	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE HondaVTREventCursor
		DEALLOCATE HondaVTREventCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		SELECT @ReturnBatchID = @BatchID
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE HondaVTREventCursor
		DEALLOCATE HondaVTREventCursor
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
