USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetRailVehicleInspectionVINDetails]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [dbo].[spGetRailVehicleInspectionVINDetails]
@VehicleID int,
@VIN varchar(17)
as
begin
	/*
	Created by: Cristi P, ESD
	Create Date: 07/21/2011
	*/

	SELECT V.VehicleID, V.VIN, V.Make + ' ' + V.Model as MakeAndModel -- include current damages here
	FROM Vehicle V 
	WHERE (V.VehicleID = @VehicleID) or (V.VIN = @VIN and @VIN <> '')
	
end

GO
