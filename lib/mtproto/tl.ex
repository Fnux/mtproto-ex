defmodule MTProto.TL do
  alias MTProto.Crypto
  alias MTProto.TL.Parse
  alias MTProto.TL.Build

  @mtproto_schema "priv/mtproto.json"

  # Parse the MTProto TL-schema and output a map.
  def schema(sub \\ :constructors) do
    {:ok, json} = File.read @mtproto_schema
    {:ok, schema} = JSON.decode json
    schema[Atom.to_string sub]
  end

  # Search in the MTProto TL-schema.
  def search(type, name) do
    schema = schema(type)
    field =
      case type do
        :methods -> "method"
        :constructors -> "predicate"
      end

    description = Enum.filter schema, fn
          x -> Map.get(x, field) == name
    end

    description
  end

  ###############
  # makeAuthKey #
  ###############

  # Build the payload for req_pq
  def req_pq do
    nonce = Crypto.generate_rand(16)
    Build.payload("req_pq", %{nonce: nonce})
  end

  # Build the payload for req_DH_params
  def req_DH_params(nonce, server_nonce, new_nonce, pq, key_fingerprint) do
    <<pq::integer-size(8)-unit(8)>> = pq # from bits to integer
    p = Crypto.decompose_pq pq
    q = pq / p |> round
    key_fingerprint = 14101943622620965665 #key_fingerprint |> Parse.decode_signed

    # Build & encryp p_q_inner_data
    encrypted_data = p_q_inner_data(nonce, server_nonce, new_nonce, pq, p , q)

    # Build req_DH_params payload
    payload = Build.payload("req_DH_params", %{nonce: nonce,
                                    server_nonce: server_nonce,
                                    p: p,
                                    q: q,
                                    public_key_fingerprint: key_fingerprint,
                                    encrypted_data: encrypted_data})
  end

  # Build & encrypt p_q_inner_data (will be included in req_DH_params' payload)
  def p_q_inner_data(nonce, server_nonce, new_nonce, pq, p, q) do
    # Build and serialize
    data = Build.encode("p_q_inner_data",
                        %{ pq: pq,
                           p: p,
                           q: q,
                           nonce: nonce,
                           server_nonce: server_nonce,
                           new_nonce: new_nonce,
                          },
                          :constructors
                        )
    # data_with_hash := SHA1(data) + data + (any random bytes); such that the length equal 255 bytes;
    data = :crypto.hash(:sha, data) <> data
    padding = 255 - byte_size(data)
    data_with_hash = data <> <<0::size(padding)-unit(8)>>

    # encrypted_data := RSA (data_with_hash, server_public_key); a 255-byte long number (big endian)
    # is raised to the requisite power over the requisite modulus, and the result is stored as a
    # 256-byte number.
    {e, n} = Crypto.get_key # get RSA public key components
    encrypted_data = :crypto.mod_pow data_with_hash, e, n # data_with_hash^e % n
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
    constructor = :binary.part(answer, 0, 4) |> Parse.deserialize(:meta4) # server_DH_params_ok#d0e8075c
    constructor = -1249309254 #! hostfix, override ^
    values = :binary.part(answer, 4, byte_size(answer) - 4) # remove constructor ^

    map = %{constructor: constructor, values: values}

    # Parse & deserialize
    map |> MTProto.TL.Parse.decode(:non_wrapped)
  end

  # Build set_client_DH_params payload
  def set_client_DH_params(nonce, server_nonce, g, dh_prime, tmp_aes_key, tmp_aes_iv) do
    # Build & encrypt client_DH_inner_data
    encrypted_data = client_DH_inner_data nonce, server_nonce, g, dh_prime, tmp_aes_key, tmp_aes_iv

    payload = Build.payload "set_client_DH_params", %{
        nonce: nonce,
        server_nonce: server_nonce,
        encrypted_data: encrypted_data
      }
  end

  # Build & encrypt client_DH_inner_data (will be included in set_client_DH_params' payload)
  defp client_DH_inner_data(nonce, server_nonce, g, dh_prime, tmp_aes_key, tmp_aes_iv) do
    b = Crypto.generate_rand 256 # random number
    g_b = :crypto.mod_pow g, b, dh_prime # g^b % dh_prime
    data = Build.encode("client_DH_inner_data",
                        %{
                          nonce: nonce,
                          server_nonce: server_nonce,
                          retry_id: 0,
                          g_b: g_b
                         },
                         :constructors
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
end