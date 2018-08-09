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
  extend self

  NAME = "FIX.4.4"

  def encode(data)
    data.map do |key, value|
      if value.is_a?(Array(Hash(Int32, String)))
        groups = value.map do |group|
          group.map do |k, v|
            item = "#{k}=#{v}\x01"
          end.join
        end.join
        "#{key}=#{value.size}\x01#{groups}"
      else
        "#{key}=#{value}\x01"
      end
    end.join
  end

  def decode(data : String) : FIXMessage
    # cant handle groups
    decoded = {} of Int32 => String | Array(Hash(Int32, String))
    data.split("\x01")[0...-1].each do |field|
      k, v = field.split("=")
      decoded[k.to_i] = v
    end
    # validate message
    # contains required fields
    if ([Tags::CheckSum,
         Tags::BeginString,
         Tags::BodyLength,
         Tags::SenderCompID,
         Tags::TargetCompID,
         Tags::MsgSeqNum,
         Tags::SendingTime,
         Tags::MsgType] - decoded.keys).empty?
      checksum = Utils.calculate_checksum(data[0...data.rindex(Tags::CheckSum.to_s).not_nil!])
      length = data.rindex(Tags::CheckSum.to_s).not_nil! - data.index(Tags::MsgType.to_s).not_nil!
      puts decoded[Tags::CheckSum] == "%03d" % checksum
      puts decoded[Tags::BodyLength] == length.to_s
      if decoded[Tags::CheckSum] == "%03d" % checksum && decoded[Tags::BodyLength] == length.to_s
        msgtype = decoded.delete(Tags::MsgType).as(String)
        return FIXMessage.new msgtype, decoded
      end
    end
    raise "Invalid Message"
  end

  def logon(heartbeat = 30, resetSeq = true)
    msg = FIXMessage.new MessageTypes::LOGON
    msg.setField(Tags::EncryptMethod, "0")
    msg.setField(Tags::ResetSeqNumFlag, resetSeq ? "Y" : "N")
    msg.setField(Tags::HeartBtInt, heartbeat.to_s)
    msg
  end

  def logout
    FIXMessage.new(MessageTypes::LOGOUT)
  end

  def heartbeat
    FIXMessage.new(MessageTypes::HEARTBEAT)
  end

  def heartbeat(testID)
    msg = FIXMessage.new(MessageTypes::HEARTBEAT)
    msg.setField(Tags::TestReqID, testID)
    msg
  end

  def test_request(testID)
    msg = FIXMessage.new(MessageTypes::TESTREQUEST)
    msg.setField(Tags::TestReqID, testID)
    msg
  end

  def sequence_reset(isGapFill = false)
    msg = FIXMessage.new(MessageTypes::SEQUENCERESET)
    msg.setField(fixtags.GapFillFlag, isGapFill ? "Y" : "N")
    msg.setField(fixtags.MsgSeqNum, respondingTo[Tags::BeginSeqNo])
    msg
  end

  def resend_request(beginSeqNo : Int32, endSeqNo : Int32 = 0)
    msg = FIXMessage.new(MessageTypes::RESENDREQUEST)
    msg.setField(fixtags.BeginSeqNo, beginSeqNo)
    msg.setField(fixtags.EndSeqNo, endSeqNo)
    msg
  end
end
