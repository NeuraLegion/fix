require "socket"
require "./protocol"
require "./utils"
require "./message"
require "./exception"

module FIX
  # A FIX client capable of connecting and disconnecting to a server, maintaining a session and sending and parsing messages
  # TODO: Receiving repeating groups
  class Session
    @test_id : String?
    @in_seq : Int32 = 1
    @out_seq : Int32 = 1
    @last_sent = Time.now
    @last_recv = Time.now
    @messages = {} of Int32 => Message
    @username : String?
    @password : String?
    @running = true

    # Called when succesful logon takes place
    def on_logon(&block)
      @on_logon_callback = block
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

    # Initializes and connects a Session with heartbeat interval of `hb_int`
    def initialize(host : String, port : Int32, @username = nil, @password = nil, @fix_ver = "FIX.4.4", @fixt = false, @hb_int = 30, timeout = 5)
      @client = TCPSocket.new host, port
      @client.read_timeout = timeout
      @client.write_timeout = timeout
    end

    def send_logon
      send Protocol.logon(hb_int: @hb_int, reset_seq: true, username: @username, password: @password)
    end

    def closed?
      return !@running
    end

    def close
      return unless @running
      send Protocol.logout
      @client.close
      @running = false
    end

    # Handles and maintains the FIX session
    def run
      while @running
        # puts "loop"
        if received = recv
          puts received.data
          case received.msg_type
          when MESSAGE_TYPES[:Logon]
            # puts "received logon"
            @on_logon_callback.not_nil!.call if @on_logon_callback
          when MESSAGE_TYPES[:Heartbeat]
            close if @test_id && (!received.data.has_key? TAGS[:TestReqID] || received.data[TAGS[:TestReqID]] != @test_id)
            @test_id = nil
          when MESSAGE_TYPES[:Logout]
            send Protocol.logout
            close
          when MESSAGE_TYPES[:TestRequest]
            send Protocol.heartbeat received.data[TAGS[:TestReqID]]?.to_s
          when MESSAGE_TYPES[:ResendRequest]
            i = received.data[TAGS[:BeginSeqNo]].as(String).to_i
            @messages.each do |k, v|
              if k >= i
                if k > i
                  send Protocol.sequence_reset(k, true)
                  i = k
                end
                v.set_field(TAGS[:PossDupFlag], "Y")
                send v
                i += 1
              end
            end
          when MESSAGE_TYPES[:Reject]
            @on_error_callback.not_nil!.call SessionRejectException.new(SessionRejectReason.new(received.data[TAGS[:SessionRejectReason]].as(String).to_i), received.data[TAGS[:Text]].as(String)) if @on_error_callback
          when MESSAGE_TYPES[:SequenceReset]
            if received.data[TAGS[:GapFillFlag]]? != "Y" && received.data[TAGS[:MsgSeqNum]].as(String).to_i != @in_seq
              @on_error_callback.not_nil!.call InvalidSeqNum.new if @on_error_callback
            elsif received.data.has_key? TAGS[:NewSeqNo]
              if received.data[TAGS[:NewSeqNo]].as(String).to_i < @in_seq
                close
              else
                @in_seq = received.data[TAGS[:NewSeqNo]].as(String).to_i
              end
            end
          end
        end

        # target inactivity
        if Time.now - @last_recv > (@hb_int + 3).seconds
          if @test_id.nil?
            @test_id = Random.rand(1000...10_000).to_s
            send Protocol.test_request @test_id.not_nil!
            @last_recv = Time.now
          else
            close
          end
        end

        # send heartbeats
        if Time.now - @last_sent >= (@hb_int - 1).seconds
          send Protocol.heartbeat
        end
        # puts "ping hbeat"

        sleep 5.milliseconds
      end
    end

    # Returns decoded incoming Message if a valid one exists in socket buffer - non blocking
    def recv : Message?
      return unless @running

      raw = ""

      begin
        while b = @client.read_byte
          raw += b.chr
          if (b == 1) && (i = raw.rindex("#{TAGS[:BodyLength]}="))
            bytes = Slice(UInt8).new(raw[i + 1 + TAGS[:BodyLength].to_s.size...-1].to_i + TAGS[:CheckSum].to_s.size + 5)
            if !@client.read_fully? bytes
              @on_error_callback.not_nil!.call(DecodeException.new(DecodeFailureReason::INVALID_BODYLENGTH)) if @on_error_callback
              return
            end
            raw += String.new(bytes)
            break
          end
        end
      rescue e
        if @running
          raise e
        else
          return
        end
      end

      if raw != ""
        begin
          msg = Utils.decode raw
          if msg
            if msg.msg_type == MESSAGE_TYPES[:SequenceReset] || msg.data[TAGS[:MsgSeqNum]].as(String).to_i == @in_seq
              # puts "RECEIVED #{msg.data}"
              if [MESSAGE_TYPES[:Heartbeat],
                  MESSAGE_TYPES[:Logout],
                  MESSAGE_TYPES[:Logon],
                  MESSAGE_TYPES[:TestRequest],
                  MESSAGE_TYPES[:ResendRequest],
                  MESSAGE_TYPES[:Reject],
                  MESSAGE_TYPES[:SequenceReset]].includes? msg.msg_type
                @from_admin_callback.not_nil!.call msg if @from_admin_callback
              else
                @from_app_callback.not_nil!.call msg if @from_app_callback
              end
              @last_recv = Time.now
              @in_seq += 1
              return msg
            elsif msg.data[TAGS[:MsgSeqNum]].as(String).to_i > @in_seq
              send Protocol.resend_request @in_seq
            else
              @on_error_callback.not_nil!.call InvalidSeqNum.new if @on_error_callback
              close
            end
          end
        rescue ex : DecodeException
          @on_error_callback.not_nil!.call ex if @on_error_callback
        end
      end
      return nil
    end

    # Sends FIX message `msg` to connected server, set `validate` to `False` to send message as-is
    def send(msg : Message, validate = true) : Nil
      puts msg.data
      return unless @running

      puts msg.data

      msg.data.merge!({TAGS[:SenderCompID] => "CLIENT",
                       TAGS[:TargetCompID] => "TARGET",
                       TAGS[:MsgSeqNum]    => @out_seq.to_s,
                       TAGS[:SendingTime]  => Utils.encode_time(Time.utc_now)}) if validate # add required fields

      if @fixt && validate
        begin_str = "FIXT.1.1"
        msg.set_field(TAGS[:DefaultApplVerID], @fix_ver)
      else
        begin_str = (validate || !msg.data.has_key? TAGS[:BeginString]) ? @fix_ver : msg.data[TAGS[:BeginString]]
      end

      msg.delete_field TAGS[:BeginString]

      msg.delete_field TAGS[:BodyLength]
      msg.delete_field TAGS[:CheckSum]

      encoded_body = Utils.encode(msg.data)

      header = {TAGS[:BeginString] => begin_str,
                TAGS[:BodyLength]  => (encoded_body.size + 4 + msg.msg_type.size).to_s,
                TAGS[:MsgType]     => msg.msg_type}

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
            MESSAGE_TYPES[:SequenceReset]].includes? msg.msg_type
          @to_admin_callback.not_nil!.call msg if @to_admin_callback
        else
          @to_app_callback.not_nil!.call msg if @to_app_callback
          @messages[@out_seq] = msg
        end
      rescue ex : DoNotSend
        return
      end

      encoded_msg = "#{encoded_msg}#{TAGS[:CheckSum]}=%03d\x01" % checksum

      @client.send encoded_msg
      # puts "SENT #{msg.data}"
      @last_sent = Time.now
      @out_seq += 1
    end
  end
end
