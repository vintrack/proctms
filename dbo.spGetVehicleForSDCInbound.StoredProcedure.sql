USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetVehicleForSDCInbound]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO






CREATE Procedure [dbo].[spGetVehicleForSDCInbound]
AS
BEGIN

	SELECT  L.DeliveryBayLocation AS Location,
	CASE WHEN D.OutsideCarrierInd = 0 THEN 'DAI' ELSE OC.CarrierName END AS CarrierName,
	ISNULL(D.DriverNumber, '') as DriverNumber, 
	ISNULL(L2.LoadNumber,'') AS LoadNumber, 
	V.FullVIN, 
	V.ModelDescription + ' - ' + V.ExteriorColor as VehicleDescription,
	'' AS BayLocation,
	0 as WasReviewed,
	CONVERT(varchar(500), '') as DamageCodes
	FROM VPCVehicle V 
	LEFT JOIN Legs L On V.SOAVehicleID = L.VehicleID
	LEFT JOIN Loads L2 On L.LoadID = L2.LoadsID
	LEFT JOIN Driver D ON L2.DriverID = D.DriverID
	LEFT JOIN OutsideCarrier OC ON L2.OutsideCarrierID = OC.OutsideCarrierID
	OR D.OutsideCarrierID = OC.OutsideCarrierID
	WHERE V.DateIn IS NULL
	AND L.LegStatus = 'Delivered'
END

GO
