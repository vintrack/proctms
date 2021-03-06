USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetShuttlerBaysWithCompletedVehicle]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [dbo].[spGetShuttlerBaysWithCompletedVehicle]
as
begin
	Set nocount on
	
	
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

	--select * from #tmpVINs
	

	SELECT V.FullVIN, 
		isnull(V.ShipawayLane, '') as ShipawayLane, 
		isnull(V.BayLocation, '') as BayLocation
		,t.ExitDate
	FROM VPCVehicle V
	left join #tmpVINs t on v.FullVIN = t.FullVIN
	WHERE v.ShopWorkCompleteDate is not null
	and t.ExitDate is null
	and t.EntryDate is not NULL
	and V.FinalShipawayInspectionDate is NULL
	and V.DateOut is NULL
	ORDER BY  V.ShopWorkCompleteDate ASC


	drop table #tmpVINs
end


GO
