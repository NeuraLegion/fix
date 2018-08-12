require "./message"

abstract class FIXApplication
  abstract def on_logon
  abstract def on_logout
  abstract def to_admin(msg : FIXMessage)
  abstract def to_app(msg : FIXMessage)
  abstract def from_admin(msg : FIXMessage)
  abstract def from_app(msg : FIXMessage)
  abstract def on_error(err : FIXError)
end
