USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spCheckShuttlerVINCompleteAndGetShipawayLane]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [dbo].[spCheckShuttlerVINCompleteAndGetShipawayLane]
@FullVIN varchar(50)
as
begin
	Set nocount on
	
	declare @VPCVehicleID int
	declare @ShipawayLane varchar(50)
	
	SELECT TOP 1 @VPCVehicleID = V.VPCVehicleID, 
		@ShipawayLane = isnull(V.ShipawayLane, '')
	FROM VPCVehicle V
	WHERE V.FullVIN = @FullVIN 
	and V.ShopWorkCompleteDate is not null
	ORDER BY  V.ReleaseDate DESC
	
	select cast((case when @VPCVehicleID is not null then 1 else 0 end) as bit) as VINComplete, 
	isnull(@ShipawayLane, '') as ShipawayLane
end
GO
