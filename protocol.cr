require "./FIX_4.4/tags"
require "./FIX_4.4/message_types"
require "./message"

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
      if value.is_a?(String)
        "#{key}=#{value}\x01"
      else
        groups = value.map do |group|
          group.map do |k, v|
            item = "#{k}=#{v}\x01"
          end.join
        end.join
        "#{key}=#{value.size}\x01#{groups}"
      end
    end.join
  end

  def self.decode(data : String) : FIXMessage?
    # cant handle groups
    decoded = {} of Int32 => String | Array(Hash(Int32, String))
    data.split("\x01")[0...-1].each do |field|
      k, v = field.split("=")
      decoded[k.to_i] = v
    end
    # validate message
    checksum = Utils.calculate_checksum(data[0...data.rindex(Tags::CheckSum.to_s).not_nil!])
    length = data.rindex(Tags::CheckSum.to_s).not_nil! - data.index(Tags::MsgType.to_s).not_nil!
    if decoded[Tags::CheckSum] == "%03d" % checksum && decoded[Tags::BodyLength] == length.to_s && decoded.has_key? Tags::MsgType
      msgtype = decoded.delete(Tags::MsgType).as(String)
      FIXMessage.new msgtype, decoded
    end
  end

  def self.logon(heartbeat = 30)
    msg = FIXMessage.new MessageTypes::LOGON
    msg.setField(Tags::EncryptMethod, "0")
    msg.setField(Tags::HeartBtInt, heartbeat.to_s)
    msg
  end

  def self.logout
    FIXMessage.new(MessageTypes::LOGOUT)
  end

  def self.heartbeat
    FIXMessage.new(MessageTypes::HEARTBEAT)
  end

  def self.heartbeat(testID)
    msg = FIXMessage.new(MessageTypes::HEARTBEAT)
    msg.setField(Tags::TestReqID, testID)
    msg
  end

  def self.test_request(testID)
    msg = FIXMessage.new(MessageTypes::TESTREQUEST)
    msg.setField(Tags::TestReqID, testID)
    msg
  end

  def self.sequence_reset(isGapFill = false)
    msg = FIXMessage.new(MessageTypes::SEQUENCERESET)
    msg.setField(fixtags.GapFillFlag, isGapFill ? "Y" : "N")
    msg.setField(fixtags.MsgSeqNum, respondingTo[Tags::BeginSeqNo])
    msg
  end

  def self.resend_request(beginSeqNo : Int32, endSeqNo : Int32 = 0)
    msg = FIXMessage.new(MessageTypes::RESENDREQUEST)
    msg.setField(fixtags.BeginSeqNo, beginSeqNo)
    msg.setField(fixtags.EndSeqNo, endSeqNo)
    msg
  end
end
