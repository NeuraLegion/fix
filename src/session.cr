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
  @messages = {} of Int32 => FIXMessage
  @state = ConnectionState::STARTED

  # Initializes a FIXSession with heartbeat interval of `hbInt`
  def initialize(@app : FIXApplication, @hbInt = 5)
    @client = TCPSocket.new
  end

  # Connects to FIX server at hostname/ip `host` and port `port`
  def connect(host : String, port : Int)
    if @state == ConnectionState::STARTED
      @client.connect host, port
      send_msg FIXProtocol.logon @hbInt
      @state = ConnectionState::CONNECTED
      @app.on_connect
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
        when MessageTypes::LOGON
          @app.on_logon
        when MessageTypes::HEARTBEAT
          disconnect if @testID && (!received.data.includes? Tags::TestReqID || received.data[Tags::TestReqID] != @testID)
          @testId = Nil
        when MessageTypes::LOGOUT
          send_msg FIXProtocol.logout
          disconnect
        when MessageTypes::TESTREQUEST
          if received.includes? Tags::TestReqID
            send_msg FIXProtocol.heartbeat received.data[Tags::TestReqID]
          end
        when MessageTypes::RESENDREQUEST
          i = receive.data[Tags::BeginSeqNo].as(String).to_i
          @messages.each do |k, v|
            if k >= i
              if k > i
                send_msg sequence_reset(k, true)
                i = k
              end
              v.set_field(Tags::PossDupFlag, "Y")
              send_msg v
              i += 1
            end
          end
        when MessageTypes::REJECT
          @app.on_error SessionRejectException.new(SessionRejectReason.new(received.data[Tags::SessionRejectReason].as(String).to_i), received.data[Tags::Text].as(String))
        when MessageTypes::SEQUENCERESET
          if received.data[Tags::GapFillFlag]? != "Y" && msg.data[Tags::MsgSeqNum].as(String).to_i != @inSeqNum
            @app.on_error InvalidSeqNum.new
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
          send_msg FIXProtocol.test_request @testID
          @lastRecv = Time.now
        else
          disconnect
        end
      end

      # send heartbeats
      if Time.now - @lastSent > @hbInt.seconds
        send_msg FIXProtocol.heartbeat
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
          if msg.msgType == MessageTypes::SEQUENCERESET || msg.data[Tags::MsgSeqNum].as(String).to_i == @inSeqNum
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
          elsif msg.data[Tags::MsgSeqNum].as(String).to_i > @inSeqNum
            send_msg resend_request @inSeqNum
          else
            @app.on_error InvalidSeqNum.new
            disconnect
          end
        end
      rescue ex : DecodeException
        @app.on_error(ex)
      end
    end
  end

  # Sends FIX message `msg` to connected server, set `validate` to `False` to send message as-is
  def send_msg(msg : FIXMessage, validate = true)
    msg.data.merge!({Tags::SenderCompID => "CLIENT",
                     Tags::TargetCompID => "TARGET",
                     Tags::MsgSeqNum    => @outSeqNum.to_s,
                     Tags::SendingTime  => Utils.encode_time(Time.utc_now)}) if validate # add required fields

    beginString = (validate || !msg.data.includes? Tags::BeginString) ? FIXProtocol::NAME : msg.data[Tags::BeginString]
    msg.delete_field Tags::BeginString

    msg.delete_field Tags::BodyLength
    msg.delete_field Tags::CheckSum

    encoded_body = FIXProtocol.encode(msg)

    header = {Tags::BeginString => beginString,
              Tags::BodyLength  => (encoded_body.size + 4 + msg.msgType.size).to_s,
              Tags::MsgType     => msg.msgType}

    encoded_msg = "#{FIXProtocol.encode(header)}#{encoded_body}"

    checksum = "%03d" % Utils.calculate_checksum(encoded_msg)

    msg.data = header.merge(msg).merge({Tags::CheckSum => checksum})
    # puts encoded_msg.gsub "\x01", "|"

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
        @messages[@outSeqNum] = msg
      end
    rescue ex : DoNotSend
      return
    end

    encoded_msg = "#{encoded_msg}#{Tags::CheckSum}=%03d\x01" % checksum

    @client.send encoded_msg
    # puts "SENT #{msg.data}"
    @lastSent = Time.now
    @outSeqNum += 1
  end
end
