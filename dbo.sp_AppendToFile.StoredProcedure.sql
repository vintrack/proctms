USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[sp_AppendToFile]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_AppendToFile](@FileName varchar(1000), @Text1 varchar(1000)) AS
DECLARE @FS int, @OLEResult int, @FileID int


EXECUTE @OLEResult = sp_OACreate 'Scripting.FileSystemObject', @FS OUT
IF @OLEResult <> 0 PRINT 'Scripting.FileSystemObject'

--Open a file
execute @OLEResult = sp_OAMethod @FS, 'OpenTextFile', @FileID OUT, @FileName, 8, 1
IF @OLEResult <> 0 PRINT 'OpenTextFile'

--Write Text1
execute @OLEResult = sp_OAMethod @FileID, 'WriteLine', Null, @Text1
IF @OLEResult <> 0 PRINT 'WriteLine'

EXECUTE @OLEResult = sp_OADestroy @FileID
EXECUTE @OLEResult = sp_OADestroy @FS

GO
