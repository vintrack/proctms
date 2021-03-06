USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[ADMNSP_FindDependencies]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/***************************************************
	CREATED	: June 05 2013 (Laur)
	UPDATED	: 
	DESC	: finds text in SPs and other system objects (e.g. views)
***************************************************/
CREATE PROCEDURE [dbo].[ADMNSP_FindDependencies] 
@text VARCHAR(500)
AS
BEGIN
	-- Adjust search text to find all contains.
	SET @text = '%' + @text + '%'
	-- Declare general purpose variables.
	DECLARE @line VARCHAR(300)
	DECLARE @char CHAR
	DECLARE @lineNo INTEGER
	DECLARE @counter INTEGER
	
	CREATE TABLE #tmp(name varchar(1000), Line text, LineNumber int, obj_type varchar(25))
	
	-- Declare cursor structure.
	DECLARE @proc VARCHAR(1000),	@usage VARCHAR(4000), @obj_type varchar(25)
	-- Declare cursor of stored procedures.
	DECLARE codeCursor CURSOR FOR
		SELECT OBJECT_NAME(sc.id) AS sproc, sc.[text]
			, left( case so.type 
						when 'U' then 'Table - User' 
						when 'S' then 'Table - System' 
						when 'V' then 'Table - View' 
						when 'TR' then 'Trigger' 
						when 'P' then 'Stored Procedure' 
						when 'C' then 'Constraint - Check' 
						when 'D' then 'Default' 
						when 'K' then 'Key - Primary' 
						when 'F' then 'Key - Foreign' 
						when 'L' then 'Log'           
						when 'R' then 'Rule' 
						when 'RF' then 'Replication Filter stp' 
						else '<<UNKNOWN '''+so.type+'''>>'
						end,
				 25)
		FROM syscomments sc  
			INNER JOIN sysobjects so  ON so.id = sc.id	
		WHERE sc.[text] LIKE @text 
		
	-- Open cursor and fetch first row.
	OPEN codeCursor
	FETCH NEXT FROM codeCursor INTO @proc, @usage, @obj_type
	
	-- Check if any stored procedures were found.
	IF @@FETCH_STATUS <> 0 
	BEGIN
		SELECT 'Text ' + SUBSTRING(@text,2,LEN(@text)-2) + ' not found in stored procedures on database ' + @@SERVERNAME + '.' + DB_NAME()
		-- Close and release code cursor.
		CLOSE codeCursor
		DEALLOCATE codeCursor
		RETURN
	END
	
	-- Display column titles.
	-- print 'Procedure' + CHAR(9) + 'Line' + CHAR(9) + 'Reference ' + CHAR(13) + CHAR(13)
	
	-- Search each stored procedure within code cursor.
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		-- print 'a'
		
		SET @lineNo = 0
		SET @counter = 1
		-- Process each line.
		WHILE (@counter <> LEN(@usage)) 
		BEGIN
			-- print @counter
			SET @char = SUBSTRING(@usage,@counter,1)
			-- Check for line breaks.
			IF (@char = CHAR(13)) 
			BEGIN
				-- print 'b'
				SET @lineNo = @lineNo + 1
				-- Check if we found the specified text.
				IF (PATINDEX(@text,@line) <> 0)
				BEGIN
					INSERT INTO #tmp(name, Line, LineNumber, obj_type) VALUES (@proc,  LTRIM(@line), STR(@lineNo), @obj_type)
				END
				SET @line = ''
			END 
			ELSE
			BEGIN
				-- print 'char' + @char
				IF (@char <> CHAR(10))
				BEGIN
					SET @line = @line + @char
				END
			END
			SET @counter = @counter + 1
		END
	FETCH NEXT FROM codeCursor INTO @proc, @usage, @obj_type
	END
	-- Close and release cursor.
	CLOSE codeCursor
	DEALLOCATE codeCursor
	
	SELECT * FROM #tmp
	DROP TABLE #tmp
END

GO
