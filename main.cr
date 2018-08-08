require "socket"
require "./tags"
require "./message_types"

class FIXMessage
  def initialize(msgType : String)
    @msgType = msgType
    @data = {} of Int32 => String | Hash(Int32, String)
  end

  def setField(key : Tags, value : String | Hash(Int32, String))
    @data[key] = value
  end

  def deleteField(key : Tags)
    @data.delete(key)
  end

  def to_s
    return encode(@data)
  end
end

class FIX4_4
  def logon
    msg = FIXMessage(MessageType::LOGON)
    msg.setField(fixtags.EncryptMethod, 0)
    msg.setField(fixtags.HeartBtInt, 30)
    return msg
  end

  def logout
    return encode(MessageType::LOGOUT)
  end

  def heartbeat
    msg = FIXMessage(MessageType::HEARTBEAT)
    return encode(MessageType::HEARTBEAT)
  end

  def test_request
    msg = FIXMessage(MessageType::TESTREQUEST)
    return msg
  end

  def sequence_reset(respondingTo : Hash(Int32, String), isGapFill : Bool)
    msg = FIXMessage(MessageType::SEQUENCERESET)
    msg.setField(fixtags.GapFillFlag, isGapFill ? "Y" : "N")
    msg.setField(fixtags.MsgSeqNum, respondingTo[Tags::BeginSeqNo])
    return msg
  end

  def resend_request(beginSeqNo : Int32, endSeqNo : Int32 = 0)
    msg = FIXMessage(MessageType::RESENDREQUEST)
    msg.setField(fixtags.BeginSeqNo, beginSeqNo)
    msg.setField(fixtags.EndSeqNo, endSeqNo)
    return msg
  end
end

class FIXClient
  def connect(host : String, port : Int)
    @client = TCPSocket.new(host, port)
    sendMsg FIX4_4.logon
  end

  def disconnect
    sendMsg FIX4_4.logout
    @client.close
  end

  def sendMsg(msg : FIXMessage)
    encoded_body = msg.to_s

    header = {Tags::BeginString  => "FIX.4.4",
              Tags::BodyLength   => encoded_body.size + 4 + msgtype.size,
              Tags::MsgType      => msg.msgType,
              Tags::SenderCompID => "CLIENT",
              Tags::TargetCompID => "SERVER",
              Tags::MsgSqNum     => @seqNum,
              Tags::SendingTime  => Time.utc_now.to_s("%Y%m%d-%H:%M:%S.%L")}

    encoded_msg = "#{encode(header)}#{encoded_body}"

    checksum = 0
    encoded_msg.each_byte do |c|
        checksum += c
    end
    checksum %= 256
    
    encoded_msg = "#{encoded_msg}#{Tags::CheckSum}=%03d" % checksum
    @client << encoded_msg
  end
end

def encode(data : Hash(Int, String))
    return data.map do |key, value|
        item = "#{key}=#{value}\x01"
      end.join
end
