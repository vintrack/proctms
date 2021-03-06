USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spAddPayrollExportRecord]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spAddPayrollExportRecord](
	@DriverID		int,
	@RunID			int,
	@PickupLocationID	int,
	@WhoCreated		varchar(20)	-- Can be either user name or application name
	)
AS
BEGIN
	/************************************************************************
	*	spAddPayrollExportRecord					*
	*									*
	*	Description							*
	*	-----------							*
	*	Adds a payroll export record for a run.			 	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/23/2005 CMK    Initial version				*
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	@RunDate		varchar(6),
		@ControlNumber		varchar(5),
		@StartedEmptyID		int,
		@ControlNumberRoot	int,
		@StartEmptyCity		varchar(13),
		@StartEmptyState	varchar(2),
		@StartEmptyZip		varchar(5),
		@PeriodRunNumber	varchar(2),
		@DriverNumber		varchar(5),
		@TruckNumber		varchar(20),
		@OriginID		int,
		@OriginAbbrev		varchar(3),
		@Manufacturer		varchar(30),
		@RoutingType		varchar(1),
		@PayType		varchar(2),
		@SubaruDiversifiedInd	varchar(1),
		@DestinationID		int,
		@DestinationCity	varchar(13),
		@DestinationState	varchar(2),
		@Units			int,
		@ExportedDate		datetime,
		@ExportedBy		varchar(20),
		@ExportedInd		int,
		@ExportBatchID		int,
		@CreationDate		datetime,
		@CreatedBy		varchar(20),
		@UpdatedDate		datetime,
		@UpdatedBy		varchar(20),
		@CustomerID		int,
		@RecordFoundInd		int,
		@PayrollExportID	int,
		@CustomerLocationCode	varchar(20),
		@CurrentUnits		int,
		@RecordCount		int,
		@ReturnCode		int,
		@ReturnMessage		varchar(50),
		@ErrorID		int,
		@Msg			varchar(50),
		@Count			int

	SELECT @Count = 0
	SELECT @ErrorID = 0
	
	--set the defaults
	SELECT @RoutingType= 'R'
	SELECT @PayType= 'FH'
	SELECT @ExportedDate = NULL
	SELECT @ExportedBy = NULL
	SELECT @ExportedInd = 0
	SELECT @ExportBatchID = NULL
	SELECT @CreationDate = getDate()
	SELECT @CreatedBy = @WhoCreated
	SELECT @UpdatedDate = NULL
	SELECT @UpdatedBy = NULL
	SELECT @RecordFoundInd = 0
	
	SELECT @RecordCount = COUNT(*)
	FROM PayrollExport
	WHERE RunID = @RunID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Setting NextControlNumber'
		GOTO Error_Encountered2
	END
	
	IF @RecordCount = 0
	BEGIN
		--we are creating new records
		--get the next control number
		Select @ControlNumberRoot = CONVERT(int,ValueDescription)
		FROM SettingTable
		WHERE ValueKey = 'NextControlNumber'
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Getting NextControlNumber'
			GOTO Error_Encountered2
		END
		
		--update the next control number
		UPDATE SettingTable
		SET ValueDescription = CONVERT(varchar(10),@ControlNumberRoot+1)
		WHERE ValueKey = 'NextControlNumber'
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Setting NextControlNumber'
			GOTO Error_Encountered2
		END
			
		SELECT @ControlNumber = 'Z'+REPLICATE('0',4-DATALENGTH(CONVERT(varchar(10),@ControlNumberRoot)))+CONVERT(varchar(10),@ControlNumberRoot)
	END
	ELSE
	BEGIN
		SELECT TOP 1 @ControlNumber = ControlNumber
		FROM PayrollExport
		WHERE RunID = @RunID
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Setting NextControlNumber'
			GOTO Error_Encountered2
		END
	END
	
	--get the origin abbrev
	SELECT @OriginAbbrev = NULL
	SELECT @OriginAbbrev = Value1
	FROM Code
	WHERE CodeType = 'OriginAbbreviation'
	AND Code = @PickupLocationID
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Getting CustomerID'
		GOTO Error_Encountered2
	END
	
	--get the run details
	DECLARE RunDetailsCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.CustomerID, CONVERT(varchar(6),R.RunStartDate,12), R.StartedEmptyFromID,
		L3.City, L3.State, L3.Zip,
		R.DriverRunNumber, D.DriverNumber,T.TruckNumber,
		L1.PickupLocationID, C.CustomerName,
		L1.DropoffLocationID, L4.City, L4.State,
		COUNT(*), L5.CustomerLocationCode
		FROM Legs L1
		LEFT JOIN Loads L2 ON L1.LoadID = L2.LoadsID
		LEFT JOIN Run R ON L2.RunID = R.RunID
		LEFT JOIN Vehicle V ON L1.VehicleID = V.VehicleID
		LEFT JOIN Location L3 ON R.StartedEmptyFromID = L3.LocationID
		LEFT JOIN Driver D ON R.DriverID = D.DriverID
		LEFT JOIN Truck T ON T.TruckID = R.TruckID
		LEFT JOIN Location L4 ON L1.DropoffLocationID = L4.LocationID
		LEFT JOIN Location L5 ON L1.PickupLocationID = L5.LocationID
		LEFT JOIN Customer C ON V.CustomerID = C.CustomerID
		WHERE R.RunID = @RunID
		AND L1.PickupLocationID = @PickupLocationID
		GROUP BY V.CustomerID,R.RunStartDate, R.StartedEmptyFromID,
		L3.City, L3.State, L3.Zip,
		R.DriverRunNumber, D.DriverNumber, T.TruckNumber,
		L1.PickupLocationID, C.CustomerName,
		L1.DropoffLocationID, L4.City, L4.State, L5.CustomerLocationCode
	
	OPEN RunDetailsCursor
	
	BEGIN TRAN
	
	FETCH RunDetailsCursor INTO @CustomerID, @RunDate, @StartedEmptyID, @StartEmptyCity, @StartEmptyState,
		@StartEmptyZip, @PeriodRunNumber, @DriverNumber, @TruckNumber, @OriginID,
		@Manufacturer, @DestinationID, @DestinationCity, @DestinationState, @Units, @CustomerLocationCode
			
	
	WHILE @@FETCH_STATUS = 0
	BEGIN

		SELECT @RecordFoundInd = 1		
		
		IF @CustomerID = 3495 --soa
		BEGIN
			 SELECT @SubaruDiversifiedInd = 'S'
		END		
		ELSE IF @CustomerID = 3494 --sdc
		BEGIN
			SELECT @SubaruDiversifiedInd = 'D'
		END
		ELSE IF @CustomerID = 2651 --nissan
		BEGIN
			SELECT @SubaruDiversifiedInd = 'N'
		END
		ELSE IF @CustomerID = 2510 --mitsubishi
		BEGIN
			SELECT @SubaruDiversifiedInd = 'M'
		END
		ELSE
		BEGIN
			SELECT @SubaruDiversifiedInd = 'D'
		END
			
		SELECT @RecordFoundInd = COUNT(*)
		FROM PayrollExport
		WHERE RunID = @RunID
		AND OriginID = @OriginID
		AND DestinationID = @DestinationID
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered checking for duplicate RunStops Record'
			GOTO Error_Encountered
		END
		
		IF @RecordFoundInd = 0
		BEGIN
			--insert the record
			INSERT INTO PayrollExport(
				RunID,
				RunDate,
				ControlNumber,
				StartedEmptyID,
				StartEmptyCity,
				StartEmptyState,
				StartEmptyZip,
				PeriodRunNumber,
				DriverNumber,
				TruckNumber,
				OriginID,
				OriginAbbrev,
				Manufacturer,
				RoutingType,
				PayType,
				SubaruDiversifiedInd,
				DestinationID,
				DestinationCity,
				DestinationState,
				Units,
				ExportedDate,
				ExportedBy,
				ExportedInd,
				ExportBatchID,
				CreationDate,
				CreatedBy,
				UpdatedDate,
				UpdatedBy
			)
			VALUES(
				@RunID,
				@RunDate,
				@ControlNumber,
				@StartedEmptyID,
				@StartEmptyCity,
				@StartEmptyState,
				@StartEmptyZip,
				@PeriodRunNumber,
				@DriverNumber,
				@TruckNumber,
				@OriginID,
				ISNULL(@OriginAbbrev,@CustomerLocationCode),
				@Manufacturer,
				@RoutingType,
				@PayType,
				@SubaruDiversifiedInd,
				@DestinationID,
				@DestinationCity,
				@DestinationState,
				@Units,
				@ExportedDate,
				@ExportedBy,
				@ExportedInd,
				@ExportBatchID,
				@CreationDate,
				@CreatedBy,
				@UpdatedDate,
				@UpdatedBy
			)
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered creating the RunsStops Record'
				GOTO Error_Encountered
			END
		END
		ELSE
		BEGIN
			--SEE IF WE NEED TO UPDATE THE RECORD
			SELECT TOP 1 @PayrollExportID = PayrollExportID, @CurrentUnits = Units
			FROM PayrollExport
			WHERE RunID = @RunID
			AND OriginID = @OriginID
			AND DestinationID = @DestinationID
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered getting RunsStops Record'
				GOTO Error_Encountered
			END
			
			IF @Units <> @CurrentUnits
			BEGIN
				UPDATE PayrollExport
				SET Units = @Units
				WHERE PayrollExportID = @PayrollExportID
				IF @@ERROR <> 0
				BEGIN
					SELECT @ErrorID = @@ERROR
					SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' updating RunsStops Record'
					GOTO Error_Encountered
				END
			END
		END
		
		FETCH RunDetailsCursor INTO @CustomerID, @RunDate, @StartedEmptyID, @StartEmptyCity, @StartEmptyState,
			@StartEmptyZip, @PeriodRunNumber, @DriverNumber, @TruckNumber, @OriginID,
			@Manufacturer, @DestinationID, @DestinationCity, @DestinationState, @Units, @CustomerLocationCode
			
	END --end of loop
		
	--see if any stops need to be removed
	DECLARE RunStopsCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT PayrollExportID, OriginID, DestinationID
		FROM PayrollExport
		WHERE RunID = @RunID
	
	OPEN RunStopsCursor
	
	FETCH RunStopsCursor INTO @PayrollExportID, @OriginID, @DestinationID
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @RecordCount = COUNT(*)
		FROM Loads L
		LEFT JOIN Legs L2 ON L.LoadsID = L2.LoadID
		WHERE L.RunID = @RunID
		AND L2.PickupLocationID = @OriginID
		AND L2.DropoffLocationID = @DestinationID
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' getting vehicle count'
			GOTO Error_Encountered
		END
		
		IF @RecordCount = 0
		BEGIN
			DELETE PayrollExport
			WHERE PayrollExportID = @PayrollExportID
			IF @@ERROR <> 0
			BEGIN
				SELECT @ErrorID = @@ERROR
				SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' deleting old stop'
				GOTO Error_Encountered
			END
		END
		
		FETCH RunStopsCursor INTO @PayrollExportID, @OriginID, @DestinationID
	END
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE RunDetailsCursor
		DEALLOCATE RunDetailsCursor
		CLOSE RunStopsCursor
		DEALLOCATE RunStopsCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Payroll Export Record Created Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE RunDetailsCursor
		DEALLOCATE RunDetailsCursor
		CLOSE RunStopsCursor
		DEALLOCATE RunStopsCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Msg
		GOTO Do_Return
	END
	
	Error_Encountered2:
	IF @ErrorID = 0
	BEGIN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Payroll Export Record Created Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Msg
		GOTO Do_Return
	END
	
	Do_Return:
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage
	
	RETURN
END

GO
