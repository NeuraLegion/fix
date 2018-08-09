require "./FIX_4.4/tags"
require "./FIX_4.4/message_types"

# abstract class FIXProtocol
#    @MessageTypes : Hash(String, String)
#    @Tags : Enum
#    @name : String
#
#    abstract def encode(data)
#  end

module FIXProtocol # implements FIX 4.4
  include MessageTypes
  include Tags

  NAME = "FIX.4.4"

  def self.encode(data)
    data.map do |key, value|
      item = "#{key}=#{value}\x01"
    end.join
  end

  def self.logon
    msg = FIXMessage.new MessageTypes::LOGON
    msg.setField(Tags::EncryptMethod, "0")
    msg.setField(Tags::HeartBtInt, "30")
    msg
  end

  def self.logout
    FIXMessage(MessageTypes::LOGOUT)
  end

  def self.heartbeat
    FIXMessage(MessageTypes::HEARTBEAT)
  end

  def self.test_request
    FIXMessage(MessageTypes::TESTREQUEST)
  end

  def self.sequence_reset(respondingTo : Hash(Int32, String), isGapFill : Bool)
    msg = FIXMessage(MessageTypes::SEQUENCERESET)
    msg.setField(fixtags.GapFillFlag, isGapFill ? "Y" : "N")
    msg.setField(fixtags.MsgSeqNum, respondingTo[Tags::BeginSeqNo])
    msg
  end

  def self.resend_request(beginSeqNo : Int32, endSeqNo : Int32 = 0)
    msg = FIXMessage(MessageTypes::RESENDREQUEST)
    msg.setField(fixtags.BeginSeqNo, beginSeqNo)
    msg.setField(fixtags.EndSeqNo, endSeqNo)
    msg
  end
end
