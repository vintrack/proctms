USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[oldSendBillOfLadingEmail]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[oldSendBillOfLadingEmail]
AS
BEGIN
	set nocount on

	DECLARE
	@CompanyName			varchar(100),
	@CompanyAddressLine1		varchar(50),
	@CompanyAddressLine2		varchar(50),
	@CompanyCityStateZip		varchar(50),
	@CompanyPhone			varchar(20),
	@CompanyFaxNumber		varchar(20),
	@FordCarrierID			varchar(10),
	@VehicleID			int,
	@LoadsID			int,
	@RunID				int,
	@PickupLocationID		int,
	@DropoffLocationID		int,
	@DropoffDate			varchar(20),
	@DropoffTime			varchar(20),
	@DropoffTime2			varchar(20),
	@TruckNumber			varchar(20),
	@DriverName			varchar(50),
	@DriverNumber			varchar(20),
	@DriverID			varchar(20),
	@OriginName			varchar(100),
	@OriginAddressLine1		varchar(50),
	@OriginAddressLine2		varchar(50),
	@OriginCityStateZip		varchar(100),
	@OriginSubType			varchar(20),
	@LoadNumber			varchar(50),
	@DestinationName		varchar(100),
	@DestinationAddressLine1	varchar(50),
	@DestinationAddressLine2	varchar(50),
	@DestinationCityStateZip	varchar(100),
	@DestinationPhone		varchar(20),
	@DestinationDeliveryTimes	varchar(100),
	@VIN				varchar(17),
	@VehicleYear			varchar(6),
	@Make				varchar(50),
	@Model				varchar(50),
	@GreetingName			varchar(200),
	@EmailAddress			varchar(255),
	@HTMLSupportedInd		int,
	@SignatureFileName		varchar(50),
	@SignedBy			varchar(50),
	@NoSignatureReasonCode		varchar(255),
	@DamageCode			varchar(10),
	@DamageDescription		varchar(500),
	@Exception			varchar(10),
	@SubjectToInspectionInd		int,
	@TCode				varchar(20),
	@RailcarNumber			varchar(20),
	@RCode				varchar(20),
	@PreviousLoadNumber		varchar(20),
	@PreviousPickupLocationID	int,
	@PreviousDropoffLocationID	int,
	@PreviousEmailAddress		varchar(255),
	@PreviousRunID			int,
	@PreviousDriverNumber		varchar(20),
	@PreviousDropoffDate		varchar(20),
	@PreviousDropoffTime2		varchar(20),
	@PreviousSignatureFileName	varchar(50),
	@PreviousDriverName		varchar(50),
	@PreviousSignedBy		varchar(50),
	@PreviousDriverID		varchar(20),
	@PreviousOriginSubType		varchar(20),
	@PreviousNoSignatureReasonCode	varchar(255),
	@Subject			varchar(255),
	@Body 				varchar(8000),
	@HTMLBody			varchar(8000),
	@MessageFooter			varchar(1000),
	@MessageFooter2			varchar(1000),
	@AppendString			varchar(1000),
	@CommandString			varchar(1000),
	@SMTPServer			varchar(100),
	@SMTPUsername			varchar(100),
	@SMTPPassword			varchar(100),
	@BOLPath			varchar(100),
	@DriverSignatureURL		varchar(100),
	@DealerSignatureURL		varchar(100),
	@CompanyLogoURL			varchar(100),
	@ErrorID			int,
	@ErrorEncountered		varchar(5000),
	@VINCount			int,
	@loopcounter			int,
	@ResultCode			int,
	@ReturnCode			int,
	@Status				varchar(100),
	@ReturnMessage			varchar(100)

	/************************************************************************
	*	spSendBillOfLadingEmail						*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure sends bills of lading to dealers	for vehicles	*
	*	that are have been delivered.					*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	01/14/2009 CMK    Initial version				*
	*									*
	************************************************************************/

	SELECT @SMTPServer = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'SMTPServer'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting SMTP Server'
		GOTO Error_Encountered2
	END
	IF DATALENGTH(ISNULL(@SMTPServer,'')) < 1
	BEGIN
		SELECT @ErrorID = 100000
		SELECT @Status = 'Error Getting SMTP Server'
		GOTO Error_Encountered2
	END
	
	SELECT @SMTPUsername = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'SMTPUsername'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting SMTP Username'
		GOTO Error_Encountered2
	END
	IF DATALENGTH(ISNULL(@SMTPUsername,'')) < 1
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'Error Getting SMTP Username'
		GOTO Error_Encountered2
	END
	
	SELECT @SMTPPassword = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'SMTPPassword'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting SMTP Password'
		GOTO Error_Encountered2
	END
	IF DATALENGTH(ISNULL(@SMTPPassword,'')) < 1
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Status = 'Error Getting SMTP Password'
		GOTO Error_Encountered2
	END
	
	SELECT @BOLPath = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'BillOfLadingFilePath'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Bill Of Lading File Path'
		GOTO Error_Encountered2
	END
	IF DATALENGTH(ISNULL(@BOLPath,'')) < 1
	BEGIN
		SELECT @ErrorID = 100003
		SELECT @Status = 'Error Getting Bill Of Lading File Path'
		GOTO Error_Encountered2
	END
	
	SELECT @DriverSignatureURL = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'DriverSignatureURL'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Driver Signature URL'
		GOTO Error_Encountered2
	END
	IF DATALENGTH(ISNULL(@DriverSignatureURL,'')) < 1
	BEGIN
		SELECT @ErrorID = 100004
		SELECT @Status = 'Error Getting Driver Signature URL'
		GOTO Error_Encountered2
	END
	
	SELECT @DealerSignatureURL = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'DealerSignatureURL'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Dealer Signature URL'
		GOTO Error_Encountered2
	END
	IF DATALENGTH(ISNULL(@DealerSignatureURL,'')) < 1
	BEGIN
		SELECT @ErrorID = 100005
		SELECT @Status = 'Error Getting Dealer Signature URL'
		GOTO Error_Encountered2
	END
	
	SELECT @CompanyLogoURL = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'CompanyLogoURL'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Company Logo URL'
		GOTO Error_Encountered2
	END
	IF DATALENGTH(ISNULL(@CompanyLogoURL,'')) < 1
	BEGIN
		SELECT @ErrorID = 100006
		SELECT @Status = 'Error Getting Company Logo URL'
		GOTO Error_Encountered2
	END
	
	DECLARE BillOfLadingCursor CURSOR
	LOCAL FORWARD_ONLY STATIC READ_ONLY
	FOR
		/*
		SELECT V.VehicleID, L.LoadsID, L.RunID, L2.PickupLocationID, L2.DropoffLocationID, ISNULL(CONVERT(varchar(10),L2.DropoffDate,101),''),
		LEFT(ISNULL(CONVERT(varchar(10),L2.DropoffDate,108),''),5), RIGHT(CONVERT(varchar(20),L2.DropoffDate,100),7),
		ISNULL(T.TruckNumber,''), ISNULL(U.FirstName,'')+' '+ISNULL(U.LastName,''), ISNULL(D.DriverNumber,''),
		ISNULL(L3.LocationName,''), ISNULL(L3.AddressLine1,''), ISNULL(L3.AddressLine2,''), 
		ISNULL(L3.City,'')+', '+ISNULL(L3.State,'')+' '+ISNULL(L3.Zip,''), ISNULL(L3.LocationSubType,''), ISNULL(L.LoadNumber,''),
		ISNULL(L4.LocationName,''), ISNULL(L4.AddressLine1,''), ISNULL(L4.AddressLine2,''),
		ISNULL(L4.City,'')+', '+ISNULL(L4.State,'')+' '+ISNULL(L4.Zip,''),
		CASE WHEN DATALENGTH(L4.MainPhone)>=10 THEN '('+SUBSTRING(L4.MainPhone,1,3)+') '+SUBSTRING(L4.MainPhone,4,3)+'-'+SUBSTRING(L4.MainPhone,7,DATALENGTH(L4.MainPhone)-6) ELSE '' END,
		ISNULL(L4.DeliveryTimes,''),
		ISNULL(V.VIN,''), ISNULL(V.VehicleYear,''),
		ISNULL(V.Make,''), ISNULL(V.Model,''),
		LEC.GreetingName, LEC.EmailAddress, LEC.HTMLEmailSupportedInd, L2.SignatureFileName,
		L2.SignedBy, C2.CodeDescription, CONVERT(varchar(20),D.DriverID), 
		ISNULL((SELECT TOP 1 VI.SubjectToInspectionInd FROM VehicleInspection VI WHERE VI.VehicleID = V.VehicleID AND VI.InspectionType = 3),0),
		CASE WHEN V.CustomerID = (SELECT CONVERT(int,ValueDescription) FROM SettingTable WHERE ValueKey = 'NissanCustomerID') THEN (SELECT Top 1 C1.Value1 FROM Code C1, Code C2 WHERE C1.Code = C2.Code AND C1.CodeType = 'NissanCarrierCode' AND C2.CodeType = 'NissanRailheadCode' AND C2.Value1 = V.PickupLocationID) ELSE '' END,
		CASE WHEN V.CustomerID = (SELECT CONVERT(int,ValueDescription) FROM SettingTable WHERE ValueKey = 'NissanCustomerID') THEN V.RailcarNumber ELSE '' END,
		CASE WHEN V.CustomerID = (SELECT CONVERT(int,ValueDescription) FROM SettingTable WHERE ValueKey = 'NissanCustomerID') THEN (SELECT TOP 1 NI.RCode FROM NissanImportTE NI WHERE NI.VIN = V.VIN AND NI.D6Number = V.CustomerIdentification) ELSE '' END,
		CASE WHEN V.CustomerID = (SELECT CONVERT(int,ValueDescription) FROM SettingTable WHERE ValueKey = 'FordCustomerID') THEN '324' ELSE '' END
		FROM Loads L
		LEFT JOIN Legs L2 ON L.LoadsID = L2.LoadID
		--AND L2.FinalLegInd = 1
		LEFT JOIN Vehicle V ON L2.VehicleID = V.VehicleID
		LEFT JOIN Customer C ON V.CustomerID = C.CustomerID
		LEFT JOIN LocationEmailContacts LEC ON V.DropoffLocationID = LEC.LocationID 
		LEFT JOIN Location L3 ON L2.PickupLocationID = L3.LocationID
		LEFT JOIN Location L4 ON L2.DropoffLocationID = L4.LocationID
		LEFT JOIN Run R ON L.RunID = R.RunID
		LEFT JOIN Driver D ON R.DriverID = D.DriverID
		LEFT JOIN Users U ON D.UserID = U.UserID
		LEFT JOIN Truck T ON R.TruckID = T.TruckID
		LEFT JOIN Code C2 ON L2.NoSignatureReasonCode = C2.Code
		AND C2.CodeType = 'NoSignatureReasonCode'
		WHERE C.SendEmailConfirmationsInd = 1
		AND LEC.BillOfLadingInd = 1
		AND V.BillOfLadingSentInd = 0
		AND PATINDEX ('%@%.%',LEC.EmailAddress) > 0	--avoid poorly formed emails
		AND L2.DropoffDate IS NOT NULL
		AND L2.DropoffDate <= DATEADD(minute,-10,CURRENT_TIMESTAMP) -- want to make sure signature has time to be moved to daitera
		AND DATALENGTH(ISNULL(L2.SignatureFileName,''))>0
		AND L2.DropoffDate > DATEADD(day,-5,CURRENT_TIMESTAMP) --MINUS 5 DAYS IS REAL VALUE
		AND D.SignatureOnFileInd = 1
		ORDER BY L.LoadNumber, L2.PickupLocationID, L2.DropoffLocationID,LEC.EmailAddress, V.VIN
		*/
		SELECT BOLE.VehicleID, BOLE.LoadsID, BOLE.RunID, BOLE.PickupLocationID, BOLE.DropoffLocationID, ISNULL(CONVERT(varchar(10),BOLE.DropoffDate,101),''),
		LEFT(ISNULL(CONVERT(varchar(10),BOLE.DropoffDate,108),''),5), RIGHT(CONVERT(varchar(20),BOLE.DropoffDate,100),7),
		BOLE.TruckNumber, BOLE.DriverName, BOLE.DriverNumber,
		BOLE.OriginName, BOLE.OriginAddressLine1, BOLE.OriginAddressLine2, 
		BOLE.OriginCity+', '+BOLE.OriginState+' '+BOLE.OriginZip, BOLE.OriginSubType, BOLE.LoadNumber,
		BOLE.DestinationName, BOLE.DestinationAddressLine1, BOLE.DestinationAddressLine2,
		BOLE.DestinationCity+', '+BOLE.DestinationState+' '+BOLE.DestinationZip,
		CASE WHEN DATALENGTH(BOLE.DestinationPhone)>=10 THEN '('+SUBSTRING(BOLE.DestinationPhone,1,3)+') '+SUBSTRING(BOLE.DestinationPhone,4,3)+'-'+SUBSTRING(BOLE.DestinationPhone,7,DATALENGTH(BOLE.DestinationPhone)-6) ELSE '' END,
		BOLE.DestinationDeliveryTimes,
		BOLE.VIN, BOLE.VehicleYear,
		BOLE.Make, BOLE.Model,
		LEC.GreetingName, LEC.EmailAddress, LEC.HTMLEmailSupportedInd, L.SignatureFileName,
		L.SignedBy, C2.CodeDescription, CONVERT(varchar(20),BOLE.DriverID), 
		ISNULL((SELECT TOP 1 VI.SubjectToInspectionInd FROM VehicleInspection VI WHERE VI.VehicleID = BOLE.VehicleID AND VI.InspectionType = 3),0),
		BOLE.TCode, BOLE.RailcarNumber, BOLE.RCode, BOLE.FordCarrierID
		FROM BillOfLadingEmail BOLE
		LEFT JOIN Customer C ON BOLE.CustomerID = C.CustomerID
		LEFT JOIN LocationEmailContacts LEC ON BOLE.DropoffLocationID = LEC.LocationID
		LEFT JOIN Driver D ON BOLE.DriverID = D.DriverID
		LEFT JOIN Legs L ON BOLE.LegsID = L.LegsID
		LEFT JOIN Code C2 ON L.NoSignatureReasonCode = C2.Code
		AND C2.CodeType = 'NoSignatureReasonCode'
		WHERE C.SendEmailConfirmationsInd = 1
		AND LEC.BillOfLadingInd = 1
		AND BOLE.EmailSentInd = 0
		AND PATINDEX ('%@%.%',LEC.EmailAddress) > 0	--avoid poorly formed emails
		AND BOLE.DropoffDate <= DATEADD(minute,-10,CURRENT_TIMESTAMP) -- want to make sure signature has time to be moved to daitera
		AND DATALENGTH(ISNULL(L.SignatureFileName,''))>0
		AND BOLE.DropoffDate > DATEADD(day,-5,CURRENT_TIMESTAMP) --MINUS 5 DAYS IS REAL VALUE
		AND D.SignatureOnFileInd = 1
		ORDER BY BOLE.LoadNumber, BOLE.PickupLocationID, BOLE.DropoffLocationID,LEC.EmailAddress, BOLE.VIN

	SELECT @ErrorID = 0
	SELECT @loopcounter = 0
	
	
	OPEN BillOfLadingCursor
	--print 'cursor open'

	IF @@CURSOR_ROWS = 0
	BEGIN
		SELECT @ErrorID = 0
		GOTO Error_Encountered2
	END
	
	BEGIN TRAN

	FETCH BillOfLadingCursor INTO @VehicleID, @LoadsID, @RunID, @PickupLocationID, @DropoffLocationID,
		@DropoffDate, @DropoffTime, @DropoffTime2, @TruckNumber, @DriverName, @DriverNumber, @OriginName,
		@OriginAddressLine1, @OriginAddressLine2, @OriginCityStateZip, @OriginSubType, @LoadNumber,
		@DestinationName, @DestinationAddressLine1, @DestinationAddressLine2,
		@DestinationCityStateZip, @DestinationPhone, @DestinationDeliveryTimes,
		@VIN, @VehicleYear, @Make, @Model, @GreetingName, @EmailAddress, @HTMLSupportedInd,
		@SignatureFileName, @SignedBy, @NoSignatureReasonCode, @DriverID, @SubjectToInspectionInd, @TCode, @RailcarNumber, @RCode, @FordCarrierID
	
	
	SELECT @PreviousLoadNumber = @LoadNumber
	SELECT @PreviousPickupLocationID = @PickupLocationID
	SELECT @PreviousDropoffLocationID = @DropoffLocationID
	SELECT @PreviousEmailAddress = @EmailAddress
	SELECT @PreviousRunID = @RunID
	SELECT @PreviousDriverNumber = @DriverNumber
	SELECT @PreviousDropoffDate = @DropoffDate
	SELECT @PreviousDropoffTime2 = @DropoffTime2
	SELECT @PreviousSignatureFileName = @SignatureFileName
	SELECT @PreviousDriverName = @DriverName
	SELECT @PreviousSignedBy = @SignedBy
	SELECT @PreviousDriverID = @DriverID
	SELECT @PreviousNoSignatureReasonCode = @NoSignatureReasonCode
		
	SELECT TOP 1 @CompanyName = AC.CompanyName, @CompanyAddressLine1 = AC.AddressLine1,
	@CompanyAddressLine2 = AC.AddressLine2, @CompanyCityStateZip = AC.City+',  '+AC.State+'   '+AC.Zip,
	@CompanyPhone = '('+SUBSTRING(AC.Phone,1,3)+') '+SUBSTRING(AC.Phone,4,3)+'-'+SUBSTRING(AC.Phone,7,DATALENGTH(AC.Phone)-6),
	@CompanyFaxNumber = '('+SUBSTRING(AC.FaxNumber,1,3)+') '+SUBSTRING(AC.FaxNumber,4,3)+'-'+SUBSTRING(AC.FaxNumber,7,DATALENGTH(AC.FaxNumber)-6)
	FROM ApplicationConstants AC
	
	SELECT @Body = ''
	SELECT @HTMLBody = ''
	SELECT @MessageFooter = ''
	SELECT @MessageFooter2 = ''
			
	-- set the greeting and the body header
	SELECT @CommandString = 'del '+@BOLPath
	EXEC master..xp_cmdshell @CommandString
	EXEC sp_AppendToFile @BOLPath, '<html>'
	EXEC sp_AppendToFile @BOLPath, '<style>'
	EXEC sp_AppendToFile @BOLPath, 'p            {font-family: Verdana, Arial, Helvetica;'
	EXEC sp_AppendToFile @BOLPath, '             }'
	EXEC sp_AppendToFile @BOLPath, '.CompanyAddress   {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @BOLPath, '              font-size: 11pt;'
	EXEC sp_AppendToFile @BOLPath, '              color: black;'
	EXEC sp_AppendToFile @BOLPath, '              }'
	EXEC sp_AppendToFile @BOLPath, '.URBBold     {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @BOLPath, '             font-size: 10pt;'
	EXEC sp_AppendToFile @BOLPath, '             font-weight: bold;'
	EXEC sp_AppendToFile @BOLPath, '             color: black;'
	EXEC sp_AppendToFile @BOLPath, '             }'
	EXEC sp_AppendToFile @BOLPath, '.URB         {font-family: Verdana, Arial, Helvetica;'
	EXEC sp_AppendToFile @BOLPath, '             font-size: 10pt;'
	EXEC sp_AppendToFile @BOLPath, '             color: black;'
	EXEC sp_AppendToFile @BOLPath, '             }'
	EXEC sp_AppendToFile @BOLPath, '.Title       {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @BOLPath, '             font-size: 15pt;'
	EXEC sp_AppendToFile @BOLPath, '             font-weight: bold;'
	EXEC sp_AppendToFile @BOLPath, '             color: black;'
	EXEC sp_AppendToFile @BOLPath, '             }'
	EXEC sp_AppendToFile @BOLPath, '.ABBold      {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @BOLPath, '             font-size: 10pt;'
	EXEC sp_AppendToFile @BOLPath, '             font-weight: bold;'
	EXEC sp_AppendToFile @BOLPath, '             color: black;'
	EXEC sp_AppendToFile @BOLPath, '             }'
	EXEC sp_AppendToFile @BOLPath, '.AB          {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @BOLPath, '             font-size: 10pt;'
	EXEC sp_AppendToFile @BOLPath, '             color: black;'
	EXEC sp_AppendToFile @BOLPath, '             }'
	EXEC sp_AppendToFile @BOLPath, '.VBHeader    {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @BOLPath, '             font-size: 9pt;'
	EXEC sp_AppendToFile @BOLPath, '             font-weight: bold;'
	EXEC sp_AppendToFile @BOLPath, '             color: black;'
	EXEC sp_AppendToFile @BOLPath, '             }'
	EXEC sp_AppendToFile @BOLPath, '.VB          {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @BOLPath, '             font-size: 9pt;'
	EXEC sp_AppendToFile @BOLPath, '             color: black;'
	EXEC sp_AppendToFile @BOLPath, '             }'
	EXEC sp_AppendToFile @BOLPath, '.SBHeader    {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @BOLPath, '             font-size: 12pt;'
	EXEC sp_AppendToFile @BOLPath, '             font-weight: bold;'
	EXEC sp_AppendToFile @BOLPath, '             color: black;'
	EXEC sp_AppendToFile @BOLPath, '             }'
	EXEC sp_AppendToFile @BOLPath, '.SB          {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @BOLPath, '             font-size: 10pt;'
	EXEC sp_AppendToFile @BOLPath, '             color: black;'
	EXEC sp_AppendToFile @BOLPath, '             }'
	EXEC sp_AppendToFile @BOLPath, '.SBFooter    {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @BOLPath, '             font-size: 10pt;'
	EXEC sp_AppendToFile @BOLPath, '             font-weight: bold;'
	EXEC sp_AppendToFile @BOLPath, '             color: black;'
	EXEC sp_AppendToFile @BOLPath, '             }'
	EXEC sp_AppendToFile @BOLPath, '.Disclosure  {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @BOLPath, '             font-size: 9pt;'
	EXEC sp_AppendToFile @BOLPath, '             color: black;'
	EXEC sp_AppendToFile @BOLPath, '             font-weight: bold;'
	EXEC sp_AppendToFile @BOLPath, '             text-decoration: underline;'
	EXEC sp_AppendToFile @BOLPath, '             }'
	EXEC sp_AppendToFile @BOLPath, '.AucDisc     {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @BOLPath, '             font-size: 9pt;'
	EXEC sp_AppendToFile @BOLPath, '             color: black;'
	EXEC sp_AppendToFile @BOLPath, '             }'
	EXEC sp_AppendToFile @BOLPath, '.CopyInd    {font-family: Arial, Helvetica;'
	EXEC sp_AppendToFile @BOLPath, '             font-size: 12pt;'
	EXEC sp_AppendToFile @BOLPath, '             color: black;'
	EXEC sp_AppendToFile @BOLPath, '             font-weight: bold;'
	EXEC sp_AppendToFile @BOLPath, '             }'
	EXEC sp_AppendToFile @BOLPath, '</style>'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0">'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" width = "175">'
	
	--COMPANY LOGO
	SELECT @AppendString = '<img src="'+@CompanyLogoURL+'" width="125" height="125">'
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" width = "250">'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0">'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
	EXEC sp_AppendToFile @BOLPath, '<table  cellpadding="0" cellspacing="0">'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td>'
	
	--COMPANY ADDRESS
	SELECT @AppendString = '<p class=CompanyAddress>' + @CompanyName
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td>'
	SELECT @AppendString = '<p class=CompanyAddress>'+@CompanyAddressLine1
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	IF DATALENGTH(ISNULL(@CompanyAddressLine2,'')) > 0
	BEGIN
		EXEC sp_AppendToFile @BOLPath, '<tr>'
		EXEC sp_AppendToFile @BOLPath, '<td>'
		SELECT @AppendString = '<p class=CompanyAddress>'+@CompanyAddressLine2
		EXEC sp_AppendToFile @BOLPath, @AppendString
		EXEC sp_AppendToFile @BOLPath, '</td>'
		EXEC sp_AppendToFile @BOLPath, '</tr>'
		EXEC sp_AppendToFile @BOLPath, '<tr>'
	END
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td>'
	SELECT @AppendString = '<p class=CompanyAddress>'+@CompanyCityStateZip
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td>'
	SELECT @AppendString = '<p class=CompanyAddress>Phone: '+@CompanyPhone
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td>'
	SELECT @AppendString = '<p class=CompanyAddress>Fax: '+@CompanyFaxNumber
	EXEC sp_AppendToFile @BOLPath, @AppendString
	--END OF COMPANY ADDRESS
	
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	
	--FORD CARRIER ID SWITCH
	IF DATALENGTH(ISNULL(@FordCarrierID,'')) > 0
	BEGIN
		EXEC sp_AppendToFile @BOLPath, '<tr>'
		EXEC sp_AppendToFile @BOLPath, '<td>'
		SELECT @AppendString = '<p class=CompanyAddress>Ford Carrier ID: '+@FordCarrierID
		EXEC sp_AppendToFile @BOLPath, @AppendString
		EXEC sp_AppendToFile @BOLPath, '</td>'
		EXEC sp_AppendToFile @BOLPath, '</tr>'
	END
	--END OF FORD CARRIER ID SWITCH
	
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border = 1>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border = 0>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "120" align="center">'
	EXEC sp_AppendToFile @BOLPath, '<p class=URBBold> Date'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "120" align="center">'
	
	--DATE
	SELECT @AppendString = '<p class=URB>'+@DropoffDate
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border = 0>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "65" align="center">'
	EXEC sp_AppendToFile @BOLPath, '<p class=URBBold>Truck #'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "65" align="center">'
	
	--TRUCK NUMBER
	SELECT @AppendString = '<p class=URB>'+@TruckNumber
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border = 0>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "120" align="center">'
	EXEC sp_AppendToFile @BOLPath, '<p class=URBBold>Driver Name'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "120" align="center">'
	
	--DRIVER NAME
	SELECT @AppendString = '<p class=URB>'+ @DriverName
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border = 0>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "65" align="center">'
	EXEC sp_AppendToFile @BOLPath, '<p class=URBBold>Driver #'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "65" align="center">'
	
	--DRIVER NUMBER
	SELECT @AppendString = '<p class=URB>'+@DriverNumber
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" width="750">'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="center">'
	EXEC sp_AppendToFile @BOLPath, '<p class=Title>Transportation Delivery Ticket'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="center">'
	EXEC sp_AppendToFile @BOLPath, '<p class=Title>&nbsp;'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border="1" width="650">'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border="0"'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "175">'
	EXEC sp_AppendToFile @BOLPath, '<p class=ABBold>Pickup Address:'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "250">'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0">'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
	EXEC sp_AppendToFile @BOLPath, '<table  cellpadding="0" cellspacing="0">'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td>'
	
	--PICKUP ADDRESS
	SELECT @AppendString = '<p class=ABBold>'+@OriginName
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td>'
	SELECT @AppendString = '<p class=ABBold>'+@OriginAddressLine1
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	IF DATALENGTH(@OriginAddressLine2) > 0
	BEGIN
		EXEC sp_AppendToFile @BOLPath, '<tr>'
		EXEC sp_AppendToFile @BOLPath, '<td>'
		SELECT @AppendString = '<p class=ABBold>'+@OriginAddressLine2
		EXEC sp_AppendToFile @BOLPath, @AppendString
		EXEC sp_AppendToFile @BOLPath, '</td>'
		EXEC sp_AppendToFile @BOLPath, '</tr>'
	
	END
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td>'
	SELECT @AppendString = '<p class=ABBold>'+@OriginCityStateZip
	EXEC sp_AppendToFile @BOLPath, @AppendString
	--END OF PICKUP ADDRESS
	
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border = 0>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border = 0>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="left">'
	EXEC sp_AppendToFile @BOLPath, '<p class=ABBold>Load Number:'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="left">'
	
	--LOAD NUMBER
	SELECT @AppendString = '<p class=ABBold>'+@LoadNumber
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border="0"'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" width = "175">'
	EXEC sp_AppendToFile @BOLPath, '<p class=ABBold>Deliver To:'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "250">'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0">'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
	EXEC sp_AppendToFile @BOLPath, '<table  cellpadding="0" cellspacing="0">'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td>'
	
	--DELIVERY ADDRESS
	SELECT @AppendString = '<p class=ABBold>'+@DestinationName
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td>'
	SELECT @AppendString = '<p class=ABBold>'+@DestinationAddressLine1
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	IF DATALENGTH(@DestinationAddressLine2)>0
	BEGIN
		EXEC sp_AppendToFile @BOLPath, '<tr>'
		EXEC sp_AppendToFile @BOLPath, '<td>'
		SELECT @AppendString = '<p class=ABBold>'+@DestinationAddressLine2
		EXEC sp_AppendToFile @BOLPath, @AppendString
		EXEC sp_AppendToFile @BOLPath, '</td>'
		EXEC sp_AppendToFile @BOLPath, '</tr>'
	
	END
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td>'
	SELECT @AppendString = '<p class=ABBold>'+@DestinationCityStateZip
	EXEC sp_AppendToFile @BOLPath, @AppendString
	--END OF DELIVERY ADDRESS
	
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border = 0>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border = 0>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="left">'
	EXEC sp_AppendToFile @BOLPath, '<p class=ABBold>Phone:'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="left">'
	
	--DELIVERY PHONE
	SELECT @AppendString = '<p class=AB>'+@DestinationPhone
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="left">'
	EXEC sp_AppendToFile @BOLPath, '<p class=ABBold>Hours:'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="left">'
	
	--DELIVERY HOURS
	SELECT @AppendString = '<p class=AB>'+@DestinationDeliveryTimes
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	
	--CHAMBERS PARKING WARNING
	IF @DropoffLocationID IN (27022, 35500, 37231)
	BEGIN
		EXEC sp_AppendToFile @BOLPath, '<tr>'
		EXEC sp_AppendToFile @BOLPath, '<td>'
		EXEC sp_AppendToFile @BOLPath, '<p class=ABBold>&nbsp;'
		EXEC sp_AppendToFile @BOLPath, '</tr>'
		EXEC sp_AppendToFile @BOLPath, '</td>'
		EXEC sp_AppendToFile @BOLPath, '<tr>'
		EXEC sp_AppendToFile @BOLPath, '<td align="center" colspan="3">'
		EXEC sp_AppendToFile @BOLPath, '<p class=ABBold>***DO NOT PARK IN STREET TO UNLOAD VEHICLES***'
		EXEC sp_AppendToFile @BOLPath, '</tr>'
		EXEC sp_AppendToFile @BOLPath, '</td>'
	END
	
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0">'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width="30">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width="170">'
	EXEC sp_AppendToFile @BOLPath, '<p class=VBHeader>VIN'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width="220">'
	EXEC sp_AppendToFile @BOLPath, '<p class=VBHeader>DESCRIPTION'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0">'
		
	IF @SubjectToInspectionInd = 0
	BEGIN
		SELECT @Subject = 'DAI Bill of Lading for Load # '+@LoadNumber
	END
	ELSE
	BEGIN
		SELECT @Subject = 'DAI Bill of Lading for Load # '+@LoadNumber+', STI, Further Action Required'
	END
	
	SELECT @Body = @Body+'Diversified Automotive Transportation Delivery Ticket'+CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
	SELECT @Body = @Body+'Dear '+@GreetingName+','+CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
	SELECT @Body = @Body+'Attached to this e-mail is a digital copy of your Bill of Lading for load # '+@LoadNumber+','
	SELECT @Body = @Body+' delivered on '+@DropoffDate+' at '+@DropoffTime+'. If this delivery was made "Subject to Inspection",'
	SELECT @Body = @Body+' which would be denoted with an "STI" below the dealer signature field, further action is requested.'
	SELECT @Body = @Body+' You have 48 hours from the time noted above to perform an inspection on these vehicles, after which'
	SELECT @Body = @Body+' you must fax a signed copy of this bill of lading to 617-242-4455. This serves two purposes: notifying'
	SELECT @Body = @Body+' us of any pending claims as well as acknowledging that you have accounted for these vehicles on your property.'
	SELECT @Body = @Body+' Failure to do so may result in the denial of any claims pertaining to the vehicles on this load.'
	SELECT @Body = @Body+CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
	SELECT @Body = @Body+'If upon inspection all vehicles are damage free, please just sign and fax without further action. If any'
	SELECT @Body = @Body+' damage is noted, please fax and follow up with a phone call to Ken Collins at 1-800-666-9007 x103. Ken'
	SELECT @Body = @Body+' manages our claims process and can assist you in properly filing a claim.'
	SELECT @Body = @Body+CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
	SELECT @Body = @Body+'For optimal printing, please open up the attachment and print.'  
	SELECT @Body = @Body+CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
	SELECT @Body = @Body+'If you would like to request to have other employees be the recipient of these emails, or you cannot read'
	SELECT @Body = @Body+' the attachment, please contact our dispatch office at 1-800-666-9007 x104. We appreciate the opportunity'
	SELECT @Body = @Body+' to serve you. We hope that our efforts to become more efficient and environmentally conscious provide a'
	SELECT @Body = @Body+' value added benefit to our service. Your feedback is always welcome.'
	SELECT @Body = @Body+CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
	SELECT @Body = @Body+' Thanks again.'
	SELECT @VINCount = 0
			
	--print 'about to enter loop'
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--print 'entering loop'
		-- if we are moving to the next load/location/emailaddress, send the email out
		IF @PreviousLoadNumber <> @LoadNumber OR @PreviousPickupLocationID <> @PickupLocationID OR @PreviousDropoffLocationID <> @DropoffLocationID OR @PreviousEmailAddress <> @EmailAddress OR @PreviousRunID <> @RunID
		BEGIN
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border="0" width="650">'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top">'
			EXEC sp_AppendToFile @BOLPath, '<p class=SBHeader>&nbsp'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top">'
			EXEC sp_AppendToFile @BOLPath, '<p class=SBHeader>Signatures:'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border="0" width="650">'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
			EXEC sp_AppendToFile @BOLPath, '<p class=SB>Driver:'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
			
			--DRIVER SIGNATURE
			SELECT @AppendString = '<img src="'+@DriverSignatureURL+@PreviousDriverID+'.bmp" width="144" height="50">'
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
			EXEC sp_AppendToFile @BOLPath, '<p class=SB>Date:'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
			
			--SIGNATURE DATE
			SELECT @AppendString = '<p class=SB>'+@PreviousDropoffDate
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
			EXEC sp_AppendToFile @BOLPath, '<p class=SB>Dealer:'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
			
			--DEALER SIGNATURE
			SELECT @AppendString = '<img src="'+@DealerSignatureURL+@PreviousSignatureFileName+'" width="144" height="50">'
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
			EXEC sp_AppendToFile @BOLPath, '<p class=SB>Date:'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
			
			--SIGNATURE DATE
			SELECT @AppendString = '<p class=SB>'+@PreviousDropoffDate
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
			
			--DRIVER NAME
			SELECT @AppendString = '<p class=SB>'+@PreviousDriverName
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
			SELECT @AppendString = '<p class=SB>'+@PreviousDropoffTime2
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
			SELECT @AppendString = '<p class=SB>'+@PreviousSignedBy
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
			SELECT @AppendString = '<p class=SB>'+@PreviousDropoffTime2
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			
			--SWITCH FOR STI
			IF DATALENGTH(@PreviousNoSignatureReasonCode) > 0
			BEGIN
				EXEC sp_AppendToFile @BOLPath, '<tr>'
				EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
				EXEC sp_AppendToFile @BOLPath, '</td>'
				EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
				EXEC sp_AppendToFile @BOLPath, '</td>'
				EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
				EXEC sp_AppendToFile @BOLPath, '</td>'
				EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
				EXEC sp_AppendToFile @BOLPath, '</td>'
				EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
				EXEC sp_AppendToFile @BOLPath, '<p class=SB>STI Reason:'
				EXEC sp_AppendToFile @BOLPath, '</td>'
				EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
				SELECT @AppendString = '<p class=SB>'+@PreviousNoSignatureReasonCode
				EXEC sp_AppendToFile @BOLPath, @AppendString
				EXEC sp_AppendToFile @BOLPath, '</td>'
				EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
				EXEC sp_AppendToFile @BOLPath, '</td>'
				EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
				EXEC sp_AppendToFile @BOLPath, '</td>'
				EXEC sp_AppendToFile @BOLPath, '</tr>'
			END
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
			EXEC sp_AppendToFile @BOLPath, '<p class=SB>&nbsp;'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
			EXEC sp_AppendToFile @BOLPath, '<p class=SB>&nbsp;'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" width="660">'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="center">'
			EXEC sp_AppendToFile @BOLPath, '<p class = SBFooter>PLEASE SIGN AND DATE BOTH COPIES'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="center">'
			EXEC sp_AppendToFile @BOLPath, '<p class=Disclosure>Damage Noted At The Time Of Delivery Must Be Noted On Both The Dealer And Driver Copies. All Damages/Shortages'
			EXEC sp_AppendToFile @BOLPath, 'Discovered On Vehicles Dropped After Hours Or Subject To Inspection (S.T.I.) Must Be Reported Within 48 Hours Of Delivery.'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="center">'
			EXEC sp_AppendToFile @BOLPath, '<p class=Disclosure>Pictures Must Be Sent To Support All Claims.'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			IF @PreviousOriginSubType='Auction'
			BEGIN
				EXEC sp_AppendToFile @BOLPath, '<tr>'
				EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="center">'
				EXEC sp_AppendToFile @BOLPath, '<p class=AucDisc>Diversified Automotive does not accept responsibility as it relates to Auction purchased Vehicles for any claims'
				EXEC sp_AppendToFile @BOLPath, ' considered normal wear & tear items. These items include but are not limited to: stained or damaged interiors, minor door and/or'
				EXEC sp_AppendToFile @BOLPath, ' panel dings, minor scratches, bumper imperfections and chipped glass surfaces.'
				EXEC sp_AppendToFile @BOLPath, '<br>Additionally, Diversified Automotive shall not be held liable for any missing components (i.e. Audio and/or Navigation'
				EXEC sp_AppendToFile @BOLPath, ' systems, shift knobs, owner manuals, spare tire and wheel, audio antennas etc.) as no evaluation of  these components are made at the'
				EXEC sp_AppendToFile @BOLPath, ' time of vehicle pickup.'
				EXEC sp_AppendToFile @BOLPath, '</td>'
				EXEC sp_AppendToFile @BOLPath, '</tr>'
			END
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border="0" width="650">'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "175">'
			EXEC sp_AppendToFile @BOLPath, '<p class=CopyInd>Dealer Copy'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
			EXEC sp_AppendToFile @BOLPath, '<p>&nbsp;'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "75">'
			EXEC sp_AppendToFile @BOLPath, '<p>&nbsp;'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
			EXEC sp_AppendToFile @BOLPath, '<p>&nbsp;'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "75">'
			EXEC sp_AppendToFile @BOLPath, '<p>&nbsp;'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
			EXEC sp_AppendToFile @BOLPath, '<p>&nbsp;'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "125">'
			EXEC sp_AppendToFile @BOLPath, '<p class=SB>Load Number:'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
				
			--LOAD NUMBER
			SELECT @AppendString = '<p class=SB>'+@PreviousLoadNumber
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</html>'
			
			--print 'about to send'
			--print 'body = '+isnull(@Body,'')
			--print 'htmlbody = '+isnull(@HTMLBody,'')
			-- send the email
			EXEC @ResultCode = sp_send_cdosysmail
				@SMTPUsername,
				@PreviousEmailAddress,
				@Subject,
				@Body,
				@HTMLBody,
				@SMTPServer,
				'1',
				@SMTPUsername,
				@SMTPPassword,
				'customer.service@diversifiedauto.com',
				@BOLPath,
				0
				
			IF @ResultCode <> 0
			BEGIN
				SELECT @ErrorID = @ResultCode
				SELECT @Status = 'Error Sending Email'
				GOTO Error_Encountered
			END
			
			COMMIT TRAN -- don't want to roll back anything that sent successfully
						
			BEGIN TRAN
						
			
			--print 'about to clear the body fields'
			-- clear the body fields
			SELECT @Body = ''
			SELECT @HTMLBody = ''
			
			-- set the greeting and the body header
			--print 'html is supported - creating header'
			SELECT @CommandString = 'del '+@BOLPath
			EXEC master..xp_cmdshell @CommandString
			EXEC sp_AppendToFile @BOLPath, '<html>'
			EXEC sp_AppendToFile @BOLPath, '<style>'
			EXEC sp_AppendToFile @BOLPath, 'p            {font-family: Verdana, Arial, Helvetica;'
			EXEC sp_AppendToFile @BOLPath, '             }'
			EXEC sp_AppendToFile @BOLPath, '.CompanyAddress   {font-family: Arial, Helvetica;'
			EXEC sp_AppendToFile @BOLPath, '              font-size: 11pt;'
			EXEC sp_AppendToFile @BOLPath, '              color: black;'
			EXEC sp_AppendToFile @BOLPath, '              }'
			EXEC sp_AppendToFile @BOLPath, '.URBBold     {font-family: Arial, Helvetica;'
			EXEC sp_AppendToFile @BOLPath, '             font-size: 10pt;'
			EXEC sp_AppendToFile @BOLPath, '             font-weight: bold;'
			EXEC sp_AppendToFile @BOLPath, '             color: black;'
			EXEC sp_AppendToFile @BOLPath, '             }'
			EXEC sp_AppendToFile @BOLPath, '.URB         {font-family: Verdana, Arial, Helvetica;'
			EXEC sp_AppendToFile @BOLPath, '             font-size: 10pt;'
			EXEC sp_AppendToFile @BOLPath, '             color: black;'
			EXEC sp_AppendToFile @BOLPath, '             }'
			EXEC sp_AppendToFile @BOLPath, '.Title       {font-family: Arial, Helvetica;'
			EXEC sp_AppendToFile @BOLPath, '             font-size: 15pt;'
			EXEC sp_AppendToFile @BOLPath, '             font-weight: bold;'
			EXEC sp_AppendToFile @BOLPath, '             color: black;'
			EXEC sp_AppendToFile @BOLPath, '             }'
			EXEC sp_AppendToFile @BOLPath, '.ABBold      {font-family: Arial, Helvetica;'
			EXEC sp_AppendToFile @BOLPath, '             font-size: 10pt;'
			EXEC sp_AppendToFile @BOLPath, '             font-weight: bold;'
			EXEC sp_AppendToFile @BOLPath, '             color: black;'
			EXEC sp_AppendToFile @BOLPath, '             }'
			EXEC sp_AppendToFile @BOLPath, '.AB          {font-family: Arial, Helvetica;'
			EXEC sp_AppendToFile @BOLPath, '             font-size: 10pt;'
			EXEC sp_AppendToFile @BOLPath, '             color: black;'
			EXEC sp_AppendToFile @BOLPath, '             }'
			EXEC sp_AppendToFile @BOLPath, '.VBHeader    {font-family: Arial, Helvetica;'
			EXEC sp_AppendToFile @BOLPath, '             font-size: 9pt;'
			EXEC sp_AppendToFile @BOLPath, '             font-weight: bold;'
			EXEC sp_AppendToFile @BOLPath, '             color: black;'
			EXEC sp_AppendToFile @BOLPath, '             }'
			EXEC sp_AppendToFile @BOLPath, '.VB          {font-family: Arial, Helvetica;'
			EXEC sp_AppendToFile @BOLPath, '             font-size: 9pt;'
			EXEC sp_AppendToFile @BOLPath, '             color: black;'
			EXEC sp_AppendToFile @BOLPath, '             }'
			EXEC sp_AppendToFile @BOLPath, '.SBHeader    {font-family: Arial, Helvetica;'
			EXEC sp_AppendToFile @BOLPath, '             font-size: 12pt;'
			EXEC sp_AppendToFile @BOLPath, '             font-weight: bold;'
			EXEC sp_AppendToFile @BOLPath, '             color: black;'
			EXEC sp_AppendToFile @BOLPath, '             }'
			EXEC sp_AppendToFile @BOLPath, '.SB          {font-family: Arial, Helvetica;'
			EXEC sp_AppendToFile @BOLPath, '             font-size: 10pt;'
			EXEC sp_AppendToFile @BOLPath, '             color: black;'
			EXEC sp_AppendToFile @BOLPath, '             }'
			EXEC sp_AppendToFile @BOLPath, '.SBFooter    {font-family: Arial, Helvetica;'
			EXEC sp_AppendToFile @BOLPath, '             font-size: 10pt;'
			EXEC sp_AppendToFile @BOLPath, '             font-weight: bold;'
			EXEC sp_AppendToFile @BOLPath, '             color: black;'
			EXEC sp_AppendToFile @BOLPath, '             }'
			EXEC sp_AppendToFile @BOLPath, '.Disclosure  {font-family: Arial, Helvetica;'
			EXEC sp_AppendToFile @BOLPath, '             font-size: 9pt;'
			EXEC sp_AppendToFile @BOLPath, '             color: black;'
			EXEC sp_AppendToFile @BOLPath, '             font-weight: bold;'
			EXEC sp_AppendToFile @BOLPath, '             text-decoration: underline;'
			EXEC sp_AppendToFile @BOLPath, '             }'
			EXEC sp_AppendToFile @BOLPath, '.AucDisc     {font-family: Arial, Helvetica;'
			EXEC sp_AppendToFile @BOLPath, '             font-size: 9pt;'
			EXEC sp_AppendToFile @BOLPath, '             color: black;'
			EXEC sp_AppendToFile @BOLPath, '             }'
			EXEC sp_AppendToFile @BOLPath, '.CopyInd    {font-family: Arial, Helvetica;'
			EXEC sp_AppendToFile @BOLPath, '             font-size: 12pt;'
			EXEC sp_AppendToFile @BOLPath, '             color: black;'
			EXEC sp_AppendToFile @BOLPath, '             font-weight: bold;'
			EXEC sp_AppendToFile @BOLPath, '             }'
			EXEC sp_AppendToFile @BOLPath, '</style>'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0">'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" width = "175">'
			
			--COMPANY LOGO
			SELECT @AppendString = '<img src="'+@CompanyLogoURL+'" width="125" height="125">'
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" width = "250">'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0">'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
			EXEC sp_AppendToFile @BOLPath, '<table  cellpadding="0" cellspacing="0">'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td>'
				
			--COMPANY ADDRESS
			SELECT @AppendString = '<p class=CompanyAddress>' + @CompanyName
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td>'
			SELECT @AppendString = '<p class=CompanyAddress>'+@CompanyAddressLine1
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			IF DATALENGTH(ISNULL(@CompanyAddressLine2,'')) > 0
			BEGIN
				EXEC sp_AppendToFile @BOLPath, '<tr>'
				EXEC sp_AppendToFile @BOLPath, '<td>'
				SELECT @AppendString = '<p class=CompanyAddress>'+@CompanyAddressLine2
				EXEC sp_AppendToFile @BOLPath, @AppendString
				EXEC sp_AppendToFile @BOLPath, '</td>'
				EXEC sp_AppendToFile @BOLPath, '</tr>'
				EXEC sp_AppendToFile @BOLPath, '<tr>'
			END
			EXEC sp_AppendToFile @BOLPath, '<td>'
			SELECT @AppendString = '<p class=CompanyAddress>'+@CompanyCityStateZip
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td>'
			SELECT @AppendString = '<p class=CompanyAddress>Phone: '+@CompanyPhone
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td>'
			SELECT @AppendString = '<p class=CompanyAddress>Fax: '+@CompanyFaxNumber
			EXEC sp_AppendToFile @BOLPath, @AppendString
			--END OF COMPANY ADDRESS
	
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			
			--FORD CARRIER ID SWITCH
			IF DATALENGTH(ISNULL(@FordCarrierID,'')) > 0
			BEGIN
				EXEC sp_AppendToFile @BOLPath, '<tr>'
				EXEC sp_AppendToFile @BOLPath, '<td>'
				SELECT @AppendString = '<p class=CompanyAddress>Ford Carrier ID: '+@FordCarrierID
				EXEC sp_AppendToFile @BOLPath, @AppendString
				EXEC sp_AppendToFile @BOLPath, '</td>'
				EXEC sp_AppendToFile @BOLPath, '</tr>'
			END
			--END OF FORD CARRIER ID SWITCH
			
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border = 1>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border = 0>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "120" align="center">'
			EXEC sp_AppendToFile @BOLPath, '<p class=URBBold> Date'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "120" align="center">'
		
			--DATE
			SELECT @AppendString = '<p class=URB>'+@DropoffDate
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border = 0>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "65" align="center">'
			EXEC sp_AppendToFile @BOLPath, '<p class=URBBold>Truck #'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "65" align="center">'
	
			--TRUCK NUMBER
			SELECT @AppendString = '<p class=URB>'+@TruckNumber
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border = 0>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "120" align="center">'
			EXEC sp_AppendToFile @BOLPath, '<p class=URBBold>Driver Name'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "120" align="center">'
	
			--DRIVER NAME
			SELECT @AppendString = '<p class=URB>'+@DriverName
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border = 0>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "65" align="center">'
			EXEC sp_AppendToFile @BOLPath, '<p class=URBBold>Driver #'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "65" align="center">'
	
			--DRIVER NUMBER
			SELECT @AppendString = '<p class=URB>'+@DriverNumber
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" width="750">'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="center">'
			EXEC sp_AppendToFile @BOLPath, '<p class=Title>Transportation Delivery Ticket'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="center">'
			EXEC sp_AppendToFile @BOLPath, '<p class=Title>&nbsp;'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border="1" width="650">'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border="0"'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "175">'
			EXEC sp_AppendToFile @BOLPath, '<p class=ABBold>Pickup Address:'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "250">'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0">'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
			EXEC sp_AppendToFile @BOLPath, '<table  cellpadding="0" cellspacing="0">'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td>'
	
			--PICKUP ADDRESS
			SELECT @AppendString = '<p class=ABBold>'+@OriginName
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td>'
			SELECT @AppendString = '<p class=ABBold>'+@OriginAddressLine1
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			IF DATALENGTH(@OriginAddressLine2) > 0
			BEGIN
				EXEC sp_AppendToFile @BOLPath, '<tr>'
				EXEC sp_AppendToFile @BOLPath, '<td>'
				SELECT @AppendString = '<p class=ABBold>'+@OriginAddressLine2
				EXEC sp_AppendToFile @BOLPath, @AppendString
				EXEC sp_AppendToFile @BOLPath, '</td>'
				EXEC sp_AppendToFile @BOLPath, '</tr>'
			END
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td>'
			SELECT @AppendString = '<p class=ABBold>'+@OriginCityStateZip
			EXEC sp_AppendToFile @BOLPath, @AppendString
			--END OF PICKUP ADDRESS
	
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border = 0>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border = 0>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="left">'
			EXEC sp_AppendToFile @BOLPath, '<p class=ABBold>Load Number:'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="left">'
	
			--LOAD NUMBER
			SELECT @AppendString = '<p class=ABBold>'+@LoadNumber
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border="0"'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" width = "175">'
			EXEC sp_AppendToFile @BOLPath, '<p class=ABBold>Deliver To:'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width = "250">'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0">'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
			EXEC sp_AppendToFile @BOLPath, '<table  cellpadding="0" cellspacing="0">'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td>'
	
			--DELIVERY ADDRESS
			SELECT @AppendString = '<p class=ABBold>'+@DestinationName
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td>'
			SELECT @AppendString = '<p class=ABBold>'+@DestinationAddressLine1
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			IF DATALENGTH(@DestinationAddressLine2)>0
			BEGIN
				EXEC sp_AppendToFile @BOLPath, '<tr>'
				EXEC sp_AppendToFile @BOLPath, '<td>'
				SELECT @AppendString = '<p class=ABBold>'+@DestinationAddressLine2
				EXEC sp_AppendToFile @BOLPath, @AppendString
				EXEC sp_AppendToFile @BOLPath, '</td>'
				EXEC sp_AppendToFile @BOLPath, '</tr>'
			END
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td>'
			SELECT @AppendString = '<p class=ABBold>'+@DestinationCityStateZip
			EXEC sp_AppendToFile @BOLPath, @AppendString
			--END OF DELIVERY ADDRESS
	
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border = 0>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border = 0>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="left">'
			EXEC sp_AppendToFile @BOLPath, '<p class=ABBold>Phone:'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="left">'
	
			--DELIVERY PHONE
			SELECT @AppendString = '<p class=AB>'+@DestinationPhone
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="left">'
			EXEC sp_AppendToFile @BOLPath, '<p class=ABBold>Hours:'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="left">'
	
			--DELIVERY HOURS
			SELECT @AppendString = '<p class=AB>'+@DestinationDeliveryTimes
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			
			--CHAMBERS PARKING WARNING
			IF @DropoffLocationID IN (27022, 35500, 37231)
			BEGIN
				EXEC sp_AppendToFile @BOLPath, '<tr>'
				EXEC sp_AppendToFile @BOLPath, '<td>'
				EXEC sp_AppendToFile @BOLPath, '<p class=ABBold>&nbsp;'
				EXEC sp_AppendToFile @BOLPath, '</tr>'
				EXEC sp_AppendToFile @BOLPath, '</td>'
				EXEC sp_AppendToFile @BOLPath, '<tr>'
				EXEC sp_AppendToFile @BOLPath, '<td align="center" colspan="3">'
				EXEC sp_AppendToFile @BOLPath, '<p class=ABBold>***DO NOT PARK IN STREET TO UNLOAD VEHICLES***'
				EXEC sp_AppendToFile @BOLPath, '</tr>'
				EXEC sp_AppendToFile @BOLPath, '</td>'
			END
	
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0">'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width="30">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width="170">'
			EXEC sp_AppendToFile @BOLPath, '<p class=VBHeader>VIN'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width="220">'
			EXEC sp_AppendToFile @BOLPath, '<p class=VBHeader>DESCRIPTION'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0">'
		
			IF @SubjectToInspectionInd = 0
			BEGIN
				SELECT @Subject = 'DAI Bill of Lading for Load # '+@LoadNumber
			END
			ELSE
			BEGIN
				SELECT @Subject = 'DAI Bill of Lading for Load # '+@LoadNumber+', STI, Further Action Required'
			END
	
			SELECT @Body = @Body+'Diversified Automotive Transportation Delivery Ticket'+CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
			SELECT @Body = @Body+'Dear '+@GreetingName+','+CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
			SELECT @Body = @Body+'Attached to this e-mail is a digital copy of your Bill of Lading for load # '+@LoadNumber+','
			SELECT @Body = @Body+' delivered on '+@DropoffDate+' at '+@DropoffTime+'. If this delivery was made "Subject to Inspection",'
			SELECT @Body = @Body+' which would be denoted with an "STI" below the dealer signature field, further action is requested.'
			SELECT @Body = @Body+' You have 48 hours from the time noted above to perform an inspection on these vehicles, after which'
			SELECT @Body = @Body+' you must fax a signed copy of this bill of lading to 617-242-4455. This serves two purposes: notifying'
			SELECT @Body = @Body+' us of any pending claims as well as acknowledging that you have accounted for these vehicles on your property.'
			SELECT @Body = @Body+' Failure to do so may result in the denial of any claims pertaining to the vehicles on this load.'
			SELECT @Body = @Body+CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
			SELECT @Body = @Body+'If upon inspection all vehicles are damage free, please just sign and fax without further action. If any'
			SELECT @Body = @Body+' damage is noted, please fax and follow up with a phone call to Ken Collins at 1-800-666-9007 x103. Ken'
			SELECT @Body = @Body+' manages our claims process and can assist you in properly filing a claim.'
			SELECT @Body = @Body+CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
			SELECT @Body = @Body+'For optimal printing, please open up the attachment and print.'  
			SELECT @Body = @Body+CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
			SELECT @Body = @Body+'If you would like to request to have other employees be the recipient of these emails, or you cannot read'
			SELECT @Body = @Body+' the attachment, please contact our dispatch office at 1-800-666-9007 x104. We appreciate the opportunity'
			SELECT @Body = @Body+' to serve you. We hope that our efforts to become more efficient and environmentally conscious provide a'
			SELECT @Body = @Body+' value added benefit to our service. Your feedback is always welcome.'
			SELECT @Body = @Body+CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
			SELECT @Body = @Body+' Thanks again.'
			SELECT @VINCount = 0	
		END
		
		--add the vehicle information to the body
		--print 'adding html vehicle data'
		SELECT @VINCount = @VINCount + 1
		EXEC sp_AppendToFile @BOLPath, '<tr>'
		EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width="30">'
		
		--VIN COUNT
		SELECT @AppendString = '<p class=VB>'+CONVERT(varchar(20),@VINCount)+'.'
		EXEC sp_AppendToFile @BOLPath, @AppendString
		EXEC sp_AppendToFile @BOLPath, '</td>'
		EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width="170">'
		
		--VIN
		SELECT @AppendString = '<p class=VB>'+@VIN
		EXEC sp_AppendToFile @BOLPath, @AppendString
		EXEC sp_AppendToFile @BOLPath, '</td>'
		EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  width="220">'
		
		--DESCRIPTION
		SELECT @AppendString = '<p class=VB>'+@VehicleYear+' '+@Make+' '+@Model
		EXEC sp_AppendToFile @BOLPath, @AppendString
		EXEC sp_AppendToFile @BOLPath, '</td>'
		EXEC sp_AppendToFile @BOLPath, '</tr>'
		
		IF DATALENGTH(@TCode) > 0
		BEGIN
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" colspan = 4>'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0">'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" width="50">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" width="60">'
			EXEC sp_AppendToFile @BOLPath, '<p class=VB>T Code:'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" width="50">'
			--TCODE	
			SELECT @AppendString = '<p class=VB>'+@TCode
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" width="70">'
			EXEC sp_AppendToFile @BOLPath, '<p class=VB>Railcar #:'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" width="100">'
			--RAILCAR NUMBER			
			SELECT @AppendString = '<p class=VB>'+@RailcarNumber
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" width="60">'
			EXEC sp_AppendToFile @BOLPath, '<p class=VB>R Code:'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" width="60">'
			--RCODE			
			SELECT @AppendString = '<p class=VB>'+@RCode
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
		END
		
		--DAMAGES
		DECLARE DamagesCursor CURSOR
		LOCAL FORWARD_ONLY STATIC READ_ONLY
		FOR
			SELECT VDD.DamageCode,
			ISNULL(C1.CodeDescription,'')+' - '+
			ISNULL(C2.CodeDescription,'')+' - '+
			ISNULL(C3.CodeDescription,'')
			FROM VehicleInspection VI
			LEFT JOIN VehicleDamageDetail VDD ON VI.VehicleInspectionID = VDD.VehicleInspectionID
			LEFT JOIN Code C1 ON SUBSTRING(VDD.DamageCode,1,2) = C1.Code
			AND C1.CodeType = 'DamageAreaCode'
			LEFT JOIN Code C2 ON SUBSTRING(VDD.DamageCode,3,2) = C2.Code
			AND C2.CodeType = 'DamageTypeCode'
			LEFT JOIN Code C3 ON SUBSTRING(VDD.DamageCode,5,1) = C3.Code
			AND C3.CodeType = 'DamageSeverityCode'
			WHERE VI.VehicleID = @VehicleID
			AND VI.InspectionType = 3
			AND VDD.DamageCode IS NOT NULL
			ORDER BY VDD.DamageCode

		OPEN DamagesCursor
	
		FETCH DamagesCursor INTO @DamageCode, @DamageDescription
		
		SELECT @Exception = 'Exception:'
		
		WHILE @@FETCH_STATUS = 0
		BEGIN 
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" colspan = 4>'
			EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0">'
			EXEC sp_AppendToFile @BOLPath, '<tr>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" width="50">'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" width="75">'
			
			SELECT @AppendString = '<p class=VB>'+@Exception
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" width="60">'
			
			SELECT @AppendString = '<p class=VB>'+@DamageCode
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '<td valign = "top" >'
			
			SELECT @AppendString = '<p class=VB>'+@DamageDescription
			EXEC sp_AppendToFile @BOLPath, @AppendString
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			EXEC sp_AppendToFile @BOLPath, '</table>'
			EXEC sp_AppendToFile @BOLPath, '</td>'
			EXEC sp_AppendToFile @BOLPath, '</tr>'
			
			SELECT @Exception = ''
			
			FETCH DamagesCursor INTO @DamageCode, @DamageDescription
		END
		
		CLOSE DamagesCursor
		DEALLOCATE DamagesCursor
		
				
		--print 'updating the vehicle'
		--update the vehicle
		/*
		UPDATE Vehicle
		SET BillOfLadingSentInd = 1
		WHERE VehicleID = @VehicleID
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Updating Vehicle Record'
			GOTO Error_Encountered
		END
		*/
		UPDATE BillOfLadingEmail
		SET EmailSentInd = 1,
		EmailSentDate = CURRENT_TIMESTAMP
		WHERE VehicleID = @VehicleID
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrorID = @@ERROR
			SELECT @Status = 'Error Updating Vehicle Record'
			GOTO Error_Encountered
		END
		--print 'setting previous values'
		SELECT @PreviousLoadNumber = @LoadNumber
		SELECT @PreviousPickupLocationID = @PickupLocationID
		SELECT @PreviousDropoffLocationID = @DropoffLocationID
		SELECT @PreviousEmailAddress = @EmailAddress
		SELECT @PreviousRunID = @RunID
		SELECT @PreviousDriverNumber = @DriverNumber
		SELECT @PreviousDropoffDate = @DropoffDate
		SELECT @PreviousSignatureFileName = @SignatureFileName
		SELECT @PreviousDriverName = @DriverName
		SELECT @PreviousDropoffTime2 = @DropoffTime2
		SELECT @PreviousSignedBy = @SignedBy
		SELECT @PreviousDriverID = @DriverID
		SELECT @PreviousOriginSubType = @OriginSubType
		SELECT @PreviousNoSignatureReasonCode = @NoSignatureReasonCode
		
		FETCH BillOfLadingCursor INTO @VehicleID, @LoadsID, @RunID, @PickupLocationID, @DropoffLocationID,
			@DropoffDate, @DropoffTime, @DropoffTime2, @TruckNumber, @DriverName, @DriverNumber, @OriginName,
			@OriginAddressLine1, @OriginAddressLine2, @OriginCityStateZip, @OriginSubType, @LoadNumber,
			@DestinationName, @DestinationAddressLine1, @DestinationAddressLine2,
			@DestinationCityStateZip, @DestinationPhone, @DestinationDeliveryTimes,
			@VIN, @VehicleYear, @Make, @Model, @GreetingName, @EmailAddress, @HTMLSupportedInd,
			@SignatureFileName, @SignedBy, @NoSignatureReasonCode, @DriverID, @SubjectToInspectionInd, @TCode, @RailcarNumber, @RCode, @FordCarrierID

	END --end of loop
	
	--print 'out of loop'
	--send out the last email
	--close out the body
	--print 'adding html footer'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border="0" width="650">'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top">'
	EXEC sp_AppendToFile @BOLPath, '<p class=SBHeader>&nbsp'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top">'
	EXEC sp_AppendToFile @BOLPath, '<p class=SBHeader>Signatures:'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border="0" width="650">'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
	EXEC sp_AppendToFile @BOLPath, '<p class=SB>Driver:'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
			
	--DRIVER SIGNATURE
	SELECT @AppendString = '<img src="'+@DriverSignatureURL+@DriverID+'.bmp" width="144" height="50">'
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
	EXEC sp_AppendToFile @BOLPath, '<p class=SB>Date:'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
			
	--SIGNATURE DATE
	SELECT @AppendString = '<p class=SB>'+@DropoffDate
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
	EXEC sp_AppendToFile @BOLPath, '<p class=SB>Dealer:'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
			
	--DEALER SIGNATURE
	SELECT @AppendString = '<img src="'+@DealerSignatureURL+@SignatureFileName+'" width="144" height="50">'
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
	EXEC sp_AppendToFile @BOLPath, '<p class=SB>Date:'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
			
	--SIGNATURE DATE
	SELECT @AppendString = '<p class=SB>'+@DropoffDate
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
		
	--DRIVER NAME
	SELECT @AppendString = '<p class=SB>'+@DriverName
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
	SELECT @AppendString = '<p class=SB>'+@DropoffTime2
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
			
	--DEALERNAME
	SELECT @AppendString = '<p class=SB>'+@SignedBy
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
	SELECT @AppendString = '<p class=SB>'+@DropoffTime2
	EXEC sp_AppendToFile @BOLPath, @AppendString
	
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	
	--SWITCH FOR STI
	IF DATALENGTH(@NoSignatureReasonCode) > 0
	BEGIN
		EXEC sp_AppendToFile @BOLPath, '<tr>'
		EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
		EXEC sp_AppendToFile @BOLPath, '</td>'
		EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
		EXEC sp_AppendToFile @BOLPath, '</td>'
		EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
		EXEC sp_AppendToFile @BOLPath, '</td>'
		EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
		EXEC sp_AppendToFile @BOLPath, '</td>'
		EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
		EXEC sp_AppendToFile @BOLPath, '<p class=SB>STI Reason:'
		EXEC sp_AppendToFile @BOLPath, '</td>'
		EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
		SELECT @AppendString = '<p class=SB>'+@NoSignatureReasonCode
		EXEC sp_AppendToFile @BOLPath, @AppendString
		EXEC sp_AppendToFile @BOLPath, '</td>'
		EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
		EXEC sp_AppendToFile @BOLPath, '</td>'
		EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
		EXEC sp_AppendToFile @BOLPath, '</td>'
		EXEC sp_AppendToFile @BOLPath, '</tr>'
	END
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
	EXEC sp_AppendToFile @BOLPath, '<p class=SB>&nbsp;'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
	EXEC sp_AppendToFile @BOLPath, '<p class=SB>&nbsp;'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "150">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" width="660">'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="center">'
	EXEC sp_AppendToFile @BOLPath, '<p class = SBFooter>PLEASE SIGN AND DATE BOTH COPIES'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="center">'
	EXEC sp_AppendToFile @BOLPath, '<p class=Disclosure>Damage Noted At The Time Of Delivery Must Be Noted On Both The Dealer And Driver Copies. All Damages/Shortages'
	EXEC sp_AppendToFile @BOLPath, 'Discovered On Vehicles Dropped After Hours Or Subject To Inspection (S.T.I.) Must Be Reported Within 48 Hours Of Delivery.'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="center">'
	EXEC sp_AppendToFile @BOLPath, '<p class=Disclosure>Pictures Must Be Sent To Support All Claims.'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	IF @OriginSubType='Auction'
	BEGIN
		EXEC sp_AppendToFile @BOLPath, '<tr>'
		EXEC sp_AppendToFile @BOLPath, '<td valign = "top"  align="center">'
		EXEC sp_AppendToFile @BOLPath, '<p class=AucDisc>Diversified Automotive does not accept responsibility as it relates to Auction purchased Vehicles for any claims'
		EXEC sp_AppendToFile @BOLPath, ' considered normal wear & tear items. These items include but are not limited to: stained or damaged interiors, minor door and/or'
		EXEC sp_AppendToFile @BOLPath, ' panel dings, minor scratches, bumper imperfections and chipped glass surfaces.'
		EXEC sp_AppendToFile @BOLPath, '<br>Additionally, Diversified Automotive shall not be held liable for any missing components (i.e. Audio and/or Navigation'
		EXEC sp_AppendToFile @BOLPath, ' systems, shift knobs, owner manuals, spare tire and wheel, audio antennas etc.) as no evaluation of  these components are made at the'
		EXEC sp_AppendToFile @BOLPath, ' time of vehicle pickup.'
		EXEC sp_AppendToFile @BOLPath, '</td>'
		EXEC sp_AppendToFile @BOLPath, '</tr>'
	END
	EXEC sp_AppendToFile @BOLPath, '</table>'
	EXEC sp_AppendToFile @BOLPath, '<table cellpadding="0" cellspacing="0" border="0" width="650">'
	EXEC sp_AppendToFile @BOLPath, '<tr>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "175">'
	EXEC sp_AppendToFile @BOLPath, '<p class=CopyInd>Dealer Copy'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "50">'
	EXEC sp_AppendToFile @BOLPath, '<p>&nbsp;'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "75">'
	EXEC sp_AppendToFile @BOLPath, '<p>&nbsp;'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
	EXEC sp_AppendToFile @BOLPath, '<p>&nbsp;'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "75">'
	EXEC sp_AppendToFile @BOLPath, '<p>&nbsp;'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
	EXEC sp_AppendToFile @BOLPath, '<p>&nbsp;'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "115">'
	EXEC sp_AppendToFile @BOLPath, '<p class=SB>Load Number:'
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '<td valign = "bottom" width = "100">'
				
	--LOAD NUMBER
	SELECT @AppendString = '<p class=SB>'+@LoadNumber
	EXEC sp_AppendToFile @BOLPath, @AppendString
	EXEC sp_AppendToFile @BOLPath, '</td>'
	EXEC sp_AppendToFile @BOLPath, '</tr>'
	EXEC sp_AppendToFile @BOLPath, '</table>'
	
	EXEC sp_AppendToFile @BOLPath, '</html>'
	--print 'sending the email'
	--print 'body = '+isnull(@Body,'')
	--print 'htmlbody = '+isnull(@HTMLBody,'')
	-- send the email
	EXEC @ResultCode = sp_send_cdosysmail
		@SMTPUsername,
		@PreviousEmailAddress,
		@Subject,
		@Body,
		@HTMLBody,
		@SMTPServer,
		'1',
		@SMTPUsername,
		@SMTPPassword,
		'customer.service@diversifiedauto.com',
		@BOLPath,
		0
					
	IF @ResultCode <> 0
	BEGIN
		SELECT @ErrorID = @ResultCode
		SELECT @Status = 'Error Sending Email'
		GOTO Error_Encountered
	END

	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		COMMIT TRAN
		CLOSE BillOfLadingCursor
		DEALLOCATE BillOfLadingCursor
		--PRINT 'Pickup Notice Error_Encountered =' + STR(@ErrorID)
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
		CLOSE BillOfLadingCursor
		DEALLOCATE BillOfLadingCursor
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
	BEGIN
		--PRINT 'Pickup Notice Error_Encountered =' + STR(@ErrorID)
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
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage

	RETURN
END
GO
