require "socket"
require "./protocol"
require "./utils"
require "./message"
require "./exception"
require "./app"

# Helper enum for FIXSession to represent its state
enum ConnectionState
  STARTED,
  CONNECTED,
  DISCONNECTED
end

# A FIX client capable of connecting and disconnecting to a server, maintaining a session and sending and parsing messages
# TODO: Receiving repeating groups
# TODO: Convinient API probably using fibers/events or non-blocking loop
class FIXSession
  @testID : String?
  @inSeqNum : Int32 = 1
  @outSeqNum : Int32 = 1
  @lastSent = Time.now
  @lastRecv = Time.now
  @messages = {} of Int32 => String
  @state = ConnectionState::STARTED

  # Initializes a FIXSession with heartbeat interval of `hbInt`
  def initialize(@app : FIXApplication, @hbInt = 5)
    @client = TCPSocket.new
  end

  # Connects to FIX server at hostname/ip `host` and port `port`
  def connect(host : String, port : Int)
    if @state == ConnectionState::STARTED
      @client.connect host, port
      self << FIXProtocol.logon @hbInt
      @state = ConnectionState::CONNECTED
      @app.on_logon
    end
  end

  def disconnect
    if @state == ConnectionState::CONNECTED
      @client.close
      @state = ConnectionState::DISCONNECTED
      @app.on_logout
    end
  end

  # Handles and maintains the FIX session
  def loop
    # puts "loop"
    r = Random.new
    cl0rdid = r.rand(1000..10000)
    while @state == ConnectionState::CONNECTED
      # puts "loop"
      if received = recv_msg
        # puts received
        case received.msgType
        when MessageTypes::HEARTBEAT
          disconnect if @testID && received.data[Tags::TestReqID] != @testID
          @testId = Nil
        when MessageTypes::LOGOUT
          self << FIXProtocol.logout
          disconnect
        when MessageTypes::TESTREQUEST
          self << FIXProtocol.heartbeat received.data[Tags::TestReqID]
        when MessageTypes::RESENDREQUEST
        when MessageTypes::REJECT
          @app.on_error SessionRejectException.new(SessionRejectReason.new(received.data[Tags::SessionRejectReason].as(String).to_i), received.data[Tags::Text].as(String))
        when MessageTypes::SEQUENCERESET
          if received.data[Tags::GapFillFlag]? == "Y"
          elsif received.data.has_key? Tags::NewSeqNo
            if received.data[Tags::NewSeqNo].as(String).to_i < @inSeqNum
              disconnect
            else
              @inSeqNum = received.data[Tags::NewSeqNo].as(String).to_i
            end
          end
        end
      end

      # target inactivity
      if Time.now - @lastRecv > (@hbInt + 3).seconds
        if @testID.nil?
          @testID = r.rand(1000...10000).to_s
          self << FIXProtocol.test_request @testID
          @lastRecv = Time.now
        else
          disconnect
        end
      end

      # send heartbeats
      if Time.now - @lastSent > @hbInt.seconds
        self << FIXProtocol.heartbeat
      end
      # puts "ping hbeat"

      sleep 1.seconds
    end
  end

  # Returns decoded incoming FIXMessage if a valid one exists in socket buffer - non blocking
  # TODO: Read according to BodyLength
  # TODO: Resend request in case sequence number greater than expected
  def recv_msg
    bytes = Slice(UInt8).new(4096)
    @client.read bytes
    raw = String.new(bytes[0, bytes.index(0).not_nil!])
    if raw
      begin
        msg = FIXProtocol.decode raw
        if msg
          case msg.data[Tags::MsgSeqNum].as(String).to_i <=> @inSeqNum
          when 0 # Equal
            # puts "RECEIVED #{msg.data}"
            if [MessageTypes::HEARTBEAT,
                MessageTypes::LOGOUT,
                MessageTypes::LOGON,
                MessageTypes::TESTREQUEST,
                MessageTypes::RESENDREQUEST,
                MessageTypes::REJECT,
                MessageTypes::SEQUENCERESET].includes? msg.msgType
              @app.from_admin msg
            else
              @app.from_app msg
            end
            @lastRecv = Time.now
            @inSeqNum += 1
            msg
          when -1 # Smaller
            @app.on_error InvalidSeqNum.new
            disconnect
          when 1 # Bigger
            raise "Not implemented"
          end
        end
      rescue ex : DecodeException
        @app.on_error(ex)
      end
    end
  end

  # Sends FIX message `msg` to connected server
  def <<(msg : FIXMessage)
    msg.data.merge!({Tags::SenderCompID => "CLIENT",
                     Tags::TargetCompID => "TARGET",
                     Tags::MsgSeqNum    => @outSeqNum.to_s,
                     Tags::SendingTime  => Utils.encode_time(Time.utc_now)}) # add required fields
    msg.delete_field Tags::BeginString
    msg.delete_field Tags::BodyLength
    msg.delete_field Tags::CheckSum

    encoded_body = msg.to_s

    header = {Tags::BeginString => FIXProtocol::NAME,
              Tags::BodyLength  => (encoded_body.size + 4 + msg.msgType.size).to_s,
              Tags::MsgType     => msg.msgType}

    encoded_msg = "#{FIXProtocol.encode(header)}#{encoded_body}"
    encoded_msg = "#{encoded_msg}#{Tags::CheckSum}=%03d\x01" % Utils.calculate_checksum(encoded_msg)
    # puts encoded_msg.gsub "\x01", "|"
    # puts encoded_msg

    begin
      if [MessageTypes::HEARTBEAT,
          MessageTypes::LOGOUT,
          MessageTypes::LOGON,
          MessageTypes::TESTREQUEST,
          MessageTypes::RESENDREQUEST,
          MessageTypes::REJECT,
          MessageTypes::SEQUENCERESET].includes? msg.msgType
        @app.to_admin msg
      else
        @app.to_app msg
      end
    rescue ex : DoNotSend
      return
    end

    @client.send encoded_msg
    # puts "SENT #{msg.data}"
    @messages[@outSeqNum] = encoded_msg
    @lastSent = Time.now
    @outSeqNum += 1
  end
end
