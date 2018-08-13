require "./4.4/**"
require "./message"
require "./exception"

# Represents a FIX protocol with all the helper functions and tag/message type values needed to communicate in it
# Currently implements FIX 4.4
module FIX
  class Protocol4_4 < Protocol
    @name = "FIX.4.4"

    # Returns standard LOGON message with heartbeat interval of `hbInt` and optionally `resetSeq` flag
    def logon(hbInt = 30, resetSeq = true)
      msg = Message.new @messageTypes[:LOGON]
      msg.set_field(@tags[:EncryptMethod], "0")
      msg.set_field(@tags[:ResetSeqNumFlag], resetSeq ? "Y" : "N")
      msg.set_field(@tags[:HeartBtInt], hbInt.to_s)
      msg
    end

    # Returns standard LOGOUT message
    def logout
      Message.new(@messageTypes[:LOGOUT])
    end

    # Returns standard HEARTBEAT message
    def heartbeat
      Message.new(@messageTypes[:HEARTBEAT])
    end

    # Returns standard HEARTBEAT response to a TEST_REQUEST message with TestReqID of `testID`
    def heartbeat(testID)
      msg = Message.new(@messageTypes[:HEARTBEAT])
      msg.set_field(@tags[:TestReqID], testID)
      msg
    end

    # Returns standard TEST_REQUEST message with TestReqID of `testID`
    def test_request(testID)
      msg = Message.new(@messageTypes[:TESTREQUEST])
      msg.set_field(@tags[:TestReqID], testID)
      msg
    end

    # Returns standard SEQ_RESET / GAP_FILL message
    def sequence_reset(newSeqNo, isGapFill = false)
      msg = Message.new(@messageTypes[:SEQUENCERESET])
      msg.set_field(@tags[:GapFillFlag], isGapFill ? "Y" : "N")
      msg.set_field(@tags[:MsgSeqNum], newSeqNo)
      msg
    end

    # Returns standard RESEND_REQUEST message with `beginSeqNo` and `endSeqNo`
    def resend_request(beginSeqNo : Int32, endSeqNo : Int32 = 0)
      msg = Message.new(@messageTypes[:RESENDREQUEST])
      msg.set_field(@tags[:BeginSeqNo], beginSeqNo)
      msg.set_field(@tags[:EndSeqNo], endSeqNo)
      msg
    end
  end
end
