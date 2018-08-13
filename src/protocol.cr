module FIX
  abstract class Protocol
    getter name = ""
    getter messageTypes = {} of Symbol => String
    getter tags = {} of Symbol => Int32

    # Returns standard LOGON message with heartbeat interval of `hbInt` and optionally `resetSeq` flag
    abstract def logon(hbInt = 30, resetSeq = true)

    # Returns standard LOGOUT message
    abstract def logout

    # Returns standard HEARTBEAT message
    abstract def heartbeat

    # Returns standard HEARTBEAT response to a TEST_REQUEST message with TestReqID of `testID`
    abstract def heartbeat(testID)

    # Returns standard TEST_REQUEST message with TestReqID of `testID`
    abstract def test_request(testID)

    # Returns standard SEQ_RESET / GAP_FILL message
    abstract def sequence_reset(newSeqNo, isGapFill = false)

    # Returns standard RESEND_REQUEST message with `beginSeqNo` and `endSeqNo`
    abstract def resend_request(beginSeqNo : Int32, endSeqNo : Int32 = 0)
  end
end
