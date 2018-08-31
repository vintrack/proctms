USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spGetSDCLoadLanes]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROC [dbo].[spGetSDCLoadLanes] 
(
	@AvailableInd int,
	@ActiveInd int 
)
AS
BEGIN
	
	Select	SDCLoadLanesID, LaneNumber
	From	SDCLoadLanes
	Where	AvailableInd = @AvailableInd
			And ActiveInd = @ActiveInd 	
	Order By SortOrder, LaneNumber 	
			
END




GO
