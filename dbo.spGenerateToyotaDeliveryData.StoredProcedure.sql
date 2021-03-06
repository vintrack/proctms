USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateToyotaDeliveryData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateToyotaDeliveryData] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--ToyotaExportDelivery table variables
	@BatchID			int,
	@VehicleID			int,
	@CarrierCode			varchar(2),
	@FileCode			varchar(2),
	@RecordTypeA			varchar(1),
	@GroupNumber			varchar(6),
	@DeliveryDateTime		datetime,
	@DeviationNumber		varchar(6),
	@ShipToDealerCode		varchar(5),
	@Rate				varchar(6),
	@CarrierTenderDate		datetime,
	@DealerTenderTime		varchar(4),
	@RecordTypeB			varchar(1),
	@CarrierLoadNumber		varchar(10),
	@OriginCode			varchar(2),
	@DestinationCode		varchar(2),
	@PickupDateTime			datetime,
	@CarrierDiscretionField		varchar(10),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	@MatchingFlag			varchar(1),
	@ErrorFlags			varchar(5),
	@ShipmentID			varchar(10),
	--processing variables
	@ChargeRate			decimal(19,2),
	@MiscellaneousAdditive		decimal(19,2),
	@ChargeRateOverrideInd		int,
	@ValidatedRate			decimal(19,2),
	@ValidatedMiscAdditive		decimal(19,2),
	@CustomerID			int,
	@DamageCode			varchar(5),
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateToyotaDeliveryData					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generate the delivered vehicle data for Toyotas	*
	*	that have been delivered.					*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	08/18/2008 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ToyotaCustomerID'
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

	--get the carrier code
	SELECT @CarrierCode = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'ToyotaCarrierCode'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting BatchID'
		GOTO Error_Encountered2
	END
	
	--get the next batch id from the setting table
	Select @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextToyotaDeliveryExportBatchID'
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

	DECLARE ToyotaDeliveryCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, 
		CASE WHEN CHARINDEX('/',V.CustomerIdentification) > 0 THEN SUBSTRING(V.CustomerIdentification,1,CHARINDEX('/',V.CustomerIdentification)-1) WHEN DATALENGTH(V.CustomerIdentification) < 7 THEN V.CustomerIdentification ELSE '' END,
		CASE WHEN CHARINDEX('/',V.CustomerIdentification) > 0 THEN SUBSTRING(V.CustomerIdentification,CHARINDEX('/',V.CustomerIdentification)+1,DATALENGTH(V.CustomerIdentification)-CHARINDEX('/',V.CustomerIdentification)) WHEN DATALENGTH(V.CustomerIdentification) > 6 THEN V.CustomerIdentification ELSE '' END,
		L2.DropoffDate, ISNULL(V.ReleaseCode,''),
		L4.CustomerLocationCode, CONVERT(varchar(20),CONVERT(int,(V.ChargeRate+V.MiscellaneousAdditive)*100)),
		V.AvailableForPickupDate,'0000',L3.LoadNumber,
		(SELECT C.Value2 FROM Code C WHERE C.CodeType = 'ToyotaLocationCode' AND CONVERT(int,C.Value1) = V.PickupLocationID),
		'DL',L1.PickupDate, V.ChargeRate, V.MiscellaneousAdditive, V.ChargeRateOverrideInd
		FROM Vehicle V
		LEFT JOIN Legs L1 ON V.VehicleID = L1.VehicleID
		AND L1.LegNumber = 1
		LEFT JOIN Legs L2 ON V.VehicleID = L2.VehicleID
		AND L2.FinalLegInd = 1
		LEFT JOIN Loads L3 ON L2.LoadID = L3.LoadsID
		LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
		LEFT JOIN Driver D ON L3.DriverID = D.DriverID
		LEFT JOIN OutsideCarrier OC ON L3.OutsideCarrierID = OC.OutsideCarrierID
		LEFT JOIN OutsideCarrier OC2 ON D.OutsideCarrierID = OC2.OutsideCarrierID
		WHERE V.CustomerID = @CustomerID
		AND L2.DropoffDate > L1.PickupDate
		AND L1.PickupDate >= CONVERT(varchar(10),L1.DateAvailable,101)
		AND ISNULL(V.CustomerIdentification,'') <> ''
		AND V.CustomerIdentification NOT LIKE 'Dev%'
		AND (V.ChargeRate > 0 OR (V.ChargeRate = 0 AND V.ChargeRateOverrideInd = 1))
		AND V.VehicleStatus = 'Delivered'
		AND V.VehicleID NOT IN (SELECT VehicleID FROM ToyotaExportDelivery)
		AND (D.OutsideCarrierInd = 0
		OR (D.OutsideCarrierInd = 1 AND (L2.OutsideCarrierPay > 0 OR OC2.StandardCommissionRate > 0))
		OR (L2.OutsideCarrierID > 0 AND (L2.OutsideCarrierPay > 0 OR OC.StandardCommissionRate > 0)))
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN ToyotaDeliveryCursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextToyotaDeliveryExportBatchID'
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
	SELECT @FileCode = '03'
	SELECT @RecordTypeA = 'A'
	SELECT @RecordTypeB = 'B'
	SELECT @CarrierDiscretionField = ''
	SELECT @MatchingFlag = ''
	SELECT @ErrorFlags = ''

	FETCH ToyotaDeliveryCursor INTO @VehicleID, @GroupNumber, @ShipmentID, @DeliveryDateTime,
		@DeviationNumber,@ShipToDealerCode, @Rate, @CarrierTenderDate,
		@DealerTenderTime, @CarrierLoadNumber, @OriginCode, @DestinationCode,
		@PickupDateTime, @ChargeRate, @MiscellaneousAdditive, @ChargeRateOverrideInd
	
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @ChargeRateOverrideInd = 0
		BEGIN
			SELECT TOP 1 @ValidatedRate = ISNULL(CR.Rate,-1), @ValidatedMiscAdditive = CR.MiscellaneousAdditive
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
				
				SELECT @Rate = CONVERT(varchar(20),CONVERT(int,(@ChargeRate+@MiscellaneousAdditive)*100))
			END
		END	
		
		INSERT INTO ToyotaExportDelivery(
			BatchID,
			VehicleID,
			CarrierCode,
			FileCode,
			RecordTypeA,
			GroupNumber,
			DeliveryDateTime,
			DeviationNumber,
			ShipToDealerCode,
			Rate,
			CarrierTenderDate,
			DealerTenderTime,
			RecordTypeB,
			CarrierLoadNumber,
			OriginCode,
			DestinationCode,
			PickupDateTime,
			CarrierDiscretionField,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			RecordStatus,
			CreationDate,
			CreatedBy,
			MatchingFlag,
			ErrorFlags,
			ShipmentID

		)
		VALUES(
			@BatchID,
			@VehicleID,
			@CarrierCode,
			@FileCode,
			@RecordTypeA,
			@GroupNumber,
			@DeliveryDateTime,
			@DeviationNumber,
			@ShipToDealerCode,
			@Rate,
			@CarrierTenderDate,
			@DealerTenderTime,
			@RecordTypeB,
			@CarrierLoadNumber,
			@OriginCode,
			@DestinationCode,
			@PickupDateTime,
			@CarrierDiscretionField,
			@ExportedInd,
			@ExportedDate,
			@ExportedBy,
			@RecordStatus,
			@CreationDate,
			@CreatedBy,
			@MatchingFlag,
			@ErrorFlags,
			@ShipmentID
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating ToyotaExportShipped record'
			GOTO Error_Encountered
		END
		
		End_Of_Loop:
		FETCH ToyotaDeliveryCursor INTO @VehicleID, @GroupNumber, @ShipmentID, @DeliveryDateTime,
			@DeviationNumber,@ShipToDealerCode, @Rate, @CarrierTenderDate,
			@DealerTenderTime, @CarrierLoadNumber, @OriginCode, @DestinationCode,
			@PickupDateTime, @ChargeRate, @MiscellaneousAdditive, @ChargeRateOverrideInd

	END --end of loop

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ToyotaDeliveryCursor
		DEALLOCATE ToyotaDeliveryCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ToyotaDeliveryCursor
		DEALLOCATE ToyotaDeliveryCursor
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
