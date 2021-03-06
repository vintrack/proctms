USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[sp_send_cdosysmail]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[sp_send_cdosysmail](
	@From 				varchar(100),
	@To 				varchar(8000),
	@Subject 			varchar(100)	= '',
	@Body 				varchar(8000)	= '',
	@HTMLBody			varchar(8000)	= '',
	@smtpserver			varchar(100)	= '',
	@smtpauthenticate	varchar(1)		= '0',
	@sendusername		varchar(100)	= '',
	@sendpassword		varchar(100)	= '',
	@ReplyTo			varchar(100)	= null,
	@attachment			nvarchar(800)	= null, -- absolute path
	@allowInProcess		int			= 1
	)
AS
BEGIN
	/************************************************************************
	*	sp_send_cdosysmail
	*	
	*	Description
	*	-----------
	*	This stored procedure takes the parameters and sends an e-mail. 
	*	References to the CDOSYS objects are at the following MSDN Web site:
	*	http://msdn2.microsoft.com/en-us/library/ms526266.aspx
	*	
	*	Change History
	*	--------------
	*	Date       Init's Description
	*	---------- ------ ----------------------------------------
	*	06/24/2007 JEP    Initial version
	*	
	************************************************************************/	

	SET nocount on

	DECLARE	
		@iMsg			int,
		@context		int,
		@resultcode		int,
		@resultcode2	int,
		@source			varchar(255),
		@description	varchar(500),
		@output			varchar(1000),
		@step			varchar(50),
		@RtnValue  		nvarchar(2000)

	-- initialize return values
	set @source = ''
	set @description = ''

	-- 3rd param of sp_OACreate is context: 
	--   4=Local (.exe) OLE server only (safer, slightly longer process time)
	--   5=Local or InProcess (more dangerous, more compatible, only use if Local doesn't work)
	set @context = 4 --needs to be 5 when working on local machine
	if @allowInProcess = 1 set @context = 5
	
	-- Create the CDO.Message Object
	SET @step = 'sp_OACreate'
	EXEC @resultcode = sp_OACreate 'CDO.Message', @iMsg OUT, 5 -- @context
	IF @resultcode <> 0 GOTO GetErrorDetails
	
	-- sendusing: 
	--    1=Local SMTP svc Pickup Directory (outlook or outlook express account required)
	--    2=SMTP over the network, which is used here
	SET @step = 'sp_OASetProperty(sendusing)'
	EXEC @resultcode = sp_OASetProperty @iMsg, 
		'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/sendusing").Value',
		'2' 
	IF @resultcode <> 0 GOTO GetErrorDetails

	-- smtpserver
	SET @step = 'sp_OASetProperty(smtpserver)'
	EXEC @resultcode = sp_OASetProperty @iMsg, 
		'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/smtpserver").Value', 
		@smtpserver
	IF @resultcode <> 0 GOTO GetErrorDetails

	-- smtpauthenticate: 
	--   0=none (default)
	--   1=basic clear-text authentication
	--   2=NTLM authentication
	SET @step = 'sp_OASetProperty(smtpauthenticate)'
	EXEC @resultcode = sp_OASetProperty @iMsg, 
		'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/smtpauthenticate").Value',
		@smtpauthenticate 
	IF @resultcode <> 0 GOTO GetErrorDetails

	IF @smtpauthenticate = 1  -- 1=basic clear-text authentication
	BEGIN
		-- sendusername for authenticating to SMTP server using basic (clear-text) authentication
		SET @step = 'sp_OASetProperty(sendusername)'
		EXEC @resultcode = sp_OASetProperty @iMsg, 
			'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/sendusername").Value', 
			@sendusername 
		IF @resultcode <> 0 GOTO GetErrorDetails

		-- sendpassword used to authenticate to SMTP server using basic (clear-text) authentication.
		SET @step = 'sp_OASetProperty(sendpassword)'
		EXEC @resultcode = sp_OASetProperty @iMsg, 
			'Configuration.fields("http://schemas.microsoft.com/cdo/configuration/sendpassword").Value', 
			@sendpassword 
		IF @resultcode <> 0 GOTO GetErrorDetails
	END

	-- Save the configurations to the message object.
	SET @step = 'sp_OAMethod(UpdateConfiguration)'
	EXEC @resultcode = sp_OAMethod @iMsg, 'Configuration.Fields.Update', null
	IF @resultcode <> 0 GOTO GetErrorDetails

	-- recipient email addresses (separated by comma)
	SET @step = 'sp_OASetProperty(To)'
	EXEC @resultcode = sp_OASetProperty @iMsg, 'To', @To
	IF @resultcode <> 0 GOTO GetErrorDetails

	-- sender email address
	SET @step = 'sp_OASetProperty(From)'
	EXEC @resultcode = sp_OASetProperty @iMsg, 'From', @From
	IF @resultcode <> 0 GOTO GetErrorDetails

	-- ReplyTo
	if @ReplyTo is not null
	BEGIN
		SET @step = 'sp_OASetProperty(ReplyTo)'
		EXEC @resultcode = sp_OASetProperty @iMsg, 'ReplyTo', @ReplyTo
		IF @resultcode <> 0 GOTO GetErrorDetails
	END
	
	-- Subject
	SET @step = 'sp_OASetProperty(Subject)'
	EXEC @resultcode = sp_OASetProperty @iMsg, 'Subject', @Subject
	IF @resultcode <> 0 GOTO GetErrorDetails

	IF DATALENGTH(ISNULL(@Body,'')) > 0
	BEGIN
		-- TextBody
		SET @step = 'sp_OASetProperty(TextBody)'
		EXEC @resultcode = sp_OASetProperty @iMsg, 'TextBody', @Body
		IF @resultcode <> 0 GOTO GetErrorDetails
	END
	ELSE IF DATALENGTH(ISNULL(@HTMLBody,'')) > 0
	BEGIN
		-- HTMLBody
		SET @step = 'sp_OASetProperty(HTMLBody)'
		EXEC @resultcode = sp_OASetProperty @iMsg, 'HTMLBody', @HTMLBody
		IF @resultcode <> 0 GOTO GetErrorDetails
	END
	-- attachment
	if @attachment is not null
	BEGIN
		SET @step = 'sp_OASetProperty(ReplyTo)'
		
		
		
		
		---EXEC sp_OAMethod @iMsg, 'AddAttachment', null, @attachment
		
				
		WHILE (Charindex(';',@attachment)>0)
			BEGIN
			Select @RtnValue  = ltrim(rtrim(Substring(@attachment,1,Charindex(';',@attachment)-1)))
			Set @attachment = Substring(@attachment,Charindex(';',@attachment)+1,len(@attachment))
			EXEC sp_OAMethod @iMsg, 'AddAttachment', null,@RtnValue  
			
			END
		EXEC sp_OAMethod @iMsg, 'AddAttachment', null, @attachment
		
				
		IF @resultcode <> 0 GOTO GetErrorDetails
	END
	
	SET @step = 'sp_OAMethod(SendMessage)'
	EXEC @resultcode = sp_OAMethod @iMsg, 'Send', NULL
	IF @resultcode <> 0 GOTO GetErrorDetails
	
	GOTO send_cdosysmail_cleanup

GetErrorDetails:
	-- get Error Info to @source and @description
	EXEC @resultcode2 = sp_OAGetErrorInfo NULL, @source OUT, @description OUT

send_cdosysmail_cleanup:
	If @iMsg is null GOTO Done
	
	-- Clean up the objects created. (they'll be auto destroyed anyway)
	--SET @step = 'sp_OADestroy'
	EXEC @resultcode2=sp_OADestroy @iMsg

Done:
	SELECT @resultcode AS 'RC', @step AS 'step', @source AS 'source', @description AS 'description'

	RETURN @resultcode

END
GO
