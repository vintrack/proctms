USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateSubaruDeliveryData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateSubaruDeliveryData] (@LocationID int, @Origin varchar(6),@CreatedBy varchar(20), @CutoffDate datetime)
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--SubaruDeliveryExport table variables
	@SubaruDeliveryExportID		int,
	@RecordType			varchar(5),
	@LocationCode			varchar(6),
	@VehicleID			int,
	@CarrierCode			varchar(6),
	@Destination			varchar(6),
	@ReleaseDate			datetime,
	@DeliveryDate			datetime,
	@RailcarNumber			varchar(10),
	@InterchangeControlNumber	int,
	@SequenceNumber			int,
	@InvoiceNumber			varchar(10),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(20),
	@CreationDate			datetime,
	--processing variables
	@LegsID				int,
	@ChargeRateOverrideInd		int,
	@ValidatedRate			decimal(19,2),
	@OutsideCarrierPaymentMethod	int,
	@ChargeRate			decimal(19,2),
	@NextSOAInvoiceNumber		int,
	@SOAInvoicePrefix		varchar(10),
	@CustomerID			int,
	@DamageCode			varchar(5),
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateSubaruDeliveryData					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the vehicle Delivery export data for	*
	*	SOA vehicles that have been picked up.				*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	04/22/2005 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the customer id from the setting table
	Select @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SOACustomerID'
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
	SELECT @InterchangeControlNumber = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextSubaruInterchangeControlNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Interchange Control Number'
		GOTO Error_Encountered2
	END
	IF @InterchangeControlNumber IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Interchange Control Number Not Found'
		GOTO Error_Encountered2
	END

	--get the next sequence number
	SELECT @SequenceNumber = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextSubaruDeliverySequenceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Sequence Number'
		GOTO Error_Encountered2
	END
	IF @SequenceNumber IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Sequence Number Not Found'
		GOTO Error_Encountered2
	END
	
	--get the next invoice number
	SELECT @NextSOAInvoiceNumber = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextSOAInvoiceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Invoice Number'
		GOTO Error_Encountered2
	END
	IF @NextSOAInvoiceNumber IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Invoice Number Not Found'
		GOTO Error_Encountered2
	END
	--get the invoice prefix
	SELECT @SOAInvoicePrefix = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'SOAInvoicePrefix'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Invoice Prefix'
		GOTO Error_Encountered2
	END
	IF @SOAInvoicePrefix IS NULL OR DATALENGTH(@SOAInvoicePrefix)<1
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Invoice Prefix Not Found'
		GOTO Error_Encountered2
	END
	
	IF @CutoffDate IS NULL
	BEGIN
		SELECT @CutoffDate = CONVERT(varchar(10),CURRENT_TIMESTAMP,101)
	END
	
	DECLARE SubaruDeliveryCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, L.LegsID, L3.CustomerLocationCode,
		V.AvailableForPickupDate, L.DropoffDate, V.RailCarNumber,
		V.ChargeRate, V.ChargeRateOverrideInd, L.OutsideCarrierPaymentMethod
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.FinalLegInd = 1
		LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
		LEFT JOIN Location L3 ON L.DropoffLocationID = L3.LocationID
		LEFT JOIN Driver D ON L2.DriverID = D.DriverID
		LEFT JOIN OutsideCarrier OC ON L2.OutsideCarrierID = OC.OutsideCarrierID
		LEFT JOIN OutsideCarrier OC2 ON D.OutsideCarrierID = OC2.OutsideCarrierID
		WHERE V.PickupLocationID = @LocationID
		AND V.CustomerID = @CustomerID
		AND V.VehicleStatus = 'Delivered'
		AND (V.ChargeRate > 0 OR (V.ChargeRate = 0 AND V.ChargeRateOverrideInd = 1))
		AND L.PickupDate < DATEADD(day,1,@CutoffDate)
		AND L.DropoffDate > L.PickupDate
		AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
		AND (D.OutsideCarrierInd = 0
		OR (D.OutsideCarrierInd = 1 AND (L.OutsideCarrierPay > 0 OR OC2.StandardCommissionRate > 0))
		OR (L.OutsideCarrierID > 0 AND (L.OutsideCarrierPay > 0 OR OC.StandardCommissionRate > 0)))
		AND V.VehicleID NOT IN (SELECT VehicleID FROM SubaruDeliveryExport)
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN SubaruDeliveryCursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @InterchangeControlNumber+1	
	WHERE ValueKey = 'NextSubaruInterchangeControlNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting Interchange Control Number'
		GOTO Error_Encountered
	END

	--set the next sequence number in the setting table
	UPDATE SettingTable
	SET ValueDescription = @SequenceNumber+1	
	WHERE ValueKey = 'NextSubaruDeliverySequenceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting Sequence Number'
		GOTO Error_Encountered
	END
	
	--set the next invoice number
	UPDATE SettingTable
	SET ValueDescription = @NextSOAInvoiceNumber+1	
	WHERE ValueKey = 'NextSOAInvoiceNumber'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting Invoice Number'
		GOTO Error_Encountered
	END

	--set the default values
	SELECT @RecordType = 'CRDEL'
	SELECT @CarrierCode = '405000'
	SELECT @InvoiceNumber = @SOAInvoicePrefix+REPLICATE(0,4-DATALENGTH(CONVERT(VARCHAR(20),@NextSOAInvoiceNumber)))+CONVERT(varchar(20),@NextSOAInvoiceNumber)
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	FETCH SubaruDeliveryCursor INTO @VehicleID,@LegsID, @Destination,
		@ReleaseDate, @DeliveryDate, @RailcarNumber,@ChargeRate,
		@ChargeRateOverrideInd,@OutsideCarrierPaymentMethod
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN

		SELECT @LocationCode = @Destination
	
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
		
		INSERT INTO SubaruDeliveryExport(
			RecordType,
			LocationCode,
			VehicleID,
			Origin,
			CarrierCode,
			Destination,
			ReleaseDate,
			DeliveryDate,
			RailcarNumber,
			InterchangeControlNumber,
			SequenceNumber,
			InvoiceNumber,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@RecordType,
			@LocationCode,
			@VehicleID,
			@Origin,
			@CarrierCode,
			@Destination,
			@ReleaseDate,
			@DeliveryDate,
			@RailcarNumber,
			@InterchangeControlNumber,
			@SequenceNumber,
			@InvoiceNumber,
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
			SELECT @Status = 'Error creating SubaruDeliveryExport record'
			GOTO Error_Encountered
		END
			
		End_Of_Loop:
		FETCH SubaruDeliveryCursor INTO @VehicleID,@LegsID, @Destination,
			@ReleaseDate, @DeliveryDate, @RailcarNumber,@ChargeRate,
			@ChargeRateOverrideInd,@OutsideCarrierPaymentMethod

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE SubaruDeliveryCursor
		DEALLOCATE SubaruDeliveryCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE SubaruDeliveryCursor
		DEALLOCATE SubaruDeliveryCursor
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
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage, @SequenceNumber AS BatchID
	
	RETURN
END
GO
