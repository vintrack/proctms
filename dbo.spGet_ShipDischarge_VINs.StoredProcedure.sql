USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGet_ShipDischarge_VINs]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE procedure [dbo].[spGet_ShipDischarge_VINs]
@ShipNumber as varchar(50)
as
begin
	/************************************************************************
	*	spGet_ShipDischarge_VINs						*
	*														*
	*	Description											*
	*	-----------											*
	*	This returns the list of VINs				*
	*	for the DAI YMS handheld application				*
	*	(for the Ship Discharge screen). 					*
	*														*
	*	Change History										*
	*	--------------										*
	*	Date       Init's Description						*
	*	---------- ------ ----------------------------------------	*
	*	10/05/2012    CristiP    Initial version (based on Colin's script)*
	*									*
	************************************************************************/

	SELECT CaseNumber, FullVIN, LoadNumber, CampaignCode, DischargeLocation
	FROM VPCVehicle
	WHERE ShipNumber = @ShipNumber
	ORDER BY CaseNumber, VINKey, LoadNumber, CampaignCode, DischargeLocation
end



GO
