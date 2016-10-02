defmodule MTProto.TL do
  alias MTProto.Math
  alias MTProto.TCP
  alias MTProto.TL.Build
  alias MTProto.Utils

  @mtproto_schema "priv/mtproto.json"

  def req_pq do
    nonce = Math.generate_nonce(16)
    Build.payload("req_pq", %{nonce: nonce})
  end

  def req_DH_params(%{nonce: nonce, pq: pq, server_nonce: server_nonce,
    server_public_key_fingerprints: key_fingerprint}) do
    <<intPQ::integer-size(8)-unit(8)>> = pq
    p = Math.decompose_pq intPQ
    q = intPQ / p |> round
    int_key = 14101943622620965665
    {encrypted_data, new_nonce} = p_q_inner_data(intPQ, p , q, nonce, server_nonce)

    payload = Build.payload("req_DH_params", %{nonce: nonce,
                                    server_nonce: server_nonce,
                                    p: p,
                                    q: q,
                                    public_key_fingerprint: int_key,
                                    encrypted_data: encrypted_data})
    {payload, new_nonce}
  end

  def p_q_inner_data(pq, p, q,  nonce, server_nonce) do
    new_nonce = Math.generate_nonce 32
    serialized = Build.encode("p_q_inner_data", %{ pq: pq,
                                                   p: p,
                                                   q: q,
                                                   nonce: nonce,
                                                   server_nonce: server_nonce,
                                                   new_nonce: new_nonce,
                                                  }, :constructors)

    data_with_hash = :crypto.hash(:sha, serialized) <> serialized

    padding = 255 - byte_size(data_with_hash)
    hash256 = data_with_hash <> <<0::size(padding)-unit(8)>>
    #crypted = :crypto.public_encrypt :rsa, hash256 , Utils.get_key, :rsa_no_padding
    [e, n] = Utils.get_key
    crypted = :crypto.mod_pow hash256, e, n
    {:binary.decode_unsigned(crypted), new_nonce}
  end

  def server_DH_params_ok(encrypted_answer, server_nonce, new_nonce) do
    server_nonce = server_nonce |> :binary.encode_unsigned
    new_nonce = new_nonce |> :binary.encode_unsigned

    tmp_aes_key = :crypto.hash(:sha, new_nonce <> server_nonce) <> (:crypto.hash(:sha, server_nonce <> new_nonce) |> :binary.part(0, 12))

    tmp_aes_iv = (:crypto.hash(:sha, server_nonce <> new_nonce) |> :binary.part(12,8)) <> :crypto.hash(:sha, new_nonce <> new_nonce)
                                                                                       <> :binary.part(new_nonce, 0, 4)

    answer_with_hash = :crypto.block_decrypt :aes_ige256, tmp_aes_key, tmp_aes_iv, encrypted_answer
    sha_length = 20

    answer = :binary.part answer_with_hash, sha_length, byte_size(answer_with_hash) - sha_length
    map = %{ constructor: -1249309254,
             values: :binary.part(answer, 4,byte_size(answer) -4)
           }
    map |> MTProto.TL.Parse.decode(false)
  end

  def schema(sub \\ :constructors) do
    {:ok, json} = File.read @mtproto_schema
    {:ok, schema} = JSON.decode json
    schema[Atom.to_string sub]
  end

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
end
