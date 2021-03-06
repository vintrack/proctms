USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetExportRemainingToLoad]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO










/***************************************************
	CREATED	: Jan 27 2012 (Comi)
	UPDATED	: 
	DESC	: Search for all Vehicles Remaining to Load
****************************************************/
CREATE PROCEDURE [dbo].[spGetExportRemainingToLoad]
	@voyageID int
AS
BEGIN

SELECT	CONVERT(varchar(10),AEV.VoyageDate,101) + ' ' + ISNULL(AEV2.VesselName,'') AS HeaderLine
FROM	AEVoyage AEV
		LEFT JOIN AEVessel AEV2 ON AEV.AEVesselID = AEV2.AEVesselID
WHERE	AEV.AEVoyageID = @voyageID

SELECT	AEV.VIN, AEV.Make, AEV.Model, AEV.Color,
		CASE	WHEN CHARINDEX(' ',AEV.BayLocation) > 0 
				THEN LEFT(AEV.BayLocation,CHARINDEX(' ',AEV.BayLocation)-1) 
				ELSE AEV.BayLocation 
				END AS Location,
		CASE	WHEN CHARINDEX(' ',AEV.BayLocation) > 0 
				THEN SUBSTRING(AEV.BayLocation, CHARINDEX(' ',AEV.BayLocation) + 1,	DATALENGTH(AEV.BayLocation)-CHARINDEX(' ',AEV.BayLocation)) 
				ELSE '' END,
		ISNULL(AEVLS.Sequence,0) As Sequence,	
		AEV.NoStartInd, AEV.SizeClass,AEV.DestinationName
FROM	AutoportExportVehicles AEV
		LEFT JOIN AEVoyageLoadSequence AEVLS ON AEV.VoyageID = AEVLS.VoyageID AND AEVLS.CustomerID = AEV.CustomerID AND AEV.DestinationName = AEVLS.DestinationName AND AEV.SizeClass = AEVLS.SizeClass
WHERE	AEV.VoyageID = @voyageId 
		And AEV.DateShipped IS NULL 
		and AEV.CustomsApprovedDate is not null

END










GO
