require "socket"
require "./protocol"
require "./utils"
require "./message"
require "./exception"

# Helper enum for FIXSession to represent its state
enum ConnectionState
  STARTED,
  CONNECTED,
  DISCONNECTED
end

# A FIX client capable of connecting and disconnecting to a server, maintaining a session and sending and parsing messages
# TODO: Receiving repeating groups
class FIXSession
  @testID : String?
  @inSeqNum : Int32 = 1
  @outSeqNum : Int32 = 1
  @lastSent = Time.now
  @lastRecv = Time.now
  @messages = {} of Int32 => FIXMessage
  @state = ConnectionState::STARTED

  # Called when connected to server
  def on_connect(&block)
    @on_connect_callback = block
  end

  # Called when succesful logon takes place
  def on_logon(&block)
    @on_logon_callback = block
  end

  # Called when session ends, either by logout or disconnection
  def on_logout(&block)
    @on_logout_callback = block
  end

  # Called when an administrative/session message is about to be sent, throw `DoNotSend` to not send
  def to_admin(&block : FIXMessage ->)
    @to_admin_callback = block
  end

  # Called when an application message is about to be sent, throw `DoNotSend` to not send
  def to_app(&block : FIXMessage ->)
    @to_app_callback = block
  end

  # Called when an administrative/session message is received
  def from_admin(&block : FIXMessage ->)
    @from_admin_callback = block
  end

  # Called when an application message is received
  def from_app(&block : FIXMessage ->)
    @from_app_callback = block
  end

  # Called when an error occurs ( Session or message decoding issues )
  def on_error(&block : FIXException ->)
    @on_error_callback = block
  end

  # Initializes a FIXSession with heartbeat interval of `hbInt`
  def initialize(@hbInt = 5)
    @client = TCPSocket.new
  end

  # Connects to FIX server at hostname/ip `host` and port `port`
  def connect(host : String, port : Int)
    if @state == ConnectionState::STARTED
      @client.connect host, port
      send_msg FIXProtocol.logon @hbInt
      @state = ConnectionState::CONNECTED
      @on_connect_callback.not_nil!.call if @on_connect_callback
    end
  end

  def disconnect
    if @state == ConnectionState::CONNECTED
      @client.close
      @state = ConnectionState::DISCONNECTED
      @on_logout_callback.not_nil!.call if @on_logout_callback
    end
  end

  # Handles and maintains the FIX session
  def loop
    while @state == ConnectionState::CONNECTED
      # puts "loop"
      if received = recv_msg
        # puts received
        case received.msgType
        when MessageTypes::LOGON
          @on_logon_callback.not_nil!.call if @on_logon_callback
        when MessageTypes::HEARTBEAT
          disconnect if @testID && (!received.data.has_key? Tags::TestReqID || received.data[Tags::TestReqID] != @testID)
          @testId = Nil
        when MessageTypes::LOGOUT
          send_msg FIXProtocol.logout
          disconnect
        when MessageTypes::TESTREQUEST
          send_msg FIXProtocol.heartbeat received.data[Tags::TestReqID]?.to_s
        when MessageTypes::RESENDREQUEST
          i = received.data[Tags::BeginSeqNo].as(String).to_i
          @messages.each do |k, v|
            if k >= i
              if k > i
                send_msg FIXProtocol.sequence_reset(k, true)
                i = k
              end
              v.set_field(Tags::PossDupFlag, "Y")
              send_msg v
              i += 1
            end
          end
        when MessageTypes::REJECT
          @on_error_callback.not_nil!.call SessionRejectException.new(SessionRejectReason.new(received.data[Tags::SessionRejectReason].as(String).to_i), received.data[Tags::Text].as(String)) if @on_error_callback
        when MessageTypes::SEQUENCERESET
          if received.data[Tags::GapFillFlag]? != "Y" && received.data[Tags::MsgSeqNum].as(String).to_i != @inSeqNum
            @on_error_callback.not_nil!.call InvalidSeqNum.new if @on_error_callback
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
          @testID = Random.rand(1000...10000).to_s
          send_msg FIXProtocol.test_request @testID
          @lastRecv = Time.now
        else
          disconnect
        end
      end

      # send heartbeats
      if Time.now - @lastSent >= (@hbInt - 1).seconds
        send_msg FIXProtocol.heartbeat
      end
      # puts "ping hbeat"

      sleep 5.milliseconds
    end
  end

  # Returns decoded incoming FIXMessage if a valid one exists in socket buffer - non blocking
  def recv_msg
    raw = ""
    while b = @client.read_byte
      raw += b.chr
      if (b == 1) && (i = raw.rindex("#{Tags::BodyLength}="))
        bytes = Slice(UInt8).new(raw[i + 1 + Tags::BodyLength.to_s.size...-1].to_i + Tags::CheckSum.to_s.size + 5)
        if !@client.read_fully? bytes
          @on_error_callback.not_nil!.call DecodeException.new DecodeFailureReason::INVALID_BODYLENGTH if @on_error_callback
          return
        end
        raw += String.new(bytes)
        break
      end
    end

    if raw != ""
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
              @from_admin_callback.not_nil!.call msg if @from_admin_callback
            else
              @from_app_callback.not_nil!.call msg if @from_app_callback
            end
            @lastRecv = Time.now
            @inSeqNum += 1
            msg
          elsif msg.data[Tags::MsgSeqNum].as(String).to_i > @inSeqNum
            send_msg FIXProtocol.resend_request @inSeqNum
          else
            @on_error_callback.not_nil!.call InvalidSeqNum.new if @on_error_callback
            disconnect
          end
        end
      rescue ex : DecodeException
        @on_error_callback.not_nil!.call ex if @on_error_callback
      end
    end
  end

  # Sends FIX message `msg` to connected server, set `validate` to `False` to send message as-is
  def send_msg(msg : FIXMessage, validate = true) : Nil
    msg.data.merge!({Tags::SenderCompID => "CLIENT",
                     Tags::TargetCompID => "TARGET",
                     Tags::MsgSeqNum    => @outSeqNum.to_s,
                     Tags::SendingTime  => Utils.encode_time(Time.utc_now)}) if validate # add required fields

    beginString = (validate || !msg.data.has_key? Tags::BeginString) ? FIXProtocol::NAME : msg.data[Tags::BeginString]
    msg.delete_field Tags::BeginString

    msg.delete_field Tags::BodyLength
    msg.delete_field Tags::CheckSum

    encoded_body = FIXProtocol.encode(msg.data)

    header = {Tags::BeginString => beginString,
              Tags::BodyLength  => (encoded_body.size + 4 + msg.msgType.size).to_s,
              Tags::MsgType     => msg.msgType}

    encoded_msg = "#{FIXProtocol.encode(header)}#{encoded_body}"

    checksum = "%03d" % Utils.calculate_checksum(encoded_msg)

    msg.data = header.merge(msg.data).merge({Tags::CheckSum => checksum})
    # puts encoded_msg.gsub "\x01", "|"

    begin
      if [MessageTypes::HEARTBEAT,
          MessageTypes::LOGOUT,
          MessageTypes::LOGON,
          MessageTypes::TESTREQUEST,
          MessageTypes::RESENDREQUEST,
          MessageTypes::REJECT,
          MessageTypes::SEQUENCERESET].includes? msg.msgType
        @to_admin_callback.not_nil!.call msg if @to_admin_callback
      else
        @to_app_callback.not_nil!.call msg if @to_app_callback
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
