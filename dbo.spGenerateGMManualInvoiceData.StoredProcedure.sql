USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateGMManualInvoiceData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateGMManualInvoiceData] (@CreatedBy varchar(20), @CutoffDate datetime)
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--GMManualInvoiceExport table variables
	@BatchID			int,
	@VehicleID			int,
	@InvoiceNumber			varchar(10),
	@InvoiceDate			datetime,
	@OriginName			varchar(100),
	@PickupDate			datetime,
	@DestinationName		varchar(100),
	@DestinationCity		varchar(30),
	@DestinationState		varchar(2),
	@DestinationZip			varchar(14),
	@DestinationDealerCode		varchar(20),
	@DropoffDate			datetime,
	@ChargeRate			decimal(19,2),
	@MiscellaneousAdditive		decimal(19,2),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	--processing variables
	@PONumber			varchar(20),
	@OrdersID			int,
	@LastPONumber			varchar(20),
	@Count				int,
	@LegsID				int,
	@ChargeRateOverrideInd		int,
	@ValidatedRate			decimal(19,2),
	@ValidatedMiscAdditive		decimal(19,2),
	@OutsideCarrierPaymentMethod	int,
	@SizeClass			varchar(1),
	@NextGMInvoiceNumber		int,
	@GMInvoicePrefix		varchar(10),
	@CustomerID			int,
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateGMManualInvoiceData					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the invoice export data for GMs	*
	*	that have been delivered.					*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	07/10/2013 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the customer id from the setting table
	Select @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'GMCustomerID'
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
	WHERE ValueKey = 'NextGMManualInvoiceBatchID'
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
	Select @GMInvoicePrefix = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'GMInvoicePrefix'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Invoice Prefix'
		GOTO Error_Encountered2
	END
	IF @GMInvoicePrefix IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Invoice Prefix Not Found'
		GOTO Error_Encountered2
	END

	--get the next invoice number from the setting table
	Select @NextGMInvoiceNumber = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextGMInvoiceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Invoice Number'
		GOTO Error_Encountered2
	END
	IF @NextGMInvoiceNumber IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Invoice Number Not Found'
		GOTO Error_Encountered2
	END
	
	IF @CutoffDate IS NULL
	BEGIN
		SELECT @CutoffDate = CONVERT(varchar(10),CURRENT_TIMESTAMP,101)
	END
	
	DECLARE GMManualInvoiceCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, L.LegsID, L3.LocationName, L.PickupDate, 
		L4.LocationName, L4.City, L4.State, L4.Zip, L4.CustomerLocationCode, L1.DropoffDate,
		V.SizeClass, V.ChargeRate, V.MiscellaneousAdditive, V.ChargeRateOverrideInd, L.OutsideCarrierPaymentMethod,
		ISNULL(O.PONumber,''), O.OrdersID
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.LegNumber = 1
		LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
		AND L1.FinalLegInd = 1
		LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
		LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
		LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
		LEFT JOIN Driver D ON L2.DriverID = D.DriverID
		LEFT JOIN OutsideCarrier OC ON L2.OutsideCarrierID = OC.OutsideCarrierID
		LEFT JOIN OutsideCarrier OC2 ON D.OutsideCarrierID = OC2.OutsideCarrierID
		LEFT JOIN Orders O ON V.OrderID = O.OrdersID
		WHERE V.BilledInd = 0
		AND V.CustomerID = @CustomerID
		--AND ISNULL(V.CustomerIdentification,'') = ''
		AND V.VehicleStatus = 'Delivered'
		AND L.PickupDate < DATEADD(day,1,@CutoffDate)
		AND L.DropoffDate > L.PickupDate
		AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
		AND (V.ChargeRate > 0 OR (V.ChargeRate = 0 AND V.ChargeRateOverrideInd = 1))
		AND V.VehicleID NOT IN (SELECT VehicleID FROM GMManualInvoiceExport)
		AND (D.OutsideCarrierInd = 0
		OR (D.OutsideCarrierInd = 1 AND (L.OutsideCarrierPay > 0 OR OC2.StandardCommissionRate > 0))
		OR (L.OutsideCarrierID > 0 AND (L.OutsideCarrierPay > 0 OR OC.StandardCommissionRate > 0)))
		--AND DATALENGTH(O.PONumber) > 0				--TEMPORARY MEASURE
		ORDER BY ISNULL(O.PONumber,''), V.VehicleID
		
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN GMManualInvoiceCursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextGMManualInvoiceBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END
	
	--set the default values
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @InvoiceNumber = @GMInvoicePrefix+REPLICATE(0,4-DATALENGTH(CONVERT(VARCHAR(20),@NextGMInvoiceNumber)))+CONVERT(varchar(20),@NextGMInvoiceNumber)
	SELECT @InvoiceDate = @CutoffDate
	
	FETCH GMManualInvoiceCursor INTO @VehicleID,@LegsID,@OriginName, @PickupDate, @DestinationName,
		@DestinationCity, @DestinationState, @DestinationZip, @DestinationDealerCode,
		@DropoffDate, @SizeClass,@ChargeRate, @MiscellaneousAdditive,
		@ChargeRateOverrideInd,@OutsideCarrierPaymentMethod, @PONumber, @OrdersID
		
	SELECT @LastPONumber = @PONumber
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--validate the rate
		IF @ChargeRateOverrideInd = 0
		BEGIN
			SELECT TOP 1 @ValidatedRate = ISNULL(CR.Rate,-1),
			@ValidatedMiscAdditive = CR.MiscellaneousAdditive
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
			
			IF @ValidatedRate <> @ChargeRate OR @ValidatedMiscAdditive <> @MiscellaneousAdditive
			BEGIN
				SELECT @ChargeRate = @ValidatedRate
				SELECT @MiscellaneousAdditive = @ValidatedMiscAdditive
				
				UPDATE Vehicle
				SET ChargeRate = @ChargeRate,
				MiscellaneousAdditive = @MiscellaneousAdditive,
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
		
		--make sure all of the vehicles on a PONumber are complete
		IF DATALENGTH(@PONumber) > 0
		BEGIN
			SELECT @Count = COUNT(*)
			FROM Vehicle
			WHERE OrderID = @OrdersID
			AND VehicleStatus <> 'Delivered'
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error getting non delivered count'
				GOTO Error_Encountered
			END
			IF @Count > 0
			BEGIN
				GOTO End_Of_Loop
			END
		END
				
		--each PONumber should have its own invoice, if no PONumber all units can be billed together
		IF @PONumber <> @LastPONumber
		BEGIN
			SELECT @NextGMInvoiceNumber = @NextGMInvoiceNumber+1
			SELECT @InvoiceNumber = @GMInvoicePrefix+REPLICATE(0,4-DATALENGTH(CONVERT(VARCHAR(20),@NextGMInvoiceNumber)))+CONVERT(varchar(20),@NextGMInvoiceNumber)
		END
		
		INSERT INTO GMManualInvoiceExport(
			BatchID,
			VehicleID,
			InvoiceNumber,
			InvoiceDate,
			OriginName,
			PickupDate,
			DestinationName,
			DestinationCity,
			DestinationState,
			DestinationZip,
			DestinationDealerCode,
			DropoffDate,
			ChargeRate,
			ExportedInd,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@InvoiceNumber,
			@InvoiceDate,
			@OriginName,
			@PickupDate,
			@DestinationName,
			@DestinationCity,
			@DestinationState,
			@DestinationZip,
			@DestinationDealerCode,
			@DropoffDate,
			@ChargeRate+@MiscellaneousAdditive,
			@ExportedInd,
			@RecordStatus,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating GM Invoice record'
			GOTO Error_Encountered
		END
			
		End_Of_Loop:
		SELECT @LastPONumber = @PONumber
		
		FETCH GMManualInvoiceCursor INTO @VehicleID,@LegsID,@OriginName, @PickupDate, @DestinationName,
			@DestinationCity, @DestinationState, @DestinationZip, @DestinationDealerCode,
			@DropoffDate, @SizeClass,@ChargeRate, @MiscellaneousAdditive,
			@ChargeRateOverrideInd,@OutsideCarrierPaymentMethod, @PONumber, @OrdersID

	END --end of loop

	--set the next GM invoice number in the setting table
	UPDATE SettingTable
	SET ValueDescription = @NextGMInvoiceNumber+1	
	WHERE ValueKey = 'NextGMInvoiceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting Next Invoice Number'
		GOTO Error_Encountered
	END

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE GMManualInvoiceCursor
		DEALLOCATE GMManualInvoiceCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE GMManualInvoiceCursor
		DEALLOCATE GMManualInvoiceCursor
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
