USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateVW928Data]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateVW928Data] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--ExportVW928 table variables
	@BatchID			int,
	@CustomerID			int,
	@VehicleID			int,
	@InspectionID			int,
	@VehicleDamageDetailID		int,
	@InterchangeSenderID		varchar(15),
	@InterchangeReceiverID		varchar(15),
	@FunctionalID			varchar(2),
	@SenderCode			varchar(15),
	@ReceiverCode			varchar(15),
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
	@ManufacturerCode		varchar(2),
	@DamageAreaCode			varchar(2),
	@DamageTypeCode			varchar(2),
	@DamageSeverityCode		varchar(1),
	@ExportedInd			int,
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	--processing variables
	@OriginCode			varchar(20),
	@DestinationCode		varchar(20),
	@PickupLocationType		varchar(20),
	@DropoffLocationType		varchar(20),
	@InspectionType			int,
	@Status				varchar(100),
	@ICLCustomerCode		varchar(10),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateVW928Data						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the VW 928 export data for vehicles	*
	*	that have been inspected.					*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	12/05/2012 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the VolkswagenCustomerID
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'VolkswagenCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting CustomerID'
		GOTO Error_Encountered2
	END
	
	--get the ICL Customer Code
	SELECT TOP 1 @ICLCustomerCode = C.Code
	FROM Code C
	WHERE C.CodeType = 'ICLCustomerCode'
	AND C.CodeDescription = 'Volkswagen'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting ICL Customer Code'
		GOTO Error_Encountered2
	END
	
	--get the next batch id from the setting table
	--print 'getting batch id'
	Select @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextVW928ExportBatchID'
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
	--print 'have batch id'
	--cursor for the pickup records
	DECLARE VW928Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, VI.VehicleInspectionID,
		VDD.VehicleDamageDetailID, VI.InspectionType, VI.InspectionDate,
		L1.LocationSubType, L2.LocationSubType,
		CASE WHEN VDD.DamageCode IS NULL THEN '00' ELSE LEFT(VDD.DamageCode, 2) END,
		CASE WHEN VDD.DamageCode IS NULL THEN '00' ELSE SUBSTRING(VDD.DamageCode,3,2) END,
		CASE WHEN VDD.DamageCode IS NULL THEN '0' ELSE RIGHT(VDD.DamageCode,1) END,
		CASE WHEN L1.ParentRecordTable = 'Common' THEN (SELECT Code FROM Code WHERE CodeType = 'VWEDILocationCode'
		AND Value1 = CONVERT(varchar(10),L1.LocationID)) ELSE L1.CustomerLocationCode END,
		CASE WHEN L2.ParentRecordTable = 'Common' THEN (SELECT Value2 FROM Code WHERE CodeType = 'VWEDILocationCode'
		AND Value1 = CONVERT(varchar(10),L2.LocationID)) ELSE L2.CustomerLocationCode END
		FROM VehicleInspection VI
		LEFT JOIN Vehicle V ON VI.VehicleID = V.VehicleID
		LEFT JOIN VehicleDamageDetail VDD ON VI.VehicleInspectionID = VDD.VehicleInspectionID
		AND PATINDEX('%[0-9][0-9][0-9][0-9][0-9]%', VDD.DamageCode) > 0
		LEFT JOIN Location L1 ON V.PickupLocationID = L1.LocationID
		LEFT JOIN Location L2 ON V.DropoffLocationID = L2.LocationID
		WHERE V.CustomerID = @CustomerID
		AND (VI.VehicleInspectionID NOT IN (SELECT EV928.InspectionID
			FROM ExportVW928 EV928)
		OR VDD.VehicleDamageDetailID IN (SELECT VDD2.VehicleDamageDetailID
			FROM VehicleDamageDetail VDD2 WHERE VDD2.VehicleInspectionID = VI.VehicleInspectionID
			AND VDD2.VehicleDamageDetailID NOT IN (SELECT ISNULL(EV928.VehicleDamageDetailID,0)
			FROM ExportVW928 EV928 WHERE EV928.InspectionID = VDD.VehicleInspectionID)))
		AND VI.InspectionDate >= '05/01/2013'	--just want to ignore any pre-existing data
		AND CASE WHEN VI.DamageCodeCount = 0 THEN (
			SELECT COUNT(*)
			FROM VehicleInspection VI2
			WHERE VI2.VehicleID = V.VehicleID
			AND VI2.InspectionType = VI.InspectionType
			AND CONVERT(varchar(10),VI2.InspectionDate,101) = CONVERT(varchar(10),VI.InspectionDate,101)
			AND VI2.DamageCodeCount > 0
			)
			ELSE 0 END = 0
		ORDER BY V.VehicleID, VI.VehicleInspectionID
	--print 'cursor declared'
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN VW928Cursor
	--print 'cursor opened'
	BEGIN TRAN
	--print 'tran started'
	--set the next batch id in the setting table
	
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextVW928ExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END
	
	--print 'batch id updated'
	--set the default values
	SELECT @InterchangeSenderID = 'DVAI'
	SELECT @InterchangeReceiverID = 'FNKL'
	SELECT @FunctionalID = 'AI'
	SELECT @SenderCode ='DVAI'
	SELECT @ReceiverCode ='FNKL'
	SELECT @TransmissionDateTime = NULL	--populated when exported
	SELECT @InterchangeControlNumber = NULL	--populated when exported
	SELECT @ResponsibleAgencyCode = 'X'
	SELECT @VersionNumber = '003020'
	SELECT @TransactionSetControlNumber = NULL	--populated when exported
	SELECT @TransactionPurpose = '02'
	SELECT @InspectionAgency = 'DVAI'
	SELECT @ManufacturerCode = '03'
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	--print 'default values set'
	
	FETCH VW928Cursor INTO @VehicleID, @InspectionID,
		@VehicleDamageDetailID, @InspectionType, @InspectionDate,
		@PickupLocationType, @DropoffLocationType,
		@DamageAreaCode, @DamageTypeCode, @DamageSeverityCode,
		@OriginCode, @DestinationCode
	
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @InspectionType IN (0,1,5)
		BEGIN
			SELECT @InspectionLocationType = '02'
		END
		ELSE IF @InspectionType = 2
		BEGIN
			IF @PickupLocationType IN ('Port','Railyard')
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
		
		INSERT INTO ExportVW928(
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
			ManufacturerCode,
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
			@ManufacturerCode,
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
			
		FETCH VW928Cursor INTO @VehicleID, @InspectionID,
			@VehicleDamageDetailID, @InspectionType, @InspectionDate,
			@PickupLocationType, @DropoffLocationType,
			@DamageAreaCode, @DamageTypeCode, @DamageSeverityCode,
			@OriginCode, @DestinationCode

	END --end of loop
	
	--print 'end of loop'
	Error_Encountered:
	
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE VW928Cursor
		DEALLOCATE VW928Cursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE VW928Cursor
		DEALLOCATE VW928Cursor
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
