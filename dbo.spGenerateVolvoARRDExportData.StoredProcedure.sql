USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateVolvoARRDExportData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateVolvoARRDExportData] (@CreatedBy varchar(20))
AS
BEGIN

	set nocount on
	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	@BatchID			int,
	@VehicleID			int,
	@Constant			varchar(6),
	@VIN				varchar(17),
	@Ccode				varchar(5),
	@OccurenceCode			varchar(5),
	@ArrivalDateTime		datetime,
	@ExportedInd			int,
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	@VolvoCustomerID		int,
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@ReturnBatchID			int,
	@StartDate			datetime



	/************************************************************************

	*	spGenerateVolvoARRDExportData 					*
	*	This procedure generates the VolVO ARRD (Arrived Data) export	
	*	Volvo vehicles that have been delivered				*
	*	Change History							*
	*	--------------							*

	*	Date       Init's Description					*

	*	12/26/2017 SS    Initial version				*

	************************************************************************/

		--get the next batch id from the setting table

	SELECT @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextVolvoARRDExportBatchID'

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

	--print 'batchid = '+convert(varchar(20),@batchid)


	--get the volvo Customer ID

	SELECT @VolvoCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'VolvoCustomerID'

	IF @@ERROR <> 0
	BEGIN

		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting VolvoCustomerID'
		GOTO Error_Encountered2

	END

	IF @VolvoCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'VolvoCustomerID Not Found'
		GOTO Error_Encountered2
	END

	--print 'volvo customerid = '+convert(varchar(20),@gmcustomerid)

	

	--get the volvo cccode

	SELECT @Ccode = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'VolvoCcode'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting VolvoCcode'
		GOTO Error_Encountered2
	END

	IF @Ccode IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'VolvoCcode Not Found'
		GOTO Error_Encountered2
	END

	--print 'volvo ccode = '+convert(varchar(20),@volvoCcode)


	BEGIN TRAN
	--set the default values

	SELECT @Constant = 'L01OUS'
	SELECT @OccurenceCode = '10294'
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	SELECT @StartDate = '04/01/2018'

	

	DECLARE VolvoARRDCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID,V.VIN, L.DropOffDate 
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.FinalLegind=1
		WHERE  V.CustomerID = @VolvoCustomerID
		-- 6869
		AND V.VehicleStatus = 'Delivered'
		AND V.VehicleID NOT IN (SELECT E.VehicleID FROM VolvoExportARRD E WHERE E.VehicleID = V.VehicleID)
		AND L.DropoffDate >= '04/01/2018'
		ORDER BY L.DropOffDate
	

	--print 'cursor declared'

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0


	OPEN VolvoARRDCursor
	--print 'cursor opened'

	FETCH VolvoARRDCursor INTO @VehicleID, @VIN, @ArrivalDateTime 
	--print 'about to enter loop'

	WHILE @@FETCH_STATUS = 0
	BEGIN
		--print 'in loop'
		INSERT INTO VolvoExportARRD(
			BatchID,
			VehicleID,
			VIN,
			Constant,
			Ccode,
			OccurenceCode,
			ArrivalDateTime,
			ExportedInd,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@VIN,
			@Constant,
			@Ccode,
			@OccurenceCode,
			@ArrivalDateTime,
			@ExportedInd,
			@RecordStatus,
			@CreationDate,
			@CreatedBy
		)

		IF @@Error <> 0
		BEGIN

			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating VolvoARRD record'
			GOTO Error_Encountered

		END

					

		FETCH VolvoARRDCursor INTO @VehicleID, @VIN, @ArrivalDateTime


	END --end of loop

			

	--set the next batch id in the setting table

	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextVolvoARRDExportBatchID'
	IF @@ERROR <> 0
	BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Setting BatchID'
			GOTO Error_Encountered

	END

	--print 'batchid set'

	

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		--print 'error encountered = 0'

		COMMIT TRAN
		CLOSE VolvoARRDCursor
		DEALLOCATE VolvoARRDCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		SELECT @ReturnBatchID = @BatchID
		GOTO Do_Return

	END

	ELSE

	BEGIN

		--print 'error encountered = '+convert(varchar(20),@Errorid)

		ROLLBACK TRAN
		CLOSE VolvoARRDCursor
		DEALLOCATE VolvoARRDCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		SELECT @ReturnBatchID = NULL
		GOTO Do_Return

	END



	Error_Encountered2:
	IF @ErrorID = 0
	BEGIN

		--print 'error encountered2 = 0'
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		SELECT @ReturnBatchID = @BatchID
		GOTO Do_Return

	END

	ELSE

	BEGIN

		--print 'error encountered2 = '+convert(varchar(20),@Errorid)

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
