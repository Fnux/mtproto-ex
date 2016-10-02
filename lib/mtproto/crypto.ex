defmodule MTProto.Crypto do
  @key "priv/public.key"

  # Get the components of the server's public key
  def get_key do
    {_, key} = File.read @key
    [raw] = :public_key.pem_decode key
    {_,n,e} = :public_key.pem_entry_decode raw
    {e ,n}
  end

  # Build kyes for decrypting/encrypting AES256 IGE (makeAuthKey)
  def build_tmp_aes(server_nonce, new_nonce) do
    # From int to bits
    server_nonce = server_nonce |> :binary.encode_unsigned
    new_nonce = new_nonce |> :binary.encode_unsigned

    # tmp_aes_key := SHA1(new_nonce + server_nonce) 
    # + substr (SHA1(server_nonce + new_nonce), 0, 12);
    tmp_aes_key = :crypto.hash(:sha, new_nonce <> server_nonce)
                  <> (:crypto.hash(:sha, server_nonce <> new_nonce)
                  |> :binary.part(0, 12))

    # tmp_aes_iv := substr (SHA1(server_nonce + new_nonce), 12, 8)
    # + SHA1(new_nonce + new_nonce) + substr (new_nonce, 0, 4);
    tmp_aes_iv = (:crypto.hash(:sha, server_nonce <> new_nonce) |> :binary.part(12,8))
                 <> :crypto.hash(:sha, new_nonce <> new_nonce)
                 <> :binary.part(new_nonce, 0, 4)

    {tmp_aes_key, tmp_aes_iv}
  end
end
