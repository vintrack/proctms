USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateGMDeliveryData]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateGMDeliveryData] (@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID		int,
	@loopcounter		int,
	--GMExportDelivery table variables
	@BatchID		int,
	@VehicleID		int,
	@DeliveringSCAC		varchar(4),
	@CDLCode		varchar(2),
	@DispatchingSCAC	varchar(4),
	@LoadNumber		varchar(9),
	@DispatchYear		varchar(4),
	@SequenceNumber		int,
	@VIN			varchar(17),
	@DeliveryDateTime	datetime,
	@SpecialMoveNumber	varchar(6),
	@DestinationCDLCode	varchar(2),
	@SellingDivision	varchar(2),
	@DealerCode		varchar(5),
	@ExceptionCount		varchar(3),
	@DamageCodeArray	varchar(70),
	@ExportedInd		int,
	@RecordStatus		varchar(100),
	@CreationDate		datetime,
	--processing variables
	@CustomerID		int,
	@Status			varchar(100),
	@ReturnCode		int,
	@ReturnMessage		varchar(100),
	@ReturnBatchID		int

	/************************************************************************
	*	spGenerateGMDeliveryData					*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generate the delivered vehicle data for GMs	*
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
	SELECT @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextGMDeliveryExportBatchID'
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

	DECLARE GMDeliveryCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT DISTINCT V.VehicleID,
		(SELECT C.Code FROM Code C WHERE C.CodeType = 'GMLocationCode' AND CONVERT(int,C.Value1) = V.PickupLocationID),
		G.LoadNumber, DATEPART(year,L1.PickupDate), V.VIN, L2.DropoffDate,
		CASE WHEN CHARINDEX('/',V.CustomerIdentification) > 0 THEN SUBSTRING(V.CustomerIdentification,CHARINDEX('/',V.CustomerIdentification)+1,DATALENGTH(V.CustomerIdentification)-CHARINDEX('/',V.CustomerIdentification)) WHEN DATALENGTH(V.CustomerIdentification) > 2 THEN V.CustomerIdentification ELSE '' END,
		(SELECT C.Code FROM Code C WHERE C.CodeType = 'GMLocationCode' AND CONVERT(int,C.Value1) = V.DropoffLocationID),
		CASE WHEN CHARINDEX('/',V.CustomerIdentification) > 0 THEN SUBSTRING(V.CustomerIdentification,1,CHARINDEX('/',V.CustomerIdentification)-1) WHEN DATALENGTH(V.CustomerIdentification) < 3 THEN V.CustomerIdentification ELSE '' END,
		CASE WHEN DATALENGTH(L4.CustomerLocationCode) > 0 THEN CASE WHEN CHARINDEX('-',L4.CustomerLocationCode) > 0 THEN SUBSTRING(L4.CustomerLocationCode,CHARINDEX('-',L4.CustomerLocationCode)+1,DATALENGTH(L4.CustomerLocationCode) - CHARINDEX('-',L4.CustomerLocationCode)) ELSE L4.CustomerLocationCode END ELSE '' END
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
		LEFT JOIN GMIMport902 G ON V.VehicleID = G.VehicleID
		WHERE V.CustomerID = @CustomerID
		AND L2.DropoffDate > L1.PickupDate
		AND L1.PickupDate >= CONVERT(varchar(10),L1.DateAvailable,101)
		AND ISNULL(V.CustomerIdentification,'') <> ''
		AND V.VehicleStatus = 'Delivered'
		AND V.VehicleID NOT IN (SELECT VehicleID FROM GMExportDelivery)
		AND V.PickupLocationID IN (SELECT CONVERT(int,C.Value1) FROM Code C WHERE C.CodeType = 'GMLocationCode')
		--AND L2.DropoffDate >= '11/01/2013'	-- CAN BE REMOVED IN PROD
		AND G.StatusCode = 'A'
		ORDER BY V.VehicleID

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN GMDeliveryCursor

	BEGIN TRAN
	
	--set the default values
	SELECT @DeliveringSCAC = 'DVAI'
	SELECT @DispatchingSCAC = 'DVAI'
	SELECT @SequenceNumber = 1
	SELECT @ExceptionCount = '001'
	SELECT @DamageCodeArray = '0000000'
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	FETCH GMDeliveryCursor INTO @VehicleID, @CDLCode, @LoadNumber, @DispatchYear, @VIN,
		@DeliveryDateTime, @SpecialMoveNumber, @DestinationCDLCode, @SellingDivision, @DealerCode
		
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--insert the record
		INSERT INTO GMExportDelivery(
			BatchID,
			VehicleID,
			DeliveringSCAC,
			CDLCode,
			DispatchingSCAC,
			LoadNumber,
			DispatchYear,
			SequenceNumber,
			VIN,
			DeliveryDateTime,
			SpecialMoveNumber,
			DestinationCDLCode,
			SellingDivision,
			DealerCode,
			ExceptionCount,
			DamageCodeArray,
			ExportedInd,
			RecordStatus,
			CreationDate,
			CreatedBy
		)
		VALUES(
			@BatchID,
			@VehicleID,
			@DeliveringSCAC,
			@CDLCode,
			@DispatchingSCAC,
			@LoadNumber,
			@DispatchYear,
			@SequenceNumber,
			@VIN,
			@DeliveryDateTime,
			@SpecialMoveNumber,
			@DestinationCDLCode,
			@SellingDivision,
			@DealerCode,
			@ExceptionCount,
			@DamageCodeArray,
			@ExportedInd,
			@RecordStatus,
			@CreationDate,
			@CreatedBy
		)
		IF @@Error <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error creating GMExportShipped record'
			GOTO Error_Encountered
		END
		
		End_Of_Loop:
		FETCH GMDeliveryCursor INTO @VehicleID, @CDLCode, @LoadNumber, @DispatchYear, @VIN,
			@DeliveryDateTime, @SpecialMoveNumber, @DestinationCDLCode, @SellingDivision, @DealerCode

	END --end of loop

	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextGMDeliveryExportBatchID'
	IF @@ERROR <> 0
	BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Setting BatchID'
			GOTO Error_Encountered
	END
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE GMDeliveryCursor
		DEALLOCATE GMDeliveryCursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		SELECT @ReturnBatchID = @BatchID
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE GMDeliveryCursor
		DEALLOCATE GMDeliveryCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		SELECT @ReturnBatchID = NULL
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
	BEGIN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		SELECT @ReturnBatchID = @BatchID
		GOTO Do_Return
	END
	ELSE
	BEGIN
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
