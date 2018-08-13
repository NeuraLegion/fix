require "../src/session"
require "../src/message"
require "../src/exception"
require "../src/protocol"

sess = FIXSession.new

sess.on_connect do
  puts "CONNECTED"
end

sess.on_logon do
  puts "LOGGED ON"
  spawn do
    cl0rdid = Random.rand(1000..2000)
    loop do
      msg = FIXMessage.new MessageTypes::NEWORDERSINGLE
      msg.set_field Tags::Price, "%0.2f" % Random.rand(10.0..13.0).to_s
      msg.set_field Tags::OrderQty, Random.rand(100).to_s
      msg.set_field Tags::Symbol, "VOD.L"
      msg.set_field Tags::SecurityID, "GB00BH4HKS39"
      msg.set_field Tags::SecurityIDSource, "4"
      msg.set_field Tags::Account, "TEST"
      msg.set_field Tags::HandlInst, "1"
      msg.set_field Tags::ExDestination, "XLON"
      msg.set_field Tags::Side, Random.rand(1..2).to_s
      msg.set_field Tags::ClOrdID, cl0rdid.to_s
      cl0rdid += 1
      msg.set_field Tags::Currency, "GBP"
      sess.send_msg msg
      sleep 8.seconds
    end
  end
end

sess.on_logout do
  puts "DISCONNECTED"
end

sess.to_admin do |msg|
  puts "ADMIN ---->: #{msg.data}"
end

sess.to_app do |msg|
  puts "APP ---->: #{msg.data}"
end

sess.from_admin do |msg|
  puts "ADMIN <----: #{msg.data}"
end

sess.from_app do |msg|
  puts "APP <----: #{msg.data}"
end

sess.on_error do |err|
  puts "ERROR: #{err}"
end
msg = FIXMessage.new MessageTypes::NEWORDERSINGLE
msg.set_field Tags::Price, "%0.2f" % Random.rand(10.0..13.0).to_s
msg.set_field Tags::OrderQty, Random.rand(100).to_s
msg.set_field Tags::Symbol, "VOD.L"
msg.set_field Tags::SecurityID, "GB00BH4HKS39"
msg.set_field Tags::SecurityIDSource, "4"
msg.set_field Tags::Account, "TEST"
msg.set_field Tags::HandlInst, "1"
msg.set_field Tags::ExDestination, "XLON"
msg.set_field Tags::Side, Random.rand(1..2).to_s
msg.set_field Tags::ClOrdID, 12.to_s
msg.set_field Tags::Currency, "GBP"
puts msg.data
