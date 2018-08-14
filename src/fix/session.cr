require "socket"
require "./protocol"
require "./utils"
require "./message"
require "./exception"

module FIX
  # Helper enum for FIXSession to represent its state
  enum ConnectionState
    STARTED,
    CONNECTED,
    DISCONNECTED
  end

  # A FIX client capable of connecting and disconnecting to a server, maintaining a session and sending and parsing messages
  # TODO: Receiving repeating groups
  class Session
    @testID : String?
    @inSeqNum : Int32 = 1
    @outSeqNum : Int32 = 1
    @lastSent = Time.now
    @lastRecv = Time.now
    @messages = {} of Int32 => Message
    @state = ConnectionState::STARTED
    @username : String?
    @password : String?

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
    def to_admin(&block : Message ->)
      @to_admin_callback = block
    end

    # Called when an application message is about to be sent, throw `DoNotSend` to not send
    def to_app(&block : Message ->)
      @to_app_callback = block
    end

    # Called when an administrative/session message is received
    def from_admin(&block : Message ->)
      @from_admin_callback = block
    end

    # Called when an application message is received
    def from_app(&block : Message ->)
      @from_app_callback = block
    end

    # Called when an error occurs ( Session or message decoding issues )
    def on_error(&block : Exception ->)
      @on_error_callback = block
    end

    # Initializes a FIXSession with heartbeat interval of `hbInt`
    def initialize(@fixVer = "FIX.4.4", @fixt = false, @hbInt = 30, @username = nil, @password = nil)
      @client = TCPSocket.new
    end

    # Connects to FIX server at hostname/ip `host` and port `port`
    def connect(host : String, port : Int)
      if @state == ConnectionState::STARTED
        @client.connect host, port
        send_msg Protocol.logon(hbInt: @hbInt, resetSeq: true, username: @username, password: @password)
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
          when MESSAGE_TYPES[:Logon]
            @on_logon_callback.not_nil!.call if @on_logon_callback
          when MESSAGE_TYPES[:Heartbeat]
            disconnect if @testID && (!received.data.has_key? TAGS[:TestReqID] || received.data[TAGS[:TestReqID]] != @testID)
            @testId = Nil
          when MESSAGE_TYPES[:Logout]
            send_msg Protocol.logout
            disconnect
          when MESSAGE_TYPES[:TestRequest]
            send_msg Protocol.heartbeat received.data[TAGS[:TestReqID]]?.to_s
          when MESSAGE_TYPES[:ResendRequest]
            i = received.data[TAGS[:BeginSeqNo]].as(String).to_i
            @messages.each do |k, v|
              if k >= i
                if k > i
                  send_msg Protocol.sequence_reset(k, true)
                  i = k
                end
                v.set_field(TAGS[:PossDupFlag], "Y")
                send_msg v
                i += 1
              end
            end
          when MESSAGE_TYPES[:Reject]
            @on_error_callback.not_nil!.call SessionRejectException.new(SessionRejectReason.new(received.data[TAGS[:SessionRejectReason]].as(String).to_i), received.data[TAGS[:Text]].as(String)) if @on_error_callback
          when MESSAGE_TYPES[:SequenceReset]
            if received.data[TAGS[:GapFillFlag]]? != "Y" && received.data[TAGS[:MsgSeqNum]].as(String).to_i != @inSeqNum
              @on_error_callback.not_nil!.call InvalidSeqNum.new if @on_error_callback
            elsif received.data.has_key? TAGS[:NewSeqNo]
              if received.data[TAGS[:NewSeqNo]].as(String).to_i < @inSeqNum
                disconnect
              else
                @inSeqNum = received.data[TAGS[:NewSeqNo]].as(String).to_i
              end
            end
          end
        end

        # target inactivity
        if Time.now - @lastRecv > (@hbInt + 3).seconds
          if @testID.nil?
            @testID = Random.rand(1000...10000).to_s
            send_msg Protocol.test_request @testID.not_nil!
            @lastRecv = Time.now
          else
            disconnect
          end
        end

        # send heartbeats
        if Time.now - @lastSent >= (@hbInt - 1).seconds
          send_msg Protocol.heartbeat
        end
        # puts "ping hbeat"

        sleep 5.milliseconds
      end
    end

    # Returns decoded incoming Message if a valid one exists in socket buffer - non blocking
    def recv_msg
      raw = ""
      while b = @client.read_byte
        raw += b.chr
        if (b == 1) && (i = raw.rindex("#{TAGS[:BodyLength]}="))
          bytes = Slice(UInt8).new(raw[i + 1 + TAGS[:BodyLength].to_s.size...-1].to_i + TAGS[:CheckSum].to_s.size + 5)
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
          msg = Utils.decode raw
          if msg
            if msg.msgType == MESSAGE_TYPES[:SequenceReset] || msg.data[TAGS[:MsgSeqNum]].as(String).to_i == @inSeqNum
              # puts "RECEIVED #{msg.data}"
              if [MESSAGE_TYPES[:Heartbeat],
                  MESSAGE_TYPES[:Logout],
                  MESSAGE_TYPES[:Logon],
                  MESSAGE_TYPES[:TestRequest],
                  MESSAGE_TYPES[:ResendRequest],
                  MESSAGE_TYPES[:Reject],
                  MESSAGE_TYPES[:SequenceReset]].includes? msg.msgType
                @from_admin_callback.not_nil!.call msg if @from_admin_callback
              else
                @from_app_callback.not_nil!.call msg if @from_app_callback
              end
              @lastRecv = Time.now
              @inSeqNum += 1
              msg
            elsif msg.data[TAGS[:MsgSeqNum]].as(String).to_i > @inSeqNum
              send_msg Protocol.resend_request @inSeqNum
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
    def send_msg(msg : Message, validate = true) : Nil
      msg.data.merge!({TAGS[:SenderCompID] => "CLIENT",
                       TAGS[:TargetCompID] => "TARGET",
                       TAGS[:MsgSeqNum]    => @outSeqNum.to_s,
                       TAGS[:SendingTime]  => Utils.encode_time(Time.utc_now)}) if validate # add required fields

      if @fixt && validate
        beginString = "FIXT.1.1"
        msg.set_field(TAGS[:DefaultApplVerID], @fixVer)
      else
        beginString = (validate || !msg.data.has_key? TAGS[:BeginString]) ? @fixVer : msg.data[TAGS[:BeginString]]
      end

      msg.delete_field TAGS[:BeginString]

      msg.delete_field TAGS[:BodyLength]
      msg.delete_field TAGS[:CheckSum]

      encoded_body = Utils.encode(msg.data)

      header = {TAGS[:BeginString] => beginString,
                TAGS[:BodyLength]  => (encoded_body.size + 4 + msg.msgType.size).to_s,
                TAGS[:MsgType]     => msg.msgType}

      encoded_msg = "#{Utils.encode(header)}#{encoded_body}"

      checksum = "%03d" % Utils.calculate_checksum(encoded_msg)

      msg.data = header.merge(msg.data).merge({TAGS[:CheckSum] => checksum})
      # puts encoded_msg.gsub "\x01", "|"

      begin
        if [MESSAGE_TYPES[:Heartbeat],
            MESSAGE_TYPES[:Logout],
            MESSAGE_TYPES[:Logon],
            MESSAGE_TYPES[:TestRequest],
            MESSAGE_TYPES[:ResendRequest],
            MESSAGE_TYPES[:Reject],
            MESSAGE_TYPES[:SequenceReset]].includes? msg.msgType
          @to_admin_callback.not_nil!.call msg if @to_admin_callback
        else
          @to_app_callback.not_nil!.call msg if @to_app_callback
          @messages[@outSeqNum] = msg
        end
      rescue ex : DoNotSend
        return
      end

      encoded_msg = "#{encoded_msg}#{TAGS[:CheckSum]}=%03d\x01" % checksum

      @client.send encoded_msg
      # puts "SENT #{msg.data}"
      @lastSent = Time.now
      @outSeqNum += 1
    end
  end
end