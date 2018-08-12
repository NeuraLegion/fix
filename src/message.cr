require "./protocol"

# Represents a FIX message
class FIXMessage
  getter msgType
  property data

  # Initialize a new FIX message with message type of `msgType` and fields/groups data of `data`
  def initialize(@msgType : String, @data = {} of Int32 => String | Array(Hash(Int32, String)))
  end

  # Set field `key` to `value`
  def set_field(key, value)
    @data[key] = value.to_s
  end

  # Add a group to the repeating group `groupKey`
  def add_to_group(groupKey, values)
    if @data.has_key? groupKey
      @data[groupKey] << values
    else
      @data[groupKey] = [values]
    end
  end

  # Set repeating group of `groupKey` to `groups`
  def set_group(groupKey, groups : Array)
    @data[groupKey] = groups
  end

  # Delete repeating group `groupKey`
  def delete_group(groupKey)
    @data.delete groupKey
  end

  # Delete field `key`
  def delete_field(key)
    @data.delete key
  end

  def to_s
    FIXProtocol.encode(@data)
  end
end
