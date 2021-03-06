USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateTokioMarine928Data]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateTokioMarine928Data] (@CustomerID int, @ManufacturerCode varchar(2), @CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--ExportTokioMarine928 table variables
	@BatchID			int,
	@VehicleID			int,
	@InspectionID			int,
	@VehicleDamageDetailID		int,
	@InterchangeSenderID		varchar(15),
	@InterchangeReceiverID		varchar(15),
	@FunctionalID			varchar(2),
	@SenderCode			varchar(12),
	@ReceiverCode			varchar(12),
	@TransmissionDateTime		datetime,
	@InterchangeControlNumber	int,
	@ResponsibleAgencyCode		varchar(2),
	@VersionNumber			varchar(12),
	@TransactionSetControlNumber	int,
	@TransactionPurpose		varchar(2),
	@InspectionAgency		varchar(4),
	@InspectionDate			datetime,
	@InspectionLocationType		varchar(2),
	@IDCodeQualifier		varchar(2),
	@IDCode				varchar(17),
	@EquipmentInitial		varchar(4),
	@EquipmentNumber		varchar(10),
	@WaybillDate			datetime,
	@DamageExceptionInd		varchar(1),
	@DamageAreaCode			varchar(2),
	@DamageTypeCode			varchar(2),
	@DamageSeverityCode		varchar(1),
	@ExportedInd			int,
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	--processing variables
	@ManufacturerStartDate		datetime,
	@RailcarNumber			varchar(20),
	@OriginCode			varchar(20),
	@DestinationCode		varchar(20),
	@PickupLocationType		varchar(20),
	@DropoffLocationType		varchar(20),
	@InspectionType			int,
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateTokioMarine928Data					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the Tokio Marine 928 export data for	*
	*	vehicles (for the specified Tokio Marine customer) that have	*
	*	been inspected.							*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	01/24/2011 CMK    Initial version				*
	*	11/01/2016 CMK    Change Code table lookup to use new		*
	*	                  TokioMarinexxLocationCode entries		*
	*									*
	************************************************************************/
	
	--get the next batch id from the setting table
	--print 'getting batch id'
	SELECT TOP 1 @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextTokioMarine928ExportBatchID'
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
	
	SELECT TOP 1 @ManufacturerStartDate = Value2
	FROM Code
	WHERE CodeType = 'TokioMarineManufacturerCode'
	AND Code = @ManufacturerCode
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting ManufacturerStartDate'
		GOTO Error_Encountered2
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Status = 'ManufacturerStartDate Not Found'
		GOTO Error_Encountered2
	END
	
	SELECT TOP 1 @InterchangeSenderID = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'CompanySCACCode'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Company SCAC Code'
		GOTO Error_Encountered2
	END
	IF @InterchangeSenderID IS NULL
	BEGIN
		SELECT @ErrorID = 100003
		SELECT @Status = 'InterchangeSenderID Not Found'
		GOTO Error_Encountered2
	END
	
	--print 'have batch id'
	--cursor for the pickup records
	DECLARE TokioMarine928Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, VI.VehicleInspectionID,
		VDD.VehicleDamageDetailID, VI.InspectionType, VI.InspectionDate,
		L1.LocationSubType, L2.LocationSubType,
		'Y',
		LEFT(VDD.DamageCode, 2),
		SUBSTRING(VDD.DamageCode,3,2),
		RIGHT(VDD.DamageCode,1),
		CASE WHEN L1.ParentRecordTable = 'Common' THEN (SELECT C.Code FROM Code C WHERE C.CodeType = 'TokioMarine'+@ManufacturerCode+'LocationCode'
		AND C.Value1 = CONVERT(varchar(10),L1.LocationID)) ELSE L1.CustomerLocationCode END,
		CASE WHEN L2.ParentRecordTable = 'Common' THEN (SELECT C2.Code FROM Code C2 WHERE C2.CodeType = 'TokioMarine'+@ManufacturerCode+'LocationCode'
		AND C2.Value1 = CONVERT(varchar(10),L2.LocationID)) ELSE L2.CustomerLocationCode END,
		V.RailcarNumber, V.AvailableForPickupDate
		FROM VehicleInspection VI
		LEFT JOIN Vehicle V ON VI.VehicleID = V.VehicleID
		LEFT JOIN VehicleDamageDetail VDD ON VI.VehicleInspectionID = VDD.VehicleInspectionID
		LEFT JOIN Location L1 ON V.PickupLocationID = L1.LocationID
		LEFT JOIN Location L2 ON V.DropoffLocationID = L2.LocationID
		WHERE V.CustomerID = @CustomerID
		AND VI.InspectionType IN (0,1,2)
		AND VI.InspectionDate >= @ManufacturerStartDate
		AND PATINDEX('%[0-9][0-9][0-9][0-9][0-9]%', VDD.DamageCode) > 0
		AND (VI.VehicleInspectionID NOT IN (SELECT ETM928.InspectionID
			FROM ExportTokioMarine928 ETM928)
		OR VDD.VehicleDamageDetailID IN (SELECT VDD2.VehicleDamageDetailID
			FROM VehicleDamageDetail VDD2 WHERE VDD2.VehicleInspectionID = VI.VehicleInspectionID
			AND VDD2.VehicleDamageDetailID NOT IN (SELECT ISNULL(ETM928A.VehicleDamageDetailID,0)
			FROM ExportTokioMarine928 ETM928A WHERE ETM928A.InspectionID = VDD.VehicleInspectionID)))
		ORDER BY V.VehicleID, VI.VehicleInspectionID
	--print 'cursor declared'
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN TokioMarine928Cursor
	--print 'cursor opened'
	BEGIN TRAN
	--print 'tran started'
	--set the next batch id in the setting table
	
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextTokioMarine928ExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END
	
	--print 'batch id updated'
	--set the default values
	--SELECT @InterchangeSenderID = 'DVAI'
	SELECT @InterchangeReceiverID = 'TMC01'
	SELECT @FunctionalID = 'AI'
	SELECT @SenderCode = @InterchangeSenderID
	SELECT @ReceiverCode ='TMC01'
	SELECT @TransmissionDateTime = NULL	--populated when exported
	SELECT @InterchangeControlNumber = NULL	--populated when exported
	SELECT @ResponsibleAgencyCode = 'X'
	SELECT @VersionNumber = '004010'
	SELECT @TransactionSetControlNumber = NULL	--populated when exported
	SELECT @TransactionPurpose = '02'
	SELECT @InspectionAgency = @InterchangeSenderID
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	--print 'default values set'
	
	FETCH TokioMarine928Cursor INTO @VehicleID, @InspectionID,
		@VehicleDamageDetailID, @InspectionType, @InspectionDate,
		@PickupLocationType, @DropoffLocationType, @DamageExceptionInd,
		@DamageAreaCode, @DamageTypeCode, @DamageSeverityCode,
		@OriginCode, @DestinationCode, @RailcarNumber, @WaybillDate
	
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		/*
		IF @InspectionType IN (0,1,5)
		BEGIN
			SELECT @InspectionLocationType = '02'
		END
		ELSE IF @InspectionType = 2
		BEGIN
			IF @DropoffLocationType IN ('Port','Railyard')
			BEGIN
				SELECT @InspectionLocationType = '02'
			END
			ELSE
			BEGIN
				SELECT @InspectionLocationType = '05'
			END
		END
		ELSE IF @InspectionType = 3
		BEGIN
			IF @DropoffLocationType IN ('Port','Railyard')
			BEGIN
				SELECT @InspectionLocationType = '02'
			END
			ELSE
			BEGIN
				SELECT @InspectionLocationType = '05'
			END
		END
		ELSE
		BEGIN
			SELECT @InspectionLocationType = '02'
		END
		*/
		SELECT @InspectionLocationType = '04'
		/*
		IF @InspectionLocationType = '02'
		BEGIN
			IF @PickupLocationType IN ('Port','Railyard')
			BEGIN
				SELECT @IDCodeQualifier = '20'
			END
			ELSE
			BEGIN
				SELECT @IDCodeQualifier = '91'
			END
			SELECT @IDCode = @OriginCode			
		END
		ELSE
		BEGIN
			IF @DropoffLocationType IN ('Port','Railyard')
			BEGIN
				SELECT @IDCodeQualifier = '20'
			END
			ELSE
			BEGIN
				SELECT @IDCodeQualifier = '91'
			END
			SELECT @IDCode = @DestinationCode
		END
		*/
		SELECT @IDCodeQualifier = '20'
		SELECT @IDCode = @OriginCode
		
		IF DATALENGTH(ISNULL(@RailcarNumber,'')) > 0
		BEGIN
			IF PATINDEX('%[0-9]%',@RailcarNumber) > 0
			BEGIN
				SELECT @EquipmentInitial = SUBSTRING(@RailcarNumber,1, PATINDEX('%[0-9]%',@RailcarNumber) - 1)
				SELECT @EquipmentNumber = SUBSTRING(@RailcarNumber,PATINDEX('%[0-9]%',@RailcarNumber), DATALENGTH(@RailcarNumber) - PATINDEX('%[0-9]%',@RailcarNumber)+1)
			END
			ELSE
			BEGIN
				SELECT @EquipmentInitial = @RailcarNumber
				SELECT @EquipmentNumber = ''
			END
		END
		ELSE
		BEGIN
			SELECT @EquipmentInitial = ''
			SELECT @EquipmentNumber = ''
		END
		
		INSERT INTO ExportTokioMarine928(
			BatchID,
			CustomerID,
			VehicleID,
			InspectionID,
			VehicleDamageDetailID,
			InterchangeSenderID,
			InterchangeReceiverID,
			FunctionalID,
			SenderCode,
			ReceiverCode,
			TransmissionDateTime,
			InterchangeControlNumber,
			ResponsibleAgencyCode,
			VersionNumber,
			TransactionSetControlNumber,
			TransactionPurpose,
			InspectionAgency,
			InspectionDate,
			InspectionLocationType,
			IDCodeQualifier,
			IDCode,
			EquipmentInitial,
			EquipmentNumber,
			WaybillDate,
			ManufacturerCode,
			DamageExceptionInd,
			DamageAreaCode,
			DamageTypeCode,
			DamageSeverityCode,
			ExportedInd,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@CustomerID,
			@VehicleID,
			@InspectionID,
			@VehicleDamageDetailID,
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
			@TransactionPurpose,
			@InspectionAgency,
			@InspectionDate,
			@InspectionLocationType,
			@IDCodeQualifier,
			@IDCode,
			@EquipmentInitial,
			@EquipmentNumber,
			@WaybillDate,
			@ManufacturerCode,
			@DamageExceptionInd,
			@DamageAreaCode,
			@DamageTypeCode,
			@DamageSeverityCode,
			@ExportedInd,
			@RecordStatus,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating 928 record'
			GOTO Error_Encountered
		END
			
		FETCH TokioMarine928Cursor INTO @VehicleID, @InspectionID,
			@VehicleDamageDetailID, @InspectionType, @InspectionDate,
			@PickupLocationType, @DropoffLocationType, @DamageExceptionInd,
			@DamageAreaCode, @DamageTypeCode, @DamageSeverityCode,
			@OriginCode, @DestinationCode, @RailcarNumber, @WaybillDate

	END --end of loop
	
	--print 'end of loop'
	Error_Encountered:
	
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE TokioMarine928Cursor
		DEALLOCATE TokioMarine928Cursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE TokioMarine928Cursor
		DEALLOCATE TokioMarine928Cursor
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
