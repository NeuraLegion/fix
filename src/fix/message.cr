module FIX
  # Represents a FIX message
  class Message
    getter msg_type
    property data = {} of Int32 => String | Array(Hash(Int32, String))

    # Initialize a new FIX message with message type of `msg_type`
    def initialize(@msg_type : String)
    end

    # Initialize a new FIX message with message type of `msg_type` and fields/groups data of `data`
    def initialize(@msg_type : String, _data : RawMessage)
      _data.each do |key, value|
        data[key] = value
      end
    end

    # Set field `key` to `value`
    def set_field(key, value : Int32 | String)
      @data[key] = value.to_s
    end

    # Add a group to the repeating group `group_key`
    def add_to_group(group_key, values)
      if @data.has_key? group_key
        @data[group_key] << values
      else
        @data[group_key] = [values]
      end
    end

    # Set repeating group of `group_key` to `groups`
    def set_group(group_key, groups : Array)
      @data[group_key] = groups
    end

    # Delete repeating group `group_key`
    def delete_group(group_key)
      @data.delete group_key
    end

    # Delete field `key`
    def delete_field(key)
      @data.delete key
    end
  end
end
