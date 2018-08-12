enum SessionRejectReason
  INVALID_TAG_NUMBER               =  0,
  REQUIRED_TAG_MISSING             =  1,
  TAG_NOT_DEFINED_FOR_MESSAGE_TYPE =  2,
  UNDEFINED_TAG                    =  3,
  TAG_WITHOUT_VALUE                =  4,
  VALUE_INCORRECT                  =  5,
  INCORRECT_DATA_FORMAT            =  6,
  DECRYPTION_PROBLEM               =  7,
  SIGNATURE_PROBLEM                =  8,
  COMPID_PROBLEM                   =  9,
  SENDING_TIME_INACCURATE          = 10,
  INVALID_MSGTYPE                  = 11,
  UNDEFINED
end

enum DecodeFailureReason
  INVALID_CHECKSUM,
  INVALID_BODYLENGTH,
  REQUIRED_FIELD_MISSING,
  INVALID_FORMAT
end

class FIXException < Exception
end

class DoNotSend < Exception
end

class SessionRejectException < FIXException
  getter code : SessionRejectReason

  def initialize(@code = SessionRejectReason::UNDEFINED, msg : String = "Message rejected.")
    super msg
  end
end

class InvalidSeqNum < FIXException # too small
  def initialize(msg = "Incoming sequence number too small")
  end
end

class DecodeException < FIXException
  getter code : DecodeFailureReason

  def initialize(@code = DecodeFailureReason::INVALID_FORMAT, msg : String = "Decoding failed.")
    super msg
  end

  def to_s(io)
    io << "Code: " << @code << " Msg: " << @message
  end
end
