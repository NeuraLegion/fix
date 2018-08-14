require "./message"

# Represents a FIX protocol with all the helper functions and tag/message type values needed to communicate in it
module FIX
  module Protocol
    extend self

    # Returns standard LOGON message with heartbeat interval of `hb_int` and optionally `reset_seq` flag
    def logon(hb_int = 30, reset_seq = true, username : String? = nil, password : String? = nil)
      msg = Message.new MESSAGE_TYPES[:Logon]
      msg.set_field(TAGS[:EncryptMethod], "0")
      msg.set_field(TAGS[:ResetSeqNumFlag], "Y") if reset_seq
      msg.set_field(TAGS[:Username], username) if username
      msg.set_field(TAGS[:Password], password) if password
      msg.set_field(TAGS[:HeartBtInt], hb_int.to_s)
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

    # Returns standard HEARTBEAT response to a TEST_REQUEST message with TestReqID of `test_id`
    def heartbeat(test_id)
      msg = Message.new(MESSAGE_TYPES[:Heartbeat])
      msg.set_field(TAGS[:TestReqID], test_id)
      msg
    end

    # Returns standard TEST_REQUEST message with TestReqID of `test_id`
    def test_request(test_id : String)
      msg = Message.new(MESSAGE_TYPES[:TestRequest])
      msg.set_field(TAGS[:TestReqID], test_id)
      msg
    end

    # Returns standard SEQ_RESET / GAP_FILL message
    def sequence_reset(new_seq, is_gap_fill = false)
      msg = Message.new(MESSAGE_TYPES[:SequenceReset])
      msg.set_field(TAGS[:GapFillFlag], "Y") if is_gap_fill
      msg.set_field(TAGS[:MsgSeqNum], new_seq)
      msg
    end

    # Returns standard RESEND_REQUEST message with `begin_seq_no` and `endSeqNo`
    def resend_request(begin_seq : Int32, end_seq : Int32 = 0)
      msg = Message.new(MESSAGE_TYPES[:ResendRequest])
      msg.set_field(TAGS[:BeginSeqNo], begin_seq)
      msg.set_field(TAGS[:EndSeqNo], end_seq)
      msg
    end
  end
end
