module FIX
  alias RawMessage = Hash(Int32 | String, String) | Hash(Int32 | String, Array(Hash(Int32, String))) | Hash(Int32 | String, String | Array(Hash(Int32 | String, String)))
end
