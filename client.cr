require "socket"
require "./protocol"
require "./utils"
require "./message"

class FIXClient
  def initialize(@proto : FIXProtocol, host : String, port : Int)
    @client = TCPSocket.new(host, port)
    @seqNum = 0
    sendMsg @proto.logon
    @lastSent = Time.now
  end

  def disconnect
    sendMsg @proto.logout
    @client.close
  end

  def loop
    if Time.now - @lastSent > 30.seconds
        @client << @proto.heartbeat
    end
  end

  def sendMsg(msg : FIXMessage)
    encoded_body = msg.to_s

    header = {Tags::BeginString  => @proto.name,
              Tags::BodyLength   => encoded_body.size + 4 + msg.msgType.size,
              Tags::MsgType      => msg.msgType,
              Tags::SenderCompID => "CLIENT",
              Tags::TargetCompID => "SERVER",
              Tags::MsgSeqNum    => @seqNum,
              Tags::SendingTime  => Time.utc_now.to_s("%Y%m%d-%H:%M:%S.%L")}

    encoded_msg = "#{Utils.encode(header)}#{encoded_body}"
    encoded_msg = "#{encoded_msg}#{Tags::CheckSum.value}=%03d" % Utils.calculate_checksum(encoded_msg)
    puts encoded_msg
    @client << encoded_msg
    @lastSent = Time.now
  end
end

c = FIXClient.new("localhost", 9898)
