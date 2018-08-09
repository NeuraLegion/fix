require "socket"
require "./protocol"
require "./utils"
require "./message"

class FIXClient
  def initialize(@heartbeat = 30)
    @client = TCPSocket.new
    @inSeqNum = 1
    @outSeqNum = 1

    # puts @client.gets
    @lastSent = Time.now
  end

  def connect(host : String, port : Int)
    @client.connect host, port
    sendMsg FIXProtocol.logon @heartbeat
  end

  def disconnect
    sendMsg FIXProtocol.logout
    @client.close
  end

  def loop
    r = Random.new
    cl0rdid = r.rand(1000..10000)
    loop do
      recvMsg

      msg = FIXMessage.new MessageTypes::NEWORDERSINGLE
      msg.setField Tags::Price, "%0.2f" % r.rand(10.0..13.0).to_s
      msg.setField Tags::OrderQty, r.rand(100).to_s
      msg.setField Tags::Symbol, "VOD.L"
      msg.setField Tags::SecurityID, "GB00BH4HKS39"
      msg.setField Tags::SecurityIDSource, "4"
      msg.setField Tags::Account, "TEST"
      msg.setField Tags::HandlInst, "1"
      msg.setField Tags::ExDestination, "XLON"
      msg.setField Tags::Side, r.rand(1..2).to_s
      msg.setField Tags::ClOrdID, cl0rdid.to_s
      cl0rdid += 1
      msg.setField Tags::Currency, "GBP"
      sendMsg msg

      # if Time.now - @lastSent > @heartbeat.seconds
      #  @client << FIXProtocol.heartbeat
      # end

      sleep 5.seconds
    end
  end

  def recvMsg
    bytes = Slice(UInt8).new(4096)
    @client.read bytes
    raw = String.new(bytes[0, bytes.index(0).not_nil!])
    if !raw.nil?
      msg = FIXProtocol.decode raw
      if !msg.nil?
        puts "RECEIVED #{msg.data}"
        @inSeqNum += 1
      end
    end
  end

  def sendMsg(msg : FIXMessage)
    msg.data.merge!({Tags::SenderCompID => "CLIENT",
                     Tags::TargetCompID => "SERVER",
                     Tags::MsgSeqNum    => @outSeqNum.to_s,
                     Tags::SendingTime  => Utils.encode_time(Time.utc_now)}) # add required fields
    msg.deleteField Tags::BeginString
    msg.deleteField Tags::BodyLength
    msg.deleteField Tags::CheckSum

    encoded_body = msg.to_s

    header = {Tags::BeginString => FIXProtocol::NAME,
              Tags::BodyLength  => encoded_body.size + 4 + msg.msgType.size,
              Tags::MsgType     => msg.msgType}

    encoded_msg = "#{FIXProtocol.encode(header)}#{encoded_body}"
    encoded_msg = "#{encoded_msg}#{Tags::CheckSum}=%03d\n" % Utils.calculate_checksum(encoded_msg)
    # puts encoded_msg
    @client.send encoded_msg
    puts "SENT #{msg.data}"
    @lastSent = Time.now
    @outSeqNum += 1
  end
end

c = FIXClient.new
c.connect "127.0.0.1", 9898
c.loop
