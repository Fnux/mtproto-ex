defmodule MTProto.Utils do
  @key "priv/public.key"

  def get_key do
    {_, key} = File.read @key
    [raw] = :public_key.pem_decode key
    {_,n,e} = :public_key.pem_entry_decode raw
    [e,n]
  end
end
