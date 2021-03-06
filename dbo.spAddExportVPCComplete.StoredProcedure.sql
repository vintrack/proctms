USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spAddExportVPCComplete]    Script Date: 8/31/2018 1:03:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




Create Procedure [dbo].[spAddExportVPCComplete]
	@Vin VARCHAR(20),
	@CompleteDate datetime,
	@CompleteBy varchar(20),
	@LoadLane varchar(20)
AS
BEGIN

	DECLARE @BayLocation varchar(20), 
			@ReturnCode int,
			@ReturnMessage varchar(200) 

	-- Change this line and get the bay location from the vin
	SET @BayLocation  = NULL

	INSERT INTO ExportVPCComplete(VINKey, VPCCompleteDate, VPCCompleteBy, LoadLane, BayLocation, ExportedInd, RecordStatus, CreationDate, CreatedBy,UpdateType)
	VALUES (SUBSTRING(@VIN, 10, 8), CONVERT(varchar(8), @CompleteDate, 112) , @CompleteBy, @LoadLane, @BayLocation, 0, 'Export Pending', GETDATE(), @CompleteBy, 'VPCComplete')

	SELECT @ReturnCode = @@Error
	SELECT @ReturnMessage = CASE WHEN @@Error = 0	THEN 'Export VPC Complete Dates added successfully.' 
													ELSE 'Error Number' + CONVERT(VARCHAR(10), @@Error) + ' encountered while adding the Export VPC Complete record' END

	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM'

	
END


GO
