USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[DAPP_GetCabFileName]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*
/Params
Get the cab file name version
*/
CREATE Procedure [dbo].[DAPP_GetCabFileName]
	@version varchar(50)	
AS
Begin
	
	Select	top 1 R.CabFileName 
	From	DAPT_Sys_Release R
	Where	R.Version = @version
	order by DAPT_Sys_ReleaseId desc
End



GO
