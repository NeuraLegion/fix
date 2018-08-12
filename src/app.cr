require "./message"
require "./exception"

abstract class FIXApplication
  # Called when connected to server
  abstract def on_connect

  # Called when succesful logon takes place
  abstract def on_logon(sess : FIXSession)

  # Called when session ends, either by logout or disconnection
  abstract def on_logout

  # Called when an administrative/session message is about to be sent, throw `DoNotSend` to not send
  abstract def to_admin(msg : FIXMessage)

  # Called when an application message is about to be sent, throw `DoNotSend` to not send
  abstract def to_app(msg : FIXMessage)

  # Called when an administrative/session message is received
  abstract def from_admin(msg : FIXMessage)

  # Called when an application message is received
  abstract def from_app(msg : FIXMessage)

  # Called when an error occurs ( Session or message decoding issues )
  abstract def on_error(err : FIXException)
end
