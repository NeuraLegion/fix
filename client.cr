require "socket"
require "./protocol"
require "./utils"
require "./message"

class FIXClient
  def initialize(host : String, port : Int)
    @client = TCPSocket.new(host, port)
    @seqNum = 0
    sendMsg FIXProtocol.logon
    @lastSent = Time.now
  end

  def disconnect
    sendMsg FIXProtocol.logout
    @client.close
  end

  def loop
    if Time.now - @lastSent > 30.seconds
      @client << FIXProtocol.heartbeat
    end
  end

  def sendMsg(msg : FIXMessage)
    msg.data.merge({Tags::SenderCompID => "CLIENT",
                     Tags::TargetCompID => "SERVER",
                     Tags::MsgSeqNum    => @seqNum,
                     Tags::SendingTime  => Utils.encode_time(Time.utc_now)}) # add required fields
    msg.deleteField Tags::BeginString
    msg.deleteField Tags::BodyLength
    msg.deleteField Tags::CheckSum

    encoded_body = msg.to_s

    header = {Tags::BeginString  => FIXProtocol::NAME,
              Tags::BodyLength   => encoded_body.size + 4 + msg.msgType.size,
              Tags::MsgType      => msg.msgType}

    encoded_msg = "#{FIXProtocol.encode(header)}#{encoded_body}"
    encoded_msg = "#{encoded_msg}#{Tags::CheckSum}=%03d" % Utils.calculate_checksum(encoded_msg)
    puts encoded_msg
    @client << encoded_msg
    @lastSent = Time.now
  end
end

c = FIXClient.new("localhost", 9898)
