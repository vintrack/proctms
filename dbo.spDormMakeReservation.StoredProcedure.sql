USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spDormMakeReservation]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		David Maibor
-- Create date: 3/12/18
-- Description:	Make reservation & create status rec if res available, return 'OK'
--	return 'TAKEN' if not available
--  return 'SECONDRES' if another reservation exists for the user
-- 3/26/18 D.Maibor: return DUP result when User already has the reserveration
-- =============================================
CREATE PROCEDURE [dbo].[spDormMakeReservation]
	@UserID int,
	@CreatedBy varchar(20),
	@ReservationDate date,
	@RoomID int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE 
	@ReservationID int,
	@DormLocation varchar(40),
	@DormRoom varchar(40),
	@Done int = 0;

	DECLARE
	@tbl TABLE
	(result varchar(10),
	ReservationID int,
	DormLocation varchar(40),
	DormRoom varchar(40)
	);

	-- Ck if user has a reservation for reservationdate and diff room
	IF EXISTS
	(SELECT ReservationID 
		FROM DormReservations
		WHERE ReservationDate=@ReservationDate
		AND UserID=@UserID AND DormRoomID<>@RoomID)
	BEGIN
		-- Get the ReservationID,RoomID,DormLocation
		SELECT @ReservationID = res.ReservationID,
		@DormLocation=room.DormLocation,
		@DormRoom=room.DormRoom 
		FROM DormReservations res
		INNER JOIN DormRooms room on room.DormRoomID=res.DormRoomID
		WHERE res.ReservationDate=@ReservationDate
		AND res.UserID=@UserID AND res.DormRoomID<>@RoomID

		INSERT INTO @tbl (result,ReservationID,DormLocation,DormRoom) 
		VALUES ('SECONDRES',@ReservationID,@DormLocation,@DormRoom);
		SET @Done = 1;
	END
	
	-- Ck if room is already reserved by someone else
	IF @Done=0 AND EXISTS
	(SELECT ReservationID 
	FROM DormReservations
	WHERE ReservationDate=@ReservationDate
		AND DormRoomID=@RoomID AND UserID <> @UserID)
	BEGIN
		INSERT INTO @tbl (result) VALUES ('TAKEN');
		SET @Done=1;
	END

	-- Ck if room is already reserved by @UserID
	IF @Done=0 AND EXISTS
	(SELECT ReservationID 
	FROM DormReservations
	WHERE ReservationDate=@ReservationDate
		AND DormRoomID=@RoomID AND UserID = @UserID)
	BEGIN
		SELECT @ReservationID = res.ReservationID,
		@DormLocation=room.DormLocation,
		@DormRoom=room.DormRoom 
		FROM DormReservations res
		INNER JOIN DormRooms room on room.DormRoomID=res.DormRoomID
		WHERE res.ReservationDate=@ReservationDate
		AND res.UserID=@UserID AND res.DormRoomID=@RoomID

		INSERT INTO @tbl (result,ReservationID,DormLocation,DormRoom) 
		VALUES ('DUP',@ReservationID,@DormLocation,@DormRoom);
		SET @Done = 1;
	END
	
	-- Make new reservation & updated status
	IF @Done=0
	BEGIN
		-- Create new Reservation
		INSERT INTO DormReservations(UserID,DormRoomID,
		ReservationDate,CreatedBy,CreationDate) VALUES
		(@UserID,@RoomID,@ReservationDate,@CreatedBy,
		CURRENT_TIMESTAMP);

		-- Get new ReservationID
		SELECT @ReservationID = ReservationID 
		FROM DormReservations
		WHERE ReservationDate=@ReservationDate
		AND UserID=@UserID;

		-- Get DormLocation & DormRoom
		SELECT @DormLocation = DormLocation FROM DormRooms
		WHERE DormRoomID=@RoomID;

		SELECT @DormRoom = DormRoom FROM DormRooms
		WHERE DormRoomID=@RoomID;

		-- Create Status rec
		INSERT INTO DormResStatusHistory(ReservationID,DormRoomID,
		ReservationStatus,ReservationDate,CreatedBy,CreationDate)
		VALUES (@ReservationID,@RoomID,'RESERVED',@ReservationDate,
		@CreatedBy,CURRENT_TIMESTAMP);

		INSERT INTO @tbl (result,ReservationID,DormLocation,DormRoom) 
		VALUES ('OK',@ReservationID,@DormLocation,@DormRoom);
	END

	SELECT * FROM @tbl;
END

GO
