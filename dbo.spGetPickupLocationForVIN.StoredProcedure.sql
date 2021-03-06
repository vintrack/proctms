USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetPickupLocationForVIN]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




CREATE    procedure [dbo].[spGetPickupLocationForVIN]
@sVIN varchar(18)
as
begin
	/*
	Created by: Cristi P, ESD
	Create Date: 08/24/2011
	*/

	declare @LocationID int
	declare @LocationName varchar(100)
	declare @VehicleID int
	
	set @LocationID = 0
	set @LocationName = ''
	set @VehicleID = 0

	SELECT TOP 1 @LocationID = isnull(L.LocationID, 0),
	@LocationName = isnull(CASE WHEN DATALENGTH(L.LocationShortName) > 0 THEN L.LocationShortName ELSE L.LocationName END, ''), 
	@VehicleID = V.VehicleID
	FROM Vehicle V
	LEFT OUTER JOIN Location L ON V.PickupLocationID = L.LocationID
	WHERE (V.VIN = @sVIN or (len(@sVIN) < 17 and V.VIN Like '%' + @sVIN))
	ORDER BY V.VehicleId desc

	select @LocationID as LocationID, @LocationName as LocationName, @VehicleID as VehicleID
end




GO
