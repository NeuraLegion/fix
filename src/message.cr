require "./protocol"

class FIXMessage
  getter msgType
  property data

  def initialize(@msgType : String, @data = {} of Int32 => String | Array(Hash(Int32, String)))
  end

  def setField(key, value)
    @data[key] = value.to_s
  end

  def addToGroup(groupKey, values)
    if @data.has_key? groupKey
      @data[groupKey] << values
    else
      @data[groupKey] = [values]
    end
  end

  def setGroup(groupKey, groups : Array)
    @data[groupKey] = groups
  end

  def deleteGroup(groupKey)
    @data.delete groupKey
  end

  def deleteField(key)
    @data.delete key
  end

  def to_s
    FIXProtocol.encode(@data)
  end
end
