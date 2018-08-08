module Utils
  def self.calculate_checksum(data : String)
    checksum = 0
    data.each_byte do |c|
      checksum += c
    end
    checksum %= 256
    return checksum
  end

  def self.encode(data)
    puts "zs"
    return data.map do |key, value|
      item = "#{key.value}=#{value}\x01"
    end.join
  end
end
