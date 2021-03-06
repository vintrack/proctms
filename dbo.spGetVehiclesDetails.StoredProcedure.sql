USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetVehiclesDetails]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




/***************************************************
	CREATED	: Jan 19 2012 (Comi)
	UPDATED	: 
	DESC	: Create the Lookup File for the Subaru - Find Vehicle screen for the OFFLINE mode
****************************************************/
CREATE PROCEDURE [dbo].[spGetVehiclesDetails]
AS
BEGIN
	/*
	DECLARE @SDCCustomerID INT,
			@SDCDAILocationID INT

	SELECT	@SDCCustomerID = CONVERT(INT,ValueDescription)
	FROM	SettingTable
	WHERE	ValueKey = 'SDCCustomerID'

	SELECT @SDCDAILocationID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'SDCDiversifiedLocationID'
	*/
	
	SELECT	ISNULL(REPLACE(V.FullVIN,',',''),'') AS Vin,
	ISNULL(REPLACE(V.BayLocation,',',''),'') AS Location, 
	V.LoadNumber as LoadNumber, 
	ISNULL(REPLACE(V.ModelDescription,',',''),'') AS Model, 
	ISNULL(REPLACE(V.ExteriorColor,',',''),'') As Color,
	ISNULL(REPLACE(V.VehicleStatus,',',''),'') AS VehicleStatus,
	V.DestinationDealerCode as Dealer, 
	V.DateIn as DateIn, 
	V.DriverIn as DriverIn, 
	V.ReleaseDate as ReleaseDate, 
	convert(varchar(16), V.ShopWorkStartedDate, 120) as ThrowIn, 
	convert(varchar(16), V.ShopWorkCompleteDate, 120) as VPCComplete, 
	V.ShipawayLane as SALane, 
	V.DateOut as DateOut, 
	V.DriverOut as DriverOut,
	'' AS DamageCodes
	FROM	VPCVehicle V 
	WHERE	V.DateOut IS NULL

END


GO
