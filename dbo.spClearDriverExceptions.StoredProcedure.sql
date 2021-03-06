USE [Daidb]
GO
/****** Object:  StoredProcedure [dbo].[spClearDriverExceptions]    Script Date: 8/31/2018 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spClearDriverExceptions](
	@DriverID	int,
	@UpdatedBy	varchar(20) = 'dats'
	)
AS
BEGIN
	/************************************************************************
	*	spClearDriverExceptions					*
	*									*
	*	Description							*
	*	-----------							*
	*	Clears any UnAcknowledged Exception Records (on ClearReloadFromServer)	*
	*	returns count of records updated	*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	08/12/2005 JEP    Initial version				*
	*									*
	************************************************************************/	

	SET nocount on

	DECLARE	
		@PhoneMessage		varchar(255),  -- exception shown on phone
		@ExceptionMessage	varchar(1000), -- message shown to dispatch
		@ClearedDate	datetime,
		@UpdatedDate		datetime,
		-- process vars
		@ClearedCount	int,
		@ReturnCode		int,
		@ReturnMessage	varchar(50),
		@ErrorID		int,
		@Msg			varchar(50)

	BEGIN TRAN
	
	set @ClearedDate = getdate()
	set @PhoneMessage = 'CLEARED using GetAssignment/Refresh'
	set @ExceptionMessage = 'CLEARED using GetAssignment/Refresh'
	set @ClearedCount = 0
	
	--update the exception records
	UPDATE Exception
	SET ExceptionFlag = 3, -- cleared
		PhoneMessage = @PhoneMessage,
		ExceptionMessage = @ExceptionMessage,
		ClearedDate = @ClearedDate,
		UpdatedDate = @ClearedDate,
		UpdatedBy = @UpdatedBy
	WHERE DriverID = @DriverID
		AND ExceptionFlag = 1 -- unacknowledged exceptions only
	SET @ClearedCount = @@ROWCOUNT
	IF @@ERROR <> 0
	  BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Msg = 'Error Number '+CONVERT(varchar(10),@ErrorID)+' encountered clearing the driver exceptions'
		GOTO Error_Encountered
	  END
	
	Error_Encountered:
	IF @ErrorID <> 0
	BEGIN
		ROLLBACK TRAN
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Msg
	END
	ELSE
	BEGIN
		COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = CONVERT(varchar(10),@ClearedCount)+' Exception(s) Cleared Successfully'		
	END

	SELECT @ReturnCode AS 'RC', @ReturnMessage AS 'RM', @ClearedCount AS 'CNT'

	RETURN @ReturnCode
END


GO
