USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateICLR92Data]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateICLR92Data] (@CustomerID int, @ICLCustomerCode varchar(2),@CreatedBy varchar(20), @CutoffDate datetime)
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--ExportICLR92 table variables
	@BatchID			int,
	@VehicleID			int,
	@InvoiceNumber			varchar(15),
	@DateOfInvoice			datetime,
	@ICLAccountCode			varchar(4),
	@DamageCode			varchar(6),
	@PIOCode			varchar(4),
	@DestinationCode		varchar(7),
	@Sign				varchar(1),
	@Amount				varchar(8),
	@CompletionDate			datetime,
	@ShipmentAuthorizationCode	varchar(12),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(20),
	@CreationDate			datetime,
	@OriginLocationCode		varchar(10),
	--processing variables
	@ChargeRate			decimal(19,2),
	@MiscellaneousAdditive		decimal(19,2),
	@Tolls				decimal(19,2),
	@Ferry				decimal(19,2),
	@FuelSurcharge			decimal(19,2),
	@LegsID				int,
	@ChargeRateOverrideInd		int,
	@ValidatedRate			decimal(19,2),
	@ValidatedMiscAdditive		decimal(19,2),
	@OutsideCarrierPaymentMethod	int,
	@OutsideCarrierUnitInd		int,
	@PreviousOutsideCarrierUnitInd	int,
	@VIN				varchar(20),
	@I95RecordCount			int,
	@InvoicePrefixCode		varchar(10),			
	@NextInvoiceNumber		int,
	@CursorHasRowsInd		int,
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@FuelSurchargeCustomerInd	int,
	@OCCommissionOverrideRecordInd	int,
	@ToyotaCustomerID		int,
	@ToyotaFSCMilesPerGallon	decimal(19,2),
	@ToyotaFSCLoadFactor		decimal(19,2),
	@ToyotaFSCBaselineDieselPrice	decimal(19,2)

	/************************************************************************
	*	spGenerateICLR92Data						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the ICL R92 export data for vehicles	*
	*	(for the specified ICL customer) that have been delivered.	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/30/2005 CMK    Initial version				*
	*	08/04/2009 CMK    Added Fuel Surcharge Program Code		*
	*	10/04/2016 CMK    Added in coding for Toyota Fuel Surcharge	*
	*	06/12/2017 CMK    Added support for Toyota Misc Moves		*
	*									*
	************************************************************************/
	
	--get the next batch id from the setting table
	SELECT @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextICL'+@ICLCustomerCode+'R92BatchID'
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

	--get the next invoice number from the setting table
	SELECT @NextInvoiceNumber = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextICL'+@ICLCustomerCode+'InvoiceNumber'
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
	
	SELECT @InvoicePrefixCode = Value2
	FROM Code
	WHERE CodeType = 'ICLCustomerCode'
	AND Code = @ICLCustomerCode
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Invoice Prefix Code'
		GOTO Error_Encountered2
	END
	IF @InvoicePrefixCode IS NULL OR DATALENGTH(@InvoicePrefixCode) < 1
	BEGIN
		SELECT @ErrorID = 100005
		SELECT @Status = 'Invoice Prefix Code Not Found'
		GOTO Error_Encountered2
	END
	
	--get the next batch id from the setting table
	SELECT @ToyotaCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ToyotaCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting ToyotaCustomerID'
		GOTO Error_Encountered2
	END
	IF @ToyotaCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'ToyotaCustomerID Not Found'
		GOTO Error_Encountered2
	END
		
	SELECT @ToyotaFSCMilesPerGallon = CONVERT(decimal(19,2),ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ToyotaFSCMilesPerGallon'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting ToyotaFSCMilesPerGallon'
		GOTO Error_Encountered2
	END
	IF @ToyotaFSCMilesPerGallon IS NULL
	BEGIN
		SELECT @ErrorID = 100006
		SELECT @Status = 'ToyotaFSCMilesPerGallon Not Found'
		GOTO Error_Encountered2
	END
	
	SELECT @ToyotaFSCLoadFactor = CONVERT(decimal(19,2),ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ToyotaFSCLoadFactor'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting ToyotaFSCLoadFactor'
		GOTO Error_Encountered2
	END
	IF @ToyotaFSCLoadFactor IS NULL
	BEGIN
		SELECT @ErrorID = 100007
		SELECT @Status = 'ToyotaFSCLoadFactor Not Found'
		GOTO Error_Encountered2
	END
	
	SELECT @ToyotaFSCBaselineDieselPrice = CONVERT(decimal(19,2),ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ToyotaFSCBaselineDieselPrice'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting ToyotaFSCBaselineDieselPrice'
		GOTO Error_Encountered2
	END
	IF @ToyotaFSCBaselineDieselPrice IS NULL
	BEGIN
		SELECT @ErrorID = 100008
		SELECT @Status = 'ToyotaFSCBaselineDieselPrice Not Found'
		GOTO Error_Encountered2
	END
	
	IF @CutoffDate IS NULL
	BEGIN
		SELECT @CutoffDate = CONVERT(varchar(10),CURRENT_TIMESTAMP,101)
	END
	
	--see if this is a fuel surcharge customer
	SELECT @FuelSurchargeCustomerInd = COUNT(*)
	FROM Code
	WHERE CodeType = 'ICLFuelSCCustomerCode'
	AND Code = @ICLCustomerCode
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END
	
	--cursor for the delivery records
	DECLARE ICLR92Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, L.LegsID, ISNULL(L3.CustomerLocationCode,LEFT(L3.Zip,5)),				
		CONVERT(int,V.ChargeRate*100), L.DropoffDate,
		CASE WHEN CHARINDEX('/',V.CustomerIdentification) > 0 THEN
			--LEFT(V.CustomerIdentification,CHARINDEX('/',V.CustomerIdentification)-1)
			CASE WHEN CHARINDEX('/',V.CustomerIdentification) > 0 THEN SUBSTRING(V.CustomerIdentification,CHARINDEX('/',V.CustomerIdentification)+1,DATALENGTH(V.CustomerIdentification)-CHARINDEX('/',V.CustomerIdentification)) WHEN DATALENGTH(V.CustomerIdentification) > 6 THEN V.CustomerIdentification ELSE '' END
		ELSE V.CustomerIdentification END,
		V.VIN,
		V.ChargeRate, V.MiscellaneousAdditive, V.ChargeRateOverrideInd, L.OutsideCarrierPaymentMethod,
		CASE WHEN ISNULL(OC.OutsideCarrierID,0) > 0 OR ISNULL(OC2.OutsideCarrierID,0) > 0 THEN 1 ELSE 0 END OCInd,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN
			ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
			AND C.Value1 = CONVERT(varchar(10),V.PickupLocationID)),LEFT(L4.Zip,5))
			ELSE ISNULL(L4.CustomerLocationCode,LEFT(L4.Zip,5)) END TheOrigin
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.FinalLegInd = 1
		LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
		LEFT JOIN Location L3 ON V.DropoffLocationID = L3.LocationID
		LEFT JOIN Location L4 ON V.PickupLocationID = L4.LocationID
		LEFT JOIN Driver D ON L2.DriverID = D.DriverID
		LEFT JOIN OutsideCarrier OC ON L2.OutsideCarrierID = OC.OutsideCarrierID
		LEFT JOIN OutsideCarrier OC2 ON D.OutsideCarrierID = OC2.OutsideCarrierID
		LEFT JOIN Customer C ON V.CustomerID = C.CustomerID
		--new code
		LEFT JOIN ICLFuelSurchargeRates IFSR ON (SELECT TOP 1 IFSR2.ICLFuelSurchargeRatesID FROM ICLFuelSurchargeRates IFSR2
		WHERE V.CustomerID = IFSR2.CustomerID
		AND V.PickupLocationID = IFSR2.LocationID
		AND IFSR2.RateStartDate <= L.PickupDate
		AND ISNULL(DATEADD(day,1,IFSR2.RateEndDate),DATEADD(day,1,CURRENT_TIMESTAMP)) > L.PickupDate) = IFSR.ICLFuelSurchargeRatesID
		--end new code
		WHERE V.CustomerID = @CustomerID
		AND V.BilledInd = 0
		--OR (V.CustomerID = @ToyotaCustomerID AND V.DateBilled >= '06/01/2017')) --05/12/2017 - CMK - added for ICL parallel billing testing
		AND V.VehicleStatus = 'Delivered'
		AND (V.ChargeRate > 0 OR (V.ChargeRate = 0 AND V.ChargeRateOverrideInd = 1))
		AND L.DropoffDate < DATEADD(day,1,@CutoffDate)
		AND L.DropoffDate > L.PickupDate
		AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
		--AND V.CustomerIdentification IS NOT NULL						--06/12/2017 - CMK - commented for Toyota Misc Move support
		--AND V.CustomerIdentification <> ''							--06/12/2017 - CMK - commented for Toyota Misc Move support
		AND (ISNULL(V.CustomerIdentification,'') <> '' OR V.CustomerID = @ToyotaCustomerID)	--06/12/2017 - CMK - added for Toyota Misc Move support
		AND V.VehicleID NOT IN (SELECT E.VehicleID FROM ExportICLR92 E WHERE E.VehicleID = V.VehicleID AND E.ICLAccountCode IN('1400','1415','1450'))
		AND (D.OutsideCarrierInd = 0
		OR (D.OutsideCarrierInd = 1 AND (L.OutsideCarrierPay > 0 OR OC2.StandardCommissionRate > 0))
		OR (L.OutsideCarrierID > 0 AND (L.OutsideCarrierPay > 0 OR OC.StandardCommissionRate > 0)))
		AND CASE
			WHEN @FuelSurchargeCustomerInd = 0 THEN 1
			WHEN IFSR.FuelSurchargeRate IS NOT NULL THEN 1
			WHEN (SELECT COUNT(*) 
				FROM ImportI95 I
				WHERE I.VIN = V.VIN
				AND I.ShipmentAuthorizationCode = V.CustomerIdentification) > 0 THEN 1
			WHEN (SELECT COUNT(*) 
				FROM OCCommissionOverrides OCCO 
				WHERE OCCO.CustomerID = V.CustomerID 
				AND OCCO.LocationID = V.PickupLocationID
				AND OCCO.OutsideCarrierID = ISNULL(OC.OutsideCarrierID,OC2.OutsideCarrierID)) > 0 THEN 0 
			ELSE 1 END = 1
		--ORDER BY OCInd, V.VehicleID
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN ICLR92Cursor

	BEGIN TRAN
	
	--set the default values
	--SELECT @PreviousOutsideCarrierUnitInd = NULL
	SELECT @ExportedInd = 0
	SELECT @InvoiceNumber = @InvoicePrefixCode+REPLICATE(0,4-DATALENGTH(CONVERT(VARCHAR(20),@NextInvoiceNumber)))+CONVERT(varchar(20),@NextInvoiceNumber)
	IF @CutoffDate IS NOT NULL
	BEGIN
		SELECT @DateOfInvoice = @CutoffDate
	END
	ELSE
	BEGIN
		SELECT @DateOfInvoice = CURRENT_TIMESTAMP
	END
	SELECT @CursorHasRowsInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @DamageCode = ''
	SELECT @PIOCode = ''
	SELECT @Sign = '+'
	
	FETCH ICLR92Cursor INTO @VehicleID,@LegsID, @DestinationCode, @Amount, @CompletionDate, @ShipmentAuthorizationCode,
		@VIN, @ChargeRate, @MiscellaneousAdditive, @ChargeRateOverrideInd, @OutsideCarrierPaymentMethod, @OutsideCarrierUnitInd,
		@OriginLocationCode
	
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @CursorHasRowsInd = 1
		
		SELECT @CreationDate = CURRENT_TIMESTAMP
	
		--validate the rate
		IF @ChargeRateOverrideInd = 0 OR @CustomerID = @ToyotaCustomerID
		BEGIN
			SELECT TOP 1 @ValidatedRate = ISNULL(CR.Rate,-1),
			@ValidatedMiscAdditive = ISNULL(CR.MiscellaneousAdditive,0),
			@Tolls = ISNULL(Tolls,0),
			@Ferry = ISNULL(Ferry,0)
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
			
			IF (@ValidatedRate IS NULL OR @ValidatedRate = -1) AND (@CustomerID <> @ToyotaCustomerID OR @ChargeRateOverrideInd = 0) 
			BEGIN
				GOTO End_Of_Loop
			END
			
			IF (@ValidatedRate <> @ChargeRate) OR (@CustomerID = @ToyotaCustomerID AND @ValidatedMiscAdditive <> @MiscellaneousAdditive)
			BEGIN
				IF @ChargeRateOverrideInd = 0
				BEGIN
					SELECT @ChargeRate = @ValidatedRate
				END
				IF @CustomerID = @ToyotaCustomerID
				BEGIN
					SELECT @MiscellaneousAdditive = @ValidatedMiscAdditive
				END
				ELSE
				BEGIN
					SELECT @MiscellaneousAdditive = 0
				END
									
				SELECT @Amount = CONVERT(int,@ChargeRate*100)
				
				--IF @CustomerID <> @ToyotaCustomerID	--5/12/17 - CMK - added if statement for Toyota parallel billing testing.
									--We do not want to update here because it could affect a unit that was 
									--already billed through the real Toyota Payment procees
									--THIS IF SHOULD BE REMOVED ONCE THE R92 BECOMES THE MAIN BILLING PROCESS
				--BEGIN
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
				--END
			END
		END
		
		SELECT @I95RecordCount = Count(*)
		FROM ImportI95
		WHERE VIN = @VIN
		AND ShipmentAuthorizationCode = @ShipmentAuthorizationCode
		--AND ImportedInd = 1
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting I95 Record Count'
			GOTO Error_Encountered
		END
		
		IF @I95RecordCount >= 1
		BEGIN
			SELECT @ICLAccountCode = '1450'
			SELECT @Tolls = 0
			SELECT @Ferry = 0
			SELECT @MiscellaneousAdditive = 0
		END
		ELSE
		BEGIN
			--SELECT @ICLAccountCode = '1415'
			SELECT @ICLAccountCode = '1400'
		END
	
		IF @ICLCustomerCode = 'SW'
		BEGIN
			SELECT @CompletionDate = NULL
		END
		
		IF @CustomerID = @ToyotaCustomerID
		BEGIN
			SELECT @Amount = @Amount - CONVERT(int,@Tolls*100)
			
			--06/12/2017 - CMK - adding support for toyota Misc Move vehicles
			IF ISNULL(@ShipmentAuthorizationCode,'') = '' OR ISNULL(@ShipmentAuthorizationCode,'') LIKE 'Dev%'
			BEGIN
				SELECT @ShipmentAuthorizationCode = 'MISCMOVE'
			END
		END
		
		--SELECT @Amount = CONVERT(int,@ChargeRate*100)
		
		INSERT INTO ExportICLR92(
			BatchID,
			CustomerID,
			ICLCustomerCode,
			VehicleID,
			InvoiceNumber,
			DateOfInvoice,
			ICLAccountCode,
			DamageCode,
			PIOCode,
			DestinationCode,
			Sign,
			Amount,
			CompletionDate,
			ShipmentAuthorizationCode,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			RecordStatus,
			CreationDate,
			CreatedBy,
			OriginLocationCode
		)
		VALUES(
			@BatchID,
			@CustomerID,
			@ICLCustomerCode,
			@VehicleID,
			@InvoiceNumber,
			@DateOfInvoice,
			@ICLAccountCode,
			@DamageCode,
			@PIOCode,
			@DestinationCode,
			@Sign,
			@Amount,
			@CompletionDate,
			@ShipmentAuthorizationCode,
			@ExportedInd,
			@ExportedDate,
			@ExportedBy,
			@RecordStatus,
			@CreationDate,
			@CreatedBy,
			@OriginLocationCode
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating R92 record'
			GOTO Error_Encountered
		END
		
		IF @CustomerID = @ToyotaCustomerID AND @Tolls > 0
		BEGIN
			SELECT @CreationDate = CURRENT_TIMESTAMP
			SELECT @ICLAccountCode = '1461'
			SELECT @Amount = CONVERT(int,@Tolls*100)
			
			INSERT INTO ExportICLR92(
				BatchID,
				CustomerID,
				ICLCustomerCode,
				VehicleID,
				InvoiceNumber,
				DateOfInvoice,
				ICLAccountCode,
				DamageCode,
				PIOCode,
				DestinationCode,
				Sign,
				Amount,
				CompletionDate,
				ShipmentAuthorizationCode,
				ExportedInd,
				ExportedDate,
				ExportedBy,
				RecordStatus,
				CreationDate,
				CreatedBy,
				OriginLocationCode
			)
			VALUES(
				@BatchID,
				@CustomerID,
				@ICLCustomerCode,
				@VehicleID,
				@InvoiceNumber,
				@DateOfInvoice,
				@ICLAccountCode,
				@DamageCode,
				@PIOCode,
				@DestinationCode,
				@Sign,
				@Amount,
				@CompletionDate,
				@ShipmentAuthorizationCode,
				@ExportedInd,
				@ExportedDate,
				@ExportedBy,
				@RecordStatus,
				@CreationDate,
				@CreatedBy,
				@OriginLocationCode
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error creating R92 Tolls record'
				GOTO Error_Encountered
			END
		END
			
		IF @CustomerID = @ToyotaCustomerID AND @Ferry > 0
		BEGIN
			SELECT @CreationDate = CURRENT_TIMESTAMP
			SELECT @ICLAccountCode = '1462'
			SELECT @Amount = CONVERT(int,@Ferry*100)
			
			INSERT INTO ExportICLR92(
				BatchID,
				CustomerID,
				ICLCustomerCode,
				VehicleID,
				InvoiceNumber,
				DateOfInvoice,
				ICLAccountCode,
				DamageCode,
				PIOCode,
				DestinationCode,
				Sign,
				Amount,
				CompletionDate,
				ShipmentAuthorizationCode,
				ExportedInd,
				ExportedDate,
				ExportedBy,
				RecordStatus,
				CreationDate,
				CreatedBy,
				OriginLocationCode
			)
			VALUES(
				@BatchID,
				@CustomerID,
				@ICLCustomerCode,
				@VehicleID,
				@InvoiceNumber,
				@DateOfInvoice,
				@ICLAccountCode,
				@DamageCode,
				@PIOCode,
				@DestinationCode,
				@Sign,
				@Amount,
				@CompletionDate,
				@ShipmentAuthorizationCode,
				@ExportedInd,
				@ExportedDate,
				@ExportedBy,
				@RecordStatus,
				@CreationDate,
				@CreatedBy,
				@OriginLocationCode
			)
			IF @@Error <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error creating R92 Ferry record'
				GOTO Error_Encountered
			END
		END
			
		End_Of_Loop:
		SELECT @PreviousOutsideCarrierUnitInd = @OutsideCarrierUnitInd
		
		FETCH ICLR92Cursor INTO @VehicleID,@LegsID, @DestinationCode, @Amount, @CompletionDate, @ShipmentAuthorizationCode,
			@VIN, @ChargeRate, @MiscellaneousAdditive, @ChargeRateOverrideInd, @OutsideCarrierPaymentMethod, @OutsideCarrierUnitInd,
			@OriginLocationCode

	END --end of loop
	
	
	--START OF ICL FUEL SURCHARGE PROGRAM CODE
	IF @FuelSurchargeCustomerInd > 0
	BEGIN
		CLOSE ICLR92Cursor
		DEALLOCATE ICLR92Cursor
		
		SELECT @CreationDate = CURRENT_TIMESTAMP
	
		--cursor for the fuel surcharge records
		DECLARE ICLR92Cursor CURSOR
		LOCAL FORWARD_ONLY STATIC READ_ONLY
		FOR
			SELECT V.VehicleID, L.LegsID, ISNULL(L2.CustomerLocationCode,LEFT(L2.Zip,5)),
			--10/04/2016 - cmk - adding in logic for other fuel surcharge program type
			CASE WHEN IFSR.ProgramTypeInd = 0 THEN
				CONVERT(int,ROUND(V.ChargeRate*IFSR.FuelSurchargeRate/100,2)*100)	--original code,
			WHEN IFSR.ProgramTypeInd = 1 THEN
				--CONVERT(int,ROUND(((CEILING(IFSR.NationalAveragePriceOfDiesel*10)/10 - @ToyotaFSCBaselineDieselPrice)/@ToyotaFSCMilesPerGallon/@ToyotaFSCLoadFactor)*ISNULL(CR.Mileage,0),2)*100)
				CONVERT(int,ROUND((((CEILING(IFSR.NationalAveragePriceOfDiesel*10)/10) - @ToyotaFSCBaselineDieselPrice)*ROUND(1/@ToyotaFSCMilesPerGallon/@ToyotaFSCLoadFactor,4))*ISNULL(CR.Mileage,0),2)*100)
			ELSE
				0
			END,
			--10/04/2016 - cmk - adding in logic for other fuel surcharge program type
			CASE WHEN IFSR.ProgramTypeInd = 0 THEN
				ROUND(V.ChargeRate*IFSR.FuelSurchargeRate/100,2)		--original code,
			WHEN IFSR.ProgramTypeInd = 1 THEN
				--ROUND(((CEILING(IFSR.NationalAveragePriceOfDiesel*10)/10 - @ToyotaFSCBaselineDieselPrice)/@ToyotaFSCMilesPerGallon/@ToyotaFSCLoadFactor)*ISNULL(CR.Mileage,0),2)
				ROUND((((CEILING(IFSR.NationalAveragePriceOfDiesel*10)/10) - @ToyotaFSCBaselineDieselPrice)*ROUND(1/@ToyotaFSCMilesPerGallon/@ToyotaFSCLoadFactor,4))*ISNULL(CR.Mileage,0),2)
			ELSE
				0
			END,
			L.DropoffDate,
			CASE WHEN CHARINDEX('/',V.CustomerIdentification) > 0 THEN
				--LEFT(V.CustomerIdentification,CHARINDEX('/',V.CustomerIdentification)-1)
				CASE WHEN CHARINDEX('/',V.CustomerIdentification) > 0 THEN SUBSTRING(V.CustomerIdentification,CHARINDEX('/',V.CustomerIdentification)+1,DATALENGTH(V.CustomerIdentification)-CHARINDEX('/',V.CustomerIdentification)) WHEN DATALENGTH(V.CustomerIdentification) > 6 THEN V.CustomerIdentification ELSE '' END
			ELSE V.CustomerIdentification END,
			V.VIN,
			CASE WHEN L3.ParentRecordTable = 'Common' THEN
				ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
				AND C.Value1 = CONVERT(varchar(10),V.PickupLocationID)),LEFT(L3.Zip,5))
				ELSE ISNULL(L3.CustomerLocationCode,LEFT(L3.Zip,5)) END TheOrigin
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			AND L.FinalLegInd = 1
			LEFT JOIN Location L2 ON V.DropoffLocationID = L2.LocationID
			LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
			LEFT JOIN ICLFuelSurchargeRates IFSR ON (SELECT TOP 1 IFSR2.ICLFuelSurchargeRatesID FROM ICLFuelSurchargeRates IFSR2
				WHERE V.CustomerID = IFSR2.CustomerID
				AND V.PickupLocationID = IFSR2.LocationID
				AND IFSR2.RateStartDate <= L.PickupDate
				AND ISNULL(DATEADD(day,1,IFSR2.RateEndDate),DATEADD(day,1,CURRENT_TIMESTAMP)) > L.PickupDate) = IFSR.ICLFuelSurchargeRatesID
			LEFT JOIN ChargeRate CR ON (SELECT TOP 1 CR2.ChargeRateID FROM ChargeRate CR2	--10/04/2016 - cmk - need mileage from rate for new fuel program
				WHERE V.CustomerID = CR2.CustomerID
				AND V.PickupLocationID = CR2.StartLocationID
				AND V.DropoffLocationID = CR2.EndLocationID
				AND ISNULL(CR2.Mileage,0) > 0
				ORDER BY CR2.ChargeRateID DESC) = CR.ChargeRateID	--10/04/2016 - cmk - can ignore size class and dates as we only need miles
			WHERE V.CustomerID = @CustomerID
			--AND V.BilledInd = 1
			AND V.VehicleStatus = 'Delivered'
			AND L.DropoffDate < DATEADD(day,1,@CutoffDate)
			AND L.DropoffDate > L.PickupDate
			AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
			AND V.CustomerIdentification IS NOT NULL
			AND V.CustomerIdentification <> ''
			AND V.CustomerIdentification NOT LIKE 'MM%'
			AND V.CustomerIdentification NOT LIKE 'Dev%'	--06/12/2017 - CMK - added to ensure Toyota Misc Moves do not generate Fuel Surcharge records
			AND V.VehicleID IN (SELECT E.VehicleID FROM ExportICLR92 E WHERE E.VehicleID = V.VehicleID AND E.ICLAccountCode IN ('1400', '1415'))
			AND V.VehicleID NOT IN (SELECT E.VehicleID FROM ExportICLR92 E WHERE E.VehicleID = V.VehicleID AND E.ICLAccountCode = '1430')
			AND IFSR.FuelSurchargeRate IS NOT NULL
			ORDER BY V.VehicleID
		
		OPEN ICLR92Cursor
		
		--BEGIN TRAN
			
		--set the default values
		FETCH ICLR92Cursor INTO @VehicleID,@LegsID, @DestinationCode, @Amount, @FuelSurcharge, @CompletionDate, 
			@ShipmentAuthorizationCode, @VIN, @OriginLocationCode
		
		--print 'about to enter loop'
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT @CursorHasRowsInd = 1
			--validate the rate
			SELECT @ICLAccountCode = '1430'
			
			IF @ICLCustomerCode = 'SW'
			BEGIN
				SELECT @CompletionDate = NULL
			END
				
			IF ISNULL(@FuelSurcharge,0) > 0	--no insert or update needed if there is no fuel surcharge
			BEGIN
				INSERT INTO ExportICLR92(
					BatchID,
					CustomerID,
					ICLCustomerCode,
					VehicleID,
					InvoiceNumber,
					DateOfInvoice,
					ICLAccountCode,
					DamageCode,
					PIOCode,
					DestinationCode,
					Sign,
					Amount,
					CompletionDate,
					ShipmentAuthorizationCode,
					ExportedInd,
					ExportedDate,
					ExportedBy,
					RecordStatus,
					CreationDate,
					CreatedBy,
					OriginLocationCode
				)
				VALUES(
					@BatchID,
					@CustomerID,
					@ICLCustomerCode,
					@VehicleID,
					@InvoiceNumber,
					@DateOfInvoice,
					@ICLAccountCode,
					@DamageCode,
					@PIOCode,
					@DestinationCode,
					@Sign,
					@Amount,
					@CompletionDate,
					@ShipmentAuthorizationCode,
					@ExportedInd,
					@ExportedDate,
					@ExportedBy,
					@RecordStatus,
					@CreationDate,
					@CreatedBy,
					@OriginLocationCode
				)
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error creating R92 record'
					GOTO Error_Encountered
				END
			
				--IF @CustomerID <>  @ToyotaCustomerID	--TEMPORARY IF FOR TOYOTA, REMOVE AFTER FULL CHANGEOVER TO ICL
				--BEGIN	--TEMPORARY IF FOR TOYOTA, REMOVE AFTER FULL CHANGEOVER TO ICL
				UPDATE Vehicle
				SET FuelSurcharge = @FuelSurcharge
				WHERE VehicleID = @VehicleID
				IF @@Error <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Status = 'Error Updating Vehicle Record'
					GOTO Error_Encountered
				END
				--END	--TEMPORARY IF FOR TOYOTA, REMOVE AFTER FULL CHANGEOVER TO ICL
			END
			
			End_Of_Loop2:
			SELECT @PreviousOutsideCarrierUnitInd = @OutsideCarrierUnitInd
				
			FETCH ICLR92Cursor INTO @VehicleID,@LegsID, @DestinationCode, @Amount, @FuelSurcharge, @CompletionDate, 
				@ShipmentAuthorizationCode, @VIN, @OriginLocationCode
		
		END --end of loop
		
	END
	
	--END OF ICL FUEL SURCHARGE PROGRAM CODE
	
	--set the next batchid and invoicenumber
	IF @CursorHasRowsInd = 1
	BEGIN
		--set the next batch id in the setting table
		UPDATE SettingTable
		SET ValueDescription = @BatchID+1	
		WHERE ValueKey = 'NextICL'+@ICLCustomerCode+'R92BatchID'
		IF @@ERROR <> 0
		BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Status = 'Error Setting BatchID'
				GOTO Error_Encountered
		END
	
		--set the next invoice number in the setting table
		UPDATE SettingTable
		SET ValueDescription = @NextInvoiceNumber+1	
		WHERE ValueKey = 'NextICL'+@ICLCustomerCode+'InvoiceNumber'
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
		CLOSE ICLR92Cursor
		DEALLOCATE ICLR92Cursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ICLR92Cursor
		DEALLOCATE ICLR92Cursor
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
