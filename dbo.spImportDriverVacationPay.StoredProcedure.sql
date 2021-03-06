USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spImportDriverVacationPay]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spImportDriverVacationPay] (@BatchID int, @UserCode varchar(20))
AS
BEGIN
	DECLARE	--DriverVacationPayImport Table Variables
	@DriverVacationPayImportID	int,
	@DriverNumber			varchar(20),
	@DriverName			varchar(100),
	@PostedDate			datetime,
	@VacationPay			decimal(19,2),
	@RecordStatus			varchar(100),
	--Payroll Table Variables
	@PayrollID			int,
	@DriverID			int,
	@PayrollRecordType		varchar(20),
	@PayPeriodYear			int,
	@PayPeriod			int,
	@RunID				int,
	@ControlNumber			varchar(10),
	@Mileage			decimal(19,2),
	@MileageOverrideInd		int,
	@MileagePayCalcType		int,
	@MileagePayRate			decimal(19,2),
	@MileagePayRateOverrideInd	int,
	@MileagePay			decimal(19,2),
	@MileagePayOverrideInd		int,
	@HaulType			varchar(20),
	@ShortHaulPay			decimal(19,2),
	@MaxVehiclesInLoad		int,
	@MaxVehiclesInLoadOverrideInd	int,
	@TotalUnits			int,
	@LoadingRate			decimal(19,2),
	@LoadingRateOverrideInd		int,
	@LoadingPay			decimal(19,2),
	@NumberOfSkidDrops		int,
	@SkidDropRate			decimal(19,2),
	@SkidDropRateOverrideInd	int,
	@SkidDropPay			decimal(19,2),
	@NumberOfReloads		int,
	@ReloadRate			decimal(19,2),
	@ReloadRateOverrideInd		int,
	@ReloadPay			decimal(19,2),
	@NumberOfShagUnits		int,
	@ShagUnitRate			decimal(19,2),
	@ShagUnitRateOverrideInd	int,
	@ShagUnitPay			decimal(19,2),
	@AuctionPay			decimal(19,2),
	@AuctionPayOverrideInd		int,
	@OtherPay1Description		varchar(30),
	@OtherPay1			decimal(19,2),
	@OtherPay2Description		varchar(30),
	@OtherPay2			decimal(19,2),
	@OtherPay3Description		varchar(30),
	@OtherPay3			decimal(19,2),
	@OtherPay4Description		varchar(30),
	@OtherPay4			decimal(19,2),
	@TotalPay			decimal(19,2),
	@PaperworkReceivedInd		int,
	@PaperworkReceivedDate		datetime,
	@PayrollRecordDate		datetime,
	@PaidInd			int,
	@PaidDate			datetime,
	@AmountPaid			decimal(19,2),
	@Comments			varchar(255),
	@PayrollRecordStatus		varchar(20),
	@ReviewedInd			int,
	@ReviewedBy			varchar(20),
	@CreationDate			datetime,
	@CreatedBy			varchar(20),
	--Processing Variables
	@ErrorID			int,
	@PostedDateDate			datetime,
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@ExceptionEncounteredInd	int,
	@RowCount			int,
	@loopcounter			int

	/************************************************************************
	*	spImportDriverVacationPay					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure takes the data from the DriverVacationPayImport	*
	*	table and creates new driver payroll records.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	08/24/2006 CMK    Initial version				*
	*									*
	************************************************************************/
	
	set nocount on
	/* Declare the main processing cursor */
	DECLARE ImportVacationPayCursor INSENSITIVE CURSOR
	FOR
	SELECT DriverVacationPayImportID, DriverNumber, DriverName,
	PostedDate, VacationPay
	FROM DriverVacationPayImport
	WHERE BatchID = @BatchID
	ORDER BY DriverNumber

	SELECT @loopcounter = 0
	OPEN ImportVacationPayCursor
	
	BEGIN TRAN
	
	SELECT @RowCount = @@cursor_rows
	SELECT @ExceptionEncounteredInd = 0
	
	FETCH ImportVacationPayCursor INTO @DriverVacationPayImportID, @DriverNumber,
		@DriverName, @PostedDate, @VacationPay
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--Reset the Processing Variables
		SELECT @ErrorID = 0
		
		--print 'posted date = ' +@postedDate
		print 'posted date converted = ' +convert(varchar(10),@posteddate,101)
		--SELECT @PostedDateDate = @PostedDate
		
		--Set the default values
		SELECT @PayrollRecordType = 'BenefitPay'
		SELECT @RunID = NULL
		SELECT @ControlNumber = NULL
		SELECT @Mileage = 0
		SELECT @MileageOverrideInd = 0
		SELECT @MileagePayCalcType = 0
		SELECT @MileagePayRate = 0
		SELECT @MileagePayRateOverrideInd = 0
		SELECT @MileagePay = 0
		SELECT @MileagePayOverrideInd = 0
		SELECT @HaulType = 'N/A'
		SELECT @ShortHaulPay = 0
		SELECT @MaxVehiclesInLoad = 0
		SELECT @MaxVehiclesInLoadOverrideInd = 0
		SELECT @TotalUnits = 0
		SELECT @LoadingRate = 0
		SELECT @LoadingRateOverrideInd = 0
		SELECT @LoadingPay = 0
		SELECT @NumberOfSkidDrops = 0
		SELECT @SkidDropRate = 0
		SELECT @SkidDropRateOverrideInd = 0
		SELECT @SkidDropPay = 0
		SELECT @NumberOfReloads = 0
		SELECT @ReloadRate = 0
		SELECT @ReloadRateOverrideInd = 0
		SELECT @ReloadPay = 0
		SELECT @NumberOfShagUnits = 0
		SELECT @ShagUnitRate = 0
		SELECT @ShagUnitRateOverrideInd = 0
		SELECT @ShagUnitPay = 0
		SELECT @AuctionPay = 0
		SELECT @AuctionPayOverrideInd = 0
		SELECT @OtherPay1Description = 'VacationPay'
		SELECT @OtherPay1 = CONVERT(decimal(19,2),@VacationPay)
		SELECT @OtherPay2Description = 'N/A'
		SELECT @OtherPay2 = 0
		SELECT @OtherPay3Description = 'N/A'
		SELECT @OtherPay3 = 0
		SELECT @OtherPay4Description = 'N/A'
		SELECT @OtherPay4 = 0
		SELECT @TotalPay = CONVERT(decimal(19,2),@VacationPay)
		SELECT @PaperworkReceivedInd = 0
		SELECT @PaperworkReceivedDate = NULL
		SELECT @PayrollRecordDate = @PostedDate
		SELECT @PaidInd = 1
		SELECT @PaidDate = @PostedDate
		SELECT @AmountPaid = CONVERT(decimal(19,2),@VacationPay)
		SELECT @Comments = ''
		SELECT @PayrollRecordStatus = 'Paid'
		SELECT @ReviewedInd = 1
		SELECT @ReviewedBy = NULL
		SELECT @CreationDate = CURRENT_TIMESTAMP
		SELECT @CreatedBy = 'Vac Pay Impt'
				
		-- get the driverid
		SELECT @DriverID = NULL
		
		SELECT TOP 1 @DriverID = DriverID
		FROM Driver
		WHERE DriverNumber = @DriverNumber
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Status = 'Error Getting Driver Info'
			GOTO Error_Encountered
		END
		IF @DriverID IS NULL
		BEGIN
			SELECT @RecordStatus = 'DRIVER NOT FOUND'
			SELECT @ErrorID = 100000
			GOTO End_Of_Loop
		END
		
		-- get the pay period
		SELECT TOP 1 @PayPeriodYear = CalendarYear,
		@PayPeriod = PeriodNumber
		FROM PayPeriod
		WHERE  PeriodEndDate >= @PostedDate
		ORDER BY PeriodEndDate
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Status = 'Error Getting Pay Period Info'
			GOTO Error_Encountered
		END
		IF @PayPeriodYear IS NULL OR @PayPeriod IS NULL
		BEGIN
			SELECT @RecordStatus = 'PAY PERIOD NOT FOUND'
			SELECT @ErrorID = 100001
			GOTO End_Of_Loop
		END
		
		--Insert the Payroll record
		INSERT INTO Payroll (
			DriverID,
			PayrollRecordType,
			PayPeriodYear,
			PayPeriod,
			RunID,
			ControlNumber,
			Mileage,
			MileageOverrideInd,
			MileagePayCalcType,
			MileagePayRate,
			MileagePayRateOverrideInd,
			MileagePay,
			MileagePayOverrideInd,
			HaulType,
			ShortHaulPay,
			MaxVehiclesInLoad,
			MaxVehiclesInLoadOverrideInd,
			TotalUnits,
			LoadingRate,
			LoadingRateOverrideInd,
			LoadingPay,
			NumberOfSkidDrops,
			SkidDropRate,
			SkidDropRateOverrideInd,
			SkidDropPay,
			NumberOfReloads,
			ReloadRate,
			ReloadRateOverrideInd,
			ReloadPay,
			NumberOfShagUnits,
			ShagUnitRate,
			ShagUnitRateOverrideInd,
			ShagUnitPay,
			AuctionPay,
			AuctionPayOverrideInd,
			OtherPay1Description,
			OtherPay1,
			OtherPay2Description,
			OtherPay2,
			OtherPay3Description,
			OtherPay3,
			OtherPay4Description,
			OtherPay4,
			TotalPay,
			PaperworkReceivedInd,
			PaperworkReceivedDate,
			PayrollRecordDate,
			PaidInd,
			PaidDate,
			AmountPaid,
			Comments,
			PayrollRecordStatus,
			ReviewedInd,
			ReviewedBy,
			CreationDate,
			CreatedBy
		)
		VALUES (
			@DriverID,
			@PayrollRecordType,
			@PayPeriodYear,
			@PayPeriod,
			@RunID,
			@ControlNumber,
			@Mileage,
			@MileageOverrideInd,
			@MileagePayCalcType,
			@MileagePayRate,
			@MileagePayRateOverrideInd,
			@MileagePay,
			@MileagePayOverrideInd,
			@HaulType,
			@ShortHaulPay,
			@MaxVehiclesInLoad,
			@MaxVehiclesInLoadOverrideInd,
			@TotalUnits,
			@LoadingRate,
			@LoadingRateOverrideInd,
			@LoadingPay,
			@NumberOfSkidDrops,
			@SkidDropRate,
			@SkidDropRateOverrideInd,
			@SkidDropPay,
			@NumberOfReloads,
			@ReloadRate,
			@ReloadRateOverrideInd,
			@ReloadPay,
			@NumberOfShagUnits,
			@ShagUnitRate,
			@ShagUnitRateOverrideInd,
			@ShagUnitPay,
			@AuctionPay,
			@AuctionPayOverrideInd,
			@OtherPay1Description,
			@OtherPay1,
			@OtherPay2Description,
			@OtherPay2,
			@OtherPay3Description,
			@OtherPay3,
			@OtherPay4Description,
			@OtherPay4,
			@TotalPay,
			@PaperworkReceivedInd,
			@PaperworkReceivedDate,
			@PayrollRecordDate,
			@PaidInd,
			@PaidDate,
			@AmountPaid,
			@Comments,
			@PayrollRecordStatus,
			@ReviewedInd,
			@ReviewedBy,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Status = 'Error Inserting Payroll Record'
			GOTO Error_Encountered
		END
		
		SELECT @PayrollID = @@IDENTITY
			
		SELECT @RecordStatus = 'Imported'
		
		-- add payroll line items record
		INSERT INTO PayrollLineItems(
			PayrollID,
			DriverID,
			PayPeriodYear,
			PayPeriod,
			DatePaid,
			AmountPaid,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@PayrollID,
			@DriverID,
			@PayPeriodYear,
			@PayPeriod,
			@PaidDate,
			@AmountPaid,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Status = 'Error Inserting Payroll Line Items Record'
			GOTO Error_Encountered
		END
		
		End_Of_Loop:
		IF @ErrorID <> 0
		BEGIN
			print 'excpetion encountered'
			SELECT @ExceptionEncounteredInd = 1
		END
					
		--update the import record
		UPDATE DriverVacationPayImport
		SET RecordStatus = @RecordStatus
		WHERE DriverVacationPayImportID = @DriverVacationPayImportID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@Error
			SELECT @Status = 'Error Updating Record Status'
			GOTO Error_Encountered
		END
		
		FETCH ImportVacationPayCursor INTO @DriverVacationPayImportID, @DriverNumber,
			@DriverName, @PostedDate, @VacationPay
	END
	SELECT @ErrorID = 0 --if we got to this point this should be fine
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE ImportVacationPayCursor
		DEALLOCATE ImportVacationPayCursor
		SELECT @ReturnCode = 0
		IF @ExceptionEncounteredInd = 0
		BEGIN
			SELECT @ReturnMessage = 'Processing Completed Successfully'
		END
		ELSE
		BEGIN
			SELECT @ReturnMessage = 'Processing Completed Successfully, but with exceptions'
		END
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE ImportVacationPayCursor
		DEALLOCATE ImportVacationPayCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
	END
	
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage
	
	RETURN
END
GO
