defmodule MTProto.Crypto do
  alias MTProto.TL.Build
  alias MTProto.TL.Parse

  @key "priv/public.key"
  @moduledoc false
  # Provide crypto utils related to MTProto.

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
    server_nonce = server_nonce |> Build.encode_signed
    new_nonce = new_nonce |> Build.encode_signed

    # tmp_aes_key := SHA1(new_nonce + server_nonce) 
    # + substr (SHA1(server_nonce + new_nonce), 0, 12);
    tmp_aes_key = :crypto.hash(:sha, new_nonce <> server_nonce)
                  <> :binary.part :crypto.hash(:sha, server_nonce <> new_nonce), 0, 12

    # tmp_aes_iv := substr (SHA1(server_nonce + new_nonce), 12, 8)
    # + SHA1(new_nonce + new_nonce) + substr (new_nonce, 0, 4);
    tmp_aes_iv = :binary.part(:crypto.hash(:sha, server_nonce <> new_nonce), 12, 8)
                 <> :crypto.hash(:sha, new_nonce <> new_nonce)
                 <> :binary.part(new_nonce, 0, 4)

    {tmp_aes_key, tmp_aes_iv}
  end

  # Generate rand number
  def rand_bytes(n) do
    :crypto.strong_rand_bytes(n) |> Parse.decode_signed
  end

  # Compute GCD
  def gcd(a,0), do: abs(a)
  def gcd(a,b), do: gcd(b, rem(a,b))

  # Decompose PQ (Pollard's rho algorithm)
  def decompose_pq(n) do
    x = :rand.uniform(n-1)
    y = x
    c = :rand.uniform(n-1)
    g = 1

    decompose_pq(x,y,g,c,n)
  end

  defp decompose_pq(x,y,g,c,n) when g == 1 do
    f = fn(e) -> (rem(e*e,n) + c) |> rem(n) end

    x = f.(x)
    y = f.(f.(y))
    g = abs(x-y) |> gcd(n)

    decompose_pq(x,y,g,c,n)
  end

  defp decompose_pq(_,_,g,_,_), do: g

  # See https://core.telegram.org/mtproto/description#defining-aes-key-and-initialization-vector
  def build_message_aes(auth_key, msg_key, x) do
    # sha1_a
    sha1_a = :crypto.hash(:sha, msg_key <> :binary.part(auth_key, x, 32))
    # sha1_b
    sha1_b = :crypto.hash(:sha, :binary.part(auth_key, 32 + x, 16) <> msg_key
                                                                   <> :binary.part(auth_key, 48 + x, 16))
    # sha1_c
    sha1_c = :crypto.hash(:sha, :binary.part(auth_key, 64 + x, 32) <> msg_key)
    # sha1_d
    sha1_d = :crypto.hash(:sha, msg_key <> :binary.part(auth_key, 96 + x, 32))
    # aes_key
    aes_key = :binary.part(sha1_a, 0, 8) <> :binary.part(sha1_b, 8, 12)
                                         <> :binary.part(sha1_c, 4, 12)
    # aes_iv
    aes_iv = :binary.part(sha1_a, 8, 12) <> :binary.part(sha1_b, 0, 8)
                                         <> :binary.part(sha1_c, 16, 4)
                                         <> :binary.part(sha1_d, 0, 8)
    # return
    {aes_key, aes_iv}
  end

  # Encrypt a message
  def encrypt_message(auth_key, server_salt, session_id, payload) do
    #auth_key = auth_key |> Build.encode_signed

    msg = Build.encode_signed(server_salt) <> Build.encode_signed(session_id)
                                           <> payload
    msg_key = :crypto.hash(:sha, msg) |> :binary.part(4,16)

    # get encryption keys
    {aes_key, aes_iv} = build_message_aes(auth_key, msg_key, 0)

    # Padding
    x =  byte_size(msg) / 16
    y = x - Float.floor(x)
    padding =
      if y == 0.0 do
        0
      else
        (1-y) * 16 |> round
      end

    msg = <<msg::binary, :crypto.strong_rand_bytes(padding)::binary>>

    # Ecnrypt
    encrypted_data = :crypto.block_encrypt :aes_ige256, aes_key, aes_iv, msg
    auth_key_id = :crypto.hash(:sha, auth_key) |> :binary.part(12, 8)

    auth_key_id <> msg_key <> encrypted_data
  end

  # Decrypt a message
  def decrypt_message(payload, auth_key) do

    # Check if auth_key and auth_key_id match
    auth_key_id = :binary.part payload, 0, 8
    expected_auth_key_id = :crypto.hash(:sha, auth_key) |> :binary.part(12, 8)
    unless auth_key_id == expected_auth_key_id do
      raise "Wrong authorization key !"
    end

    # Get msg_key
    msg_key = :binary.part payload, 8, 16

    # get decryption keys
    {aes_key, aes_iv} = build_message_aes(auth_key, msg_key, 8)

    # Decrypt
    encrypted_data = :binary.part payload, 24, byte_size(payload) - 24
    data = :crypto.block_decrypt :aes_ige256, aes_key, aes_iv, encrypted_data
  end
end
