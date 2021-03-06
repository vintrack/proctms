USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateGM900Data]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateGM900Data] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--ExportICLR41 table variables
	@BatchID			int,
	@VehicleID			int,
	@ActionCode			varchar(1),
	@VIN				varchar(17),
	@CDLCode			varchar(2),
	@ReceivingSCAC			varchar(4),
	@ReceiptDateTime		datetime,
	@BayingLocation			varchar(7),
	@FreightBillNumber		varchar(10),
	@ExportedInd			int,
	@RecordStatus			varchar(100),
	@CreationDate			datetime,
	--processing variables
	@GMCustomerID		int,
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@ReturnBatchID			int

	/************************************************************************
	*	spGenerateGM900Data						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the GM 900 (Vehicle Receipt) export	*
	*	GM vehicles that have been received from the rail company	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	10/24/2013 CMK    Initial version				*
	*									*
	************************************************************************/
	
	--get the next batch id from the setting table
	SELECT @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextGM900ExportBatchID'
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
	
	--get the GM Customer ID
	SELECT @GMCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'GMCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting GMCustomerID'
		GOTO Error_Encountered2
	END
	IF @GMCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'GMCustomerID Not Found'
		GOTO Error_Encountered2
	END
	--print 'gm customerid = '+convert(varchar(20),@gmcustomerid)
	
	BEGIN TRAN
	
	--set the default values
	SELECT @ActionCode = 'A'
	SELECT @ReceivingSCAC = 'DVAI'
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	DECLARE GM900Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT DISTINCT V.VehicleID, V.VIN, C.Code CDLCode, 
		--CONVERT(varchar(10),CSX.UnloadDate,101)+' '+SUBSTRING(CSX.UnloadTime,1,2)+':'+SUBSTRING(CSX.UnloadTime,3,2) ReceiptDateTime,
		ISNULL(CONVERT(datetime,CONVERT(varchar(10),CSX.UnloadDate,101)+' '+SUBSTRING(CSX.UnloadTime,1,2)+':'+SUBSTRING(CSX.UnloadTime,3,2)),ISNULL(FIFR.ReleaseDate,V.AvailableForPickupDate)) ReceiptDateTime,
		V.BayLocation
		FROM Vehicle V
		LEFT JOIN Location L ON V.PickupLocationID = L.LocationID
		LEFT JOIN Code C ON L.LocationID = CONVERT(int,C.Value1)
		AND C.CodeType = 'GMLocationCode'
		LEFT JOIN CSXRailheadFeedImport CSX ON V.VIN = CSX.VIN
		LEFT JOIN FordImportFAPSRelease FIFR ON V.VIN = FIFR.VIN
		WHERE V.CustomerID = @GMCustomerID
		AND V.VehicleID NOT IN (SELECT E.VehicleID FROM GMExport900 E WHERE E.VehicleID = V.VehicleID)
		AND V.PickupLocationID IN (SELECT CONVERT(int,C2.Value1) FROM Code C2 WHERE C2.CodeType = 'GMLocationCode')
		--AND CSX.VIN IS NOT NULL
		AND CHARINDEX('/',V.CustomerIdentification) = 3	--want to make sure that the selling division is set up correctly
		AND ISNULL(CSX.UnloadDate,ISNULL(FIFR.ReleaseDate,V.AvailableForPickupDate)) IS NOT NULL
		ORDER BY ReceiptDateTime
	
	--print 'cursor declared'
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	OPEN GM900Cursor
	--print 'cursor opened'
	
		
	FETCH GM900Cursor INTO @VehicleID, @VIN, @CDLCode, @ReceiptDateTime, @BayingLocation
			
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--print 'in loop'
		INSERT INTO GMExport900(
			BatchID,
			VehicleID,
			ActionCode,
			VIN,
			CDLCode,
			ReceivingSCAC,
			ReceiptDateTime,
			BayingLocation,
			FreightBillNumber,
			ExportedInd,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@ActionCode,
			@VIN,
			@CDLCode,
			@ReceivingSCAC,
			@ReceiptDateTime,
			@BayingLocation,
			@FreightBillNumber,
			@ExportedInd,
			@RecordStatus,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating R41 record'
			GOTO Error_Encountered
		END
					
		FETCH GM900Cursor INTO @VehicleID, @VIN, @CDLCode, @ReceiptDateTime, @BayingLocation
		
	END --end of loop
			
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextGM900ExportBatchID'
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
		CLOSE GM900Cursor
		DEALLOCATE GM900Cursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		SELECT @ReturnBatchID = @BatchID
		GOTO Do_Return
	END
	ELSE
	BEGIN
		--print 'error encountered = '+convert(varchar(20),@Errorid)
		ROLLBACK TRAN
		CLOSE GM900Cursor
		DEALLOCATE GM900Cursor
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
