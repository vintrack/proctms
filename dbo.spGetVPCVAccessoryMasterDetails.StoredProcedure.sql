USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetVPCVAccessoryMasterDetails]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/***************************************************
	CREATED	: May 17 2013 (Laur Exari)
	UPDATED	: 
	DESC	: Return a record from VPCAccessoryMaster. 
			The input parameters @VMSCarAccessoryID  and @AccessoryCode are used to uniquely identify an Accessory. Please refer to VMSCarAccessoryID  and AccessoryCode columns from VPCVehicleAccessory table.
			The input parameter @CarLineTitle is required because information in VPCAccessoryMaster may depend on Car Line
			The input parameter @@VehicleYear is required because information in VPCAccessoryMaster may depend on Vehicle Year
			The input parameter @RequestDate is going to indentify the information that is effective at the Request Date.
			
			Sample call(s): exec [spGetVPCVAccessoryMasterDetails] 362, 'R9B', 'Legacy', 2013, '01/01/2010'
							exec [spGetVPCVAccessoryMasterDetails] 52, 'K8F', 'WRX/STi', 2013, '01/01/2013'( also see exec [spGetVPCVehicleAccessoryDetails] 13498, '01/01/2013')
***************************************************/
CREATE Procedure [dbo].[spGetVPCVAccessoryMasterDetails]
	@VMSCarAccessoryID INT,
	@AccessoryCode VARCHAR(10),
	@CarLineTitle VARCHAR(50),
	@VehicleYear INT,
	@RequestDate DATETIME
