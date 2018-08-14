require "./message"

# Represents a FIX protocol with all the helper functions and tag/message type values needed to communicate in it
module FIX
  module Protocol
    extend self

    # Returns standard LOGON message with heartbeat interval of `hbInt` and optionally `resetSeq` flag
    def logon(hbInt = 30, resetSeq = true)
      msg = Message.new MESSAGE_TYPES[:Logon]
      msg.set_field(TAGS[:EncryptMethod], "0")
      msg.set_field(TAGS[:ResetSeqNumFlag], resetSeq ? "Y" : "N")
      msg.set_field(TAGS[:HeartBtInt], hbInt.to_s)
      msg
    end

    # Returns standard LOGOUT message
    def logout
      Message.new(MESSAGE_TYPES[:Logout])
    end

    # Returns standard HEARTBEAT message
    def heartbeat
      Message.new(MESSAGE_TYPES[:Heartbeat])
    end

    # Returns standard HEARTBEAT response to a TEST_REQUEST message with TestReqID of `testID`
    def heartbeat(testID)
      msg = Message.new(MESSAGE_TYPES[:Heartbeat])
      msg.set_field(TAGS[:TestReqID], testID)
      msg
    end

    # Returns standard TEST_REQUEST message with TestReqID of `testID`
    def test_request(testID)
      msg = Message.new(MESSAGE_TYPES[:TestRequest])
      msg.set_field(TAGS[:TestReqID], testID)
      msg
    end

    # Returns standard SEQ_RESET / GAP_FILL message
    def sequence_reset(newSeqNo, isGapFill = false)
      msg = Message.new(MESSAGE_TYPES[:SequenceReset])
      msg.set_field(TAGS[:GapFillFlag], isGapFill ? "Y" : "N")
      msg.set_field(TAGS[:MsgSeqNum], newSeqNo)
      msg
    end

    # Returns standard RESEND_REQUEST message with `beginSeqNo` and `endSeqNo`
    def resend_request(beginSeqNo : Int32, endSeqNo : Int32 = 0)
      msg = Message.new(MESSAGE_TYPES[:ResendRequest])
      msg.set_field(TAGS[:BeginSeqNo], beginSeqNo)
      msg.set_field(TAGS[:EndSeqNo], endSeqNo)
      msg
    end
  end
end
