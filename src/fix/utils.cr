module FIX
  # Utility functions
  module Utils
    extend self

    # Calculates checksum of string ( sum of char values % 256 )
    def calculate_checksum(data : String)
      data.chars.reduce(0) { |acc, c| acc + c.ord } % 256
    end

    # Encodes time in fix timestamp format
    def encode_time(time : Time)
      time.to_s("%Y%m%d-%H:%M:%S.%L")
    end

    # Encodes a FIX message in `k=v\x01` format
    # ```
    # encode({35 => "A", 6 => "asd", 7 => "tr", 20 => [{26 => "oo", 29 => "gj"}, {26 => "53o", 29 => "g5j"}]})
    # ```
    # will yield
    # ```text
    # "35=A|6=asd|7=tr|20=2|26=oo|29=gj|26=53o|29=g5j|"
    # ```
    def encode(data)
      data.map do |key, value|
        if value.is_a?(Array(Hash(Int32, String)))
          groups = value.map do |group|
            group.map do |k, v|
              "#{k}=#{v}\x01"
            end.join
          end.join
          "#{key}=#{value.size}\x01#{groups}"
        else
          "#{key}=#{value}\x01"
        end
      end.join
    end

    # Decodes a FIX message encoded in `k=v\x01` format to a Message object
    # ```
    # decode("35=A|6=asd|7=tr|20=2")
    # ```
    # will yield
    # ```text
    # Message(msg_type="A", data={6=>"asd", 7=>"tr", 20=>"2"})
    # ```
    # TODO: Add repeating groups decoding
    def decode(data : String) : Message
      decoded = {} of Int32 => String | Array(Hash(Int32, String))
      begin
        data.split("\x01")[0...-1].each do |field|
          k, v = field.split("=")
          decoded[k.to_i] = v
        end
      rescue ex
        raise DecodeException.new DecodeFailureReason::INVALID_FORMAT, data
      end

      # validate message
      # contains required fields
      raise DecodeException.new DecodeFailureReason::REQUIRED_FIELD_MISSING, data unless ([TAGS[:CheckSum],
                                                                                           TAGS[:BeginString],
                                                                                           TAGS[:BodyLength],
                                                                                           TAGS[:SenderCompID],
                                                                                           TAGS[:TargetCompID],
                                                                                           TAGS[:MsgSeqNum],
                                                                                           TAGS[:SendingTime],
                                                                                           TAGS[:MsgType]] - decoded.keys).empty?

      # correct checksum
      checksum = Utils.calculate_checksum(data[0...data.rindex("#{TAGS[:CheckSum]}=").not_nil!])
      raise DecodeException.new DecodeFailureReason::INVALID_CHECKSUM, data unless decoded[TAGS[:CheckSum]] == "%03d" % checksum

      # correct body length
      length = data.rindex("#{TAGS[:CheckSum]}=").not_nil! - data.index("#{TAGS[:MsgType]}=").not_nil!
      raise DecodeException.new DecodeFailureReason::INVALID_BODYLENGTH, data unless decoded[TAGS[:BodyLength]] == length.to_s

      # create message
      msgtype = decoded.delete(TAGS[:MsgType]).as(String)
      return Message.new msgtype, decoded
    end
  end
end
