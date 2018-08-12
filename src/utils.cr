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
end
