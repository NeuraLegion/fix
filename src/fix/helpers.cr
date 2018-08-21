module FIX
  alias RawMessage = Hash(Int32, String) | Hash(Int32, Array(Hash(Int32, String))) | Hash(Int32, String | Array(Hash(Int32, String)))
end
