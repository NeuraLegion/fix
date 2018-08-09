class FIXMessage
  getter msgType
  property data = {} of Int32 => String | Array(Hash(Int32, String))

  def initialize(@msgType : String)
  end

  def setField(key, value)
    @data[key] = value
  end

  def addToGroup(groupKey, values)
    if @data.has_key? groupKey
      @data[groupKey] << values
    else
      @data[groupKey] = [values]
    end
  end

  def deleteField(key : Tags)
    @data.delete(key)
  end

  def to_s
    return Utils.encode(@data)
  end
end
