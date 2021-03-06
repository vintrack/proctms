USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateMercedesDeliveryData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateMercedesDeliveryData] (@LocationID int, @VPC varchar(2),@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--MercedesDeliveryExport table variables
	@MercedesDeliveryExportID	int,
	@BatchID			int,
	@VehicleID			int,
	@TransmissionNumber		varchar(5),
	@TransmissionDateTime		datetime,
	@MBUSARecordKey			varchar(29),
	@ReferenceNumber		varchar(12),
	@PickupDateTime			datetime,
	@EstimatedDeliveryDateTime	datetime,
	@ActualDeliveryDateTime		datetime,
	@DamageIndicator		varchar(1),
	@CarrierEquipmentType		varchar(1),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	--processing variables
	@PONumber			varchar(20),
	@DateAvailable			datetime,
	@VIN				varchar(17),
	@CustomerID			int,
	@DamageCode			varchar(5),
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@DealerETADate			datetime
	/************************************************************************
	*	spGenerateMercedesDeliveryData					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the vehicle delivery export data for	*
	*	Mercedes vehicles that have been picked up.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	05/07/2007 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'MercedesCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting CustomerID'
		GOTO Error_Encountered2
	END
	IF @CustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'CustomerID Not Found'
		GOTO Error_Encountered2
	END

	--get the next batch id from the setting table
	SELECT @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextMercedesDeliveryExportBatchID'
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

	--cursor for eta records
	DECLARE MercedesDeliveryCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, --O.PONumber, V.AvailableForPickupDate,
		V.VIN, L3.LoadNumber,L1.PickupDate,V.DealerETADate,L2.DropoffDate, CASE WHEN (SELECT COUNT(*)
		FROM VehicleDamageDetail VDD
		WHERE VDD.VehicleID = V.VehicleID) > 0 THEN 'Y' ELSE 'N' END
		FROM Vehicle V
		LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
		AND L1.LegNumber = 1
		LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID
		AND L2.FinalLegInd = 1
		LEFT JOIN Loads L3 ON L2.LoadID = L3.LoadsID
		LEFT JOIN Orders O ON V.OrderID = O.OrdersID
		WHERE V.PickupLocationID = @LocationID
		AND V.CustomerID = @CustomerID
		AND L2.DateAvailable >= '11/01/2012'	-- effective start date for file
		AND V.VehicleID NOT IN (SELECT MDE.VehicleID FROM MercedesDeliveryExport MDE WHERE MDE.VehicleID = V.VehicleID AND EstimatedDeliveryDateTime IS NULL)
		AND V.DealerETADate IS NOT NULL
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN MercedesDeliveryCursor

	BEGIN TRAN
	
	--set the default values
	SELECT @TransmissionNumber = null -- set during export
	SELECT @TransmissionDateTime = null -- set during export
	SELECT @CarrierEquipmentType = 'O'
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	FETCH MercedesDeliveryCursor INTO @VehicleID,
		@VIN, @ReferenceNumber,
		@PickupDateTime, @EstimatedDeliveryDateTime,@ActualDeliveryDateTime,@DamageIndicator
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		/*
		SELECT TOP 1 @MBUSARecordKey = LoadNumber+SUBSTRING(AvailableDate,3,4)+VIN+VPC
		FROM MercedesImport
		WHERE VIN = @VIN
		ORDER BY CreationDate DESC
		*/
		SELECT @MBUSARecordKey = NULL
		
		SELECT TOP 1 @MBUSARecordKey = ISNULL(M.LoadNumber,REPLICATE(' ',10))+ISNULL(V.VIN,REPLICATE(' ',17))+ISNULL(M.VPC,REPLICATE(' ',2)) --AvailableDate now concatenated onto Load Number
		FROM Vehicle V
		LEFT JOIN MercedesImport M ON V.VIN = M.VIN
		WHERE V.VIN = @VIN
		ORDER BY M.CreationDate DESC
		
		INSERT INTO MercedesDeliveryExport(
			BatchID,
			VehicleID,
			TransmissionNumber,
			TransmissionDateTime,
			MBUSARecordKey,
			ReferenceNumber,
			PickupDateTime,
			EstimatedDeliveryDateTime,
			ActualDeliveryDateTime,
			DamageIndicator,
			CarrierEquipmentType,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@TransmissionNumber,
			@TransmissionDateTime,
			@MBUSARecordKey,
			@ReferenceNumber,
			@PickupDateTime,
			@EstimatedDeliveryDateTime
,			@ActualDeliveryDateTime,
			@DamageIndicator,
			@CarrierEquipmentType,
			@ExportedInd,
			@ExportedDate,
			@ExportedBy,
			@RecordStatus,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating NissanExportVD record'
			GOTO Error_Encountered
		END
			
		FETCH MercedesDeliveryCursor INTO @VehicleID,
		@VIN, @ReferenceNumber,
		@PickupDateTime, @EstimatedDeliveryDateTime,@ActualDeliveryDateTime,@DamageIndicator
	
	END --end of loop

	CLOSE MercedesDeliveryCursor
	DEALLOCATE MercedesDeliveryCursor
		
	DECLARE MercedesDeliveryCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, --O.PONumber, V.AvailableForPickupDate,
		V.VIN, L3.LoadNumber,L1.PickupDate,L2.DropoffDate, CASE WHEN (SELECT COUNT(*)
		FROM VehicleDamageDetail VDD
		WHERE VDD.VehicleID = V.VehicleID) > 0 THEN 'Y' ELSE 'N' END
		FROM Vehicle V
		LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
		AND L1.LegNumber = 1
		LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID
		AND L2.FinalLegInd = 1
		LEFT JOIN Loads L3 ON L2.LoadID = L3.LoadsID
		LEFT JOIN Orders O ON V.OrderID = O.OrdersID
		WHERE V.PickupLocationID = @LocationID
		AND V.CustomerID = @CustomerID
		AND L2.DropoffDate >= '01/01/2007'	-- effective start date for file
		AND V.VehicleStatus = 'Delivered'
		AND V.VehicleID NOT IN (SELECT MDE.VehicleID FROM MercedesDeliveryExport MDE WHERE MDE.VehicleID = V.VehicleID AND EstimatedDeliveryDateTime IS NULL)
		--AND V.DealerETADate IS NULL
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN MercedesDeliveryCursor

	--set the default values
	SELECT @TransmissionNumber = null -- set during export
	SELECT @TransmissionDateTime = null -- set during export
	SELECT @CarrierEquipmentType = 'O'
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @EstimatedDeliveryDateTime = null	
	
	FETCH MercedesDeliveryCursor INTO @VehicleID,
		@VIN, @ReferenceNumber,
		@PickupDateTime,@ActualDeliveryDateTime,@DamageIndicator

	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		/*
		SELECT TOP 1 @MBUSARecordKey = LoadNumber+SUBSTRING(AvailableDate,3,4)+VIN+VPC
		FROM MercedesImport
		WHERE VIN = @VIN
		ORDER BY CreationDate DESC
		*/
		SELECT @MBUSARecordKey = NULL
		
		SELECT TOP 1 @MBUSARecordKey = ISNULL(M.LoadNumber,REPLICATE(' ',10))+ISNULL(V.VIN,REPLICATE(' ',17))+ISNULL(M.VPC,REPLICATE(' ',2)) --AvailableDate now concatenated onto Load Number
		FROM Vehicle V
		LEFT JOIN MercedesImport M ON V.VIN = M.VIN
		WHERE V.VIN = @VIN
		ORDER BY M.CreationDate DESC
		
		INSERT INTO MercedesDeliveryExport(
			BatchID,
			VehicleID,
			TransmissionNumber,
			TransmissionDateTime,
			MBUSARecordKey,
			ReferenceNumber,
			PickupDateTime,
			EstimatedDeliveryDateTime,
			ActualDeliveryDateTime,
			DamageIndicator,
			CarrierEquipmentType,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@TransmissionNumber,
			@TransmissionDateTime,
			@MBUSARecordKey,
			@ReferenceNumber,
			@PickupDateTime,
			@EstimatedDeliveryDateTime,
			@ActualDeliveryDateTime,
			@DamageIndicator,
			@CarrierEquipmentType,
			@ExportedInd,
			@ExportedDate,
			@ExportedBy,
			@RecordStatus,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating NissanExportVD record'
			GOTO Error_Encountered
		END
			
		FETCH MercedesDeliveryCursor INTO @VehicleID,@VIN, @ReferenceNumber,
		@PickupDateTime,@ActualDeliveryDateTime,@DamageIndicator

	END --end of loop

	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextMercedesDeliveryExportBatchID'
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
		CLOSE MercedesDeliveryCursor
		DEALLOCATE MercedesDeliveryCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE MercedesDeliveryCursor
		DEALLOCATE MercedesDeliveryCursor
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
