defmodule MTProto.TL do
  alias MTProto.{Payload, Crypto}
  alias MTProto.TL.{Build, Parse}

  @moduledoc """
    Implement some TL items.
  """

  ###############
  # makeAuthKey #
  ###############

  # Build the payload for req_pq
  def req_pq do
    nonce = Crypto.rand_bytes(16)
    Payload.build("req_pq", %{nonce: nonce}, :plain)
  end

  # Build the payload for req_DH_params
  def req_DH_params(nonce, server_nonce, new_nonce, pq, key_fingerprint) do
    <<pq::integer-size(8)-unit(8)>> = pq # from bits to integer
    p = Crypto.decompose_pq pq
    q = pq / p |> round
    f = key_fingerprint

    # Build & encryp p_q_inner_data
    {_,data_with_hash} = p_q_inner_data(nonce, server_nonce, new_nonce, pq, p , q)

    # encrypted_data := RSA (data_with_hash, server_public_key); a 255-byte long number (big endian)
    # is raised to the requisite power over the requisite modulus, and the result is stored as a
    # 256-byte number.
    {e, n} = Crypto.get_key # get RSA public key components, @TODO : check with given fingerprint
    #encrypted_data = :crypto.public_encrypt :rsa, data_with_hash, [e,n], :rsa_no_padding
    encrypted_data = :crypto.mod_pow data_with_hash, e, n


    # Build req_DH_params payload
    Payload.build("req_DH_params", %{nonce: nonce,
                  server_nonce: server_nonce,
                  p: p,
                  q: q,
                  public_key_fingerprint: f,
                  encrypted_data: encrypted_data},
    :plain)
  end

  # Build & encrypt p_q_inner_data (will be included in req_DH_params' payload)
  def p_q_inner_data(nonce, server_nonce, new_nonce, pq, p, q) do
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

  # Decrypt and parse the server_DH_params_ok payload
  def server_DH_inner_data(encrypted_answer, tmp_aes_key, tmp_aes_iv) do
    # answer_with_hash := SHA1(answer) + answer + (0-15 random bytes); 
    # such that the length be divisible by 16;
    # Encrypted with AES_256_IGE;
    answer_with_hash = :crypto.block_decrypt :aes_ige256, tmp_aes_key, tmp_aes_iv, encrypted_answer

    # Extract answer
    sha_length = 20
    answer = :binary.part answer_with_hash, sha_length, byte_size(answer_with_hash) - sha_length

    # Extract constructor & values from answer
    #constructor = :binary.part(answer, 0, 4) |> Parse.deserialize(:int) # server_DH_params_ok#d0e8075c
    container = -1249309254 #! hotfix, override ^
    values = :binary.part(answer, 4, byte_size(answer) - 4) # remove constructor ^

    # Parse & deserialize
    TL.parse(container, values)
  end

  # Build set_client_DH_params payload
  def set_client_DH_params(nonce, server_nonce, g, b, dh_prime, tmp_aes_key, tmp_aes_iv) do
    # Build & encrypt client_DH_inner_data
    encrypted_data = client_DH_inner_data nonce, server_nonce, g, b, dh_prime, tmp_aes_key, tmp_aes_iv

    Payload.build("set_client_DH_params", %{nonce: nonce,
                  server_nonce: server_nonce, encrypted_data: encrypted_data}, :plain)
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

  ####################
  # Service Messages #
  ####################

  @doc """
    Build the payload of a ping message.
  """
  def ping do
    Payload.build("ping", %{ping_id: Crypto.rand_bytes(16)}, :encrypted)
  end
end
