USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateFordGTNexusShipmentStatusData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateFordGTNexusShipmentStatusData] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID				int,
	--FordExportGTNexusShipmentStatus table variables
	@FordExportGTNexusShipmentStatusID	int,
	@BatchID				int,
	@VehicleID				int,
	@InterchangeSenderID			varchar(15),
	@InterchangeReceiverID			varchar(15),
	@FunctionalID				varchar(2),
	@SenderCode				varchar(12),
	@ReceiverCode				varchar(12),
	@TransmissionDateTime			datetime,
	@InterchangeControlNumber		int,
	@ResponsibleAgencyCode			varchar(2),
	@VersionNumber				varchar(12),
	@TransactionSetControlNumber		varchar(9),
	@FreightBillNumber			varchar(30),
	@ShipmentIdentifyingNumber		varchar(30),
	@CarrierSCACCode			varchar(4),
	@EquipmentNumber			varchar(30),
	@VINNumber				varchar(30),
	@LaneType				varchar(30),
	@DamageCodes				varchar(120),
	@ShipFromName				varchar(60),
	@ShipFromIdentificationCodeQualifier	varchar(2),
	@ShipFromIdentificationCode		varchar(80),
	@ShipFromAddressLine1			varchar(55),
	@ShipFromCityName			varchar(30),
	@ShipFromState				varchar(2),
	@ShipFromZIP				varchar(15),
	@ShipFromCountry			varchar(3),
	@ShipFromLocationQualifier		varchar(2),
	@ShipFromLocationIdentifier		varchar(30),
	@ScheduledPickupDate			datetime,
	@ShipToName				varchar(60),
	@ShipToIdentificationCodeQualifier	varchar(2),
	@ShipToIdentificationCode		varchar(80),
	@ShipToAddressLine1			varchar(55),
	@ShipToCityName				varchar(30),
	@ShipToState				varchar(2),
	@ShipToZIP				varchar(15),
	@ShipToCountry				varchar(3),
	@ShipToLocationQualifier		varchar(2),
	@ShipToLocationIdentifier		varchar(30),
	@EstimatedDeliveryDate			datetime,
	@InterlineSCACCode			varchar(4),
	@RoutingSequenceCode			varchar(2),
	@TransportationMethodTypeCode		varchar(2),
	@SequenceNumber				int,
	@ShipmentStatusCode			varchar(2),
	@ShipmentStatusReasonCode		varchar(2),
	@StatusEventDate			datetime,
	@EventCityName				varchar(30),
	@EventState				varchar(2),
	@EventCountry				varchar(3),
	@WeightQualifier			varchar(2),
	@WeightUnitCode				varchar(1),
	@Weight					varchar(10),
	@VolumeUnitQualifier			varchar(1),
	@Volume					varchar(8),
	@ExportedInd				int,
	@ExportedDate				datetime,
	@ExportedBy				varchar(20),
	@RecordStatus				varchar(100),
	@CreationDate				datetime,
	@UpdatedDate				datetime,
	@UpdatedBy				varchar(20),
	--processing variables
	@GTNexusStartDate			datetime,
	@DamageCode				varchar(5),
	@FordDefaultStandardDays		int,
	@CustomerID				int,
	@LegsID					int,
	@CustomerIdentification			varchar(25),
	@InspectionType				int,		--07/13/2018 - CMK - added new variable
	@LoopCounter				int,
	@Status					varchar(100),
	@ReturnCode				int,
	@ReturnMessage				varchar(100)	

	/************************************************************************
	*	spGenerateFordGTNexusShipmentStatusData				*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the shipment status export data for	*
	*	Fords								*
	*	that have been delivered.					*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	05/10/2016 CMK    Initial version				*
	*	02/28/2018 CMK    Added AP (Shipment Redirect) code		*
	*	07/13/2018 CMK	  Changes to transmit BK (on-site repair) and	*
	*			  BT (off-site repair) for specified damages	*
	*									*
	************************************************************************/
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'FordCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting CustomerID'
		GOTO Error_Encountered3
	END
	IF @CustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'CustomerID Not Found'
		GOTO Error_Encountered3
	END

	--get the next batch id from the setting table
	SELECT @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextFordGTNexusShipmentStatusExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting BatchID'
		GOTO Error_Encountered3
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'BatchID Not Found'
		GOTO Error_Encountered3
	END
	
	SELECT @ErrorID = 0
	
	SELECT TOP 1 @InterchangeSenderID = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'FordGTNexusSenderID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting InterchangeSenderID'
		GOTO Error_Encountered3
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Status = 'InterchangeSenderID Not Found'
		GOTO Error_Encountered3
	END
	
	SELECT TOP 1 @CarrierSCACCode = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'CompanySCACCode'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting CompanySCACCode'
		GOTO Error_Encountered3
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100003
		SELECT @Status = 'CompanySCACCode Not Found'
		GOTO Error_Encountered3
	END
	
	
	SELECT TOP 1 @FordDefaultStandardDays = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'FordDefaultStandardDays'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting FordDefaultStandardDays'
		GOTO Error_Encountered3
	END
	IF @FordDefaultStandardDays IS NULL
	BEGIN
		SELECT @ErrorID = 100004
		SELECT @Status = 'FordDefaultStandardDays Not Found'
		GOTO Error_Encountered3
	END
	
	--get the GT Nexus Start Date
	SELECT @GTNexusStartDate = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'GTNexusStartDate'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting GT Nexus Start Date'
		GOTO Error_Encountered3
	END
	IF @GTNexusStartDate IS NULL
	BEGIN
		SELECT @ErrorID = 100005
		SELECT @Status = 'GT Nexus Start Date Not Found'
		GOTO Error_Encountered3
	END
		
	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextFordGTNexusShipmentStatusExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered2
	END
	
	--set the default values
		
	SELECT @LoopCounter = 0
	
	--these defaults are for all types
	SELECT @InterchangeReceiverID = 'GTNEXUS'
	SELECT @FunctionalID = 'QM'
	SELECT @SenderCode = @InterchangeSenderID 
	SELECT @ReceiverCode = 'FORDIT'
	SELECT @TransmissionDateTime = NULL --value set during export
	SELECT @InterchangeControlNumber = NULL --value set during export
	SELECT @ResponsibleAgencyCode = 'X'
	SELECT @VersionNumber = '004010'
	SELECT @TransactionSetControlNumber = NULL --value set during export
	SELECT @EquipmentNumber = ''
	SELECT @ExportedInd = 0
	SELECT @ExportedDate = NULL
	SELECT @ExportedBy = NULL
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @UpdatedDate = NULL
	SELECT @UpdatedBy = NULL
	
	--process the Vehicle Received records
	
	--Vehicle Received defaults
	SELECT @FreightBillNumber = 'TBD'
	SELECT @DamageCodes = ''
	SELECT @ShipmentStatusCode = 'R1'
	SELECT @ShipmentStatusReasonCode = 'NS'
	SELECT @ShipFromIdentificationCodeQualifier = 'SF'
	SELECT @ShipToIdentificationCodeQualifier = 'ST'
	SELECT @RoutingSequenceCode = 'O'
	SELECT @TransportationMethodTypeCode = 'J'
	SELECT @SequenceNumber = NULL
		
	
	INSERT INTO FordExportGTNexusShipmentStatus SELECT @BatchID,
		V.VehicleID,
		NULL,	--VehicleInspectionID
		@InterchangeSenderID,
		@InterchangeReceiverID,
		@FunctionalID,
		@SenderCode,
		@ReceiverCode,
		@TransmissionDateTime,
		@InterchangeControlNumber,
		@ResponsibleAgencyCode,
		@VersionNumber,
		@TransactionSetControlNumber,
		@FreightBillNumber,
		CONVERT(varchar(20),V.VehicleID), --ShipmentIdentifyingNumber
		@CarrierSCACCode,
		@EquipmentNumber,
		V.VIN,
		CASE WHEN L4.ParentRecordTable = 'Common' OR L4.LocationSubType IN ('Port','Railyard','Plant') THEN 'C' ELSE 'D' END,	--LaneType
		@DamageCodes,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END + '-' + LEFT(L3.LocationName,60),	--ShipFromName
		@ShipFromIdentificationCodeQualifier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END + '-' + CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END,	--ShipFromIdentificationCode
		ISNULL(L3.AddressLine1,'TBD'),	--ShipFromAddressLine1
		L3.City,	--ShipFromCityName
		L3.State,	--ShipFromState
		L3.Zip,	--ShipFromZIP
		CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE '' END,	--ShipFromCountry
		'SL', --ShipFromLocationQualifier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END+'-'+
			CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE '' END, --ShipFromLocationIdentifier,
		DATEADD(Day,ISNULL(LPS.StandardDays,@FordDefaultStandardDays),ISNULL(V.DateMadeAvailable,V.AvailableForPickupDate)), --ScheduledPickupDate,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END + '-' + LEFT(L4.LocationName,60),	--ShipToName
		@ShipToIdentificationCodeQualifier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END + '-' + CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END,	--ShipToIdentificationCode
		L4.AddressLine1,	--ShipToAddressLine1
		L4.City,	--ShipToCityName
		L4.State,	--ShipToState
		L4.Zip,	--ShipToZIP
		CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE '' END,	--ShipToCountry
		'SL', --ShipToLocationQualifier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END+'-'+
			CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE '' END, --ShipToLocationIdentifier,
		DATEADD(Day,ISNULL(LPS.StandardDays,@FordDefaultStandardDays),ISNULL(V.DateMadeAvailable,V.AvailableForPickupDate)), --EstimatedDeliveryDate,
		@CarrierSCACCode,	--InterlineSCACCode
		@RoutingSequenceCode,
		@TransportationMethodTypeCode,
		@SequenceNumber,
		@ShipmentStatusCode,
		@ShipmentStatusReasonCode,
		ISNULL(V.DateMadeAvailable,V.AvailableForPickupDate),	--@StatusEventDate
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode ELSE L3.City END,	--EventCityName
		CASE WHEN L3.ParentRecordTable = 'Common' OR DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN 'SL' ELSE L3.State END,	--EventState
		CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE '' END,	--EventCountry
		@WeightQualifier,
		@WeightUnitCode,
		@Weight,
		@VolumeUnitQualifier,
		@Volume,
		@ExportedInd,
		@ExportedDate,
		@ExportedBy,
		@RecordStatus,
		@CreationDate,
		@CreatedBy,
		@UpdatedDate,
		@UpdatedBy
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	AND L.LegNumber = 1
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
	LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	AND V.PickupLocationID = LPS.OriginID
	AND V.DropoffLocationID = LPS.DestinationID
	WHERE V.CustomerID = @CustomerID
	AND V.AvailableForPickupDate >= @GTNexusStartDate
	AND V.VehicleID NOT IN (SELECT FEG.VehicleID FROM FordExportGTNexusShipmentStatus FEG WHERE FEG.ShipmentStatusCode = 'R1')
	AND L3.City IS NOT NULL
	AND L3.State IS NOT NULL
	AND L3.Zip IS NOT NULL
	AND L3.Country IS NOT NULL
	AND L4.AddressLine1 IS NOT NULL
	AND L4.City IS NOT NULL
	AND L4.State IS NOT NULL
	AND L4.Zip IS NOT NULL
	AND L4.Country IS NOT NULL
	ORDER BY V.VehicleID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating Vehicle Received records'
		GOTO Error_Encountered2
	END
	
	--end of process the Vehicle Received records
	
	--process the Estimated Delivery records
				
	--Vehicle Estimated Delivery defaults
	SELECT @FreightBillNumber = 'TBD'
	SELECT @DamageCodes = ''
	SELECT @ShipmentStatusCode = 'AG'
	SELECT @ShipmentStatusReasonCode = 'NS'
	SELECT @ShipFromIdentificationCodeQualifier = 'SF'
	SELECT @ShipToIdentificationCodeQualifier = 'ST'
	SELECT @RoutingSequenceCode = 'O'
	SELECT @TransportationMethodTypeCode = 'J'
	SELECT @SequenceNumber = NULL
			
			
	INSERT INTO FordExportGTNexusShipmentStatus SELECT @BatchID,
		V.VehicleID,
		NULL,	--VehicleInspectionID
		@InterchangeSenderID,
		@InterchangeReceiverID,
		@FunctionalID,
		@SenderCode,
		@ReceiverCode,
		@TransmissionDateTime,
		@InterchangeControlNumber,
		@ResponsibleAgencyCode,
		@VersionNumber,
		@TransactionSetControlNumber,
		@FreightBillNumber,
		CONVERT(varchar(20),V.VehicleID), --ShipmentIdentifyingNumber
		@CarrierSCACCode,
		@EquipmentNumber,
		V.VIN,
		CASE WHEN L4.ParentRecordTable = 'Common' OR L4.LocationSubType IN ('Port','Railyard','Plant') THEN 'C' ELSE 'D' END,	--LaneType
		@DamageCodes,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END + '-' + LEFT(L3.LocationName,60),	--ShipFromName
		@ShipFromIdentificationCodeQualifier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END + '-' + CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END,	--ShipFromIdentificationCode
		L3.AddressLine1,	--ShipFromAddressLine1
		L3.City,	--ShipFromCityName
		L3.State,	--ShipFromState
		L3.Zip,	--ShipFromZIP
		CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE '' END,	--ShipFromCountry
		'SL', --ShipFromLocationQualifier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END+'-'+
			CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE '' END, --ShipFromLocationIdentifier,
		DATEADD(Day,ISNULL(LPS.StandardDays,@FordDefaultStandardDays),ISNULL(V.DateMadeAvailable,V.AvailableForPickupDate)), --ScheduledPickupDate,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END + '-' + LEFT(L4.LocationName,60),	--ShipToName
		@ShipToIdentificationCodeQualifier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END + '-' + CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END,	--ShipToIdentificationCode
		L4.AddressLine1,	--ShipToAddressLine1
		L4.City,	--ShipToCityName
		L4.State,	--ShipToState
		L4.Zip,	--ShipToZIP
		CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE '' END,	--ShipToCountry
		'SL', --ShipToLocationQualifier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END+'-'+
			CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE '' END, --ShipToLocationIdentifier,
		DATEADD(Day,ISNULL(LPS.StandardDays,@FordDefaultStandardDays),ISNULL(V.DateMadeAvailable,V.AvailableForPickupDate)), --EstimatedDeliveryDate,
		@CarrierSCACCode,	--InterlineSCACCode
		@RoutingSequenceCode,
		@TransportationMethodTypeCode,
		@SequenceNumber,
		@ShipmentStatusCode,
		@ShipmentStatusReasonCode,
		ISNULL(V.DateMadeAvailable,V.AvailableForPickupDate),	--@StatusEventDate
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode ELSE L3.City END,	--EventCityName
		CASE WHEN L3.ParentRecordTable = 'Common' OR DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN 'SL' ELSE L3.State END,	--EventState
		CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE '' END,	--EventCountry
		@WeightQualifier,
		@WeightUnitCode,
		@Weight,
		@VolumeUnitQualifier,
		@Volume,
		@ExportedInd,
		@ExportedDate,
		@ExportedBy,
		@RecordStatus,
		@CreationDate,
		@CreatedBy,
		@UpdatedDate,
		@UpdatedBy
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	AND L.LegNumber = 1
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
	LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	AND V.PickupLocationID = LPS.OriginID
	AND V.DropoffLocationID = LPS.DestinationID
	WHERE V.CustomerID = @CustomerID
	AND V.AvailableForPickupDate >= @GTNexusStartDate
	AND V.VehicleID NOT IN (SELECT FEG.VehicleID FROM FordExportGTNexusShipmentStatus FEG WHERE FEG.ShipmentStatusCode = 'AG')
	AND L3.City IS NOT NULL
	AND L3.State IS NOT NULL
	AND L3.Zip IS NOT NULL
	AND L3.Country IS NOT NULL
	AND L4.AddressLine1 IS NOT NULL
	AND L4.City IS NOT NULL
	AND L4.State IS NOT NULL
	AND L4.Zip IS NOT NULL
	AND L4.Country IS NOT NULL
	ORDER BY V.VehicleID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating Estimated Delivery records'
		GOTO Error_Encountered2
	END
			
	--end of process the Estimated Delivery records
	
	--process the Departed records
		
	--Vehicle Departed defaults
	SELECT @DamageCodes = ''
	SELECT @ShipmentStatusCode = 'AF'
	SELECT @ShipmentStatusReasonCode = 'NS'
	SELECT @ShipFromIdentificationCodeQualifier = 'SF'
	SELECT @ShipToIdentificationCodeQualifier = 'ST'
	SELECT @RoutingSequenceCode = 'O'
	SELECT @SequenceNumber = NULL
		
	
	INSERT INTO FordExportGTNexusShipmentStatus SELECT @BatchID,
		V.VehicleID,
		NULL,	--VehicleInspectionID
		@InterchangeSenderID,
		@InterchangeReceiverID,
		@FunctionalID,
		@SenderCode,
		@ReceiverCode,
		@TransmissionDateTime,
		@InterchangeControlNumber,
		@ResponsibleAgencyCode,
		@VersionNumber,
		@TransactionSetControlNumber,
		L5.LoadNumber, --FreightBillNumber,
		CONVERT(varchar(20),V.VehicleID), --ShipmentIdentifyingNumber
		@CarrierSCACCode,
		CASE WHEN ISNULL(U.FirstName,'')+' '+ISNULL(U.LastName,'') = 'DEALER PICKUP' THEN V.VIN ELSE T.TruckNumber END, --EquipmentNumber,
		V.VIN,
		CASE WHEN L4.ParentRecordTable = 'Common' OR L4.LocationSubType IN ('Port','Railyard','Plant') THEN 'C' ELSE 'D' END,	--LaneType
		@DamageCodes,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END + '-' + LEFT(L3.LocationName,60),	--ShipFromName
		@ShipFromIdentificationCodeQualifier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END + '-' + CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END,	--ShipFromIdentificationCode
		L3.AddressLine1,	--ShipFromAddressLine1
		L3.City,	--ShipFromCityName
		L3.State,	--ShipFromState
		L3.Zip,	--ShipFromZIP
		CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE '' END,	--ShipFromCountry
		'SL', --ShipFromLocationQualifier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END+'-'+
			CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE '' END, --ShipFromLocationIdentifier,
		L.PickupDate, --ScheduledPickupDate,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END + '-' + LEFT(L4.LocationName,60),	--ShipToName
		@ShipToIdentificationCodeQualifier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END + '-' + CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END,	--ShipToIdentificationCode
		L4.AddressLine1,	--ShipToAddressLine1
		L4.City,	--ShipToCityName
		L4.State,	--ShipToState
		L4.Zip,	--ShipToZIP
		CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE '' END,	--ShipToCountry
		'SL', --ShipToLocationQualifier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END+'-'+
			CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE '' END, --ShipToLocationIdentifier,
		DATEADD(Day,1,L.PickupDate), --EstimatedDeliveryDate,
		@CarrierSCACCode,	--InterlineSCACCode
		@RoutingSequenceCode,
		CASE WHEN ISNULL(U.FirstName,'')+' '+ISNULL(U.LastName,'') = 'DEALER PICKUP' THEN 'DA' WHEN (SELECT COUNT(*) FROM Vehicle V2 LEFT JOIN LEGS L6 ON V2.VehicleID = L6.VehicleID WHERE L6.LoadID = L.LoadID AND V2.CustomerID <> V.CustomerID) > 0 THEN 'LT' ELSE 'J' END, --TransportationMethodTypeCode,
		@SequenceNumber,
		@ShipmentStatusCode,
		@ShipmentStatusReasonCode,
		L.PickupDate,	--@StatusEventDate
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode ELSE L3.City END,	--EventCityName
		CASE WHEN L3.ParentRecordTable = 'Common' OR DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN 'SL' ELSE L3.State END,	--EventState
		CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE '' END,	--EventCountry
		@WeightQualifier,
		@WeightUnitCode,
		@Weight,
		@VolumeUnitQualifier,
		@Volume,
		@ExportedInd,
		@ExportedDate,
		@ExportedBy,
		@RecordStatus,
		@CreationDate,
		@CreatedBy,
		@UpdatedDate,
		@UpdatedBy
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	AND L.LegNumber = 1
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
	LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	AND V.PickupLocationID = LPS.OriginID
	AND V.DropoffLocationID = LPS.DestinationID
	LEFT JOIN Run R ON L.RunID = R.RunID
	LEFT JOIN Loads L5 ON L.LoadID = L5.LoadsID
	LEFT JOIN Truck T ON R.TruckID = T.TruckID
	LEFT JOIN Driver D ON R.DriverID = D.DriverID
	LEFT JOIN Users U ON D.UserID = U.UserID
	WHERE V.CustomerID = @CustomerID
	AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
	AND V.AvailableForPickupDate >= @GTNexusStartDate
	AND V.VehicleStatus IN ('EnRoute','Delivered')
	AND V.VehicleID NOT IN (SELECT FEG.VehicleID FROM FordExportGTNexusShipmentStatus FEG WHERE FEG.ShipmentStatusCode = 'AF')
	AND ISNULL(L.RunID,0) <> 0
	AND L3.City IS NOT NULL
	AND L3.State IS NOT NULL
	AND L3.Zip IS NOT NULL
	AND L3.Country IS NOT NULL
	AND L4.AddressLine1 IS NOT NULL
	AND L4.City IS NOT NULL
	AND L4.State IS NOT NULL
	AND L4.Zip IS NOT NULL
	AND L4.Country IS NOT NULL
	ORDER BY V.VehicleID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating Departed records'
		GOTO Error_Encountered2
	END
	
	--end of process the Departed records
	
	--process the Delivered records
			
	--Vehicle Departed defaults
	SELECT @DamageCodes = ''
	SELECT @ShipmentStatusCode = 'X1'
	SELECT @ShipmentStatusReasonCode = 'NS'
	SELECT @ShipFromIdentificationCodeQualifier = 'SF'
	SELECT @ShipToIdentificationCodeQualifier = 'ST'
	SELECT @RoutingSequenceCode = 'O'
	SELECT @SequenceNumber = NULL
		
		
	INSERT INTO FordExportGTNexusShipmentStatus SELECT @BatchID,
		V.VehicleID,
		NULL,	--VehicleInspectionID
		@InterchangeSenderID,
		@InterchangeReceiverID,
		@FunctionalID,
		@SenderCode,
		@ReceiverCode,
		@TransmissionDateTime,
		@InterchangeControlNumber,
		@ResponsibleAgencyCode,
		@VersionNumber,
		@TransactionSetControlNumber,
		L5.LoadNumber, --FreightBillNumber,
		CONVERT(varchar(20),V.VehicleID), --ShipmentIdentifyingNumber
		@CarrierSCACCode,
		CASE WHEN ISNULL(U.FirstName,'')+' '+ISNULL(U.LastName,'') = 'DEALER PICKUP' THEN V.VIN ELSE T.TruckNumber END, --EquipmentNumber,
		V.VIN,
		CASE WHEN L4.ParentRecordTable = 'Common' OR L4.LocationSubType IN ('Port','Railyard','Plant') THEN 'C' ELSE 'D' END,	--LaneType
		@DamageCodes,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END + '-' + LEFT(L3.LocationName,60),	--ShipFromName
		@ShipFromIdentificationCodeQualifier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END + '-' + CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END,	--ShipFromIdentificationCode
		L3.AddressLine1,	--ShipFromAddressLine1
		L3.City,	--ShipFromCityName
		L3.State,	--ShipFromState
		L3.Zip,	--ShipFromZIP
		CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE 'US' END,	--ShipFromCountry
		'SL', --ShipFromLocationQualifier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END+'-'+
			CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE '' END, --ShipFromLocationIdentifier,
		L.PickupDate, --ScheduledPickupDate,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END + '-' + LEFT(L4.LocationName,60),	--ShipToName
		@ShipToIdentificationCodeQualifier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END + '-' + CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END,	--ShipToIdentificationCode
		L4.AddressLine1,	--ShipToAddressLine1
		L4.City,	--ShipToCityName
		L4.State,	--ShipToState
		L4.Zip,	--ShipToZIP
		CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE 'US' END,	--ShipToCountry
		'SL', --ShipToLocationQualifier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END+'-'+
			CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE '' END, --ShipToLocationIdentifier,
		L.DropoffDate, --EstimatedDeliveryDate,
		@CarrierSCACCode,	--InterlineSCACCode
		@RoutingSequenceCode,
		CASE WHEN ISNULL(U.FirstName,'')+' '+ISNULL(U.LastName,'') = 'DEALER PICKUP' THEN 'DA' WHEN (SELECT COUNT(*) FROM Vehicle V2 LEFT JOIN LEGS L6 ON V2.VehicleID = L6.VehicleID WHERE L6.LoadID = L.LoadID AND V2.CustomerID <> V.CustomerID) > 0 THEN 'LT' ELSE 'J' END, --TransportationMethodTypeCode,
		@SequenceNumber,
		@ShipmentStatusCode,
		@ShipmentStatusReasonCode,
		L.DropoffDate,	--@StatusEventDate
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode ELSE L4.City END,	--EventCityName
		CASE WHEN L4.ParentRecordTable= 'Common' OR DATALENGTH(ISNULL(L4.SPLCCOde,'')) > 0 THEN 'SL' ELSE L4.State END,	--EventState
		CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE 'US' END,	--EventCountry
		@WeightQualifier,
		@WeightUnitCode,
		@Weight,
		@VolumeUnitQualifier,
		@Volume,
		@ExportedInd,
		@ExportedDate,
		@ExportedBy,
		@RecordStatus,
		@CreationDate,
		@CreatedBy,
		@UpdatedDate,
		@UpdatedBy
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	AND L.FinalLegInd = 1
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
	LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	AND V.PickupLocationID = LPS.OriginID
	AND V.DropoffLocationID = LPS.DestinationID
	LEFT JOIN Run R ON L.RunID = R.RunID
	LEFT JOIN Loads L5 ON L.LoadID = L5.LoadsID
	LEFT JOIN Truck T ON R.TruckID = T.TruckID
	LEFT JOIN Driver D ON R.DriverID = D.DriverID
	LEFT JOIN Users U ON D.UserID = U.UserID
	WHERE V.CustomerID = @CustomerID
	AND V.VehicleStatus = 'Delivered'
	AND L.DropoffDate > L.PickupDate
	AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
	AND V.AvailableForPickupDate >= @GTNexusStartDate
	AND V.VehicleStatus = 'Delivered'
	AND V.VehicleID NOT IN (SELECT FEG.VehicleID FROM FordExportGTNexusShipmentStatus FEG WHERE FEG.ShipmentStatusCode = 'X1')
	AND ISNULL(L.RunID,0) <> 0
	AND L3.City IS NOT NULL
	AND L3.State IS NOT NULL
	AND L3.Zip IS NOT NULL
	AND L3.Country IS NOT NULL
	AND L4.AddressLine1 IS NOT NULL
	AND L4.City IS NOT NULL
	AND L4.State IS NOT NULL
	AND L4.Zip IS NOT NULL
	AND L4.Country IS NOT NULL
	ORDER BY V.VehicleID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating Delivered records'
		GOTO Error_Encountered2
	END
		
	--end of process the Delivered records
	
	--process the Inspection records
				
	--Vehicle Departed defaults
	SELECT @DamageCodes = ''
	SELECT @ShipmentStatusCode = 'XB'
	SELECT @ShipmentStatusReasonCode = 'NS'
	SELECT @ShipFromIdentificationCodeQualifier = 'SF'
	SELECT @ShipToIdentificationCodeQualifier = 'ST'
	SELECT @RoutingSequenceCode = 'O'
	SELECT @SequenceNumber = NULL
			
			
	INSERT INTO FordExportGTNexusShipmentStatus SELECT @BatchID,
		V.VehicleID,
		VI.VehicleInspectionID,
		@InterchangeSenderID,
		@InterchangeReceiverID,
		@FunctionalID,
		@SenderCode,
		@ReceiverCode,
		@TransmissionDateTime,
		@InterchangeControlNumber,
		@ResponsibleAgencyCode,
		@VersionNumber,
		@TransactionSetControlNumber,
		ISNULL(L5.LoadNumber,'TBD'), --FreightBillNumber,
		CONVERT(varchar(20),V.VehicleID), --ShipmentIdentifyingNumber
		@CarrierSCACCode,
		CASE WHEN ISNULL(U.FirstName,'')+' '+ISNULL(U.LastName,'') = 'DEALER PICKUP' THEN V.VIN ELSE T.TruckNumber END, --EquipmentNumber,
		V.VIN,
		CASE WHEN L4.ParentRecordTable = 'Common' OR L4.LocationSubType IN ('Port','Railyard','Plant') THEN 'C' ELSE 'D' END,	--LaneType
		@DamageCodes,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END + '-' + LEFT(L3.LocationName,60),	--ShipFromName
		@ShipFromIdentificationCodeQualifier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END + '-' + CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END,	--ShipFromIdentificationCode
		L3.AddressLine1,	--ShipFromAddressLine1
		L3.City,	--ShipFromCityName
		L3.State,	--ShipFromState
		L3.Zip,	--ShipFromZIP
		CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE 'US' END,	--ShipFromCountry
		'SL', --ShipFromLocationQualifier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END+'-'+
			CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE '' END, --ShipFromLocationIdentifier,
		CASE WHEN V.VehicleStatus IN ('EnRoute','Delivered') THEN L.PickupDate ELSE DATEADD(Day,ISNULL(LPS.StandardDays,@FordDefaultStandardDays),ISNULL(V.DateMadeAvailable,V.AvailableForPickupDate)) END, --ScheduledPickupDate,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END + '-' + LEFT(L4.LocationName,60),	--ShipToName
		@ShipToIdentificationCodeQualifier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END + '-' + CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END,	--ShipToIdentificationCode
		L4.AddressLine1,	--ShipToAddressLine1
		L4.City,	--ShipToCityName
		L4.State,	--ShipToState
		L4.Zip,	--ShipToZIP
		CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE 'US' END,	--ShipToCountry
		'SL', --ShipToLocationQualifier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END+'-'+
			CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE '' END, --ShipToLocationIdentifier,
		CASE WHEN V.VehicleStatus = 'Delivered' THEN L.DropoffDate WHEN V.VehicleStatus = 'EnRoute' THEN DATEADD(Day,1,L.PickupDate) ELSE DATEADD(Day,ISNULL(LPS.StandardDays,@FordDefaultStandardDays),ISNULL(V.DateMadeAvailable,V.AvailableForPickupDate)) END, --EstimatedDeliveryDate,
		@CarrierSCACCode,	--InterlineSCACCode
		@RoutingSequenceCode,
		CASE WHEN ISNULL(U.FirstName,'')+' '+ISNULL(U.LastName,'') = 'DEALER PICKUP' THEN 'DA' WHEN (SELECT COUNT(*) FROM Vehicle V2 LEFT JOIN LEGS L6 ON V2.VehicleID = L6.VehicleID WHERE L6.LoadID = L.LoadID AND V2.CustomerID <> V.CustomerID) > 0 THEN 'LT' ELSE 'J' END, --TransportationMethodTypeCode,
		@SequenceNumber,
		@ShipmentStatusCode,
		@ShipmentStatusReasonCode,
		VI.InspectionDate,	--@StatusEventDate
		CASE WHEN V.VehicleStatus = 'Delivered' THEN
			CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
				AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode ELSE L4.City END
		ELSE
			CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
				AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode ELSE L3.City END
		END,	--EventCityName
		CASE WHEN V.VehicleStatus = 'Delivered' THEN
			CASE WHEN L4.ParentRecordTable = 'Common' OR DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN 'SL' ELSE L4.State END
		ELSE
			CASE WHEN L3.ParentRecordTable = 'Common' OR DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN 'SL' ELSE L3.State END
		END,	--EventState
		CASE WHEN V.VehicleStatus = 'Delivered' THEN
			CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE 'US' END
		ELSE
			CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE 'US' END
		END,	--EventCountry
		@WeightQualifier,
		@WeightUnitCode,
		@Weight,
		@VolumeUnitQualifier,
		@Volume,
		@ExportedInd,
		@ExportedDate,
		@ExportedBy,
		@RecordStatus,
		@CreationDate,
		@CreatedBy,
		@UpdatedDate,
		@UpdatedBy
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	AND L.FinalLegInd = 1
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
	LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	AND V.PickupLocationID = LPS.OriginID
	AND V.DropoffLocationID = LPS.DestinationID
	LEFT JOIN Run R ON L.RunID = R.RunID
	LEFT JOIN Loads L5 ON L.LoadID = L5.LoadsID
	LEFT JOIN Truck T ON R.TruckID = T.TruckID
	LEFT JOIN Driver D ON R.DriverID = D.DriverID
	LEFT JOIN Users U ON D.UserID = U.UserID
	LEFT JOIN VehicleInspection VI ON VI.VehicleID = V.VehicleID
	WHERE V.CustomerID = @CustomerID
	--AND VI.InspectionType IN ('0','1','2','3','6')
	--AND VI.InspectionType = '2' --07/13/2018 - CMK - commented out
	AND VI.InspectionType IN (0,1,2) --07/13/2018 - CMK - added in 0 and 1 inspection types
	AND VI.InspectionDate IS NOT NULL
	AND V.AvailableForPickupDate >= @GTNexusStartDate
	--AND VI.VehicleInspectionID NOT IN (SELECT FEG.VehicleInspectionID FROM FordExportGTNexusShipmentStatus FEG WHERE FEG.ShipmentStatusCode = 'XB') --07/13/2018 - CMK - commented out
	AND VI.VehicleID NOT IN (SELECT FEG.VehicleID FROM FordExportGTNexusShipmentStatus FEG WHERE FEG.ShipmentStatusCode = 'XB') --07/13/2018 - CMK - only want to ever send one inspection record, now that we are sending multiple inspection types, the match is now on VehicleID instead of VehicleInspectionID
	AND L3.City IS NOT NULL
	AND L3.State IS NOT NULL
	AND L3.Zip IS NOT NULL
	AND L3.Country IS NOT NULL
	AND L4.AddressLine1 IS NOT NULL
	AND L4.City IS NOT NULL
	AND L4.State IS NOT NULL
	AND L4.Zip IS NOT NULL
	AND L4.Country IS NOT NULL
	ORDER BY V.VehicleID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating Delivered records'
		GOTO Error_Encountered2
	END
			
	--end of process the Inspection records
			
	--process the Damage Identified records
				
	--Vehicle Damaged defaults
	SELECT @DamageCodes = '' --will be blank until after the record are inserted and looped through
	SELECT @ShipmentStatusCode = 'A9'
	SELECT @ShipmentStatusReasonCode = 'BG' --07/13/2018 - CMK - this will be modified to BK or BT when adding the damage codes, when appropriate
	SELECT @ShipFromIdentificationCodeQualifier = 'SF'
	SELECT @ShipToIdentificationCodeQualifier = 'ST'
	SELECT @RoutingSequenceCode = 'O'
	SELECT @SequenceNumber = NULL
			
			
	INSERT INTO FordExportGTNexusShipmentStatus SELECT DISTINCT @BatchID,
		V.VehicleID,
		VI.VehicleInspectionID,
		@InterchangeSenderID,
		@InterchangeReceiverID,
		@FunctionalID,
		@SenderCode,
		@ReceiverCode,
		@TransmissionDateTime,
		@InterchangeControlNumber,
		@ResponsibleAgencyCode,
		@VersionNumber,
		@TransactionSetControlNumber,
		ISNULL(L5.LoadNumber,'TBD'), --FreightBillNumber,
		CONVERT(varchar(20),V.VehicleID), --ShipmentIdentifyingNumber
		@CarrierSCACCode,
		CASE WHEN ISNULL(U.FirstName,'')+' '+ISNULL(U.LastName,'') = 'DEALER PICKUP' THEN V.VIN ELSE T.TruckNumber END, --EquipmentNumber,
		V.VIN,
		CASE WHEN L4.ParentRecordTable = 'Common' OR L4.LocationSubType IN ('Port','Railyard','Plant') THEN 'C' ELSE 'D' END,	--LaneType
		@DamageCodes,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END + '-' + LEFT(L3.LocationName,60),	--ShipFromName
		@ShipFromIdentificationCodeQualifier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END + '-' + CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END,	--ShipFromIdentificationCode
		L3.AddressLine1,	--ShipFromAddressLine1
		L3.City,	--ShipFromCityName
		L3.State,	--ShipFromState
		L3.Zip,	--ShipFromZIP
		CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE 'US' END,	--ShipFromCountry
		'SL', --ShipFromLocationQualifier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END+'-'+
			CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE '' END, --ShipFromLocationIdentifier,
		CASE WHEN V.VehicleStatus IN ('EnRoute','Delivered') THEN L.PickupDate ELSE DATEADD(Day,ISNULL(LPS.StandardDays,@FordDefaultStandardDays),ISNULL(V.DateMadeAvailable,V.AvailableForPickupDate)) END, --ScheduledPickupDate,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END + '-' + LEFT(L4.LocationName,60),	--ShipToName
		@ShipToIdentificationCodeQualifier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END + '-' + CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END,	--ShipToIdentificationCode
		L4.AddressLine1,	--ShipToAddressLine1
		L4.City,	--ShipToCityName
		L4.State,	--ShipToState
		L4.Zip,	--ShipToZIP
		CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE 'US' END,	--ShipToCountry
		'SL', --ShipToLocationQualifier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END+'-'+
			CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE '' END, --ShipToLocationIdentifier,
		CASE WHEN V.VehicleStatus = 'Delivered' THEN L.DropoffDate WHEN V.VehicleStatus = 'EnRoute' THEN DATEADD(Day,1,L.PickupDate) ELSE DATEADD(Day,ISNULL(LPS.StandardDays,@FordDefaultStandardDays),ISNULL(V.DateMadeAvailable,V.AvailableForPickupDate)) END, --EstimatedDeliveryDate,
		@CarrierSCACCode,	--InterlineSCACCode
		@RoutingSequenceCode,
		CASE WHEN ISNULL(U.FirstName,'')+' '+ISNULL(U.LastName,'') = 'DEALER PICKUP' THEN 'DA' WHEN (SELECT COUNT(*) FROM Vehicle V2 LEFT JOIN LEGS L6 ON V2.VehicleID = L6.VehicleID WHERE L6.LoadID = L.LoadID AND V2.CustomerID <> V.CustomerID) > 0 THEN 'LT' ELSE 'J' END, --TransportationMethodTypeCode,
		@SequenceNumber,
		@ShipmentStatusCode,
		@ShipmentStatusReasonCode,
		VI.InspectionDate,	--@StatusEventDate
		CASE WHEN V.VehicleStatus = 'Delivered' THEN
			CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
				AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode ELSE L4.City END
		ELSE
			CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
				AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode ELSE L3.City END
		END,	--EventCityName
		CASE WHEN V.VehicleStatus = 'Delivered' THEN
			CASE WHEN L4.ParentRecordTable = 'Common' OR DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN 'SL' ELSE L4.State END
		ELSE
			CASE WHEN L3.ParentRecordTable = 'Common' OR DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN 'SL' ELSE L3.State END
		END,	--EventState
		CASE WHEN V.VehicleStatus = 'Delivered' THEN
			CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE 'US' END
		ELSE
			CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE 'US' END
		END,	--EventCountry
		@WeightQualifier,
		@WeightUnitCode,
		@Weight,
		@VolumeUnitQualifier,
		@Volume,
		@ExportedInd,
		@ExportedDate,
		@ExportedBy,
		@RecordStatus,
		@CreationDate,
		@CreatedBy,
		@UpdatedDate,
		@UpdatedBy
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	AND L.FinalLegInd = 1
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
	LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	AND V.PickupLocationID = LPS.OriginID
	AND V.DropoffLocationID = LPS.DestinationID
	LEFT JOIN Run R ON L.RunID = R.RunID
	LEFT JOIN Loads L5 ON L.LoadID = L5.LoadsID
	LEFT JOIN Truck T ON R.TruckID = T.TruckID
	LEFT JOIN Driver D ON R.DriverID = D.DriverID
	LEFT JOIN Users U ON D.UserID = U.UserID
	LEFT JOIN VehicleInspection VI ON VI.VehicleID = V.VehicleID
	LEFT JOIN VehicleDamageDetail VDD ON VI.VehicleInspectionID = VDD.VehicleInspectionID
	WHERE V.CustomerID = @CustomerID
	AND VI.InspectionType IN (0,1,2,3,6)
	AND VI.InspectionDate IS NOT NULL
	AND V.AvailableForPickupDate >= @GTNexusStartDate
	AND VI.DamageCodeCount > 0
	AND VI.VehicleInspectionID NOT IN (SELECT FEG.VehicleInspectionID FROM FordExportGTNexusShipmentStatus FEG WHERE FEG.ShipmentStatusCode = 'A9' AND CHARINDEX(VDD.DamageCode,FEG.DamageCodes) > 0)
	--AND ISNULL(L.RunID,0) <> 0 --07/13/2018 - CMK - no longer waiting for a Run to transmit damages
	AND L3.City IS NOT NULL
	AND L3.State IS NOT NULL
	AND L3.Zip IS NOT NULL
	AND L3.Country IS NOT NULL
	AND L4.AddressLine1 IS NOT NULL
	AND L4.City IS NOT NULL
	AND L4.State IS NOT NULL
	AND L4.Zip IS NOT NULL
	AND L4.Country IS NOT NULL
	ORDER BY V.VehicleID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating Damage Identified records'
		GOTO Error_Encountered2
	END

	DECLARE GTNexusCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT FEG.FordExportGTNexusShipmentStatusID, VDD.DamageCode, VI.InspectionType --07/13/2018 - CMK - added InspectionType
		FROM FordExportGTNexusShipmentStatus FEG
		LEFT JOIN VehicleDamageDetail VDD ON FEG.VehicleInspectionID = VDD.VehicleInspectionID
		LEFT JOIN VehicleInspection VI ON VDD.VehicleInspectionID = VI.VehicleInspectionID --07/13/2018 - CMK - added join to VehicleInspection
		WHERE FEG.ExportedInd = 0
		AND FEG.BatchID = @BatchID
		AND FEG.ShipmentStatusCode = 'A9'
		AND (SELECT COUNT(*) FROM FordExportGTNexusShipmentStatus FEG2
			WHERE FEG2.VehicleInspectionID = FEG.VehicleInspectionID
			AND CHARINDEX(VDD.DamageCode,FEG2.DamageCodes) > 0) = 0
	
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN GTNexusCursor
	
	FETCH GTNexusCursor INTO @FordExportGTNexusShipmentStatusID, @DamageCode, @InspectionType --07/13/2018 - CMK - added @InspectionType
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @InspectionType IN (2,3,6)	--07/13/2018 - CMK - added new IF block to determine ShipmentStatusReasonCode
		BEGIN
			SELECT @ShipmentStatusReasonCode = 'BG' --07/13/2018 - CMK - any damages that ship are BG
		END
		ELSE IF LEFT(@DamageCode,4) IN ('0202','0208','4408','7211','7411','7611','7811','7208','7408','7608','7808',
			'7308','7508','7708','7908','2808','2802','2020','2021','2022','2023','1020','1120','1220','1320',
			'1021','1121','1221','1321','1022','1122','1222','1322','1023','1123','1223','1333','2120','2122','2123')
		BEGIN
			SELECT @ShipmentStatusReasonCode = 'BK' --07/13/2018 - CMK - per Ford list of on-site repairable codes
		END
		ELSE IF RIGHT(@DamageCode,1) IN ('0','1','2') --07/13/2018 - CMK - if severity is 2 or less and not one of the on-site codes, the unit can ship
		BEGIN
			SELECT @ShipmentStatusReasonCode = 'BG' --07/13/2018 - CMK - any damages that ship are BG
		END
		ELSE
		BEGIN
			SELECT @ShipmentStatusReasonCode = 'BT' --07/13/2018 - CMK - if it cant ship or be repaired on-site, it is off-site repair
		END 	--07/13/2018 - CMK - end of new IF block to determine ShipmentStatusReasonCode
		
		--add the damages to the record
		UPDATE FordExportGTNexusShipmentStatus
		SET DamageCodes = ISNULL(DamageCodes,'')+CASE WHEN DATALENGTH(DamageCodes) > 0 THEN ';' ELSE '' END + @DamageCode,
		ShipmentStatusReasonCode = @ShipmentStatusReasonCode				--07/13/2018 - CMK - added update of ShipmentStatusReasonCode
		WHERE FordExportGTNexusShipmentStatusID = @FordExportGTNexusShipmentStatusID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Adding Damage Codes'
			GOTO Error_Encountered
		END
	
		FETCH GTNexusCursor INTO @FordExportGTNexusShipmentStatusID, @DamageCode, @InspectionType --07/13/2018 - CMK - added @InspectionType
	
	END --end of loop
	
	CLOSE GTNexusCursor
	DEALLOCATE GTNexusCursor
	--end of process the Damage Identified records
	
	--process the Delayed In Transit records
				
	--Vehicle Delayed In Transit defaults
	SELECT @DamageCodes = ''
	SELECT @ShipmentStatusCode = 'SD'
	SELECT @ShipFromIdentificationCodeQualifier = 'SF'
	SELECT @ShipToIdentificationCodeQualifier = 'ST'
	SELECT @RoutingSequenceCode = 'O'
	SELECT @SequenceNumber = NULL
			
			
	INSERT INTO FordExportGTNexusShipmentStatus SELECT @BatchID,
		V.VehicleID,
		NULL, --VehicleInspectionID
		@InterchangeSenderID,
		@InterchangeReceiverID,
		@FunctionalID,
		@SenderCode,
		@ReceiverCode,
		@TransmissionDateTime,
		@InterchangeControlNumber,
		@ResponsibleAgencyCode,
		@VersionNumber,
		@TransactionSetControlNumber,
		ISNULL(L5.LoadNumber,'TBD'), --FreightBillNumber,
		CONVERT(varchar(20),V.VehicleID), --ShipmentIdentifyingNumber
		@CarrierSCACCode,
		CASE WHEN ISNULL(U.FirstName,'')+' '+ISNULL(U.LastName,'') = 'DEALER PICKUP' THEN V.VIN ELSE T.TruckNumber END, --EquipmentNumber,
		V.VIN,
		CASE WHEN L4.ParentRecordTable = 'Common' OR L4.LocationSubType IN ('Port','Railyard','Plant') THEN 'C' ELSE 'D' END,	--LaneType
		@DamageCodes,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END + '-' + LEFT(L3.LocationName,60),	--ShipFromName
		@ShipFromIdentificationCodeQualifier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END + '-' + CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END,	--ShipFromIdentificationCode
		L3.AddressLine1,	--ShipFromAddressLine1
		L3.City,	--ShipFromCityName
		L3.State,	--ShipFromState
		L3.Zip,	--ShipFromZIP
		CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE 'US' END,	--ShipFromCountry
		'SL', --ShipFromLocationQualifier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END+'-'+
			CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE '' END, --ShipFromLocationIdentifier,
		CASE WHEN V.VehicleStatus IN ('EnRoute','Delivered') THEN L.PickupDate ELSE DATEADD(Day,ISNULL(LPS.StandardDays,@FordDefaultStandardDays),ISNULL(V.DateMadeAvailable,V.AvailableForPickupDate)) END, --ScheduledPickupDate,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END + '-' + LEFT(L4.LocationName,60),	--ShipToName
		@ShipToIdentificationCodeQualifier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END + '-' + CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END,	--ShipToIdentificationCode
		L4.AddressLine1,	--ShipToAddressLine1
		L4.City,	--ShipToCityName
		L4.State,	--ShipToState
		L4.Zip,	--ShipToZIP
		CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE 'US' END,	--ShipToCountry
		'SL', --ShipToLocationQualifier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END+'-'+
			CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE '' END, --ShipToLocationIdentifier,
		CASE WHEN V.VehicleStatus = 'Delivered' THEN L.DropoffDate WHEN V.VehicleStatus = 'EnRoute' THEN DATEADD(Day,1,L.PickupDate) ELSE DATEADD(Day,ISNULL(LPS.StandardDays,@FordDefaultStandardDays),ISNULL(V.DateMadeAvailable,V.AvailableForPickupDate)) END, --EstimatedDeliveryDate,
		@CarrierSCACCode,	--InterlineSCACCode
		@RoutingSequenceCode,
		CASE WHEN ISNULL(U.FirstName,'')+' '+ISNULL(U.LastName,'') = 'DEALER PICKUP' THEN 'DA' WHEN (SELECT COUNT(*) FROM Vehicle V2 LEFT JOIN LEGS L6 ON V2.VehicleID = L6.VehicleID WHERE L6.LoadID = L.LoadID AND V2.CustomerID <> V.CustomerID) > 0 THEN 'LT' ELSE 'J' END, --TransportationMethodTypeCode,
		@SequenceNumber,
		@ShipmentStatusCode,
		FDT.GTNexusDelayCode,	--ShipmentStatusReasonCode	
		FDT.DelayEffectiveDate,	--@StatusEventDate
		CASE WHEN V.VehicleStatus = 'Delivered' THEN
			CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
				AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode ELSE L4.City END
		ELSE
			CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
				AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode ELSE L3.City END
		END,	--EventCityName
		CASE WHEN V.VehicleStatus = 'Delivered' THEN
			CASE WHEN L4.ParentRecordTable = 'Common' OR DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN 'SL' ELSE L4.State END
		ELSE
			CASE WHEN L3.ParentRecordTable = 'Common' OR DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN 'SL' ELSE L3.State END
		END,	--EventState
		CASE WHEN V.VehicleStatus = 'Delivered' THEN
			CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE 'US' END
		ELSE
			CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE 'US' END
		END,	--EventCountry
		@WeightQualifier,
		@WeightUnitCode,
		@Weight,
		@VolumeUnitQualifier,
		@Volume,
		@ExportedInd,
		@ExportedDate,
		@ExportedBy,
		@RecordStatus,
		@CreationDate,
		@CreatedBy,
		@UpdatedDate,
		@UpdatedBy
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	AND L.FinalLegInd = 1
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
	LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	AND V.PickupLocationID = LPS.OriginID
	AND V.DropoffLocationID = LPS.DestinationID
	LEFT JOIN Run R ON L.RunID = R.RunID
	LEFT JOIN Loads L5 ON L.LoadID = L5.LoadsID
	LEFT JOIN Truck T ON R.TruckID = T.TruckID
	LEFT JOIN Driver D ON R.DriverID = D.DriverID
	LEFT JOIN Users U ON D.UserID = U.UserID
	LEFT JOIN FordDelayTransactions FDT ON V.VehicleID = FDT.VehicleID
	WHERE V.CustomerID = @CustomerID
	AND FDT.DateEntered >= @GTNexusStartDate
	AND DATALENGTH(ISNULL(FDT.GTNexusDelayCode,'')) > 0
	AND FDT.DelayReportedToGTNexusInd = 0
	AND L3.City IS NOT NULL
	AND L3.State IS NOT NULL
	AND L3.Zip IS NOT NULL
	AND L3.Country IS NOT NULL
	AND L4.AddressLine1 IS NOT NULL
	AND L4.City IS NOT NULL
	AND L4.State IS NOT NULL
	AND L4.Zip IS NOT NULL
	AND L4.Country IS NOT NULL
	ORDER BY V.VehicleID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating Delayed In Transit records'
		GOTO Error_Encountered2
	END
			
	DECLARE GTNexusCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT FEG.VehicleID
		FROM FordExportGTNexusShipmentStatus FEG
		WHERE FEG.ExportedInd = 0
		AND FEG.BatchID = @BatchID
		AND FEG.ShipmentStatusCode = 'SD'
			
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN GTNexusCursor
	
	FETCH GTNexusCursor INTO @VehicleID
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--add the damages to the record
		UPDATE FordDelayTransactions
		SET DelayReportedToGTNexusInd = 1,
		DateDelayReportedToGTNexus = ISNULL(DateDelayReportedToGTNexus,CURRENT_TIMESTAMP)
		WHERE VehicleID = @VehicleID
		AND DelayReportedToGTNexusInd = 0
		AND DATALENGTH(ISNULL(GTNexusDelayCode,'')) > 0
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error updating Ford Delay Transactions'
			GOTO Error_Encountered
		END
	
		FETCH GTNexusCursor INTO @VehicleID
	
	END --end of loop
	
	--end of process the Delayed In Transit records
	
	CLOSE GTNexusCursor
	DEALLOCATE GTNexusCursor
	--end of process the Damage Identified records
		
	--process the Hold Set/Released records
					
	--Vehicle Hold Set/Released defaults
	SELECT @DamageCodes = ''
	SELECT @ShipFromIdentificationCodeQualifier = 'SF'
	SELECT @ShipToIdentificationCodeQualifier = 'ST'
	SELECT @RoutingSequenceCode = 'O'
	SELECT @SequenceNumber = NULL
				
				
	INSERT INTO FordExportGTNexusShipmentStatus SELECT @BatchID,
		V.VehicleID,
		NULL, --VehicleInspectionID
		@InterchangeSenderID,
		@InterchangeReceiverID,
		@FunctionalID,
		@SenderCode,
		@ReceiverCode,
		@TransmissionDateTime,
		@InterchangeControlNumber,
		@ResponsibleAgencyCode,
		@VersionNumber,
		@TransactionSetControlNumber,
		ISNULL(L5.LoadNumber,'TBD'), --FreightBillNumber,
		CONVERT(varchar(20),V.VehicleID), --ShipmentIdentifyingNumber
		@CarrierSCACCode,
		CASE WHEN ISNULL(U.FirstName,'')+' '+ISNULL(U.LastName,'') = 'DEALER PICKUP' THEN V.VIN ELSE T.TruckNumber END, --EquipmentNumber,
		V.VIN,
		CASE WHEN L4.ParentRecordTable = 'Common' OR L4.LocationSubType IN ('Port','Railyard','Plant') THEN 'C' ELSE 'D' END,	--LaneType
		@DamageCodes,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END + '-' + LEFT(L3.LocationName,60),	--ShipFromName
		@ShipFromIdentificationCodeQualifier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END + '-' + CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) > 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END,	--ShipFromIdentificationCode
		L3.AddressLine1,	--ShipFromAddressLine1
		L3.City,	--ShipFromCityName
		L3.State,	--ShipFromState
		L3.Zip,	--ShipFromZIP
		CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE 'US' END,	--ShipFromCountry
		'SL', --ShipFromLocationQualifier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END+'-'+
			CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE '' END, --ShipFromLocationIdentifier,
		CASE WHEN V.VehicleStatus IN ('EnRoute','Delivered') THEN L.PickupDate ELSE DATEADD(Day,ISNULL(LPS.StandardDays,@FordDefaultStandardDays),ISNULL(V.DateMadeAvailable,V.AvailableForPickupDate)) END, --ScheduledPickupDate,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END + '-' + LEFT(L4.LocationName,60),	--ShipToName
		@ShipToIdentificationCodeQualifier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END + '-' + CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = 'FordLocationCode'
		AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) > 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END,	--ShipToIdentificationCode
		L4.AddressLine1,	--ShipToAddressLine1
		L4.City,	--ShipToCityName
		L4.State,	--ShipToState
		L4.Zip,	--ShipToZIP
		CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE 'US' END,	--ShipToCountry
		'SL', --ShipToLocationQualifier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
			AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END+'-'+
			CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE '' END, --ShipToLocationIdentifier,
		CASE WHEN V.VehicleStatus = 'Delivered' THEN L.DropoffDate WHEN V.VehicleStatus = 'EnRoute' THEN DATEADD(Day,1,L.PickupDate) ELSE DATEADD(Day,ISNULL(LPS.StandardDays,@FordDefaultStandardDays),ISNULL(V.DateMadeAvailable,V.AvailableForPickupDate)) END, --EstimatedDeliveryDate,
		@CarrierSCACCode,	--InterlineSCACCode
		@RoutingSequenceCode,
		CASE WHEN ISNULL(U.FirstName,'')+' '+ISNULL(U.LastName,'') = 'DEALER PICKUP' THEN 'DA' WHEN (SELECT COUNT(*) FROM Vehicle V2 LEFT JOIN LEGS L6 ON V2.VehicleID = L6.VehicleID WHERE L6.LoadID = L.LoadID AND V2.CustomerID <> V.CustomerID) > 0 THEN 'LT' ELSE 'J' END, --TransportationMethodTypeCode,
		@SequenceNumber,
		CASE WHEN FDT.DelayReportedToGTNexusInd = 0 THEN 'PR' ELSE 'AI' END,	--ShipmentStatusCode
		FDT.GTNexusHoldCode,	--ShipmentStatusReasonCode	
		CASE WHEN FDT.DelayReportedToGTNexusInd = 0 THEN FDT.DelayEffectiveDate ELSE FDT.DateReleased END,	--@StatusEventDate
		CASE WHEN V.VehicleStatus = 'Delivered' THEN
			CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
				AND Value1 = CONVERT(varchar(10),L4.LocationID)) WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode ELSE L4.State END
		ELSE
			CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Value2 FROM Code WHERE CodeType = 'FordLocationCode'
				AND Value1 = CONVERT(varchar(10),L3.LocationID)) WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END
		END,	--EventCityName
		CASE WHEN V.VehicleStatus = 'Delivered' THEN
			CASE WHEN L4.ParentRecordTable = 'Common' OR DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN 'SL' ELSE L4.State END
		ELSE
			CASE WHEN L3.ParentRecordTable = 'Common' OR DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN 'SL' ELSE L3.State END
		END,	--EventState
		CASE WHEN V.VehicleStatus = 'Delivered' THEN
			CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE 'US' END
		ELSE
			CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE 'US' END
		END,	--EventCountry
		@WeightQualifier,
		@WeightUnitCode,
		@Weight,
		@VolumeUnitQualifier,
		@Volume,
		@ExportedInd,
		@ExportedDate,
		@ExportedBy,
		@RecordStatus,
		@CreationDate,
		@CreatedBy,
		@UpdatedDate,
		@UpdatedBy
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	AND L.FinalLegInd = 1
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
	LEFT JOIN LocationPerformanceStandards LPS ON V.CustomerID = LPS.CustomerID
	AND V.PickupLocationID = LPS.OriginID
	AND V.DropoffLocationID = LPS.DestinationID
	LEFT JOIN Run R ON L.RunID = R.RunID
	LEFT JOIN Loads L5 ON L.LoadID = L5.LoadsID
	LEFT JOIN Truck T ON R.TruckID = T.TruckID
	LEFT JOIN Driver D ON R.DriverID = D.DriverID
	LEFT JOIN Users U ON D.UserID = U.UserID
	LEFT JOIN FordDelayTransactions FDT ON V.VehicleID = FDT.VehicleID
	WHERE V.CustomerID = @CustomerID
	AND FDT.DateEntered >= @GTNexusStartDate
	AND DATALENGTH(ISNULL(FDT.GTNexusHoldCode,'')) > 0
	AND (FDT.DelayReportedToGTNexusInd = 0
	OR (FDT.RecordStatus = 'Closed' AND FDT.ReleaseReportedToGTNexusind = 0))
	AND L3.City IS NOT NULL
	AND L3.State IS NOT NULL
	AND L3.Zip IS NOT NULL
	AND L3.Country IS NOT NULL
	AND L4.AddressLine1 IS NOT NULL
	AND L4.City IS NOT NULL
	AND L4.State IS NOT NULL
	AND L4.Zip IS NOT NULL
	AND L4.Country IS NOT NULL
	ORDER BY V.VehicleID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating Hold Set/Released records'
		GOTO Error_Encountered2
	END
			
	DECLARE GTNexusCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT FEG.VehicleID, FEG.ShipmentStatusCode
		FROM FordExportGTNexusShipmentStatus FEG
		WHERE FEG.ExportedInd = 0
		AND FEG.BatchID = @BatchID
		AND FEG.ShipmentStatusCode IN ('PR','AI')
			
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN GTNexusCursor
	
	FETCH GTNexusCursor INTO @VehicleID, @ShipmentStatusCode
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--add the damages to the record
		UPDATE FordDelayTransactions
		SET DelayReportedToGTNexusInd = 1,
		DateDelayReportedToGTNexus = ISNULL(DateDelayReportedToGTNexus,CURRENT_TIMESTAMP),
		ReleaseReportedToGTNexusInd = CASE WHEN @ShipmentStatusCode = 'AI' THEN 1 ELSE 0 END,
		DateReleaseReportedToGTNexus = CASE WHEN @ShipmentStatusCode = 'AI' THEN CURRENT_TIMESTAMP ELSE NULL END
		WHERE VehicleID = @VehicleID
		AND (DelayReportedToGTNexusInd = 0
		OR (RecordStatus = 'Closed' AND ReleaseReportedToGTNexusInd = 0))
		AND DATALENGTH(ISNULL(GTNexusHoldCode,'')) > 0
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error updating Ford Delay Transactions'
			GOTO Error_Encountered
		END
	
		FETCH GTNexusCursor INTO @VehicleID, @ShipmentStatusCode
	
	END --end of loop
	
	--end of process the Hold Set/Released records
	
	--process the Shipment Redirect records
	--02/28/2018 - CMK - start of Shipment Redirect code
	
	--Vehicle Shipment Redirect defaults
	SELECT @ShipmentStatusCode = 'AP'
	SELECT @SequenceNumber = NULL
			
	--updating the original R1 records to be an AP record so that if the vehicle
	--is made available again, the system will generate a new R1 record
	
	UPDATE FordExportGTNexusShipmentStatus
	SET SequenceNumber = @SequenceNumber,
	ShipmentStatusCode = @ShipmentStatusCode,
	StatusEventDate = CURRENT_TIMESTAMP,
	ExportedInd = 0,
	ExportedDate = NULL,
	Exportedby = NULL,
	RecordStatus = 'Export Pending',
	UpdatedDate = @CreationDate,
	UpdatedBy = @CreatedBy
	WHERE FordExportGTNexusShipmentStatusID IN (SELECT F.FordExportGTNexusShipmentStatusID
	FROM FordExportGTNexusShipmentStatus F
	LEFT JOIN Vehicle V ON F.VehicleID = V.VehicleID
	WHERE ShipmentStatusCode = 'R1'
	AND F.CreationDate >= DATEADD(day,-180, CURRENT_TIMESTAMP)
	AND ISNULL(V.VehicleStatus,'Pending') = 'Pending')
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error processing Shipment Redirect records'
		GOTO Error_Encountered2
	END
	
	--end of process the Shipment Redirect records
	--02/28/2018 - CMK - end of Shipment Redirect code
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE GTNexusCursor
		DEALLOCATE GTNexusCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE FordDeliveryExportCursor
		DEALLOCATE FordDeliveryExportCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
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

	Error_Encountered3:
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
