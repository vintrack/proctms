USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateFoxProExportData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateFoxProExportData] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	@loopcounter		int,
	--ExportICLR41 table variables
	@ExportFoxProUpdateID	int,
	@BatchID		int,
	@VehicleID		int,
	@DriverID		int,
	@TruckID		int,
	@VINKey			varchar(8),
	@DateOut		datetime,
	@ShippedInd		varchar(10),
	@DamageInsType		varchar(10),
	@DriverNumber		varchar(10),
	@DriverName		varchar(60),
	@TruckNumber		varchar(10),
	@DamageCode1		varchar(5),
	@DamageCode2		varchar(5),
	@DamageCode3		varchar(5),
	@DamageCode4		varchar(5),
	@DamageCode5		varchar(5),
	@DamageCode6		varchar(5),
	@DamageCode7		varchar(5),
	@DamageCode8		varchar(5),
	@DamageCode9		varchar(5),
	@DamageCode10		varchar(5),
	@MasterFrom		varchar(10),
	@MasterLoads		varchar(10),
	@ControlNumber		varchar(20),
	@OriginZip		varchar(14),
	@OriginState		varchar(2),
	@OriginCity		varchar(30),
	@ExportedInd		int,
	@ExportedDate		datetime,
	@ExportedBy		varchar(20),
	@RecordStatus		varchar(100),
	@CreationDate		datetime,
	--processing variables
	@CustomerID		int,
	@PickupLocationID	int,
	@Status			varchar(100),
	@ReturnCode		int,
	@ReturnMessage		varchar(100)	

	/************************************************************************
	*	spGenerateFoxProExportData					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the FoxPro export data for SDC 	*
	*	vehicles that have been picked up or delivered.			*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/30/2005 CMK    Initial version				*
	*	09/13/2007 CMK    Removed Damage Queries From Cursor, too slow	*
	*									*
	************************************************************************/
	
	--get the customer id from the setting table
	Select @CustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SDCCustomerID'
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
	
	--get the dai location id
	SELECT @PickupLocationID = CONVERT(int,Value1)
	FROM Code
	WHERE CodeType = 'SDCLocationCode'
	AND Code = 'DAI' --ALL SDC LOADS ORIGINATE FROM CHARLESTOWN
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'ERROR GETTING ORIGIN LOCATION'
		GOTO Error_Encountered2
	END
	
	--get the next batch id from the setting table
	Select @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextFoxProExportID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting BatchID'
		GOTO Error_Encountered2
	END
	
	--get the data
	print 'declaring cursor'
	DECLARE FoxProExportCursor CURSOR
	LOCAL FAST_FORWARD READ_ONLY
	--LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT DISTINCT V.VehicleID
		FROM Vehicle V WITH (NOLOCK)
		WHERE V.CustomerID = @CustomerID
		AND V.VehicleStatus IN ('EnRoute','Delivered')
		AND V.VehicleID NOT IN (SELECT EFPU.VehicleID FROM ExportFoxProUpdate EFPU WHERE EFPU.VehicleID IS NOT NULL)
		AND V.PickupLocationID = @PickupLocationID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	print 'about to open cursor'
	OPEN FoxProExportCursor
	print 'opened cursor'
	BEGIN TRAN
	print 'starting tran'
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextFoxProExportID'
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
	print 'about to fetch'
	FETCH FoxProExportCursor INTO @VehicleID
	
	print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT DISTINCT TOP 1 @DriverID = D.DriverID, @TruckID = T.TruckID, @VINKey = RIGHT(V.VIN,8),
		@DateOut = L.PickupDate, @ShippedInd = 'S', @DamageInsType = 'D',
		@DriverNumber = CASE WHEN L2.OutsideCarrierLoadInd = 1 OR D.OutsideCarrierInd = 1 THEN '100' ELSE D.DriverNumber END,
		@DriverName = CASE WHEN L2.OutsideCarrierLoadInd = 1 OR D.OutsideCarrierInd = 1 THEN 'Broker' ELSE SUBSTRING(U.FirstName,1,1)+' '+U.LastName END,
		@TruckNumber = CASE WHEN L2.OutsideCarrierLoadInd = 1 OR D.OutsideCarrierInd = 1 THEN '001' ELSE T.TruckNumber END,
		@MasterFrom = 'DIV',
		@MasterLoads = CASE WHEN L2.OutsideCarrierLoadInd = 1 OR D.OutsideCarrierInd = 1 THEN '1' ELSE R.DriverRunNumber END,
		@ControlNumber = RIGHT(L2.LoadNumber,5),
		@OriginZip = CASE WHEN L2.OutsideCarrierLoadInd = 1 OR D.OutsideCarrierInd = 1 THEN '02129' ELSE L3.Zip END,
		@OriginState = CASE WHEN L2.OutsideCarrierLoadInd = 1 OR D.OutsideCarrierInd = 1 THEN 'MA' ELSE L3.State END,
		@OriginCity = CASE WHEN L2.OutsideCarrierLoadInd = 1 OR D.OutsideCarrierInd = 1 THEN 'Charlestown' ELSE L3.City END
		FROM Vehicle V WITH (NOLOCK)
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.PickupLocationID = V.PickupLocationID
		LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
		LEFT JOIN Run R ON L2.RunID = R.RunID
		LEFT JOIN Driver D ON R.DriverID = D.DriverID
		OR L2.DriverID = D.DriverID
		LEFT JOIN Users U ON D.UserID = U.UserID
		LEFT JOIN Truck T ON R.TruckID = T.TruckID
		LEFT JOIN RunStops RS ON R.RunID = RS.RunID
		AND RS.RunStopNumber = 1
		LEFT JOIN Location L3 ON RS.LocationID = L3.LocationID
		WHERE V.VehicleID = @VehicleID
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Damage Code 1'
			GOTO Error_Encountered
		END
		
		SELECT @DamageCode1 = NULL
		SELECT @DamageCode2 = NULL
		SELECT @DamageCode3 = NULL
		SELECT @DamageCode4 = NULL
		SELECT @DamageCode5 = NULL
		SELECT @DamageCode6 = NULL
		SELECT @DamageCode7 = NULL
		SELECT @DamageCode8 = NULL
		SELECT @DamageCode9 = NULL
		SELECT @DamageCode10 = NULL
		
		SELECT TOP 1 @DamageCode1 = VDD.DamageCode
		FROM VehicleInspection VI
		LEFT JOIN VehicleDamageDetail VDD ON VI.VehicleInspectionID = VDD.VehicleInspectionID
		WHERE  VI.VehicleID = @VehicleID
		AND VI.InspectionType = 2
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Damage Code 1'
			GOTO Error_Encountered
		END
		
		SELECT TOP 1 @DamageCode2 = VDD.DamageCode
		FROM VehicleInspection VI
		LEFT JOIN VehicleDamageDetail VDD ON VI.VehicleInspectionID = VDD.VehicleInspectionID
		WHERE  VI.VehicleID = @VehicleID
		AND VI.InspectionType = 2
		AND VDD.DamageCode NOT IN (@DamageCode1)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Damage Code 2'
			GOTO Error_Encountered
		END
		
		SELECT TOP 1 @DamageCode3 = VDD.DamageCode
		FROM VehicleInspection VI
		LEFT JOIN VehicleDamageDetail VDD ON VI.VehicleInspectionID = VDD.VehicleInspectionID
		WHERE  VI.VehicleID = @VehicleID
		AND VI.InspectionType = 2
		AND VDD.DamageCode NOT IN (@DamageCode1, @DamageCode2)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Damage Code 3'
			GOTO Error_Encountered
		END
		
		SELECT TOP 1 @DamageCode4 = VDD.DamageCode
		FROM VehicleInspection VI
		LEFT JOIN VehicleDamageDetail VDD ON VI.VehicleInspectionID = VDD.VehicleInspectionID
		WHERE  VI.VehicleID = @VehicleID
		AND VI.InspectionType = 2
		AND VDD.DamageCode NOT IN (@DamageCode1, @DamageCode2, @DamageCode3)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Damage Code 4'
			GOTO Error_Encountered
		END
		
		SELECT TOP 1 @DamageCode5 = VDD.DamageCode
		FROM VehicleInspection VI
		LEFT JOIN VehicleDamageDetail VDD ON VI.VehicleInspectionID = VDD.VehicleInspectionID
		WHERE  VI.VehicleID = @VehicleID
		AND VI.InspectionType = 2
		AND VDD.DamageCode NOT IN (@DamageCode1, @DamageCode2, @DamageCode3, @DamageCode4)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Damage Code 5'
			GOTO Error_Encountered
		END
		
		SELECT TOP 1 @DamageCode6 = VDD.DamageCode
		FROM VehicleInspection VI
		LEFT JOIN VehicleDamageDetail VDD ON VI.VehicleInspectionID = VDD.VehicleInspectionID
		WHERE  VI.VehicleID = @VehicleID
		AND VI.InspectionType = 2
		AND VDD.DamageCode NOT IN (@DamageCode1, @DamageCode2, @DamageCode3, @DamageCode4, @DamageCode5)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Damage Code 6'
			GOTO Error_Encountered
		END
		
		SELECT TOP 1 @DamageCode7 = VDD.DamageCode
		FROM VehicleInspection VI
		LEFT JOIN VehicleDamageDetail VDD ON VI.VehicleInspectionID = VDD.VehicleInspectionID
		WHERE  VI.VehicleID = @VehicleID
		AND VI.InspectionType = 2
		AND VDD.DamageCode NOT IN (@DamageCode1, @DamageCode2, @DamageCode3, @DamageCode4, @DamageCode5,
		@DamageCode6)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Damage Code 7'
			GOTO Error_Encountered
		END
		
		SELECT TOP 1 @DamageCode8 = VDD.DamageCode
		FROM VehicleInspection VI
		LEFT JOIN VehicleDamageDetail VDD ON VI.VehicleInspectionID = VDD.VehicleInspectionID
		WHERE  VI.VehicleID = @VehicleID
		AND VI.InspectionType = 2
		AND VDD.DamageCode NOT IN (@DamageCode1, @DamageCode2, @DamageCode3, @DamageCode4, @DamageCode5,
		@DamageCode6, @DamageCode7)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Damage Code 8'
			GOTO Error_Encountered
		END
		
		SELECT TOP 1 @DamageCode9 = VDD.DamageCode
		FROM VehicleInspection VI
		LEFT JOIN VehicleDamageDetail VDD ON VI.VehicleInspectionID = VDD.VehicleInspectionID
		WHERE  VI.VehicleID = @VehicleID
		AND VI.InspectionType = 2
		AND VDD.DamageCode NOT IN (@DamageCode1, @DamageCode2, @DamageCode3, @DamageCode4, @DamageCode5,
		@DamageCode6, @DamageCode7, @DamageCode8)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Damage Code 9'
			GOTO Error_Encountered
		END
		
		SELECT TOP 1 @DamageCode10 = VDD.DamageCode
		FROM VehicleInspection VI
		LEFT JOIN VehicleDamageDetail VDD ON VI.VehicleInspectionID = VDD.VehicleInspectionID
		WHERE  VI.VehicleID = @VehicleID
		AND VI.InspectionType = 2
		AND VDD.DamageCode NOT IN (@DamageCode1, @DamageCode2, @DamageCode3, @DamageCode4, @DamageCode5,
		@DamageCode6, @DamageCode7, @DamageCode8, @DamageCode9)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Getting Damage Code 10'
			GOTO Error_Encountered
		END
		
		print 'about to insert'
		INSERT INTO ExportFoxProUpdate(
			BatchID,
			VehicleID,
			DriverID,
			TruckID,
			VINKey,
			DateOut,
			ShippedInd,
			DamageInsType,
			DriverNumber,
			DriverName,
			TruckNumber,
			DamageCode1,
			DamageCode2,
			DamageCode3,
			DamageCode4,
			DamageCode5,
			DamageCode6,
			DamageCode7,
			DamageCode8,
			DamageCode9,
			DamageCode10,
			MasterFrom,
			MasterLoads,
			ControlNumber,
			OriginZip,
			OriginState,
			OriginCity,
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
			@DriverID,
			@TruckID,
			@VINKey,
			@DateOut,
			@ShippedInd,
			@DamageInsType,
			@DriverNumber,
			@DriverName,
			@TruckNumber,
			@DamageCode1,
			@DamageCode2,
			@DamageCode3,
			@DamageCode4,
			@DamageCode5,
			@DamageCode6,
			@DamageCode7,
			@DamageCode8,
			@DamageCode9,
			@DamageCode10,
			@MasterFrom,
			@MasterLoads,
			@ControlNumber,
			@OriginZip,
			@OriginState,
			@OriginCity,
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
			SELECT @Status = 'Error Adding Export Record'
			GOTO Error_Encountered
		END
		print 'insert done'	
		FETCH FoxProExportCursor INTO @VehicleID

	END --end of loop
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		print 'no errors'
		COMMIT TRAN
		print 'about to close cursor'
		CLOSE FoxProExportCursor
		print 'about to deallocate cursor'
		DEALLOCATE FoxProExportCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		print 'errors'
		ROLLBACK TRAN
		print 'about to close cursor'
		CLOSE FoxProExportCursor
		print 'about to deallocate cursor'
		DEALLOCATE FoxProExportCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
	BEGIN
		print 'in error encountered 2, errorid 0'
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		print 'in error encountered 2, with errorid'
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END
	
	Do_Return:
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage, @BatchID AS BatchID
	
	RETURN
END
GO
