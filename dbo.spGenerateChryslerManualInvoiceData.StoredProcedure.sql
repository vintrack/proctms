USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateChryslerManualInvoiceData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateChryslerManualInvoiceData] (@LocationID int, @CreatedBy varchar(20), @CutoffDate datetime)
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--ChryslerInvoiceExport table variables
	@BatchID			int,
	@VehicleID			int,
	@OriginName			varchar(100),
	@OriginSPLC			varchar(10),
	@DestinationSPLC		varchar(10),
	@DestinationDealerCode		varchar(20),
	@DestinationDealer		varchar(100),
	@DestinationDealerCityState	varchar(50),
	@LoadNumber			varchar(20),
	@VIN				varchar(17),
	@Plant				varchar(1),
	@DropoffDate			datetime,
	@ChargeRate			decimal(19,2),
	@InvoiceNumber			varchar(20),
	@InvoiceDate			datetime,
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	--processing variables
	@LegsID			int,
	@ChargeRateOverrideInd		int,
	@ValidatedRate			decimal(19,2),
	@OutsideCarrierPaymentMethod	int,
	@NextChryslerInvoiceNumber	int,
	@ChryslerInvoicePrefix		varchar(10),
	@CustomerID			int,
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateChryslerManualInvoiceData				*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the invoice export data for Chryslers	*
	*	that have been delivered.					*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/07/2007 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the customer id from the setting table
	Select @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ChryslerCustomerID'
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
	Select @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextChryslerInvoiceExportBatchID'
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
	
	--get the invoice prefix from the setting table
	Select @ChryslerInvoicePrefix = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'ChryslerInvoicePrefix'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Invoice Prefix'
		GOTO Error_Encountered2
	END
	IF @ChryslerInvoicePrefix IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Invoice Prefix Not Found'
		GOTO Error_Encountered2
	END

	--get the next invoice number from the setting table
	Select @NextChryslerInvoiceNumber = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextChryslerInvoiceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Invoice Number'
		GOTO Error_Encountered2
	END
	IF @NextChryslerInvoiceNumber IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Invoice Number Not Found'
		GOTO Error_Encountered2
	END
	
	IF @CutoffDate IS NULL
	BEGIN
		SELECT @CutoffDate = CONVERT(varchar(10),CURRENT_TIMESTAMP,101)
	END
	
	DECLARE ChryslerInvoiceExportCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, L.LegsID, L3.LocationName,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT Value2 FROM Code WHERE CodeType = 'ChryslerRailheadCode'
		AND Value1 = CONVERT(varchar(10),L3.LocationID)) ELSE L3.SPLCCode END,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT Value2 FROM Code WHERE CodeType = 'ChryslerRailheadCode'
		AND Value1 = CONVERT(varchar(10),L4.LocationID)) ELSE L4.SPLCCode END,
		L4.CustomerLocationCode,L4.LocationName, L4.City+' '+L4.State, L2.LoadNumber,V.VIN, SUBSTRING(VIN,11,1),
		L.DropoffDate, V.ChargeRate, V.ChargeRateOverrideInd, L.OutsideCarrierPaymentMethod
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
		LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
		LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
		LEFT JOIN Driver D ON L2.DriverID = D.DriverID
		LEFT JOIN OutsideCarrier OC ON L2.OutsideCarrierID = OC.OutsideCarrierID
		LEFT JOIN OutsideCarrier OC2 ON D.OutsideCarrierID = OC2.OutsideCarrierID
		WHERE V.BilledInd = 0
		AND V.PickupLocationID = @LocationID
		AND V.CustomerID = @CustomerID
		AND V.VehicleStatus = 'Delivered'
		AND L.FinalLegInd = 1
		AND V.VIN NOT IN (SELECT IV.VIN FROM ImportVISTA660 IV WHERE IV.VIN = V.VIN) -- only manually bill if we don't have an ASN
		AND L.PickupDate < DATEADD(day,1,@CutoffDate)
		AND L.DropoffDate > L.PickupDate
		AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
		--AND V.CustomerIdentification IS NOT NULL
		--AND V.CustomerIdentification <> ''
		AND (V.ChargeRate > 0 OR (V.ChargeRate = 0 AND V.ChargeRateOverrideInd = 1))
		AND V.VehicleID NOT IN (SELECT CMIE.VehicleID FROM ChryslerManualInvoiceExport CMIE)
		AND (D.OutsideCarrierInd = 0
		OR (D.OutsideCarrierInd = 1 AND (L.OutsideCarrierPay > 0 OR OC2.StandardCommissionRate > 0))
		OR (L.OutsideCarrierID > 0 AND (L.OutsideCarrierPay > 0 OR OC.StandardCommissionRate > 0)))
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN ChryslerInvoiceExportCursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextChryslerInvoiceExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END
	
	--set the next nissan invoice number in the setting table
	UPDATE SettingTable
	SET ValueDescription = @NextChryslerInvoiceNumber+1	
	WHERE ValueKey = 'NextChryslerInvoiceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting Next Invoice Number'
		GOTO Error_Encountered
	END

	--set the default values
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @InvoiceNumber = @ChryslerInvoicePrefix+REPLICATE(0,5-DATALENGTH(CONVERT(VARCHAR(20),@NextChryslerInvoiceNumber)))+CONVERT(varchar(20),@NextChryslerInvoiceNumber)
	SELECT @InvoiceDate = CURRENT_TIMESTAMP
	
	FETCH ChryslerInvoiceExportCursor INTO @VehicleID,@LegsID,@OriginName,@OriginSPLC,@DestinationSPLC,
		@DestinationDealerCode,@DestinationDealer,@DestinationDealerCityState,@LoadNumber,
		@VIN,@Plant,@DropoffDate,@ChargeRate,@ChargeRateOverrideInd,@OutsideCarrierPaymentMethod
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--validate the rate
		IF @ChargeRateOverrideInd = 0
		BEGIN
			SELECT TOP 1 @ValidatedRate = ISNULL(CR.Rate,-1)
			FROM Vehicle V
			LEFT JOIN Customer C ON V.CustomerID = C.CustomerID
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			AND L.LegNumber = 1
			LEFT JOIN ChargeRate CR ON CR.CustomerID = V.CustomerID
			AND CR.StartLocationID = V.PickupLocationID
			AND CR.EndLocationID = V.DropoffLocationID
			AND CR.RateType = CASE WHEN V.SizeClass = 'N/A' THEN 'Size A Rate' WHEN V.SizeClass IS NULL THEN 'Size A Rate' ELSE 'Size '+V.SizeClass+' Rate' END
			AND ISNULL(L.PickupDate,CURRENT_TIMESTAMP) >= CR.StartDate
			AND ISNULL(L.PickupDate,CURRENT_TIMESTAMP) < DATEADD(day,1,ISNULL(CR.EndDate,CURRENT_TIMESTAMP))
			WHERE V.VehicleID = @VehicleID
			ORDER BY CR.StartDate DESC
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Validating Rate'
				GOTO Error_Encountered
			END
			
			IF @ValidatedRate IS NULL OR @ValidatedRate = -1
			BEGIN
				GOTO End_Of_Loop
			END
			
			IF @ValidatedRate <> @ChargeRate
			BEGIN
				SELECT @ChargeRate = @ValidatedRate
				
				UPDATE Vehicle
				SET ChargeRate = @ChargeRate,
				UpdatedDate = CURRENT_TIMESTAMP,
				UpdatedBy = @CreatedBy
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Updating Rate'
					GOTO Error_Encountered
				END
				
				--if this is an outside carrier leg, update the outside carrier pay
				IF @OutsideCarrierPaymentMethod = 1
				BEGIN
					-- by zeroing out the carrier pay the invoicing method will automatically recalculate it
					UPDATE Legs
					SET OutsideCarrierPay = 0,
					UpdatedDate = CURRENT_TIMESTAMP,
					UpdatedBy = @CreatedBy
					WHERE LegsID = @LegsID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'Error updating leg records'
						GOTO Error_Encountered
					END
				END
			END
		END
		
		INSERT INTO ChryslerManualInvoiceExport(
			BatchID,
			VehicleID,
			OriginName,
			OriginSPLC,
			DestinationSPLC,
			DestinationDealerCode,
			DestinationDealer,
			DestinationDealerCityState,
			LoadNumber,
			VIN,
			Plant,
			DropoffDate,
			ChargeRate,
			InvoiceNumber,
			InvoiceDate,
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
			@OriginName,
			@OriginSPLC,
			@DestinationSPLC,
			@DestinationDealerCode,
			@DestinationDealer,
			@DestinationDealerCityState,
			@LoadNumber,
			@VIN,
			@Plant,
			@DropoffDate,
			@ChargeRate,
			@InvoiceNumber,
			@InvoiceDate,
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
			SELECT @Status = 'Error creating Chrysler record'
			GOTO Error_Encountered
		END
			
		End_Of_Loop:
		FETCH ChryslerInvoiceExportCursor INTO @VehicleID,@LegsID,@OriginName,@OriginSPLC,@DestinationSPLC,
			@DestinationDealerCode,@DestinationDealer,@DestinationDealerCityState,@LoadNumber,
			@VIN,@Plant,@DropoffDate,@ChargeRate,@ChargeRateOverrideInd,@OutsideCarrierPaymentMethod

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ChryslerInvoiceExportCursor
		DEALLOCATE ChryslerInvoiceExportCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ChryslerInvoiceExportCursor
		DEALLOCATE ChryslerInvoiceExportCursor
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
