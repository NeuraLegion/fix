require "../src/app"
require "../src/session"
require "../src/message"
require "../src/exception"
require "../src/protocol"

class MyApp < FIXApplication
  def on_connect
    puts "CONNECTED"
  end

  def on_logon(sess)
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
        sleep 4.seconds
      end
    end
  end

  def on_logout
    puts "DISCONNECTED"
  end

  def to_admin(msg : FIXMessage)
    puts "ADMIN ->: #{msg.data}"
  end

  def to_app(msg : FIXMessage)
    puts "APP ->: #{msg.data}"
  end

  def from_admin(msg : FIXMessage)
    puts "ADMIN <-: #{msg.data}"
  end

  def from_app(msg : FIXMessage)
    puts "APP <-: #{msg.data}"
  end

  def on_error(err : FIXException)
    puts "ERROR: #{err}"
  end
end

myapp = MyApp.new
sess = FIXSession.new myapp
sess.connect "127.0.0.1", 9898
sess.loop