AS
BEGIN

	CREATE TABLE #VPCAccessoryMaster(
		[VMSCarAccessoryID] [int] NOT NULL,
		[AccessoryCode] [varchar](10) NOT NULL,
		[AccessoryDescription] [varchar](250),
		[PartNumber] [varchar](20) NULL,
		[VMSPieceRateID] [int] NULL,
		[EffectiveDate] [datetime] NULL,
		[ExpirationDate] [datetime] NULL,
		[CarLineTitle] [varchar](50) NULL,
		[VehicleYear] [int] NULL,
		[RetailCost] [decimal](18, 2) NULL,
		[SOAPieceRate] [decimal](18, 2) NULL,
		[DiversifiedPieceRate] [decimal](18, 2) NULL,
		[PayAtPDIRateInd] INT NULL
	)


	INSERT INTO #VPCAccessoryMaster 
		(
		 [VMSCarAccessoryID]
		,[AccessoryCode]
		,[AccessoryDescription]
		,[PartNumber]
		,[CarLineTitle]
		,[VehicleYear]
		,[RetailCost]
		,[SOAPieceRate]
		,[DiversifiedPieceRate]
		,[PayAtPDIRateInd]
		)
	SELECT @VMSCarAccessoryID as [VMSCarAccessoryID]
		,  @AccessoryCode as [AccessoryCode]
		, NULL as [AccessoryDescription]
		, cast(null as varchar(20)) as [PartNumber]
		, @CarLineTitle as [CarLineTitle]
		, @VehicleYear as [VehicleYear]
		, cast(null as decimal(18,2)) as [RetailCost]
		, cast(null as decimal(18,2)) as [SOAPieceRate]
		, cast(null as decimal(18,2)) as [DiversifiedPieceRate]
		, cast(null as int) as [PayAtPDIRateInd]
	
	/*get info per Car Model Year and Car Line*/
	UPDATE temp
		SET [RetailCost] = acc_m.RetailCost
			, [SOAPieceRate] = acc_m.[SOAPieceRate]
			, [PartNumber] = acc_m.[PartNumber]
			, [AccessoryDescription] = acc_m.[AccessoryDescription]
			, [DiversifiedPieceRate] = acc_m.[DiversifiedPieceRate]
			, [PayAtPDIRateInd] = acc_m.[PayAtPDIRateInd]
	FROM #VPCAccessoryMaster temp
			LEFT OUTER JOIN VPCAccessoryMaster acc_m on (temp.[VMSCarAccessoryID] = acc_m.[VMSCarAccessoryID]
															AND temp.[AccessoryCode] = acc_m.[AccessoryCode]
															AND temp.[VehicleYear]  = acc_m.[VehicleYear]
															AND temp.[CarLineTitle]  = acc_m.[CarLineTitle]
															AND @RequestDate between acc_m.EffectiveDate AND IsNull(acc_m.ExpirationDate, '2999-01-01 00:00:00.000') )
	WHERE temp.[SOAPieceRate] IS NULL

	/*get temp.[SOAPieceRate] per Car Line*/
	UPDATE temp
		SET [RetailCost] = acc_m.RetailCost
					, [SOAPieceRate] = acc_m.[SOAPieceRate]
					, [PartNumber] = acc_m.[PartNumber]
					, [AccessoryDescription] = acc_m.[AccessoryDescription]
					, [DiversifiedPieceRate] = acc_m.[DiversifiedPieceRate]
					, [PayAtPDIRateInd] = acc_m.[PayAtPDIRateInd]
	FROM #VPCAccessoryMaster temp
			LEFT OUTER JOIN VPCAccessoryMaster acc_m on (temp.[VMSCarAccessoryID] = acc_m.[VMSCarAccessoryID]
															AND temp.[AccessoryCode] = acc_m.[AccessoryCode]
															AND acc_m.[VehicleYear] IS NULL
															AND temp.[CarLineTitle] = acc_m.[CarLineTitle] 
															AND @RequestDate between acc_m.EffectiveDate AND IsNull(acc_m.ExpirationDate, '2999-01-01 00:00:00.000') )
	WHERE temp.[SOAPieceRate] IS NULL

	/*get temp.[SOAPieceRate] per Car Model Year*/
	UPDATE temp
		SET [RetailCost] = acc_m.RetailCost
					, [SOAPieceRate] = acc_m.[SOAPieceRate]
					, [PartNumber] = acc_m.[PartNumber]
					, [AccessoryDescription] = acc_m.[AccessoryDescription]
					, [DiversifiedPieceRate] = acc_m.[DiversifiedPieceRate]
					, [PayAtPDIRateInd] = acc_m.[PayAtPDIRateInd]
	FROM #VPCAccessoryMaster temp
			LEFT OUTER JOIN VPCAccessoryMaster acc_m on (temp.[VMSCarAccessoryID] = acc_m.[VMSCarAccessoryID]
															AND temp.[AccessoryCode] = acc_m.[AccessoryCode]
															AND acc_m.[VehicleYear] = temp.[VehicleYear]
															AND acc_m.[CarLineTitle] IS NULL
															AND @RequestDate between acc_m.EffectiveDate AND IsNull(acc_m.ExpirationDate, '2999-01-01 00:00:00.000') )
	WHERE temp.[SOAPieceRate] IS NULL

	/*get default temp.[SOAPieceRate]*/
	UPDATE temp
		SET [RetailCost] = acc_m.RetailCost
					, [SOAPieceRate] = acc_m.[SOAPieceRate]
					, [PartNumber] = acc_m.[PartNumber]
					, [AccessoryDescription] = acc_m.[AccessoryDescription]
					, [DiversifiedPieceRate] = acc_m.[DiversifiedPieceRate]
					, [PayAtPDIRateInd] = acc_m.[PayAtPDIRateInd]
	FROM #VPCAccessoryMaster temp
			LEFT OUTER JOIN VPCAccessoryMaster acc_m on (temp.[VMSCarAccessoryID] = acc_m.[VMSCarAccessoryID]
															AND temp.[AccessoryCode] = acc_m.[AccessoryCode]
															AND acc_m.[VehicleYear] IS NULL
															AND acc_m.[CarLineTitle] IS NULL
															AND @RequestDate between IsNull(acc_m.EffectiveDate, '01/01/1900') AND IsNull(acc_m.ExpirationDate, '2999-01-01 00:00:00.000') )
	WHERE temp.[SOAPieceRate] IS NULL
	/*end get acc prices*/

	SELECT [VMSCarAccessoryID]
		,[AccessoryCode]
		,[AccessoryDescription]
		,[PartNumber]
		,[CarLineTitle]
		,[VehicleYear]
		,[RetailCost]
		,[SOAPieceRate]
		,[DiversifiedPieceRate]
		,[PayAtPDIRateInd]
	FROM #VPCAccessoryMaster

	DROP TABLE #VPCAccessoryMaster

	
END


GO
