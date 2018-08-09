module Utils
  def self.calculate_checksum(data : String)
    checksum = 0
    data.each_byte do |c|
      checksum += c
    end
    checksum % 256
  end

  def self.encode_time(time : Time)
    time.to_s("%Y%m%d-%H:%M:%S.%L")
  end
end
