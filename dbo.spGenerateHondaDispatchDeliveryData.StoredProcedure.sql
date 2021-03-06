USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateHondaDispatchDeliveryData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateHondaDispatchDeliveryData] (@CutoffDate datetime, @CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--ExportHondaDispatchDelivery table variables
	@BatchID			int,
	@CustomerID			int,
	@VehicleID			int,
	@TransactionCode		varchar(2),
	@CarrierNumber			varchar(3),
	@RecordType			varchar(1),
	@OriginCode			varchar(3),
	@SPLCCode			varchar(9),
	@RailReleaseDate		datetime,
	@DispatchDate			datetime,
	@EstimatedArrivalDate		datetime,
	@ArrivalDate			datetime,
	@InvoiceDate			datetime,
	@FreightCost			decimal(19,2),
	@CarrierInvoiceNumber		varchar(10),
	@ShipTypeCode			varchar(1),
	@WaybillNumber			varchar(10),
	@ShipToDealerNumber		varchar(6),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(20),
	@CreationDate			datetime,
	--processing variables
	@HondaInvoicePrefix		varchar(10),			
	@NextInvoiceNumber		int,
	@ChargeRateOverrideInd		int,
	@ValidatedRate			decimal(19,2),
	@OutsideCarrierPaymentMethod	int,
	@CursorHasRowsInd		int,
	@LocationSubType		varchar(20),
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@ReturnBatchID			int

	/************************************************************************
	*	spGenerateHondaDispatchDeliveryData				*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the Honda export data for vehicles	*
	*	that have been picked up or delivered.				*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	01/22/2010 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the customerid for Honda
	Select @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'HondaCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting CustomerID'
		GOTO Error_Encountered2
	END
	IF @CustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100000
		SELECT @Status = 'CustomerID Not Found'
		GOTO Error_Encountered2
	END

	--get the honda carrier number from the setting table
	Select @CarrierNumber = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'HondaCarrierNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting BatchID'
		GOTO Error_Encountered2
	END
	IF @CarrierNumber IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Carrier Number Not Found'
		GOTO Error_Encountered2
	END

	--get the next batch id from the setting table
	Select @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextHondaDispatchDeliveryBatchID'
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

	--cursor for the pickup records
	DECLARE HondaDispatchDeliveryCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, C.Code, C.Value2, V.AvailableForPickupDate, L.PickupDate
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.LegNumber = 1
		LEFT JOIN Code C ON V.PickupLocationID = C.Value1
		AND C.CodeType = 'HondaLocationCode'
		WHERE V.CustomerID = @CustomerID
		AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
		AND V.VehicleStatus IN ('EnRoute','Delivered')
		AND V.VehicleID NOT IN (SELECT HEDD.VehicleID FROM HondaExportDispatchDelivery HEDD WHERE HEDD.TransactionCode = 'T1' AND HEDD.VehicleID = V.VehicleID)
		ORDER BY C.Code

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN HondaDispatchDeliveryCursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextHondaDispatchDeliveryBatchID'
	IF @@ERROR <> 0
	BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Setting BatchID'
			GOTO Error_Encountered
	END

	--set the default values
	SELECT @RecordType = '2'
	SELECT @TransactionCode = 'T1'
	SELECT @ArrivalDate = NULL
	SELECT @InvoiceDate = NULL
	SELECT @FreightCost = NULL
	SELECT @CarrierInvoiceNumber = NULL
	SELECT @ShipTypeCode = 'T'
	SELECT @WaybillNumber = NULL
	SELECT @ShipToDealerNumber = NULL
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	FETCH HondaDispatchDeliveryCursor INTO @VehicleID, @OriginCode, @SPLCCode, @RailReleaseDate, @DispatchDate
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @EstimatedArrivalDate = DATEADD(day,1,@DispatchDate) --DO WE NEED BETTER LOGIC THAN THIS???
		
		INSERT INTO HondaExportDispatchDelivery(
			BatchID,
			CustomerID,
			VehicleID,
			TransactionCode,
			CarrierNumber,
			RecordType,
			OriginCode,
			SPLCCode,
			RailReleaseDate,
			DispatchDate,
			EstimatedArrivalDate,
			ArrivalDate,
			InvoiceDate,
			FreightCost,
			CarrierInvoiceNumber,
			ShipTypeCode,
			WaybillNumber,
			ShipToDealerNumber,
			ExportedInd,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@CustomerID,
			@VehicleID,
			@TransactionCode,
			@CarrierNumber,
			@RecordType,
			@OriginCode,
			@SPLCCode,
			@RailReleaseDate,
			@DispatchDate,
			@EstimatedArrivalDate,
			@ArrivalDate,
			@InvoiceDate,
			@FreightCost,
			@CarrierInvoiceNumber,
			@ShipTypeCode,
			@WaybillNumber,
			@ShipToDealerNumber,
			@ExportedInd,
			@RecordStatus,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating Honda Dispatch Delivery record'
			GOTO Error_Encountered
		END
			
		FETCH HondaDispatchDeliveryCursor INTO @VehicleID, @OriginCode, @SPLCCode, @RailReleaseDate, @DispatchDate

	END --end of loop
	
	CLOSE HondaDispatchDeliveryCursor
	DEALLOCATE HondaDispatchDeliveryCursor
		
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	--get the next invoice number from the setting table
	Select @NextInvoiceNumber = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextHondaInvoiceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Invoice Number'
		GOTO Error_Encountered2
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Next Invoice Number Not Found'
		GOTO Error_Encountered2
	END
		
	--get the invoice prefix
	SELECT @HondaInvoicePrefix = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'HondaInvoicePrefix'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Invoice Prefix'
		GOTO Error_Encountered2
	END
	IF @HondaInvoicePrefix IS NULL OR DATALENGTH(@HondaInvoicePrefix)<1
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Invoice Prefix Not Found'
		GOTO Error_Encountered2
	END
	
	IF @CutoffDate IS NULL
	BEGIN
		SELECT @CutoffDate = CONVERT(varchar(10),CURRENT_TIMESTAMP,101)
	END
	--cursor for the delivery records
	DECLARE HondaDispatchDeliveryCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, C.Code, L2.SPLCCode, V.AvailableForPickupDate, L.PickupDate,
		L3.DropoffDate, V.ChargeRate, V.ChargeRateOverrideInd,
		L4.LoadNumber, L2.CustomerLocationCode, L.OutsideCarrierPaymentMethod
		FROM Vehicle V
		LEFT JOIN Code C ON V.PickupLocationID = C.Value1
		AND C.CodeType = 'HondaLocationCode'
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.LegNumber = 1
		LEFT JOIN Location L2 ON V.DropoffLocationID = L2.LocationID
		LEFT JOIN Legs L3 ON V.VehicleID = L3.VehicleID
		AND L3.FinalLegInd = 1
		LEFT JOIN Loads L4 ON L3.LoadID = L4.LoadsID
		LEFT JOIN Driver D ON L4.DriverID = D.DriverID
		LEFT JOIN OutsideCarrier OC ON L4.OutsideCarrierID = OC.OutsideCarrierID
		LEFT JOIN OutsideCarrier OC2 ON D.OutsideCarrierID = OC2.OutsideCarrierID
		WHERE V.CustomerID = @CustomerID
		AND V.VehicleStatus = 'Delivered'
		AND (V.ChargeRate > 0 OR (V.ChargeRate = 0 AND V.ChargeRateOverrideInd = 1))
		AND L.PickupDate < DATEADD(day,1,@CutoffDate)
		AND L3.DropoffDate > L.PickupDate
		AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
		AND (D.OutsideCarrierInd = 0
		OR (D.OutsideCarrierInd = 1 AND (L.OutsideCarrierPay > 0 OR OC2.StandardCommissionRate > 0))
		OR (L.OutsideCarrierID > 0 AND (L.OutsideCarrierPay > 0 OR OC.StandardCommissionRate > 0)))
		AND V.VehicleID NOT IN (SELECT HEDD.VehicleID FROM HondaExportDispatchDelivery HEDD WHERE HEDD.TransactionCode = 'T2' AND HEDD.VehicleID = V.VehicleID)
		ORDER BY C.Code, L2.CustomerLocationCode
		
	OPEN HondaDispatchDeliveryCursor

	SELECT @CarrierInvoiceNumber = @HondaInvoicePrefix+REPLICATE(0,4-DATALENGTH(CONVERT(VARCHAR(20),@NextInvoiceNumber)))+CONVERT(varchar(20),@NextInvoiceNumber)
	IF @CutoffDate IS NOT NULL
	BEGIN
		SELECT @InvoiceDate = @CutoffDate
	END
	ELSE
	BEGIN
		SELECT @InvoiceDate = CURRENT_TIMESTAMP
	END
	
	SELECT @TransactionCode = 'T2'
	SELECT @ShipTypeCode = 'T'
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	FETCH HondaDispatchDeliveryCursor INTO @VehicleID, @OriginCode, @SPLCCode, @RailReleaseDate, @DispatchDate,
		@ArrivalDate, @FreightCost, @ChargeRateOverrideInd, @WaybillNumber, @ShipToDealerNumber,
		@OutsideCarrierPaymentMethod
	
	SELECT @CursorHasRowsInd = 0
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @CursorHasRowsInd = 1
		
		SELECT @EstimatedArrivalDate = DATEADD(day,1,@DispatchDate) --DO WE NEED BETTER LOGIC THAN THIS???
		
		IF @ChargeRateOverrideInd = 0
		BEGIN
			SELECT TOP 1 @ValidatedRate = ISNULL(CR.Rate,-1)
			FROM Vehicle V
			LEFT JOIN Customer C ON V.CustomerID = C.CustomerID
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			AND L.FinalLegInd = 1
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
			
			IF @ValidatedRate <> @FreightCost
			BEGIN
				SELECT @FreightCost = @ValidatedRate
				
				UPDATE Vehicle
				SET ChargeRate = @FreightCost,
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
					WHERE VehicleID = @VehicleID
					IF @@Error <> 0
					BEGIN
						SELECT @ErrorID = @@ERROR
						SELECT @Status = 'Error updating leg records'
						GOTO Error_Encountered
					END
				END
			END
		END
		
		INSERT INTO HondaExportDispatchDelivery(
			BatchID,
			CustomerID,
			VehicleID,
			TransactionCode,
			CarrierNumber,
			RecordType,
			OriginCode,
			SPLCCode,
			RailReleaseDate,
			DispatchDate,
			EstimatedArrivalDate,
			ArrivalDate,
			InvoiceDate,
			FreightCost,
			CarrierInvoiceNumber,
			ShipTypeCode,
			WaybillNumber,
			ShipToDealerNumber,
			ExportedInd,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@CustomerID,
			@VehicleID,
			@TransactionCode,
			@CarrierNumber,
			@RecordType,
			@OriginCode,
			@SPLCCode,
			@RailReleaseDate,
			@DispatchDate,
			@EstimatedArrivalDate,
			@ArrivalDate,
			@InvoiceDate,
			@FreightCost,
			@CarrierInvoiceNumber,
			@ShipTypeCode,
			@WaybillNumber,
			@ShipToDealerNumber,
			@ExportedInd,
			@RecordStatus,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating Honda Dispatch Delivery record'
			GOTO Error_Encountered
		END
			
		End_Of_Loop:
		FETCH HondaDispatchDeliveryCursor INTO @VehicleID, @OriginCode, @SPLCCode, @RailReleaseDate, @DispatchDate,
			@ArrivalDate, @FreightCost, @ChargeRateOverrideInd, @WaybillNumber, @ShipToDealerNumber,
			@OutsideCarrierPaymentMethod

	END --end of loop

	--set the next invoicenumber
	IF @CursorHasRowsInd = 1
	BEGIN
		--set the next invoice number in the setting table
		UPDATE SettingTable
		SET ValueDescription = @NextInvoiceNumber+1	
		WHERE ValueKey = 'NextHondaInvoiceNumber'
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Setting InvoiceNumber'
			GOTO Error_Encountered
		END
	END
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE HondaDispatchDeliveryCursor
		DEALLOCATE HondaDispatchDeliveryCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		SELECT @ReturnBatchID = @BatchID
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE HondaDispatchDeliveryCursor
		DEALLOCATE HondaDispatchDeliveryCursor
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
