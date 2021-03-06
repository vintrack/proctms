USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateVISTA630Data]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateVISTA630Data] (@OriginID int, @OriginSPLC varchar(10), @CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	--ExportVISTA630 table variables
	@BatchID			int,
	@CustomerID			int,
	@InterchangeSenderID		varchar(15),
	@InterchangeReceiverID		varchar(15),
	@FunctionalID			varchar(2),
	@SenderCode			varchar(12),
	@ReceiverCode			varchar(12),
	@TransmissionDateTime		datetime,
	@InterchangeControlNumber	int,
	@ResponsibleAgencyCode		varchar(2),
	@VersionNumber			varchar(12),
	@TransactionSetControlNumber	varchar(9),
	@SCAC				varchar(4),
	@ContractNumber			varchar(8),
	@ContractEffectiveDate		datetime,
	@RateEffectiveDate		datetime,
	@RoundingCode			varchar(1),
	@ContractTerminationDate	datetime,
	@RateTerminationDate		datetime,
	@TariffAgencyCode		varchar(4),
	@Exparte			varchar(5),
	@ExparteEffectiveDate		datetime,
	@TariffSupplementNumber		varchar(5),
	@FundsCode			varchar(1),
	@CanadianSurchargeIndicator	varchar(1),
	@TariffBasisContractNumber	varchar(8),
	@Currency			varchar(3),
	@RateValueQualifier		varchar(2),
	@VehicleClassification		varchar(1),
	@FreightRate			varchar(9),
	@TariffItemNumber		varchar(10),
	@CarrierModeClassification	varchar(2),
	@DealerIdentificationNumber	varchar(5),
	@CityName			varchar(19),
	@StateOrProvinceCode		varchar(2),
	@Address			varchar(35),
	@DealerName			varchar(30),
	@DestinationSPLC		varchar(9),
	@SpecialServicesCode		varchar(9),
	@DistanceQualifier		varchar(1),
	@TariffDistance			varchar(5),
	@SpecialRateCode		varchar(1),
	@SpecialPlantCode		varchar(1),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	--processing variables
	@RateClass			varchar(20),
	@Year				varchar(2),
	@CarrierIDNumber		varchar(1),
	@LoadSize			int,
	@LoopCounter			int,
	@SequenceNumber			int,
	@NextChryslerInvoiceNumber	int,
	@ChryslerInvoicePrefix		varchar(10),
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100)	

	/************************************************************************
	*	spGenerateVISTA510Data						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the VISTA 630 export data for Chrysler	*
	*	rates.								*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/07/2007 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the customer id from the setting table
	SELECT @CustomerID = CONVERT(int,ValueDescription)
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
	SELECT @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextVISTA630ExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting BatchID'
		GOTO Error_Encountered2
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Status = 'BatchID Not Found'
		GOTO Error_Encountered2
	END
	
	DECLARE VISTA630ExportCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT CR.RateType, CONVERT(varchar(9),(CONVERT(int,(CR.Rate*10000)))),
		L.CustomerLocationCode, L.SPLCCode, CONVERT(varchar(5),CONVERT(int,ROUND(CR.Mileage,0))),
		CR.StartDate
		FROM ChargeRate CR
		LEFT JOIN Location L ON CR.EndLocationID = L.LocationID
		WHERE CR.CustomerID = @CustomerID
		AND CR.StartLocationID = @OriginID	-- want to do each railyard separately
		AND (CR.EndDate IS NULL
		OR CR.EndDate >= CURRENT_TIMESTAMP)
		AND CR.StartDate < DATEADD(day,1,CONVERT(varchar(10),CURRENT_TIMESTAMP,101))
		ORDER BY L.CustomerLocationCode, CR.RateType

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN VISTA630ExportCursor

	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextVISTA630ExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END
	
	--set the default values
	SELECT @LoopCounter = 0
	SELECT @InterchangeSenderID = '58792'
	SELECT @InterchangeReceiverID = 'VISTA'
	SELECT @FunctionalID = 'VI'
	SELECT @SenderCode = 'DVAI'
	SELECT @ReceiverCode = 'VISTA'
	SELECT @TransmissionDateTime = NULL --value set during export
	SELECT @InterchangeControlNumber = NULL --value set during export
	SELECT @ResponsibleAgencyCode = 'T'
	SELECT @VersionNumber = '1'
	SELECT @TransactionSetControlNumber = NULL --value set during export
	SELECT @SCAC = 'DVAI'
	IF @OriginID = 12570 -- selkirk
	BEGIN
		SELECT @ContractNumber = 'DVAISK07'
	END
	ELSE IF @OriginID = 12571 -- brookfield
	BEGIN
		SELECT @ContractNumber = 'DVAIEB07'
	END
	ELSE
	BEGIN
		SELECT @ErrorID = 100003
		SELECT @Status = 'CONTRACT NOT SET UP'
		GOTO Error_Encountered
	END
	SELECT @ContractEffectiveDate = '03/02/2007'
	--SELECT @RateEffectiveDate = '03/02/2007'
	SELECT @RoundingCode = 'P'
	SELECT @ContractTerminationDate = NULL
	SELECT @RateTerminationDate = NULL
	SELECT @TariffAgencyCode = 'DVAI'
	SELECT @Exparte = NULL
	SELECT @ExparteEffectiveDate = NULL
	SELECT @TariffSupplementNumber = NULL
	SELECT @FundsCode = 'U'
	SELECT @CanadianSurchargeIndicator = ' '
	SELECT @TariffBasisContractNumber = NULL
	SELECT @Currency = NULL
	SELECT @RateValueQualifier = 'HL'
	SELECT @TariffItemNumber = NULL
	SELECT @CarrierModeClassification = NULL
	SELECT @CityName = NULL
	SELECT @StateOrProvinceCode = NULL
	SELECT @Address = NULL
	SELECT @DealerName = NULL
	SELECT @SpecialServicesCode = NULL			
	SELECT @DistanceQualifier = 'T'
	SELECT @SpecialRateCode = NULL
	SELECT @SpecialPlantCode = NULL
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	
	FETCH VISTA630ExportCursor INTO @RateClass, @FreightRate, @DealerIdentificationNumber,
		@DestinationSPLC, @TariffDistance, @RateEffectiveDate
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @LoopCounter = @LoopCounter + 1
		
		IF @RateClass = 'Size A Rate'
		BEGIN
			SELECT @VehicleClassification = 'C'
		END
		ELSE IF @RateClass = 'Size B Rate'
		BEGIN
			SELECT @VehicleClassification = 'M'
		END
		ELSE IF @RateClass = 'Size C Rate'
		BEGIN
			SELECT @VehicleClassification = 'T'
		END
		
		INSERT INTO ExportVISTA630(
			BatchID,
			CustomerID,
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
			SCAC,
			OriginSPLC,
			ContractNumber,
			ContractEffectiveDate,
			RateEffectiveDate,
			RoundingCode,
			ContractTerminationDate,
			RateTerminationDate,
			TariffAgencyCode,
			Exparte,
			ExparteEffectiveDate,
			TariffSupplementNumber,
			FundsCode,
			CanadianSurchargeIndicator,
			TariffBasisContractNumber,
			Currency,
			RateValueQualifier,
			VehicleClassification,
			FreightRate,
			TariffItemNumber,
			CarrierModeClassification,
			DealerIdentificationNumber,
			CityName,
			StateOrProvinceCode,
			Address,
			DealerName,
			DestinationSPLC,
			SpecialServicesCode,
			DistanceQualifier,
			TariffDistance,
			SpecialRateCode,
			SpecialPlantCode,
			ExportedInd,
			ExportedDate,
			ExportedBy,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@CustomerID,
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
			@SCAC,
			@OriginSPLC,
			@ContractNumber,
			@ContractEffectiveDate,
			@RateEffectiveDate,
			@RoundingCode,
			@ContractTerminationDate,
			@RateTerminationDate,
			@TariffAgencyCode,
			@Exparte,
			@ExparteEffectiveDate,
			@TariffSupplementNumber,
			@FundsCode,
			@CanadianSurchargeIndicator,
			@TariffBasisContractNumber,
			@Currency,
			@RateValueQualifier,
			@VehicleClassification,
			@FreightRate,
			@TariffItemNumber,
			@CarrierModeClassification,
			@DealerIdentificationNumber,
			@CityName,
			@StateOrProvinceCode,
			@Address,
			@DealerName,
			@DestinationSPLC,
			@SpecialServicesCode,
			@DistanceQualifier,
			@TariffDistance,
			@SpecialRateCode,
			@SpecialPlantCode,
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
			
		FETCH VISTA630ExportCursor INTO @RateClass, @FreightRate, @DealerIdentificationNumber,
			@DestinationSPLC, @TariffDistance, @RateEffectiveDate

	END --end of loop
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE VISTA630ExportCursor
		DEALLOCATE VISTA630ExportCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE VISTA630ExportCursor
		DEALLOCATE VISTA630ExportCursor
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
