defmodule MTProto.Utils do
#  @key "priv/public.key"
#
#  def get_key do
#    {_, key} = File.read @key
#    [{type, key, _}] = :public_key.pem_decode key
#    key
#  end
#
#  def get_fingerprint(key) do
#    :crypto.hash(:sha, key)
#  end
end
