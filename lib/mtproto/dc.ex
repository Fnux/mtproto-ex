defmodule MTProto.DC do
  defstruct id: nil,
            address: nil,
            port: 443,
            auth_key: <<0::8*8>>,
            server_salt: 0
end
