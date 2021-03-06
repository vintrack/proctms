USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetFindVehicleList_Storage]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




/***************************************************
	CREATED	: JUL 25 2013 (Cristi)
	UPDATED	: 
	DESC	: Get the Vehicle List for the Storage - Find Vehicle screen for the ONLINE mode
****************************************************/
CREATE   PROCEDURE [dbo].[spGetFindVehicleList_Storage]
	@VIN VARCHAR(20)
AS
BEGIN
	IF DATALENGTH(@VIN) = 17
	BEGIN
		SELECT V.[VIN], max(V.[PortStorageVehiclesID]) as PortStorageVehiclesID
		FROM PortStorageVehicles V 
		WHERE V.RecordStatus = 'Active' and V.[VIN] = @VIN
		GROUP BY V.[VIN]
	END
	ELSE IF DATALENGTH(@VIN) = 8
	BEGIN
		SELECT V.[VIN], max(V.[PortStorageVehiclesID]) as PortStorageVehiclesID
		FROM PortStorageVehicles V 
		WHERE V.RecordStatus = 'Active' and V.[VIN] LIKE '%' + @VIN + '%'
		GROUP BY V.[VIN]
	END
	ELSE
	BEGIN
		SELECT V.[VIN], max(V.[PortStorageVehiclesID]) as PortStorageVehiclesID
		FROM PortStorageVehicles V 
		WHERE V.RecordStatus = 'Active' and V.[VIN] LIKE '%' + @VIN  + '%'
		GROUP BY V.[VIN]
	END
END





GO
