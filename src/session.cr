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
    def on_error(&block : FIXException ->)
      @on_error_callback = block
    end

    # Initializes a FIXSession with heartbeat interval of `hbInt`
    def initialize(@proto : Protocol, @hbInt = 5)
      @client = TCPSocket.new
    end

    # Connects to FIX server at hostname/ip `host` and port `port`
    def connect(host : String, port : Int)
      if @state == ConnectionState::STARTED
        @client.connect host, port
        send_msg Protocol.logon @hbInt
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
          when @proto.messageTypes[:LOGON]
            @on_logon_callback.not_nil!.call if @on_logon_callback
          when @proto.messageTypes[:HEARTBEAT]
            disconnect if @testID && (!received.data.has_key? @proto.tags[:TestReqID] || received.data[@proto.tags[:TestReqID]] != @testID)
            @testId = Nil
          when @proto.messageTypes[:LOGOUT]
            send_msg Protocol.logout
            disconnect
          when @proto.messageTypes[:TESTREQUEST]
            send_msg Protocol.heartbeat received.data[@proto.tags[:TestReqID]]?.to_s
          when @proto.messageTypes[:RESENDREQUEST]
            i = received.data[@proto.tags[:BeginSeqNo]].as(String).to_i
            @messages.each do |k, v|
              if k >= i
                if k > i
                  send_msg Protocol.sequence_reset(k, true)
                  i = k
                end
                v.set_field(@proto.tags[:PossDupFlag], "Y")
                send_msg v
                i += 1
              end
            end
          when @proto.messageTypes[:REJECT]
            @on_error_callback.not_nil!.call SessionRejectException.new(SessionRejectReason.new(received.data[@proto.tags[:SessionRejectReason]].as(String).to_i), received.data[@proto.tags[:Text]].as(String)) if @on_error_callback
          when @proto.messageTypes[:SEQUENCERESET]
            if received.data[@proto.tags[:GapFillFlag]]? != "Y" && received.data[@proto.tags[:MsgSeqNum]].as(String).to_i != @inSeqNum
              @on_error_callback.not_nil!.call InvalidSeqNum.new if @on_error_callback
            elsif received.data.has_key? @proto.tags[:NewSeqNo]
              if received.data[@proto.tags[:NewSeqNo]].as(String).to_i < @inSeqNum
                disconnect
              else
                @inSeqNum = received.data[@proto.tags[:NewSeqNo]].as(String).to_i
              end
            end
          end
        end

        # target inactivity
        if Time.now - @lastRecv > (@hbInt + 3).seconds
          if @testID.nil?
            @testID = Random.rand(1000...10000).to_s
            send_msg Protocol.test_request @testID
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
        if (b == 1) && (i = raw.rindex("#{@proto.tags[:BodyLength]}="))
          bytes = Slice(UInt8).new(raw[i + 1 + @proto.tags[:BodyLength].to_s.size...-1].to_i + @proto.tags[:CheckSum].to_s.size + 5)
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
          msg = Protocol.decode raw
          if msg
            if msg.msgType == @proto.messageTypes[:SEQUENCERESET] || msg.data[@proto.tags[:MsgSeqNum]].as(String).to_i == @inSeqNum
              # puts "RECEIVED #{msg.data}"
              if [@proto.messageTypes[:HEARTBEAT],
                  @proto.messageTypes[:LOGOUT],
                  @proto.messageTypes[:LOGON],
                  @proto.messageTypes[:TESTREQUEST],
                  @proto.messageTypes[:RESENDREQUEST],
                  @proto.messageTypes[:REJECT],
                  @proto.messageTypes[:SEQUENCERESET]].includes? msg.msgType
                @from_admin_callback.not_nil!.call msg if @from_admin_callback
              else
                @from_app_callback.not_nil!.call msg if @from_app_callback
              end
              @lastRecv = Time.now
              @inSeqNum += 1
              msg
            elsif msg.data[@proto.tags[:MsgSeqNum]].as(String).to_i > @inSeqNum
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
      msg.data.merge!({@proto.tags[:SenderCompID] => "CLIENT",
                       @proto.tags[:TargetCompID] => "TARGET",
                       @proto.tags[:MsgSeqNum]    => @outSeqNum.to_s,
                       @proto.tags[:SendingTime]  => Utils.encode_time(Time.utc_now)}) if validate # add required fields

      beginString = (validate || !msg.data.has_key? @proto.tags[:BeginString]) ? Protocol::NAME : msg.data[@proto.tags[:BeginString]]
      msg.delete_field @proto.tags[:BeginString]

      msg.delete_field @proto.tags[:BodyLength]
      msg.delete_field @proto.tags[:CheckSum]

      encoded_body = Protocol.encode(msg.data)

      header = {@proto.tags[:BeginString] => beginString,
                @proto.tags[:BodyLength]  => (encoded_body.size + 4 + msg.msgType.size).to_s,
                @proto.tags[:MsgType]     => msg.msgType}

      encoded_msg = "#{Protocol.encode(header)}#{encoded_body}"

      checksum = "%03d" % Utils.calculate_checksum(encoded_msg)

      msg.data = header.merge(msg.data).merge({@proto.tags[:CheckSum] => checksum})
      # puts encoded_msg.gsub "\x01", "|"

      begin
        if [@proto.messageTypes[:HEARTBEAT],
            @proto.messageTypes[:LOGOUT],
            @proto.messageTypes[:LOGON],
            @proto.messageTypes[:TESTREQUEST],
            @proto.messageTypes[:RESENDREQUEST],
            @proto.messageTypes[:REJECT],
            @proto.messageTypes[:SEQUENCERESET]].includes? msg.msgType
          @to_admin_callback.not_nil!.call msg if @to_admin_callback
        else
          @to_app_callback.not_nil!.call msg if @to_app_callback
          @messages[@outSeqNum] = msg
        end
      rescue ex : DoNotSend
        return
      end

      encoded_msg = "#{encoded_msg}#{@proto.tags[:CheckSum]}=%03d\x01" % checksum

      @client.send encoded_msg
      # puts "SENT #{msg.data}"
      @lastSent = Time.now
      @outSeqNum += 1
    end
  end
end
