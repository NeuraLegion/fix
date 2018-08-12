require "../src/app"
require "../src/session"
require "../src/message"
require "../src/exception"
require "../src/protocol"

class MyApp < FIXApplication
  def on_logon
    puts "CONNECTED"
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
