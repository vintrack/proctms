USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateEDI928Data]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateEDI928Data] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--ExportEDI928 table variables
	@BatchID			int,
	@CustomerID			int,
	@VehicleID			int,
	@InspectionID			int,
	@VehicleDamageDetailID		int,
	@SenderCode			varchar(12),
	@ReceiverCode			varchar(12),
	@TransmissionDateTime		datetime,
	@InterchangeControlNumber	int,
	@FunctionalID			varchar(2),
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
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	@UpdatedDate			datetime,
	@UpdatedBy			varchar(20),
	--processing variables
	@PickupLocationType		varchar(20),
	@DropoffLocationType		varchar(20),
	@InspectionType			int,
	@VIN				varchar(20),
	@I95RecordCount			int,
	@InvoicePrefixCode		varchar(10),			
	@NextInvoiceNumber		int,
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateEDI928Data						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the EDI 928 export data for vehicles	*
	*	(for the specified EDI customer) that have been inspected.	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	02/24/2006 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the next batch id from the setting table
	--print 'getting batch id'
	Select @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextEDI928ExportBatchID'
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
	DECLARE EDI928Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.CustomerID, V.VehicleID, VI.VehicleInspectionID,
		VDD.VehicleDamageDetailID, VI.InspectionType, VI.InspectionDate,
		L1.LocationSubType, L2.LocationSubType,
		CASE WHEN VDD.DamageCode IS NULL THEN '00' ELSE LEFT(VDD.DamageCode, 2) END,
		CASE WHEN VDD.DamageCode IS NULL THEN '00' ELSE SUBSTRING(VDD.DamageCode,3,2) END,
		CASE WHEN VDD.DamageCode IS NULL THEN '0' ELSE RIGHT(VDD.DamageCode,1) END
		FROM VehicleInspection VI
		LEFT JOIN Vehicle V ON VI.VehicleID = V.VehicleID
		LEFT JOIN VehicleDamageDetail VDD ON VI.VehicleInspectionID = VDD.VehicleInspectionID
		LEFT JOIN Location L1 ON V.PickupLocationID = L1.LocationID
		LEFT JOIN Location L2 ON V.DropoffLocationID = L2.LocationID
		WHERE V.CustomerID IN ((SELECT CONVERT(int,Value1) FROM Code WHERE CodeType = 'ACESCustomerCode'))
		AND (VI.VehicleInspectionID NOT IN (SELECT EE928.InspectionID
					FROM ExportEDI928 EE928)
				OR VDD.VehicleDamageDetailID IN (SELECT VDD2.VehicleDamageDetailID
					FROM VehicleDamageDetail VDD2 WHERE VDD2.VehicleInspectionID = VI.VehicleInspectionID
					AND VDD2.VehicleDamageDetailID NOT IN (SELECT ISNULL(EE928.VehicleDamageDetailID,0)
			FROM ExportEDI928 EE928 WHERE EE928.InspectionID = VDD.VehicleInspectionID)))
		ORDER BY V.VehicleID, VI.VehicleInspectionID
	--print 'cursor declared'
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN EDI928Cursor
	--print 'cursor opened'
	BEGIN TRAN
	--print 'tran started'
	--set the next batch id in the setting table
	
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextEDI928ExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END
	
	--print 'batch id updated'
	--set the default values
	SELECT @SenderCode ='GDIV'
	SELECT @ReceiverCode ='GLOV'
	SELECT @TransmissionDateTime = NULL	--populated when exported
	SELECT @InterchangeControlNumber = NULL	--populated when exported
	SELECT @FunctionalID = 'GC'
	SELECT @TransactionSetControlNumber = NULL	--populated when exported
	SELECT @TransactionPurpose = '02'
	SELECT @InspectionAgency = 'GDIV'
	SELECT @IDCodeQualifier = '20'
	SELECT @IDCode = 'GDIV'
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	--print 'default values set'
	
	FETCH EDI928Cursor INTO @CustomerID, @VehicleID, @InspectionID,
		@VehicleDamageDetailID, @InspectionType, @InspectionDate,
		@PickupLocationType, @DropoffLocationType,
		@DamageAreaCode, @DamageTypeCode, @DamageSeverityCode
	
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @CustomerID = (SELECT CONVERT(int,Value1) FROM Code WHERE CodeType = 'ACESCustomerCode' AND Code = 'HMA')
		BEGIN
			SELECT @ManufacturerCode = '01'
		END
		ELSE
		BEGIN
			SELECT @ManufacturerCode = '02'
		END


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
				SELECT @InspectionLocationType = '04'
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
		
		INSERT INTO ExportEDI928(
			BatchID,
			CustomerID,
			VehicleID,
			InspectionID,
			VehicleDamageDetailID,
			SenderCode,
			ReceiverCode,
			TransmissionDateTime,
			InterchangeControlNumber,
			FunctionalID,
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
			@SenderCode,
			@ReceiverCode,
			@TransmissionDateTime,
			@InterchangeControlNumber,
			@FunctionalID,
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
			
		FETCH EDI928Cursor INTO @CustomerID, @VehicleID, @InspectionID,
			@VehicleDamageDetailID, @InspectionType, @InspectionDate,
			@PickupLocationType, @DropoffLocationType,
			@DamageAreaCode, @DamageTypeCode, @DamageSeverityCode

	END --end of loop
	
	--print 'end of loop'
	Error_Encountered:
	
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE EDI928Cursor
		DEALLOCATE EDI928Cursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE EDI928Cursor
		DEALLOCATE EDI928Cursor
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
