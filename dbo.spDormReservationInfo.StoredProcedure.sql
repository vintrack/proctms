USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spDormReservationInfo]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		David Maibor
-- Create date: 3/12/18
-- Description:	Retrieve Reservation info to display in table
--	for specified Reservation Date & Dorm Location
-- =============================================
CREATE PROCEDURE [dbo].[spDormReservationInfo]
	@ReservationDate Date,
	@DormLocation varchar(40),
	@UserID int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

   SELECT 
	room.DormRoom,
	CASE
		WHEN ISNULL(room.AvailableInd,0) = 0 THEN 'BLOCKED'
		WHEN ReservationID IS NULL THEN 'AVAILABLE'
		WHEN res.UserID = @UserID THEN 'YOUR RES'
		ELSE 'RESERVED'
	END AS Status,
	'' AS Action,
	room.DormRoomID,
	res.ReservationID,
	res.UserID,
	Users.UserCode,
	Users.FirstName + ' ' + Users.LastName AS UserName
	FROM
	DormRooms room
	LEFT OUTER JOIN DormReservations res on res.DormRoomID=room.DormRoomID
			AND res.ReservationDate=@ReservationDate
	LEFT OUTER JOIN Users on Users.UserID=res.UserID
	WHERE room.DormLocation=@DormLocation
	order by room.SortOrder;
END

GO
