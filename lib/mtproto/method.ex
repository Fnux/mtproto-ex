defmodule MTProto.Method do
  alias MTProto.{Payload, Crypto}

  # Mostly fonctions building payload for MTProto internal's working.
  @moduledoc false

  ###############
  # makeAuthKey #
  ###############

  # Build the payload for req_pq
  def req_pq(nonce \\ nil) do
    nonce = unless nonce, do: Crypto.rand_bytes(16), else: nonce
    Payload.build("req_pq", %{nonce: nonce})
  end

  # Build the payload for req_DH_params
  def req_DH_params(nonce, server_nonce, new_nonce, pq, key_fingerprint) do
    p = Crypto.decompose_pq pq
    q = pq / p |> round
    f = key_fingerprint

    # Build & encrypt p_q_inner_data
    {_,data_with_hash} = p_q_inner_data(nonce, server_nonce, new_nonce, pq, p , q)

    # encrypted_data := RSA (data_with_hash, server_public_key); a 255-byte long number (big endian)
    # is raised to the requisite power over the requisite modulus, and the result is stored as a
    # 256-byte number.
    {e, n} = Crypto.get_key # get RSA public key components, @TODO : check with given fingerprint
    #encrypted_data = :crypto.public_encrypt :rsa, data_with_hash, [e,n], :rsa_no_padding
    encrypted_data = :crypto.mod_pow data_with_hash, e, n

    # Build req_DH_params payload
    TL.build("req_DH_params", %{nonce: nonce,
                  server_nonce: server_nonce,
                  p: p,
                  q: q,
                  public_key_fingerprint: f,
                  encrypted_data: encrypted_data})
  end

  # Build & encrypt p_q_inner_data (will be included in req_DH_params' payload)
  defp p_q_inner_data(nonce, server_nonce, new_nonce, pq, p, q) do
    # Build and serialize
    data = TL.build("p_q_inner_data",
                        %{ pq: pq,
                           p: p,
                           q: q,
                           nonce: nonce,
                           server_nonce: server_nonce,
                           new_nonce: new_nonce,
                          })

    # data_with_hash := SHA1(data) + data + (any random bytes); such that the length equal 255 bytes;
    #IO.inspect data |> :binary.bin_to_list |> Enum.map fn(x) -> IO.write Integer.to_char_list(x, 16) end
    #IO.inspect byte_size data
    hash = :crypto.hash(:sha, data)
    data = <<hash::binary, data::binary>>
    padding = 255 - byte_size(data)
    data_with_hash = <<data::binary, :crypto.strong_rand_bytes(padding)::binary>>
    {hash, data_with_hash}
  end

  # Build set_client_DH_params payload
  def set_client_DH_params(nonce, server_nonce, g, b, dh_prime, tmp_aes_key, tmp_aes_iv) do
    # Build & encrypt client_DH_inner_data
    encrypted_data = client_DH_inner_data nonce, server_nonce, g, b, dh_prime, tmp_aes_key, tmp_aes_iv

    Payload.build("set_client_DH_params", %{nonce: nonce,
                  server_nonce: server_nonce, encrypted_data: encrypted_data})
  end

  # Build & encrypt client_DH_inner_data (will be included in set_client_DH_params' payload)
  defp client_DH_inner_data(nonce, server_nonce, g, b, dh_prime, tmp_aes_key, tmp_aes_iv) do
    g_b = :crypto.mod_pow g, b, dh_prime # g^b % dh_prime
    data = TL.build("client_DH_inner_data",
                        %{
                          nonce: nonce,
                          server_nonce: server_nonce,
                          retry_id: 0,
                          g_b: g_b
                         }
                       )

    # data_with_hash := SHA1(data) + data + (0-15 random bytes); such that length be divisible by 16;
    data = :crypto.hash(:sha, data) <> data
    ## Compute padding
    x =  byte_size(data) / 16
    y = x - Float.floor(x)
    padding =
      if y == 0.0 do
        0
      else
        (1-y) * 16 |> round
      end
    ## Build data_with_hash
    data_with_hash = data <> <<0::size(padding)-unit(8)>>

    # Encrypt with AES256 IGE
    :crypto.block_encrypt :aes_ige256, tmp_aes_key, tmp_aes_iv, data_with_hash
  end

  #
  def get_future_salts(num) do
    TL.build("get_future_salts", %{num: num})
  end

  ####################
  # Service Messages #
  ####################

  def ping do
    Payload.build("ping", %{ping_id: Crypto.rand_bytes(16)})
  end

  def msgs_ack(ids) do
    Payload.build("msgs_ack", %{msg_ids: ids})
  end
end
