require "./FIX_4.4/tags"
require "./FIX_4.4/message_types"
require "./message"
require "./exception"

# abstract class FIXProtocol
#    @MessageTypes : Hash(String, String)
#    @Tags : Enum
#    @name : String
#
#    abstract def encode(data)
#  end

# Represents a FIX protocol with all the helper functions and tag/message type values needed to communicate in it
# Currently implements FIX 4.4
module FIXProtocol
  include MessageTypes
  include Tags
  extend self

  NAME = "FIX.4.4"

  # Encodes a FIX message in `k=v\x01` format
  # ```
  # encode({35 => "A", 6 => "asd", 7 => "tr", 20 => [{26 => "oo", 29 => "gj"}, {26 => "53o", 29 => "g5j"}]})
  # ```
  # will yield
  # ```text
  # "35=A|6=asd|7=tr|20=2|26=oo|29=gj|26=53o|29=g5j|"
  # ```
  def encode(data : Hash(Int32, String | Array(Hash(Int32, String))))
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

  # Decodes a FIX message encoded in `k=v\x01` format to a FIXMessage object
  # ```
  # decode("35=A|6=asd|7=tr|20=2")
  # ```
  # will yield
  # ```text
  # FIXMessage(msgType="A", data={6=>"asd", 7=>"tr", 20=>"2"})
  # ```
  # TODO: Add repeating groups decoding
  def decode(data : String) : FIXMessage
    decoded = {} of Int32 => String | Array(Hash(Int32, String))
    begin
      data.split("\x01")[0...-1].each do |field|
        k, v = field.split("=")
        decoded[k.to_i] = v
      end
    rescue ex
      raise DecodeException.new DecodeFailureReason::INVALID_FORMAT, data
    end

    # validate message
    # contains required fields
    raise DecodeException.new DecodeFailureReason::REQUIRED_FIELD_MISSING, data unless ([Tags::CheckSum,
                                                                                         Tags::BeginString,
                                                                                         Tags::BodyLength,
                                                                                         Tags::SenderCompID,
                                                                                         Tags::TargetCompID,
                                                                                         Tags::MsgSeqNum,
                                                                                         Tags::SendingTime,
                                                                                         Tags::MsgType] - decoded.keys).empty?

    # correct checksum
    checksum = Utils.calculate_checksum(data[0...data.rindex("#{Tags::CheckSum}=").not_nil!])
    raise DecodeException.new DecodeFailureReason::INVALID_CHECKSUM, data unless decoded[Tags::CheckSum] == "%03d" % checksum

    # correct body length
    length = data.rindex("#{Tags::CheckSum}=").not_nil! - data.index("#{Tags::MsgType}=").not_nil!
    raise DecodeException.new DecodeFailureReason::INVALID_BODYLENGTH, data unless decoded[Tags::BodyLength] == length.to_s

    # create message
    msgtype = decoded.delete(Tags::MsgType).as(String)
    return FIXMessage.new msgtype, decoded
  end

  # Returns standard LOGON message with heartbeat interval of `hbInt` and optionally `resetSeq` flag
  def logon(hbInt = 30, resetSeq = true)
    msg = FIXMessage.new MessageTypes::LOGON
    msg.set_field(Tags::EncryptMethod, "0")
    msg.set_field(Tags::ResetSeqNumFlag, resetSeq ? "Y" : "N")
    msg.set_field(Tags::HeartBtInt, hbInt.to_s)
    msg
  end

  # Returns standard LOGOUT message
  def logout
    FIXMessage.new(MessageTypes::LOGOUT)
  end

  # Returns standard HEARTBEAT message
  def heartbeat
    FIXMessage.new(MessageTypes::HEARTBEAT)
  end

  # Returns standard HEARTBEAT response to a TEST_REQUEST message with TestReqID of `testID`
  def heartbeat(testID)
    msg = FIXMessage.new(MessageTypes::HEARTBEAT)
    msg.set_field(Tags::TestReqID, testID)
    msg
  end

  # Returns standard TEST_REQUEST message with TestReqID of `testID`
  def test_request(testID)
    msg = FIXMessage.new(MessageTypes::TESTREQUEST)
    msg.set_field(Tags::TestReqID, testID)
    msg
  end

  # Returns standard SEQ_RESET / GAP_FILL message
  def sequence_reset(isGapFill = false)
    msg = FIXMessage.new(MessageTypes::SEQUENCERESET)
    msg.set_field(fixtags.GapFillFlag, isGapFill ? "Y" : "N")
    msg.set_field(fixtags.MsgSeqNum, respondingTo[Tags::BeginSeqNo])
    msg
  end

  # Returns standard RESEND_REQUEST message with `beginSeqNo` and `endSeqNo`
  def resend_request(beginSeqNo : Int32, endSeqNo : Int32 = 0)
    msg = FIXMessage.new(MessageTypes::RESENDREQUEST)
    msg.set_field(fixtags.BeginSeqNo, beginSeqNo)
    msg.set_field(fixtags.EndSeqNo, endSeqNo)
    msg
  end
end
