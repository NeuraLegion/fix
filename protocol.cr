require "./tags"
require "./message_types"

abstract class FIXProtocol
  @MessageTypes : Hash(String, String)
  @Tags : Enum(Int32)
  @name : String

  abstract def encode(data)
end

class FIX4_4 < FIXProtocol
  @@name = "FIX.4.4"
  @@tags = Tags
  @@MessageTypes = MessageTypes

  def self.logon
    msg = FIXMessage.new MessageTypes::LOGON
    msg.setField(Tags::EncryptMethod, "0")
    msg.setField(Tags::HeartBtInt, "30")
    return msg
  end

  def self.logout
    return Utils.encode(MessageTypes::LOGOUT)
  end

  def self.heartbeat
    msg = FIXMessage(MessageTypes::HEARTBEAT)
    return Utils.encode(Tags::HEARTBEAT)
  end

  def self.test_request
    msg = FIXMessage(MessageTypes::TESTREQUEST)
    return msg
  end

  def self.sequence_reset(respondingTo : Hash(Int32, String), isGapFill : Bool)
    msg = FIXMessage(MessageTypes::SEQUENCERESET)
    msg.setField(fixtags.GapFillFlag, isGapFill ? "Y" : "N")
    msg.setField(fixtags.MsgSeqNum, respondingTo[Tags::BeginSeqNo])
    return msg
  end

  def self.resend_request(beginSeqNo : Int32, endSeqNo : Int32 = 0)
    msg = FIXMessage(MessageTypes::RESENDREQUEST)
    msg.setField(fixtags.BeginSeqNo, beginSeqNo)
    msg.setField(fixtags.EndSeqNo, endSeqNo)
    return msg
  end
end
