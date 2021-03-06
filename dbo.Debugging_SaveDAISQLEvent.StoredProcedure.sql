USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[Debugging_SaveDAISQLEvent]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Debugging_SaveDAISQLEvent]
@errorType [varchar](500),
@exceptionNumber [int],
@spName [varchar](500),
@spParams [varchar](500),
@textData [varchar](max)
AS
BEGIN
	INSERT INTO [dbo].[Debugging_DAISQLEvents]
           ([errorType]
           ,[exceptionNumber]
           ,[spName]
           ,[spParams]
           ,[textData])
     VALUES
           (@errorType
           ,@exceptionNumber
           ,@spName
           ,@spParams
           ,@textData)
END




GO
