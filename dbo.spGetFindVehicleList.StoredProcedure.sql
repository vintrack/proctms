USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetFindVehicleList]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



/***************************************************
	CREATED	: Jan 19 2012 (Comi)
	UPDATED	: 
	DESC	: Get the Vehicle List for the Subaru - Find Vehicle screen for the ONLINE mode
****************************************************/
CREATE PROCEDURE [dbo].[spGetFindVehicleList]
	@VIN VARCHAR(20)
AS
BEGIN
	IF DATALENGTH(@VIN) = 17
	BEGIN
		SELECT V.[FullVIN],V.[VPCVehicleID]
		FROM VPCVehicle V 
		WHERE V.[FullVIN] = @VIN
	END
	ELSE IF DATALENGTH(@VIN) = 8
	BEGIN
		SELECT V.[FullVIN],V.[VPCVehicleID]
		FROM VPCVehicle V 
		WHERE V.[VINKey] = @VIN
	END
	ELSE
	BEGIN
		SELECT V.[FullVIN],V.[VPCVehicleID]
		FROM VPCVehicle V 
		WHERE V.[FullVIN] LIKE '%' + @VIN  + '%'
	END
END



GO
