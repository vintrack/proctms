USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateACL322Data]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateACL322Data] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--ExportACL322 table variables
	@BatchID				int,
	@CustomerID				int,
	@VehicleID				int,
	@InterchangeSenderID			varchar(15),
	@InterchangeReceiverID			varchar(15),
	@FunctionalID				varchar(2),
	@SenderCode				varchar(12),
	@ReceiverCode				varchar(12),
	@ResponsibleAgencyCode			varchar(2),
	@VersionNumber				varchar(12),
	@ShipmentIdentificationNumber		varchar(30),
	@TransactionReferenceNumber		varchar(15),
	@TransactionReferenceDate		datetime,
	@CorrectionIndicator			varchar(2),
	@TransportationTypeCode			varchar(2),
	@ShipmentStatusCode			varchar(2),
	@StatusDateTime				datetime,
	@TimeCode				varchar(2),
	@EquipmentInitial			varchar(4),
	@EquipmentNumber			varchar(10),
	@VesselStowageLocation			varchar(12),
	@VesselCode				varchar(8),
	@VesselName				varchar(28),
	@VoyageNumber				varchar(10),
	@SCAC					varchar(4),
	@VesselCodeQualifier			varchar(1),
	@LoadingPortFunctionCode		varchar(1),
	@LoadingLocationQualifier		varchar(1),
	@LoadingLocationIdentifier		varchar(30),
	@LoadingPortName			varchar(24),
	@LoadingTerminalName			varchar(30),
	@DischargePortFunctionCode		varchar(1),
	@DischargeLocationQualifier		varchar(1),
	@DischargeLocationIdentifier		varchar(30),
	@DischargePortName			varchar(24),
	@DischargeTerminalName			varchar(30),
	@SpecialHandlingInstructions		varchar(3),
	@ReferenceIdentificationQualifier	varchar(3),
	@ReferenceIdentification		varchar(30),
	@LadingLineItemNumber			varchar(3),
	@Weight					varchar(10),
	@WeightQualifier			varchar(2),
	@Volume					varchar(8),
	@VolumeUnitQualifier			varchar(1),
	@LadingQuantity				varchar(7),
	@PackagingFormCode			varchar(3),
	@WeightUnitCode				varchar(1),
	@TypeOfServiceCode			varchar(2),
	@LadingDescription			varchar(50),
	@CommodityCode				varchar(30),
	@CommodityCodeQualifier			varchar(1),
	@PackagingCode				varchar(5),
	@MarksAndNumbers			varchar(48),
	@MarksAndNumbersQualifier		varchar(2),
	@ModelCode				varchar(30),
	@ExportedInd				int,
	@RecordStatus				varchar(100),
	@CreationDate				datetime,	
	--processing variables
	@LocationSubType			varchar(20),
	@Status					varchar(100),
	@ReturnCode				int,
	@ReturnMessage				varchar(100),
	@ReturnBatchID				int

	/************************************************************************
	*	spGenerateACL322Data						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generate the ICL R41 export data for vehicles	*
	*	(for the specified ICL customer) that have been picked up or	*
	*	delivered.							*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/30/2005 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the next batch id from the setting table
	Select @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextACL322BatchID'
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
	
	SELECT TOP 1 @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ACLCustomerID'
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Status = 'CustomerID Not Found'
		GOTO Error_Encountered2
	END
		
	--cursor for the pickup records
	DECLARE ACL322Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT AEV.AutoportExportVehiclesID, AEV.DateReceived, AEV3.LloydsCode,
		AEV3.VesselName, AEV2.VoyageNumber, C.Code, UPPER(AEV.DestinationName),
		UPPER(AEV.DestinationName), AEV.BookingNumber,
		AEV.VehicleWeight, AEV.VehicleCubicFeet, AEV.VehicleYear+' '+AEV.Make+' '+AEV.Model,
		(SELECT TOP 1 IA301.ManufacturerCode FROM ImportACL301 IA301 WHERE IA301.VIN = AEV.VIN
		AND IA301.ReservationActionCode IN ('N','U') ORDER BY IA301.ImportACL301ID DESC),
		AEV.VIN,
		(SELECT TOP 1 IA301.ModelCode FROM ImportACL301 IA301 WHERE IA301.VIN = AEV.VIN
		AND IA301.ReservationActionCode IN ('N','U') ORDER BY IA301.ImportACL301ID DESC)
		FROM AutoportExportVehicles AEV
		LEFT JOIN AEVoyage AEV2 ON AEV.VoyageID = AEV2.AEVoyageID
		LEFT JOIN AEVessel AEV3 ON AEV2.AEVesselID = AEV3.AEVesselID
		LEFT JOIN Code C ON AEV.DestinationName = C.CodeDescription
		AND C.CodeType = 'ScheduleKCode'
		WHERE AEV.CustomerID = @CustomerID
		AND AEV.DateReceived IS NOT NULL
		AND AEV.VoyageID IS NOT NULL
		AND AEV.BilledInd = 0
		AND DATALENGTH(ISNULL(AEV.BookingNumber,''))>0
		--AND DATALENGTH(ISNULL(AEV.VehicleWeight,''))>0
		AND DATALENGTH(ISNULL(AEV.VehicleCubicFeet,''))>0
		AND DATALENGTH(ISNULL(AEV.VehicleYear,''))>0
		AND DATALENGTH(ISNULL(AEV.Make,''))>0
		AND DATALENGTH(ISNULL(AEV.Model,''))>0
		AND AEV.AutoportExportVehiclesID NOT IN (SELECT E.VehicleID FROM ExportACL322 E WHERE E.ShipmentStatusCode = 'I')
		ORDER BY AEV.DateReceived, AEV.VIN

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN ACL322Cursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextACL322BatchID'
	IF @@ERROR <> 0
	BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Setting BatchID'
			GOTO Error_Encountered
	END

	--set the default values
	SELECT @InterchangeSenderID = 'BOSTON'
	SELECT @InterchangeReceiverID = 'GMGO'
	SELECT @FunctionalID = 'SO'
	SELECT @SenderCode = 'BOSTON'
	SELECT @ReceiverCode = 'GMGO'
	SELECT @ResponsibleAgencyCode = 'X'
	SELECT @VersionNumber = '004010'
	SELECT @TimeCode = 'ES'
	SELECT @ShipmentIdentificationNumber = ''
	SELECT @CorrectionIndicator= 'NA'
	SELECT @TransportationTypeCode = 'S'
	SELECT @EquipmentInitial = ''
	SELECT @EquipmentNumber = '000000'
	SELECT @VesselStowageLocation = '0,0'
	SELECT @SCAC = 'GMGO'
	SELECT @VesselCodeQualifier = 'L'
	SELECT @LoadingPortFunctionCode = 'L'
	SELECT @LoadingLocationQualifier = 'D'
	SELECT @LoadingLocationIdentifier = '0401'
	SELECT @LoadingPortName = 'BOSTON, MA'
	SELECT @LoadingTerminalName = 'BOSTON AUTOPORT'
	SELECT @DischargePortFunctionCode = 'D'
	SELECT @DischargeLocationQualifier = 'K'
	SELECT @ReferenceIdentificationQualifier = 'BN'
	SELECT @LadingLineItemNumber = '1'
	SELECT @WeightQualifier = 'G'
	SELECT @VolumeUnitQualifier = 'E'
	SELECT @LadingQuantity = '1'
	SELECT @PackagingFormCode = 'UNT'
	SELECT @WeightUnitCode = 'K'
	SELECT @TypeOfServiceCode = 'RR'
	SELECT @CommodityCodeQualifier = 'Z'
	SELECT @PackagingCode = 'UNT'
	SELECT @MarksAndNumbersQualifier = 'ZZ'
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	
	
	FETCH ACL322Cursor INTO @VehicleID, @StatusDateTime, 
		@VesselCode, @VesselName, @VoyageNumber, @DischargeLocationIdentifier,
		@DischargePortName, @DischargeTerminalName,
		@ReferenceIdentification, @Weight, @Volume, @LadingDescription, @CommodityCode,
		@MarksAndNumbers,@ModelCode
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @ShipmentStatusCode = 'I'
		INSERT INTO ExportACL322(
			BatchID,
			CustomerID,
			VehicleID,
			InterchangeSenderID,
			InterchangeReceiverID,
			FunctionalID,
			SenderCode,
			ReceiverCode,
			ResponsibleAgencyCode,
			VersionNumber,
			ShipmentIdentificationNumber,
			CorrectionIndicator,
			TransportationTypeCode,
			ShipmentStatusCode,
			StatusDateTime,
			TimeCode,
			EquipmentInitial,
			EquipmentNumber,
			VesselStowageLocation,
			VesselCode,
			VesselName,
			VoyageNumber,
			SCAC,
			VesselCodeQualifier,
			LoadingPortFunctionCode,
			LoadingLocationQualifier,
			LoadingLocationIdentifier,
			LoadingPortName,
			LoadingTerminalName,
			DischargePortFunctionCode,
			DischargeLocationQualifier,
			DischargeLocationIdentifier,
			DischargePortName,
			DischargeTerminalName,
			SpecialHandlingInstructions,
			ReferenceIdentificationQualifier,
			ReferenceIdentification,
			LadingLineItemNumber,
			Weight,
			WeightQualifier,
			Volume,
			VolumeUnitQualifier,
			LadingQuantity,
			PackagingFormCode,
			WeightUnitCode,
			TypeOfServiceCode,
			LadingDescription,
			CommodityCode,
			CommodityCodeQualifier,
			PackagingCode,
			MarksAndNumbers,
			MarksAndNumbersQualifier,
			ModelCode,
			ExportedInd,
			RecordStatus,
			CreationDate,	
			CreatedBy
		)
		VALUES(
			@BatchID,
			@CustomerID,
			@VehicleID,
			@InterchangeSenderID,
			@InterchangeReceiverID,
			@FunctionalID,
			@SenderCode,
			@ReceiverCode,
			@ResponsibleAgencyCode,
			@VersionNumber,
			@ShipmentIdentificationNumber,
			@CorrectionIndicator,
			@TransportationTypeCode,
			@ShipmentStatusCode,
			@StatusDateTime,
			@TimeCode,
			@EquipmentInitial,
			@EquipmentNumber,
			@VesselStowageLocation,
			@VesselCode,
			@VesselName,
			@VoyageNumber,
			@SCAC,
			@VesselCodeQualifier,
			@LoadingPortFunctionCode,
			@LoadingLocationQualifier,
			@LoadingLocationIdentifier,
			@LoadingPortName,
			@LoadingTerminalName,
			@DischargePortFunctionCode,
			@DischargeLocationQualifier,
			@DischargeLocationIdentifier,
			@DischargePortName,
			@DischargeTerminalName,
			@SpecialHandlingInstructions,
			@ReferenceIdentificationQualifier,
			@ReferenceIdentification,
			@LadingLineItemNumber,
			@Weight,
			@WeightQualifier,
			@Volume,
			@VolumeUnitQualifier,
			@LadingQuantity,
			@PackagingFormCode,
			@WeightUnitCode,
			@TypeOfServiceCode,
			@LadingDescription,
			@CommodityCode,
			@CommodityCodeQualifier,
			@PackagingCode,
			@MarksAndNumbers,
			@MarksAndNumbersQualifier,
			@ModelCode,
			@ExportedInd,
			@RecordStatus,
			@CreationDate,	
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating ACL 322 In-Gate record'
			GOTO Error_Encountered
		END
			
		FETCH ACL322Cursor INTO @VehicleID, @StatusDateTime,
			@VesselCode, @VesselName, @VoyageNumber,
			@DischargeLocationIdentifier, @DischargePortName, @DischargeTerminalName,
			@ReferenceIdentification, @Weight, @Volume, @LadingDescription, @CommodityCode,
			@MarksAndNumbers, @ModelCode

	END --end of loop
	
	CLOSE ACL322Cursor
	DEALLOCATE ACL322Cursor
		
	--cursor for the delivery records
	DECLARE ACL322Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		
		SELECT AEV.AutoportExportVehiclesID, AEV.DateReceived, AEV3.LloydsCode,
		AEV3.VesselName, AEV2.VoyageNumber, C.Code, UPPER(AEV.DestinationName),
		UPPER(AEV.DestinationName), AEV.BookingNumber,
		AEV.VehicleWeight, AEV.VehicleCubicFeet, AEV.VehicleYear+' '+AEV.Make+' '+AEV.Model,
		(SELECT TOP 1 IA301.ManufacturerCode FROM ImportACL301 IA301 WHERE IA301.VIN = AEV.VIN
		AND IA301.ReservationActionCode IN ('N','U') ORDER BY IA301.ImportACL301ID DESC),
		AEV.VIN,
		(SELECT TOP 1 IA301.ModelCode FROM ImportACL301 IA301 WHERE IA301.VIN = AEV.VIN
		AND IA301.ReservationActionCode IN ('N','U') ORDER BY IA301.ImportACL301ID DESC)
		FROM AutoportExportVehicles AEV
		LEFT JOIN AEVoyage AEV2 ON AEV.VoyageID = AEV2.AEVoyageID
		LEFT JOIN AEVessel AEV3 ON AEV2.AEVesselID = AEV3.AEVesselID
		LEFT JOIN Code C ON AEV.DestinationName = C.CodeDescription
		AND C.CodeType = 'ScheduleKCode'
		WHERE AEV.CustomerID = @CustomerID
		AND AEV.DateReceived IS NOT NULL
		AND AEV.VoyageID IS NOT NULL
		AND AEV.DateShipped IS NOT NULL
		AND AEV.BilledInd = 0
		AND DATALENGTH(ISNULL(AEV.BookingNumber,''))>0
		--AND DATALENGTH(ISNULL(AEV.VehicleWeight,''))>0
		AND DATALENGTH(ISNULL(AEV.VehicleCubicFeet,''))>0
		AND DATALENGTH(ISNULL(AEV.VehicleYear,''))>0
		AND DATALENGTH(ISNULL(AEV.Make,''))>0
		AND DATALENGTH(ISNULL(AEV.Model,''))>0
		AND AEV.AutoportExportVehiclesID NOT IN (SELECT E.VehicleID FROM ExportACL322 E WHERE E.ShipmentStatusCode = 'AE')
		ORDER BY AEV.DateReceived, AEV.VIN

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN ACL322Cursor

	FETCH ACL322Cursor INTO @VehicleID, @StatusDateTime,
		@VesselCode, @VesselName, @VoyageNumber,
		@DischargeLocationIdentifier, @DischargePortName, @DischargeTerminalName,
		@ReferenceIdentification, @Weight, @Volume, @LadingDescription, @CommodityCode,
		@MarksAndNumbers, @ModelCode
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		SELECT @ShipmentStatusCode = 'AE'
		INSERT INTO ExportACL322(
			BatchID,
			CustomerID,
			VehicleID,
			InterchangeSenderID,
			InterchangeReceiverID,
			FunctionalID,
			SenderCode,
			ReceiverCode,
			ResponsibleAgencyCode,
			VersionNumber,
			ShipmentIdentificationNumber,
			CorrectionIndicator,
			TransportationTypeCode,
			ShipmentStatusCode,
			StatusDateTime,
			TimeCode,
			EquipmentInitial,
			EquipmentNumber,
			VesselStowageLocation,
			VesselCode,
			VesselName,
			VoyageNumber,
			SCAC,
			VesselCodeQualifier,
			LoadingPortFunctionCode,
			LoadingLocationQualifier,
			LoadingLocationIdentifier,
			LoadingPortName,
			LoadingTerminalName,
			DischargePortFunctionCode,
			DischargeLocationQualifier,
			DischargeLocationIdentifier,
			DischargePortName,
			DischargeTerminalName,
			SpecialHandlingInstructions,
			ReferenceIdentificationQualifier,
			ReferenceIdentification,
			LadingLineItemNumber,
			Weight,
			WeightQualifier,
			Volume,
			VolumeUnitQualifier,
			LadingQuantity,
			PackagingFormCode,
			WeightUnitCode,
			TypeOfServiceCode,
			LadingDescription,
			CommodityCode,
			CommodityCodeQualifier,
			PackagingCode,
			MarksAndNumbers,
			MarksAndNumbersQualifier,
			ModelCode,
			ExportedInd,
			RecordStatus,
			CreationDate,	
			CreatedBy
		)
		VALUES(
			@BatchID,
			@CustomerID,
			@VehicleID,
			@InterchangeSenderID,
			@InterchangeReceiverID,
			@FunctionalID,
			@SenderCode,
			@ReceiverCode,
			@ResponsibleAgencyCode,
			@VersionNumber,
			@ShipmentIdentificationNumber,
			@CorrectionIndicator,
			@TransportationTypeCode,
			@ShipmentStatusCode,
			@StatusDateTime,
			@TimeCode,
			@EquipmentInitial,
			@EquipmentNumber,
			@VesselStowageLocation,
			@VesselCode,
			@VesselName,
			@VoyageNumber,
			@SCAC,
			@VesselCodeQualifier,
			@LoadingPortFunctionCode,
			@LoadingLocationQualifier,
			@LoadingLocationIdentifier,
			@LoadingPortName,
			@LoadingTerminalName,
			@DischargePortFunctionCode,
			@DischargeLocationQualifier,
			@DischargeLocationIdentifier,
			@DischargePortName,
			@DischargeTerminalName,
			@SpecialHandlingInstructions,
			@ReferenceIdentificationQualifier,
			@ReferenceIdentification,
			@LadingLineItemNumber,
			@Weight,
			@WeightQualifier,
			@Volume,
			@VolumeUnitQualifier,
			@LadingQuantity,
			@PackagingFormCode,
			@WeightUnitCode,
			@TypeOfServiceCode,
			@LadingDescription,
			@CommodityCode,
			@CommodityCodeQualifier,
			@PackagingCode,
			@MarksAndNumbers,
			@MarksAndNumbersQualifier,
			@ModelCode,
			@ExportedInd,
			@RecordStatus,
			@CreationDate,	
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating ACL 322 Shipped record'
			GOTO Error_Encountered
		END
			
		FETCH ACL322Cursor INTO @VehicleID, @StatusDateTime,
			@VesselCode, @VesselName, @VoyageNumber,
			@DischargeLocationIdentifier, @DischargePortName, @DischargeTerminalName,
			@ReferenceIdentification, @Weight, @Volume, @LadingDescription, @CommodityCode,
			@MarksAndNumbers, @ModelCode

	END --end of loop


	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ACL322Cursor
		DEALLOCATE ACL322Cursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		SELECT @ReturnBatchID = @BatchID
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ACL322Cursor
		DEALLOCATE ACL322Cursor
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
