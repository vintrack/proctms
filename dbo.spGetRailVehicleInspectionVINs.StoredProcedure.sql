USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetRailVehicleInspectionVINs]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE   procedure [dbo].[spGetRailVehicleInspectionVINs]
@LocationID int
as
begin
	/*
	Created by: Cristi P, ESD
	Create Date: 07/21/2011
	*/

	create table #tmpVINs (LocationID int, LocationName varchar(100), VehicleID int, VIN varchar(17), AvailableForPickupDate datetime, BayLocation varchar(20))

	insert into #tmpVINs (LocationID, LocationName, VehicleID, VIN, AvailableForPickupDate, BayLocation)
	SELECT L.LocationID, 
	CASE WHEN DATALENGTH(L.LocationShortName) > 0 THEN L.LocationShortName ELSE L.LocationName END as LocationName, 
	V.VehicleID, V.VIN, v.AvailableForPickupDate, v.BayLocation
	FROM Location L
	INNER JOIN Vehicle V ON V.PickupLocationID = L.LocationID and L.LocationID = @LocationID 
	WHERE V.VehicleID NOT IN (SELECT VI.VehicleID FROM VehicleInspection VI WHERE VI.VehicleID = V.VehicleID AND VI.InspectionType IN (0,1))
	AND V.AvailableForPickupDate IS NOT NULL
	AND V.VehicleStatus NOT IN ('EnRoute','Delivered')

	SELECT v.VehicleID, v.VIN, v.BayLocation, 
		case when datediff(d, v.AvailableForPickupDate, getdate()) > 0 then 1 else 0 end as IsOlderThanToday -- include current damage codes here
	FROM #tmpVINs v
	ORDER BY v.BayLocation asc, V.VIN asc

	declare @VehicleCount int

	select @VehicleCount = count(VehicleID)
	from #tmpVINs

	SELECT L.LocationID, 
	CASE WHEN DATALENGTH(L.LocationShortName) > 0 THEN L.LocationShortName ELSE L.LocationName END as LocationName,
	@VehicleCount as VehicleCount
	FROM Location L
	WHERE L.LocationID = @LocationID

	drop table #tmpVINs
end



GO
