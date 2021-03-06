USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetRailVehicleInspectionLocations]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE  procedure [dbo].[spGetRailVehicleInspectionLocations]
as
begin
	/*
	Created by: Cristi P, ESD
	Create Date: 07/21/2011
	*/

	create table  #tmpLocations (LocationID int, LocationName varchar(100), VehicleCount int)

	insert into #tmpLocations (LocationID, LocationName, VehicleCount)
	select L.LocationID, 
	CASE WHEN DATALENGTH(L.LocationShortName) > 0 THEN L.LocationShortName ELSE L.LocationName END, 0
	FROM Location L
	WHERE L.ParentRecordTable = 'Common'
	AND L.LocationSubType IN ('Port','Railyard')


	create table  #tmpLocations2 (LocationID int, LocationName varchar(100), VehicleCount int)

	insert into #tmpLocations2 (LocationID, LocationName, VehicleCount)
	SELECT L.LocationID, L.LocationName, count(V.VehicleID) as VehicleCount
	FROM #tmpLocations L
	INNER JOIN Vehicle V ON L.LocationID = V.PickupLocationID
	WHERE V.VehicleID NOT IN (SELECT VI.VehicleID FROM VehicleInspection VI WHERE VI.VehicleID = V.VehicleID AND VI.InspectionType IN (0,1))
	AND V.AvailableForPickupDate IS NOT NULL
	AND V.VehicleStatus NOT IN ('EnRoute','Delivered')
	GROUP BY L.LocationID, L.LocationName


	/*
	Get the locations from #tmpLocations2.
	union them with those locations that are in #tmpLocations but not in #tmpLocations2

	We need to see also the locations with 0 vehicles that need inspection.
	*/

	SELECT L.LocationID, L.LocationName, L.VehicleCount as VehicleCount
	FROM #tmpLocations2 L

	UNION 

	SELECT L.LocationID, L.LocationName, L.VehicleCount as VehicleCount
	FROM #tmpLocations L
	left outer join #tmpLocations2 L2 on L.LocationID = L2.LocationID
	where L2.LocationID is null

	ORDER BY L.LocationName

	drop table #tmpLocations
	drop table #tmpLocations2
end


GO
