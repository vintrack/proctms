USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateBluJay214Data]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateBluJay214Data] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	--BluJayExport214 table variables
	@BatchID			int,
	@CustomerID			int,
	@VehicleID			int,
	@InterchangeSenderID		varchar(15),
	@InterchangeReceiverID		varchar(15),
	@FunctionalID			varchar(2),
	@SenderCode			varchar(12),
	@ReceiverCode			varchar(12),
	@TransmissionDateTime		datetime,
	@InterchangeControlNumber	int,
	@ResponsibleAgencyCode		varchar(2),
	@VersionNumber			varchar(12),
	@CarrierReferenceNumber		varchar(30),
	@ShipmentIdentificationNumber	varchar(30),
	@StandardCarrierAlphaCode	varchar(4),
	@ShipperName			varchar(60),
	@ShipperIdentificationCode	varchar(80),
	@ShipmentStatusCode		varchar(2),
	@ShipmentStatus			varchar(2),
	@ShipmentAppointmentStatusCode	varchar(2),
	@ShipmentAppointmentReasonCode	varchar(2),
	@ShipmentStatusDateTime		datetime,
	@ShipmentStatusTimeCode		varchar(2),
	@StatusCityName			varchar(30),
	@StatusStateCode		varchar(2),
	@StatusCountryCode		varchar(3),
	@BillOfLadingNumber		varchar(30),
	@MotorVehicleIDNumber		varchar(30),
	@ExportedInd			int,
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	--processing variables
	@BluJayStartDate		datetime,
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateBluJay214Data						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates various event data on Volvos to	*
	*	transmit back via BluJay.					*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	06/27/2018 CMK    Initial version				*
	*									*
	************************************************************************/
	
	SELECT @ErrorID = 0
	SELECT @BluJayStartDate = '06/20/2018' --real date should be 07/01/2018
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'VolvoCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting CustomerID'
		GOTO Error_Encountered
	END
	IF @CustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'CustomerID Not Found'
		GOTO Error_Encountered
	END

	--get the next batch id from the setting table
	SELECT @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextBluJay214ExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting BatchID'
		GOTO Error_Encountered
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'BatchID Not Found'
		GOTO Error_Encountered
	END
	
	--get the Interchange Sender ID from the setting table
	SELECT @InterchangeSenderID = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'CompanySCACCode'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Company SCAC Code'
		GOTO Error_Encountered
	END
	IF @InterchangeSenderID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Company SCAC Code Not Found'
		GOTO Error_Encountered
	END
	
	--get the Interchange Receiver ID from the setting table
	SELECT @InterchangeReceiverID = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'BluJayEDICode'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting BluJay EDI Code'
		GOTO Error_Encountered
	END
	IF @InterchangeReceiverID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'BluJay EDI Code Not Found'
		GOTO Error_Encountered
	END
	
	--get the Originating Company Identifier from the setting table
	SELECT @ShipperIdentificationCode = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'VolvoDunsNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Volvo Duns Number'
		GOTO Error_Encountered
	END
	IF @ShipperIdentificationCode IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Volvo Duns Number Not Found'
		GOTO Error_Encountered
	END
	
	--set the default values
	SELECT @FunctionalID = 'QM'
	SELECT @SenderCode = @InterchangeSenderID
	SELECT @ReceiverCode = @InterchangeReceiverID
	SELECT @TransmissionDateTime = NULL --value set during export
	SELECT @InterchangeControlNumber = NULL --value set during export
	SELECT @ResponsibleAgencyCode = 'X'
	SELECT @VersionNumber = '004010'
	SELECT @CarrierReferenceNumber = 'NONE' --may change in the future
	SELECT @StandardCarrierAlphaCode = @InterchangeSenderID
	SELECT @ShipperName = 'Volvo Car Corporation'
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	--create the Carrier Departed Pickup Location with Shipment (AF) records
	SELECT @ShipmentStatusCode = 'AF'
	SELECT @ShipmentStatus = 'NS' --Normal Status
	SELECT @ShipmentAppointmentStatusCode = ''
	SELECT @ShipmentAppointmentReasonCode = ''
	SELECT @ShipmentStatusTimeCode = 'LT'
	
	INSERT INTO BluJayExport214(BatchID, CustomerID, VehicleID, InterchangeSenderID, InterchangeReceiverID,
		FunctionalID, SenderCode, ReceiverCode, ResponsibleAgencyCode, VersionNumber, CarrierReferenceNumber,
		ShipmentIdentificationNumber, StandardCarrierAlphaCode, ShipperName, ShipperIdentificationCode,
		ShipmentStatusCode, ShipmentStatus, ShipmentAppointmentStatusCode, ShipmentAppointmentReasonCode,
		ShipmentStatusDateTime, ShipmentStatusTimeCode, StatusCityName, StatusStateCode, StatusCountryCode,
		BillOfLadingNumber, MotorVehicleIDNumber, ExportedInd, RecordStatus, CreationDate, CreatedBy)
	SELECT @BatchID, @CustomerID, V.VehicleID, @InterchangeSenderID, @InterchangeReceiverID,
		@FunctionalID, @SenderCode, @ReceiverCode, @ResponsibleAgencyCode, @VersionNumber, @CarrierReferenceNumber,
		V.CustomerIdentification ShipmentIdentificationNumber, @StandardCarrierAlphaCode, @ShipperName, @ShipperIdentificationCode,
		@ShipmentStatusCode, @ShipmentStatus, @ShipmentAppointmentStatusCode, @ShipmentAppointmentReasonCode,
		L.PickupDate ShipmentStatusDateTime, @ShipmentStatusTimeCode, L2.City StatusCityName, L2.State StatusStateCode,
		CASE WHEN L2.Country = 'U.S.A.' THEN 'USA' WHEN L2.Country = 'Canada' THEN 'CAN' ELSE L2.Country END StatusCountryCode,
		O.PONumber BillOfLadingNumber, V.VIN MotorVehicleIDNumber, @ExportedInd, @RecordStatus, @CreationDate, @CreatedBy
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.LegNumber = 1
		LEFT JOIN Location L2 ON V.PickupLocationID = L2.LocationID
		LEFT JOIN Orders O ON V.OrderID = O.OrdersID
		WHERE V.CustomerID = @CustomerID
		AND V.CreationDate >= @BluJayStartDate
		AND L.PickupDate IS NOT NULL
		AND ISNULL(V.CustomerIdentification,'') <> ''
		AND ISNULL(O.PONumber,'') <> ''
		AND V.VehicleID NOT IN (SELECT E.VehicleID FROM BluJayExport214 E WHERE E.VehicleId = V.VehicleID AND E.ShipmentStatusCode = 'AF')
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating Loaded On Truck records'
		GOTO Error_Encountered
	END
	
	--create the Completed Unloading At Delivery Location (D1) records
	SELECT @ShipmentStatusCode = 'D1'
	SELECT @ShipmentStatus = 'NS' --Normal Status
	SELECT @ShipmentAppointmentStatusCode = ''
	SELECT @ShipmentAppointmentReasonCode = ''
	SELECT @ShipmentStatusTimeCode = 'LT'
		
	INSERT INTO BluJayExport214(BatchID, CustomerID, VehicleID, InterchangeSenderID, InterchangeReceiverID,
		FunctionalID, SenderCode, ReceiverCode, ResponsibleAgencyCode, VersionNumber, CarrierReferenceNumber,
		ShipmentIdentificationNumber, StandardCarrierAlphaCode, ShipperName, ShipperIdentificationCode,
		ShipmentStatusCode, ShipmentStatus, ShipmentAppointmentStatusCode, ShipmentAppointmentReasonCode,
		ShipmentStatusDateTime, ShipmentStatusTimeCode, StatusCityName, StatusStateCode, StatusCountryCode,
		BillOfLadingNumber, MotorVehicleIDNumber, ExportedInd, RecordStatus, CreationDate, CreatedBy)
	SELECT @BatchID, @CustomerID, V.VehicleID, @InterchangeSenderID, @InterchangeReceiverID,
		@FunctionalID, @SenderCode, @ReceiverCode, @ResponsibleAgencyCode, @VersionNumber, @CarrierReferenceNumber,
		V.CustomerIdentification ShipmentIdentificationNumber, @StandardCarrierAlphaCode, @ShipperName, @ShipperIdentificationCode,
		@ShipmentStatusCode, @ShipmentStatus, @ShipmentAppointmentStatusCode, @ShipmentAppointmentReasonCode,
		L.DropoffDate ShipmentStatusDateTime, @ShipmentStatusTimeCode, L2.City StatusCityName, L2.State StatusStateCode,
		CASE WHEN L2.Country = 'U.S.A.' THEN 'USA' WHEN L2.Country = 'Canada' THEN 'CAN' ELSE L2.Country END StatusCountryCode,
		O.PONumber BillOfLadingNumber, V.VIN MotorVehicleIDNumber, @ExportedInd, @RecordStatus, @CreationDate, @CreatedBy
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.FinalLegInd = 1
		LEFT JOIN Location L2 ON V.DropoffLocationID = L2.LocationID
		LEFT JOIN Orders O ON V.OrderID = O.OrdersID
		WHERE V.CustomerID = @CustomerID
		AND V.CreationDate >= @BluJayStartDate
		AND L.DropoffDate IS NOT NULL
		AND ISNULL(V.CustomerIdentification,'') <> ''
		AND ISNULL(O.PONumber,'') <> ''
		AND V.VehicleID NOT IN (SELECT E.VehicleID FROM BluJayExport214 E WHERE E.VehicleId = V.VehicleID AND E.ShipmentStatusCode = 'D1')
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating Loaded On Truck records'
		GOTO Error_Encountered
	END

	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextBluJay214ExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END
	
	SELECT @Status = 'Processing Completed Successfully'
	
	Error_Encountered:
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
