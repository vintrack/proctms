USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[DAPP_GetLatestReleaseVersion]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Get the latest version
*/

CREATE Procedure [dbo].[DAPP_GetLatestReleaseVersion]
@appVersion varchar(200),
@userCode varchar(200),
@userName varchar(200),
@handHeldID varchar(200),
@localTime varchar(200),
@localTimeZone varchar(200)
AS
Begin
	
	/*
	Update the appVersion for the user
	*/
	if not exists	(
			select [DAPT_App_VersionId] from [DAPT_App_Version] 
			where	[UserCode] = @userCode and 
					[UserName] = @UserName and 
					[HandHeldID] = @HandHeldID
				)
	begin
		insert into [DAPT_App_Version] ([AppVersion], [UserCode], [UserName], [HandHeldID], [LocalTime], [LocalTimeZone], [UpdateDate])
		values (@appVersion, @userCode, @userName, @handHeldID, @localTime, @localTimeZone, getdate())
	end
	else
	begin
		update [DAPT_App_Version]
		set [AppVersion] = @appVersion,
			[LocalTime] = @localTime,
			[LocalTimeZone] = @localTimeZone,
			[UpdateDate] = getdate()
		where	[UserCode] = @userCode and 
				[UserName] = @userName and 
				[HandHeldID] = @handHeldID
	end
	
	Declare @maxReleaseID int
	Select	@maxReleaseID = max(R.DAPT_Sys_ReleaseId)
	From	DAPT_Sys_Release R

	Select	R.Version 
	From	DAPT_Sys_Release R
	Where	R.DAPT_Sys_ReleaseId = @maxReleaseID

End


GO
