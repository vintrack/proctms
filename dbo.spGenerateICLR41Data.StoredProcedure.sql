USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGenerateICLR41Data]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spGenerateICLR41Data] (@CustomerID int, @ICLCustomerCode varchar(2),@CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID			int,
	@loopcounter			int,
	--ExportICLR41 table variables
	@BatchID			int,
	@VehicleID			int,
	@BillOfLadingNumber		varchar(15),
	@StatusDate			datetime,
	@ICLStatusCode			varchar(3),
	@SPLCCode			varchar(10),
	@AARRampCode			varchar(5),
	@DestinationCode		varchar(7),
	@TruckType			varchar(1),
	@DamageIndicator		varchar(1),
	@ShipmentAuthorizationCode	varchar(12),
	@SPLCTransmissionFlag		varchar(1),
	@ExportedInd			int,
	@ExportedDate			datetime,
	@ExportedBy			varchar(20),
	@RecordStatus			varchar(20),
	@CreationDate			datetime,
	@OriginLocationCode		varchar(10),
	--processing variables
	@NissanCustomerID		int,
	@ToyotaCustomerID		int,
	@VolkswagenCustomerID		int,
	@ChryslerCustomerID		int,
	@ICLStartDate			datetime,
	@LocationSubType		varchar(20),
	@Status				varchar(100),
	@ReturnCode			int,
	@ReturnMessage			varchar(100),
	@ReturnBatchID			int

	/************************************************************************
	*	spGenerateICLR41Data						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generate the ICL R41 export data for vehicles	*
	*	(for the specified ICL customer) that have been picked up or	*
	*	delivered.							*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	03/30/2005 CMK    Initial version				*
	*	04/05/2010 CMK    Added ICL Start Date				*
	*	03/02/2011 CMK    Added Code For R05 Rail Records (Toyota)	*
	*	06/12/2017 CMK	  Added Misc Move support for Toyota		*
	*									*
	************************************************************************/
	
	--get the next batch id from the setting table
	SELECT @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextICL'+@ICLCustomerCode+'R41BatchID'
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
	
	--get the Nissan Customer ID
	SELECT @NissanCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NissanCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting NissanCustomerID'
		GOTO Error_Encountered2
	END
	IF @NissanCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'NissanCustomerID Not Found'
		GOTO Error_Encountered2
	END
	--print 'nissan customerid = '+convert(varchar(20),@nissancustomerid)
	
	--get the Toyota Customer ID
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
	
	--get the Volkswagen Customer ID
	SELECT @VolkswagenCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'VolkswagenCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting VolkswagenCustomerID'
		GOTO Error_Encountered2
	END
	IF @VolkswagenCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'VolkswagenCustomerID Not Found'
		GOTO Error_Encountered2
	END
		
	--get the Chrysler Customer ID
	SELECT @ChryslerCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'ChryslerCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting ChryslerCustomerID'
		GOTO Error_Encountered2
	END
	IF @ChryslerCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'ChryslerCustomerID Not Found'
		GOTO Error_Encountered2
	END
		
	IF @CustomerID = @NissanCustomerID
	BEGIN
		--nissan was already existing customer, adding start date to prevent sending all old vehicles
		SELECT @ICLStartDate = '04/01/2012'
	END
	ELSE IF @CustomerID = @ToyotaCustomerID
	BEGIN
		--toyota was already existing customer, adding start date to prevent sending all old vehicles
		SELECT @ICLStartDate = '06/01/2017'	--06/12/2017 - CMK - updated date so old Toyota Misc Moves don't get sent
	END
	ELSE IF @CustomerID = @VolkswagenCustomerID
	BEGIN
		--vw was already existing customer, adding start date to limit rail data being sent
		SELECT @ICLStartDate = '01/01/2012'
	END
	ELSE IF @CustomerID = @ChryslerCustomerID
	BEGIN
		--vw was already existing customer, adding start date to limit rail data being sent
		SELECT @ICLStartDate = '03/16/2015'
	END
	ELSE
	BEGIN
		SELECT @ICLStartDate = '01/01/2001'
	END
	--print 'iclstartdate = '+convert(varchar(10),@iclstartdate,101)
	BEGIN TRAN
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextICL'+@ICLCustomerCode+'R41BatchID'
	IF @@ERROR <> 0
	BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Setting BatchID'
			GOTO Error_Encountered
	END
	--print 'batchid set'
	--set the default values
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	
	IF @CustomerID IN (@ToyotaCustomerID, @VolkswagenCustomerID, @NissanCustomerID, @ChryslerCustomerID)
	BEGIN
		--print 'in r05 if, about to declare cursor'
		--cursor for the rail release records
		/*
		IF @CustomerID = @ToyotaCustomerID
		BEGIN
			DECLARE ICLR41Cursor CURSOR
			LOCAL FORWARD_ONLY STATIC READ_ONLY
			FOR
				SELECT V.VehicleID, '', 
				ISNULL((SELECT TOP 1 CASE WHEN ISNULL(TIT.FileName,'') <> '' AND PATINDEX('%[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%',SUBSTRING(TIT.FileName,CHARINDEX('.',TIT.FileName)+1,12)) > 0
				THEN DATEADD(hour,3,CONVERT(datetime,
				SUBSTRING(TIT.FileName,CHARINDEX('.',TIT.FileName)+5,2)+'/'+
				SUBSTRING(TIT.FileName,CHARINDEX('.',TIT.FileName)+7,2)+'/'+
				SUBSTRING(TIT.FileName,CHARINDEX('.',TIT.FileName)+1,4)+' '+
				SUBSTRING(TIT.FileName,CHARINDEX('.',TIT.FileName)+9,2)+':'+
				SUBSTRING(TIT.FileName,CHARINDEX('.',TIT.FileName)+11,2)))
 				ELSE L.DateAvailable END FROM ToyotaImportTender TIT WHERE TIT.VIN = V.VIN ORDER BY TIT.ToyotaImportTenderID DESC),L.DateAvailable),
				LEFT(L4.Zip,5),
				
				ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
				AND C.Value1 = CONVERT(varchar(10),V.PickupLocationID)),LEFT(L4.Zip,5)) TheOrigin,
				
				CASE WHEN L3.ParentRecordTable = 'Common' THEN
					ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
					AND C.Value1 = CONVERT(varchar(10),V.DropoffLocationID)),LEFT(L3.Zip,5))
				ELSE ISNULL(L3.CustomerLocationCode,LEFT(L3.Zip,5)) END TheDestination,
				
				--CASE WHEN VI.DamageCodeCount > 0 THEN 'Y' ELSE 'N' END,
				CASE WHEN (SELECT SUM(VI.DamageCodeCount) FROM VehicleInspection VI WHERE VI.VehicleID = L.VehicleID AND VI.InspectionType = 2) > 0 THEN 'Y' ELSE 'N' END,
				CASE WHEN CHARINDEX('/',V.CustomerIdentification) > 0 THEN LEFT(V.CustomerIdentification,CHARINDEX('/',V.CustomerIdentification)-1) ELSE V.CustomerIdentification END,
				L4.LocationSubType
				FROM Vehicle V
				LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
				AND L.PickupLocationID = V.PickupLocationID
				AND L.LegNumber = 1
				--LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
				LEFT JOIN Location L3 ON V.DropoffLocationID = L3.LocationID
				LEFT JOIN Location L4 ON V.PickupLocationID = L4.LocationID
				--LEFT JOIN VehicleInspection VI ON L.VehicleID = VI.VehicleID
				--AND VI.InspectionType = 2
				WHERE V.CustomerID = @CustomerID
				AND L.DateAvailable IS NOT NULL
				AND L.DateAvailable >= @ICLStartDate
				--AND V.CustomerIdentification IS NOT NULL
				--AND V.CustomerIdentification <> ''
				AND V.VehicleID NOT IN (SELECT VehicleID FROM ExportICLR41 WHERE ICLStatusCode IN ('R01','R05'))
				AND (V.PickupLocationID IN (SELECT CONVERT(int,C.Value1) FROM Code C WHERE C.CodeID IN (SELECT C2.CodeID FROM Code C2 WHERE C2.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'))
				OR L4.ParentRecordTable <> 'Common')
				ORDER BY TheOrigin, TheDestination
		END
		ELSE IF @CustomerID = @VolkswagenCustomerID
		BEGIN
			DECLARE ICLR41Cursor CURSOR
			LOCAL FORWARD_ONLY STATIC READ_ONLY
			FOR
				SELECT V.VehicleID, '', 
				ISNULL(ISNULL(ISNULL((SELECT TOP 1 CONVERT(varchar(10),NS.ActionDate,101)+' '+SUBSTRING(NS.TransmitTime,1,2)+':'+SUBSTRING(NS.TransmitTime,3,2)
				FROM NSTruckerNotificationImport NS WHERE NS.VIN = V.VIN ORDER BY NS.NSTruckerNotificationImportID DESC),
				(SELECT TOP 1 CONVERT(varchar(10),CSX.UnloadDate,101)+' '+SUBSTRING(CSX.UnloadTime,1,2)+':'+SUBSTRING(CSX.UnloadTime,3,2)
				FROM CSXRailheadFeedImport CSX WHERE CSX.VIN = V.VIN ORDER BY CSX.CSXRailheadFeedImportID DESC)),
				(SELECT TOP 1 CONVERT(varchar(10),NR.ReleaseDate,101)+' '+SUBSTRING(FileName,CHARINDEX('DIVERSIFIED',FileName)+23,2)+':'+SUBSTRING(FileName,CHARINDEX('DIVERSIFIED',FileName)+26,2)
				FROM NORADReleaseImport NR WHERE NR.VIN = V.VIN ORDER BY NR.NORADReleaseImportID DESC)),L.DateAvailable),
				LEFT(L4.Zip,5),
				
				ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
				AND C.Value1 = CONVERT(varchar(10),V.PickupLocationID)),LEFT(L4.Zip,5)) TheOrigin,
				
				CASE WHEN L3.ParentRecordTable = 'Common' THEN
					ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
					AND C.Value1 = CONVERT(varchar(10),V.DropoffLocationID)),LEFT(L3.Zip,5))
				ELSE ISNULL(L3.CustomerLocationCode,LEFT(L3.Zip,5)) END TheDestination,
				
				CASE WHEN (SELECT SUM(VI.DamageCodeCount) FROM VehicleInspection VI WHERE VI.VehicleID = L.VehicleID AND VI.InspectionType = 2) > 0 THEN 'Y' ELSE 'N' END,
				V.CustomerIdentification,
				L4.LocationSubType
				FROM Vehicle V
				LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
				AND L.PickupLocationID = V.PickupLocationID
				AND L.LegNumber = 1
				LEFT JOIN Location L3 ON V.DropoffLocationID = L3.LocationID
				LEFT JOIN Location L4 ON V.PickupLocationID = L4.LocationID
				WHERE V.CustomerID = @CustomerID
				AND L.DateAvailable IS NOT NULL
				AND L.DateAvailable >= @ICLStartDate
				AND V.VehicleID NOT IN (SELECT VehicleID FROM ExportICLR41 WHERE ICLStatusCode IN ('R01','R05'))
				AND (V.PickupLocationID IN (SELECT CONVERT(int,C.Value1) FROM Code C WHERE C.CodeID IN (SELECT C2.CodeID FROM Code C2 WHERE C2.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'))
				OR L4.ParentRecordTable <> 'Common')
				ORDER BY TheOrigin, TheDestination
		END
		ELSE IF @CustomerID = @NissanCustomerID
		BEGIN
			--print 'in nissan cursor'
			DECLARE ICLR41Cursor CURSOR
			LOCAL FORWARD_ONLY STATIC READ_ONLY
			FOR
				SELECT V.VehicleID, '', 
				--ISNULL((SELECT TOP 1 SUBSTRING(NITE.ActualTenderDate,5,2)+'/'+SUBSTRING(NITE.ActualTenderDate,7,2)+'/'+SUBSTRING(NITE.ActualTenderDate,1,4)+' '+SUBSTRING(NITE.ActualTenderTime,1,2)+':'+SUBSTRING(NITE.ActualTenderTime,3,2)
				--FROM NissanImportTE NITE WHERE NITE.VIN = V.VIN ORDER BY NITE.NissanImportTEID DESC),L.DateAvailable),
				ISNULL((SELECT TOP 1 CONVERT(varchar(10),CSX.UnloadDate,101)+' '+SUBSTRING(CSX.UnloadTime,1,2)+':'+SUBSTRING(CSX.UnloadTime,3,2)
				FROM CSXRailheadFeedImport CSX WHERE CSX.VIN = V.VIN AND CSX.ActionCode = 'UNLOAD' ORDER BY CSX.CSXRailheadFeedImportID DESC),L.DateAvailable),
				LEFT(L4.Zip,5),
				
				ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
				AND C.Value1 = CONVERT(varchar(10),V.PickupLocationID)),LEFT(L4.Zip,5)) TheOrigin,
				
				CASE WHEN L3.ParentRecordTable = 'Common' THEN
					ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
					AND C.Value1 = CONVERT(varchar(10),V.DropoffLocationID)),LEFT(L3.Zip,5))
				ELSE ISNULL(L3.CustomerLocationCode,LEFT(L3.Zip,5)) END TheDestination,
				
				CASE WHEN (SELECT SUM(VI.DamageCodeCount) FROM VehicleInspection VI WHERE VI.VehicleID = L.VehicleID AND VI.InspectionType = 2) > 0 THEN 'Y' ELSE 'N' END,
				V.CustomerIdentification,
				L4.LocationSubType
				FROM Vehicle V
				LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
				AND L.PickupLocationID = V.PickupLocationID
				AND L.LegNumber = 1
				LEFT JOIN Location L3 ON V.DropoffLocationID = L3.LocationID
				LEFT JOIN Location L4 ON V.PickupLocationID = L4.LocationID
				WHERE V.CustomerID = @CustomerID
				AND L.DateAvailable IS NOT NULL
				AND L.DateAvailable >= @ICLStartDate
				AND V.VehicleID NOT IN (SELECT VehicleID FROM ExportICLR41 WHERE ICLStatusCode IN ('R01','R05'))
				AND (V.PickupLocationID IN (SELECT CONVERT(int,C.Value1) FROM Code C WHERE C.CodeID IN (SELECT C2.CodeID FROM Code C2 WHERE C2.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'))
				OR L4.ParentRecordTable <> 'Common')
				ORDER BY TheOrigin, TheDestination
		END
		ELSE IF @CustomerID = @ChryslerCustomerID
		BEGIN
			--print 'in chrysler cursor'
			DECLARE ICLR41Cursor CURSOR
			LOCAL FORWARD_ONLY STATIC READ_ONLY
			FOR
				SELECT V.VehicleID, '', 
				ISNULL(ISNULL((SELECT TOP 1 CONVERT(varchar(10),NS.ActionDate,101)+' '+SUBSTRING(NS.TransmitTime,1,2)+':'+SUBSTRING(NS.TransmitTime,3,2)
				FROM NSTruckerNotificationImport NS WHERE NS.VIN = V.VIN ORDER BY NS.NSTruckerNotificationImportID DESC),
				(SELECT TOP 1 CONVERT(varchar(10),CSX.UnloadDate,101)+' '+SUBSTRING(CSX.UnloadTime,1,2)+':'+SUBSTRING(CSX.UnloadTime,3,2)
				FROM CSXRailheadFeedImport CSX WHERE CSX.VIN = V.VIN ORDER BY CSX.CSXRailheadFeedImportID DESC)),L.DateAvailable),
				LEFT(L4.Zip,5),
				
				ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
				AND C.Value1 = CONVERT(varchar(10),V.PickupLocationID)),LEFT(L4.Zip,5)) TheOrigin,
				
				CASE WHEN L3.ParentRecordTable = 'Common' THEN
					ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
					AND C.Value1 = CONVERT(varchar(10),V.DropoffLocationID)),LEFT(L3.Zip,5))
				ELSE ISNULL(L3.CustomerLocationCode,LEFT(L3.Zip,5)) END TheDestination,
								
				CASE WHEN (SELECT SUM(VI.DamageCodeCount) FROM VehicleInspection VI WHERE VI.VehicleID = L.VehicleID AND VI.InspectionType = 2) > 0 THEN 'Y' ELSE 'N' END,
				'' ShipmentAuthCode,
				L4.LocationSubType
				FROM Vehicle V
				LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
				AND L.PickupLocationID = V.PickupLocationID
				AND L.LegNumber = 1
				LEFT JOIN Location L3 ON V.DropoffLocationID = L3.LocationID
				LEFT JOIN Location L4 ON V.PickupLocationID = L4.LocationID
				WHERE V.CustomerID = @CustomerID
				AND L.DateAvailable IS NOT NULL
				AND L.DateAvailable >= @ICLStartDate
				AND V.VehicleID NOT IN (SELECT VehicleID FROM ExportICLR41 WHERE ICLStatusCode IN ('R01','R05'))
				AND (V.PickupLocationID IN (SELECT CONVERT(int,C.Value1) FROM Code C WHERE C.CodeID IN (SELECT C2.CodeID FROM Code C2 WHERE C2.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'))
				OR L4.ParentRecordTable <> 'Common')
				ORDER BY TheOrigin, TheDestination
		END
		ELSE
		BEGIN
			GOTO Generate_In_Load_Data
		END
		*/
		
		DECLARE ICLR41Cursor CURSOR
		LOCAL FORWARD_ONLY STATIC READ_ONLY
		FOR
			SELECT V.VehicleID,
			'' as BillOfLadingNumber, --cmk
			ISNULL(V.DateMadeAvailable,V.AvailableForPickupDate) as StatusDate, --01/21/2016 cmk added isnull
			CASE WHEN PATINDEX('[A-Z][0-9][A-Z] [0-9][A-Z][0-9]',L4.ZIP) > 0 THEN REPLACE(L4.Zip,' ','') ELSE LEFT(L4.Zip,5) END TheSPLC, --01/21/2016 CMK -added better formatting for Canadian Postal Code
			CASE --BEGIN 12/02/2015 JLB    0008578: Multiple Terminal Codes support
				WHEN DATALENGTH(ISNULL((SELECT TOP 1 RailRamp From ImportI73 I73 WHERE I73.VIN = V.VIN AND V.CustomerIdentification = I73.DealerAllocationNumber ORDER BY ImportI73ID DESC),'')) > 0 THEN
					(SELECT TOP 1 RailRamp From ImportI73 I73 WHERE I73.VIN = V.VIN AND V.CustomerIdentification = I73.DealerAllocationNumber ORDER BY ImportI73ID DESC)
				WHEN DATALENGTH(ISNULL((SELECT TOP 1 USPortofEntry From ImportI73 I73 WHERE I73.VIN = V.VIN AND V.CustomerIdentification = I73.DealerAllocationNumber ORDER BY ImportI73ID DESC),'')) > 0 THEN
					(SELECT TOP 1 USPortofEntry From ImportI73 I73 WHERE I73.VIN = V.VIN AND V.CustomerIdentification = I73.DealerAllocationNumber ORDER BY ImportI73ID DESC)
				ELSE
					--8944 - 01/20/2016 - CMK - line 218 needs a top 1 in select - was returning multiple results
					ISNULL((SELECT TOP 1 C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
					AND C.Value1 = CONVERT(varchar(10),V.PickupLocationID)),LEFT(L4.Zip,5))
				END TheOrigin,  --END 12/02/2015 JLB    0008578: Multiple Terminal Codes support
			CASE 
				WHEN L3.ParentRecordTable = 'Common' THEN
					ISNULL((SELECT TOP 1 C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
					AND C.Value1 = CONVERT(varchar(10),V.DropoffLocationID)),LEFT(L3.Zip,5))
				ELSE
					ISNULL(L3.CustomerLocationCode,CASE WHEN PATINDEX('[A-Z][0-9][A-Z] [0-9][A-Z][0-9]',L3.ZIP) > 0 THEN REPLACE(L3.Zip,' ','') ELSE LEFT(L3.Zip,5) END)
				END TheDestination,  --01/21/2016 CMK This change will help with terminal to terminal and dealer to terminal moves
			CASE
				WHEN (SELECT SUM(VI.DamageCodeCount) FROM VehicleInspection VI WHERE VI.VehicleID = L.VehicleID AND VI.InspectionType = 2) > 0 THEN
					'Y'
				ELSE
					'N'
				END as DamageIndicator,
			CASE
				WHEN CHARINDEX('/',V.CustomerIdentification) > 0 THEN
					--LEFT(V.CustomerIdentification,CHARINDEX('/',V.CustomerIdentification)-1)
					CASE WHEN CHARINDEX('/',V.CustomerIdentification) > 0 THEN SUBSTRING(V.CustomerIdentification,CHARINDEX('/',V.CustomerIdentification)+1,DATALENGTH(V.CustomerIdentification)-CHARINDEX('/',V.CustomerIdentification)) WHEN DATALENGTH(V.CustomerIdentification) > 6 THEN V.CustomerIdentification ELSE '' END
				ELSE
					V.CustomerIdentification
				END as ShipmentAuthorizationCode,
			L4.LocationSubType,
			CASE WHEN L4.ParentRecordTable = 'Common' THEN
				ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
				AND C.Value1 = CONVERT(varchar(10),V.PickupLocationID)),LEFT(L4.Zip,5))
			ELSE ISNULL(L4.CustomerLocationCode,LEFT(L4.Zip,5)) END TheOriginLocationCode
			FROM Vehicle V
			LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
			AND L.PickupLocationID = V.PickupLocationID
			AND L.LegNumber = 1
			LEFT JOIN Location L3 ON V.DropoffLocationID = L3.LocationID
			LEFT JOIN Location L4 ON V.PickupLocationID = L4.LocationID
			WHERE V.CustomerID = @CustomerID
			AND L.DateAvailable IS NOT NULL
			AND L.DateAvailable >= @ICLStartDate
			AND V.VehicleID NOT IN (SELECT VehicleID FROM ExportICLR41 WHERE ICLStatusCode IN ('R01','R05'))
			AND (CONVERT(varchar(10),V.PickupLocationID) IN (SELECT C.Value1 FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode')
			OR L4.ParentRecordTable <> 'Common')
			ORDER BY TheOrigin, TheDestination
		
		--print 'cursor declared'
		SELECT @ErrorID = 0
		SELECT @loopcounter = 0
		
		OPEN ICLR41Cursor
		--print 'cursor opened'
		SELECT @TruckType = ' '
		SELECT @SPLCTransmissionFlag = 'F'
			
		FETCH ICLR41Cursor INTO @VehicleID, @BillOfLadingNumber, @StatusDate, @SPLCCode,
		@AARRampCode, @DestinationCode, @DamageIndicator, @ShipmentAuthorizationCode, @LocationSubType, @OriginLocationCode
			
		--print 'about to enter loop'
		WHILE @@FETCH_STATUS = 0
		BEGIN
			
			--SELECT @ICLStatusCode = 'R05'
			IF @LocationSubType = 'Railyard'
			BEGIN
				SELECT @ICLStatusCode = 'R05'
			END
			ELSE
			BEGIN
				SELECT @ICLStatusCode = 'R01'
			END
					
			--06/12/2017 - CMK - adding support for toyota Misc Move vehicles
			IF @CustomerID = @ToyotaCustomerID
			BEGIN
				IF ISNULL(@ShipmentAuthorizationCode,'') = '' OR ISNULL(@ShipmentAuthorizationCode,'') LIKE 'Dev%'
				BEGIN
					SELECT @ShipmentAuthorizationCode = 'MISCMOVE'
				END
			END
			
			--print 'r05 in loop'
			INSERT INTO ExportICLR41(
				BatchID,
				CustomerID,
				ICLCustomerCode,
				VehicleID,
				BillOfLadingNumber,
				StatusDate,
				ICLStatusCode,
				SPLCCode,
				AARRampCode,
				DestinationCode,
				TruckType,
				DamageIndicator,
				ShipmentAuthorizationCode,
				SPLCTransmissionFlag,
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
				@BillOfLadingNumber,
				@StatusDate,
				@ICLStatusCode,
				@SPLCCode,
				@AARRampCode,
				@DestinationCode,
				@TruckType,
				@DamageIndicator,
				@ShipmentAuthorizationCode,
				@SPLCTransmissionFlag,
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
				SELECT @Status = 'Error creating R41 record'
				GOTO Error_Encountered
			END
					
			FETCH ICLR41Cursor INTO @VehicleID, @BillOfLadingNumber, @StatusDate, @SPLCCode,
			@AARRampCode, @DestinationCode, @DamageIndicator, @ShipmentAuthorizationCode, @LocationSubType, @OriginLocationCode
		
		END --end of loop
			
		CLOSE ICLR41Cursor
		DEALLOCATE ICLR41Cursor
		--print 'closed ro5 cursor'
	END
	
	Generate_In_Load_Data:
	
	IF @CustomerID IN (@NissanCustomerID, @ChryslerCustomerID)
	BEGIN
		--print 'in t05 if, about to delcare cursor'
		--cursor for the vehicles put into loads
		IF @CustomerID = @NissanCustomerID
		BEGIN
			DECLARE ICLR41Cursor CURSOR
			LOCAL FORWARD_ONLY STATIC READ_ONLY
			FOR
				SELECT V.VehicleID, '', 
				--(SELECT TOP 1 CONVERT(varchar(20),AH.CreationDate,120)
				--FROM ActionHistory AH WHERE AH.RecordID = V.VehicleID AND AH.RecordTableName = 'Vehicle'
				--AND AH.ActionType = 'Vehicle Added To Load' ORDER BY AH.ActionHistoryID DESC),
				L5.CreationDate,
				LEFT(L4.Zip,5),
				
				ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
				AND C.Value1 = CONVERT(varchar(10),V.PickupLocationID)),LEFT(L4.Zip,5)) TheOrigin,
				
				CASE WHEN L3.ParentRecordTable = 'Common' THEN
					ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
					AND C.Value1 = CONVERT(varchar(10),V.DropoffLocationID)),LEFT(L3.Zip,5))
				ELSE ISNULL(L3.CustomerLocationCode,LEFT(L3.Zip,5)) END TheDestination,
				CASE WHEN (SELECT SUM(VI.DamageCodeCount) FROM VehicleInspection VI WHERE VI.VehicleID = L.VehicleID AND VI.InspectionType = 2) > 0 THEN 'Y' ELSE 'N' END,
				CASE WHEN @CustomerID = @NissanCustomerID THEN V.CustomerIdentification ELSE '' END,
				L4.LocationSubType
				FROM Vehicle V
				LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
				AND L.PickupLocationID = V.PickupLocationID
				AND L.LegNumber = 1
				LEFT JOIN Location L3 ON V.DropoffLocationID = L3.LocationID
				LEFT JOIN Location L4 ON V.PickupLocationID = L4.LocationID
				LEFT JOIN Loads L5 ON L.LoadID = L5.LoadsID
				WHERE V.CustomerID = @CustomerID
				AND L.DateAvailable IS NOT NULL
				AND L.DateAvailable >= @ICLStartDate
				AND L.LoadID IS NOT NULL
				AND V.VehicleID NOT IN (SELECT VehicleID FROM ExportICLR41 WHERE ICLStatusCode IN ('T01','T05'))
				AND (CONVERT(varchar(10),V.PickupLocationID) IN (SELECT C.Value1 FROM Code C WHERE C.CodeID IN (SELECT C2.CodeID FROM Code C2 WHERE C2.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'))
				OR L4.ParentRecordTable <> 'Common')
				ORDER BY TheOrigin, TheDestination
		END
		ELSE
		BEGIN
			GOTO Generate_Pickup_Data
		END
		--print 'cursor declared'
		SELECT @ErrorID = 0
		SELECT @loopcounter = 0
		
		OPEN ICLR41Cursor
		--print 'cursor opened'
		SELECT @TruckType = ' '
		SELECT @SPLCTransmissionFlag = 'F'
			
		FETCH ICLR41Cursor INTO @VehicleID, @BillOfLadingNumber, @StatusDate, @SPLCCode,
		@AARRampCode, @DestinationCode, @DamageIndicator, @ShipmentAuthorizationCode, @LocationSubType
			
		--print 'about to enter loop'
		WHILE @@FETCH_STATUS = 0
		BEGIN
			
			IF @LocationSubType = 'Railyard'
			BEGIN
				SELECT @ICLStatusCode = 'T05'
			END
			ELSE
			BEGIN
				SELECT @ICLStatusCode = 'T01'
			END
					
		
			--print 'in loop'
			INSERT INTO ExportICLR41(
				BatchID,
				CustomerID,
				ICLCustomerCode,
				VehicleID,
				BillOfLadingNumber,
				StatusDate,
				ICLStatusCode,
				SPLCCode,
				AARRampCode,
				DestinationCode,
				TruckType,
				DamageIndicator,
				ShipmentAuthorizationCode,
				SPLCTransmissionFlag,
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
				@ICLCustomerCode,
				@VehicleID,
				@BillOfLadingNumber,
				@StatusDate,
				@ICLStatusCode,
				@SPLCCode,
				@AARRampCode,
				@DestinationCode,
				@TruckType,
				@DamageIndicator,
				@ShipmentAuthorizationCode,
				@SPLCTransmissionFlag,
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
				SELECT @Status = 'Error creating R41 record'
				GOTO Error_Encountered
			END
					
			FETCH ICLR41Cursor INTO @VehicleID, @BillOfLadingNumber, @StatusDate, @SPLCCode,
			@AARRampCode, @DestinationCode, @DamageIndicator, @ShipmentAuthorizationCode, @LocationSubType
		
		END --end of loop
			
		CLOSE ICLR41Cursor
		DEALLOCATE ICLR41Cursor
		--print 'closed to5 cursor'
	END
		
	Generate_Pickup_Data:
	--print 'about to declare pickup cursor'
	--cursor for the pickup records
	DECLARE ICLR41Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		SELECT V.VehicleID, L2.LoadNumber, L.PickupDate, LEFT(L4.Zip,5),
		
		ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
		AND C.Value1 = CONVERT(varchar(10),V.PickupLocationID)),LEFT(L4.Zip,5)) TheOrigin,
		
		CASE WHEN L3.ParentRecordTable = 'Common' THEN
			ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
			AND C.Value1 = CONVERT(varchar(10),V.DropoffLocationID)),LEFT(L3.Zip,5))
		ELSE ISNULL(L3.CustomerLocationCode,LEFT(L3.Zip,5)) END TheDestination,
								
		--CASE WHEN VI.DamageCodeCount > 0 THEN 'Y' ELSE 'N' END,
		CASE WHEN (SELECT SUM(VI.DamageCodeCount) FROM VehicleInspection VI WHERE VI.VehicleID = L.VehicleID AND VI.InspectionType = 2) > 0 THEN 'Y' ELSE 'N' END,
		CASE
			WHEN CHARINDEX('/',V.CustomerIdentification) > 0 THEN
				--LEFT(V.CustomerIdentification,CHARINDEX('/',V.CustomerIdentification)-1)
				CASE WHEN CHARINDEX('/',V.CustomerIdentification) > 0 THEN SUBSTRING(V.CustomerIdentification,CHARINDEX('/',V.CustomerIdentification)+1,DATALENGTH(V.CustomerIdentification)-CHARINDEX('/',V.CustomerIdentification)) WHEN DATALENGTH(V.CustomerIdentification) > 6 THEN V.CustomerIdentification ELSE '' END
			WHEN @CustomerID = @ChryslerCustomerID THEN '' ELSE V.CustomerIdentification END,
		L4.LocationSubType,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN
			ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
			AND C.Value1 = CONVERT(varchar(10),V.PickupLocationID)),LEFT(L4.Zip,5))
		ELSE ISNULL(L4.CustomerLocationCode,LEFT(L4.Zip,5)) END TheOriginLocationCode
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.PickupLocationID = V.PickupLocationID
		AND L.LegNumber = 1
		LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
		LEFT JOIN Location L3 ON V.DropoffLocationID = L3.LocationID
		LEFT JOIN Location L4 ON V.PickupLocationID = L4.LocationID
		--LEFT JOIN VehicleInspection VI ON L.VehicleID = VI.VehicleID
		--AND VI.InspectionType = 2
		WHERE V.CustomerID = @CustomerID
		AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
		AND L.PickupDate >= @ICLStartDate
		AND V.VehicleStatus IN ('EnRoute','Delivered')
		--AND V.CustomerIdentification IS NOT NULL
		AND (ISNULL(V.CustomerIdentification,'') <> '' OR V.CustomerID = @ToyotaCustomerID)	--06/12/2017 - CMK - uncommented for Toyota Misc Move support
		--AND ISNULL(V.CustomerIdentification,'') <> ''						--06/12/2017 - CMK - commented for Toyota Misc Move support
		AND V.VehicleID NOT IN (SELECT VehicleID FROM ExportICLR41 WHERE ICLStatusCode IN ('P01', 'P08'))
		AND (CONVERT(varchar(10),V.PickupLocationID) IN (SELECT C.Value1 FROM Code C WHERE C.CodeID IN (SELECT C2.CodeID FROM Code C2 WHERE C2.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'))
		OR L4.ParentRecordTable <> 'Common')
		ORDER BY TheOrigin, TheDestination
	--print 'about to open cursor'
	OPEN ICLR41Cursor
	--print 'cursor opened'
	--SELECT @ICLStatusCode = 'P08'
	IF @ICLCustomerCode = 'SW'
	BEGIN
		SELECT @TruckType = ' '
	END
	ELSE
	BEGIN
		SELECT @TruckType = 'O'
	END
	SELECT @SPLCTransmissionFlag = 'F'
	
	FETCH ICLR41Cursor INTO @VehicleID, @BillOfLadingNumber, @StatusDate, @SPLCCode,
	@AARRampCode, @DestinationCode, @DamageIndicator, @ShipmentAuthorizationCode, @LocationSubType, @OriginLocationCode
	
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--print 'in pickup loop'
		IF @LocationSubType = 'Railyard'
		BEGIN
			SELECT @ICLStatusCode = 'P08'
		END
		ELSE
		BEGIN
			SELECT @ICLStatusCode = 'P01'
		END
		
		--06/12/2017 - CMK - adding support for toyota Misc Move vehicles
		IF @CustomerID = @ToyotaCustomerID
		BEGIN
			IF ISNULL(@ShipmentAuthorizationCode,'') = '' OR ISNULL(@ShipmentAuthorizationCode,'') LIKE 'Dev%'
			BEGIN
				SELECT @ShipmentAuthorizationCode = 'MISCMOVE'
			END
		END
		
		INSERT INTO ExportICLR41(
			BatchID,
			CustomerID,
			ICLCustomerCode,
			VehicleID,
			BillOfLadingNumber,
			StatusDate,
			ICLStatusCode,
			SPLCCode,
			AARRampCode,
			DestinationCode,
			TruckType,
			DamageIndicator,
			ShipmentAuthorizationCode,
			SPLCTransmissionFlag,
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
			@BillOfLadingNumber,
			@StatusDate,
			@ICLStatusCode,
			@SPLCCode,
			@AARRampCode,
			@DestinationCode,
			@TruckType,
			@DamageIndicator,
			@ShipmentAuthorizationCode,
			@SPLCTransmissionFlag,
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
			SELECT @Status = 'Error creating R41 record'
			GOTO Error_Encountered
		END
			
		FETCH ICLR41Cursor INTO @VehicleID, @BillOfLadingNumber, @StatusDate, @SPLCCode,
		@AARRampCode, @DestinationCode, @DamageIndicator, @ShipmentAuthorizationCode, @LocationSubType, @OriginLocationCode

	END --end of loop
	--print 'pickup loop done'
	CLOSE ICLR41Cursor
	DEALLOCATE ICLR41Cursor
	--print 'pickup cursor closed'
	
	--print 'about to declare delivery cursor'
	--cursor for the delivery records
	DECLARE ICLR41Cursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		
		SELECT V.VehicleID, L2.LoadNumber, L.DropoffDate, LEFT(L3.Zip,5),
		
		ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
		AND C.Value1 = CONVERT(varchar(10),V.PickupLocationID)),LEFT(L4.ZIP,5)) TheOrigin,
		
		CASE WHEN L3.ParentRecordTable = 'Common' THEN
			ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
			AND C.Value1 = CONVERT(varchar(10),V.DropoffLocationID)),LEFT(L3.Zip,5))
		ELSE ISNULL(L3.CustomerLocationCode,LEFT(L3.Zip,5)) END TheDestination,
								
		--CASE WHEN VI.DamageCodeCount > 0 THEN 'Y' ELSE 'N' END,
		CASE WHEN (SELECT SUM(VI.DamageCodeCount) FROM VehicleInspection VI WHERE VI.VehicleID = L.VehicleID AND VI.InspectionType = 3) > 0 THEN 'Y' ELSE 'N' END,
		CASE
			WHEN CHARINDEX('/',V.CustomerIdentification) > 0 THEN
				--LEFT(V.CustomerIdentification,CHARINDEX('/',V.CustomerIdentification)-1)
				CASE WHEN CHARINDEX('/',V.CustomerIdentification) > 0 THEN SUBSTRING(V.CustomerIdentification,CHARINDEX('/',V.CustomerIdentification)+1,DATALENGTH(V.CustomerIdentification)-CHARINDEX('/',V.CustomerIdentification)) WHEN DATALENGTH(V.CustomerIdentification) > 6 THEN V.CustomerIdentification ELSE '' END
			WHEN @CustomerID = @ChryslerCustomerID THEN '' ELSE V.CustomerIdentification END,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN
			ISNULL((SELECT C.Code FROM Code C WHERE C.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'
			AND C.Value1 = CONVERT(varchar(10),V.PickupLocationID)),LEFT(L4.Zip,5))
		ELSE ISNULL(L4.CustomerLocationCode,LEFT(L4.Zip,5)) END TheOriginLocationCode
		FROM Vehicle V
		LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
		AND L.FinalLegInd = 1
		LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
		LEFT JOIN Location L3 ON V.DropoffLocationID = L3.LocationID
		LEFT JOIN Location L4 ON V.PickupLocationID = L4.LocationID
		--LEFT JOIN VehicleInspection VI ON L.VehicleID = VI.VehicleID
		--AND VI.InspectionType = 3
		WHERE V.CustomerID = @CustomerID
		AND V.VehicleStatus = 'Delivered'
		AND L.DropoffDate > L.PickupDate
		AND L.PickupDate >= CONVERT(varchar(10),L.DateAvailable,101)
		AND L.PickupDate >= @ICLStartDate
		--AND V.CustomerIdentification IS NOT NULL
		AND (ISNULL(V.CustomerIdentification,'') <> '' OR V.CustomerID = @ToyotaCustomerID)	--06/12/2017 - CMK - uncommented for Toyota Misc Move support
		--AND ISNULL(V.CustomerIdentification,'') <> ''						--06/12/2017 - CMK - commented for Toyota Misc Move suport
		AND V.VehicleID NOT IN (SELECT VehicleID FROM ExportICLR41 WHERE ICLStatusCode = 'D09')
		AND (CONVERT(varchar(10),V.PickupLocationID) IN (SELECT C.Value1 FROM Code C WHERE C.CodeID IN (SELECT C2.CodeID FROM Code C2 WHERE C2.CodeType = 'ICL'+@ICLCustomerCode+'LocationCode'))
		OR L4.ParentRecordTable <> 'Common')
		ORDER BY TheOrigin, TheDestination
	--print 'deliver cursor declared'
	SELECT @ErrorID = 0
	SELECT @loopcounter = 0

	OPEN ICLR41Cursor
	--print 'delivery cursor opened'
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	SELECT @ICLStatusCode = 'D09'
	IF @ICLCustomerCode = 'SW'
	BEGIN
		SELECT @TruckType = ' '
	END
	ELSE
	BEGIN
		SELECT @TruckType = 'O'
	END
	SELECT @SPLCTransmissionFlag = 'F'
	
	FETCH ICLR41Cursor INTO @VehicleID, @BillOfLadingNumber, @StatusDate, @SPLCCode,
	@AARRampCode, @DestinationCode, @DamageIndicator, @ShipmentAuthorizationCode, @OriginLocationCode
	
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--06/12/2017 - CMK - adding support for toyota Misc Move vehicles
		IF @CustomerID = @ToyotaCustomerID
		BEGIN
			IF ISNULL(@ShipmentAuthorizationCode,'') = '' OR ISNULL(@ShipmentAuthorizationCode,'') LIKE 'Dev%'
			BEGIN
				SELECT @ShipmentAuthorizationCode = 'MISCMOVE'
			END
		END
		
		--print 'in loop'
		INSERT INTO ExportICLR41(
			BatchID,
			CustomerID,
			ICLCustomerCode,
			VehicleID,
			BillOfLadingNumber,
			StatusDate,
			ICLStatusCode,
			SPLCCode,
			AARRampCode,
			DestinationCode,
			TruckType,
			DamageIndicator,
			ShipmentAuthorizationCode,
			SPLCTransmissionFlag,
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
			@BillOfLadingNumber,
			@StatusDate,
			@ICLStatusCode,
			@SPLCCode,
			@AARRampCode,
			@DestinationCode,
			@TruckType,
			@DamageIndicator,
			@ShipmentAuthorizationCode,
			@SPLCTransmissionFlag,
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
			SELECT @Status = 'Error creating R41 record'
			GOTO Error_Encountered
		END
			
		FETCH ICLR41Cursor INTO @VehicleID, @BillOfLadingNumber, @StatusDate, @SPLCCode,
		@AARRampCode, @DestinationCode, @DamageIndicator, @ShipmentAuthorizationCode, @OriginLocationCode

	END --end of loop
	--print 'end of loop'
	
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		--print 'error encountered = 0'
		COMMIT TRAN
		CLOSE ICLR41Cursor
		DEALLOCATE ICLR41Cursor
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		SELECT @ReturnBatchID = @BatchID
		GOTO Do_Return
	END
	ELSE
	BEGIN
		--print 'error encountered = '+convert(varchar(20),@Errorid)
		ROLLBACK TRAN
		CLOSE ICLR41Cursor
		DEALLOCATE ICLR41Cursor
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
