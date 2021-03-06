USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetVehicleForFinalShipAwayInspection]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




CREATE Procedure [dbo].[spGetVehicleForFinalShipAwayInspection]
AS
BEGIN
	set nocount on

	select sv.FullVIN as FullVIN, MAX([DAIYMS_Shuttler_Vehicles_ID]) as MaxID, convert(datetime, '2000-01-01 00:00:00') as ExitDate,
	convert(datetime, '2000-01-01 00:00:00') as EntryDate
	into #tmpVINs
	from DataHub..DAIYMS_Shuttler_Vehicles sv
	group by sv.FullVIN

	--select * from #tmpVINs

	update t
	set ExitDate = sv.ExitSignScannedDate
	, EntryDate = sv.EntrySignScannedDate
	from #tmpVINs t 
	inner join DataHub..DAIYMS_Shuttler_Vehicles sv on t.MaxID = sv.[DAIYMS_Shuttler_Vehicles_ID]

	SELECT V.FullVIN, 
		V.VINKey, 
		isnull(V.ShipawayLane, '') as ShipawayLane, 
		'' as BayLocation,
		isnull(L2.CustomerLoadNumber, '') as CustomerLoadNumber,
		V.ModelDescription + ' - ' + V.ExteriorColor as VehicleDescription,
		0 as WasReviewed,
		CONVERT(varchar(500), '') as DamageCodes
	FROM VPCVehicle V
	INNER JOIN #tmpVINs tmp on v.FullVIN = tmp.FullVIN and tmp.ExitDate is not null
	LEFT JOIN Legs L On V.SDCVehicleID = L.VehicleID
	LEFT JOIN Loads L2 On L.LoadID = L2.LoadsID
	WHERE V.VehicleStatus = 'Complete' and isnull(V.FinalShipawayInspectionDoneInd, 0) = 0 and L2.LoadsId IS NOT NULL
	and isnull(L2.CustomerLoadNumber, '') <> '' and isnull(V.ShipawayLane, '') <> ''
	ORDER BY  L2.LoadNumber, V.ShipawayLane	
	
	drop table #tmpVINs
END



GO
