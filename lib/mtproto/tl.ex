defmodule MTProto.TL do
  alias MTProto.Math
  alias MTProto.TCP
  alias MTProto.TL.Build
  alias MTProto.Utils

  @mtproto_schema "priv/mtproto.json"

#  def res_pq(v) do
#      << nonce :: little-size(4)-unit(32) >> = :binary.part v, 0, 16
#      << server_nonce :: little-size(4)-unit(32) >> = :binary.part v, 16, 16
#      << pq :: big-size(8)-unit(8) >> = :binary.part v, 32 + 1, 12 - 1 -3
#      << fingerprint :: little-size(8)-unit(8) >> = :binary.part v, 40, 8
#
#      {nonce, server_nonce, pq, fingerprint}
#  end
#
#  def p_q_inner_data(pq, p, q,  nonce, server_nonce) do
#    method = 0x83c95aec
#    pq = pq |> Encode.serialize(12)
#    new_nonce = Math.generate_nonce(32) |> Encode.serialize(8, 32)
#
#    data = method <> pq <> p <> q <> nonce <> server_nonce <> new_nonce
#    data_with_hash_ul = :crypto.hash(:sha, data) <> data
#    padding = 255 - byte_size(data_with_hash_ul)
#    data_with_hash = data_with_hash_ul <> << 0::size(padding)-unit(8)>>
#
#    key = Utils.get_key
#
#    encrypted_data = :crypto.public_encrypt :rsa, data_with_hash, key, :rsa_no_padding # must be of the form <<>>
#    encrypted_data
#  end
#
#  def req_dh_params(pq, nonce, server_nonce, fingerprint) do
#    method = 0xd712e4be
#    nonce = nonce |> Encode.serialize(4,32)
#    server_nonce = server_nonce |> Encode.serialize(4,32)
#    p = Math.decompose_pq(pq)
#    q = pq / p |> round |> Integer.to_string |> Encode.serialize_string
#    p = p |> Integer.to_string |> Encode.serialize_string
#    public_key_fingerprint = Utils.get_key |> Utils.get_fingerprint
#    encrypted_data = p_q_inner_data(pq, p, q, nonce, server_nonce)
#
#    data = nonce <> server_nonce <> p <> q <> public_key_fingerprint <> encrypted_data
#
#    Encode.build_unencrypted(method, data) |> TCP.wrap
#  end

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
    encrypted_data = p_q_inner_data(intPQ, p , q, nonce, server_nonce)

    Build.payload("req_DH_params", %{nonce: nonce,
                                    server_nonce: server_nonce,
                                    p: p,
                                    q: q,
                                    public_key_fingerprint: int_key,
                                    encrypted_data: encrypted_data})
  end

  def p_q_inner_data(pq, p, q,  nonce, server_nonce) do
    new_nonce = Math.generate_nonce 32
    serialized = Build.encode("p_q_inner_data", %{ pq: pq,#0x17ED48941A08F981,
                                                   p: p,#0x494C553B,
                                                   q: q,#0x53911073,
                                                   nonce: nonce,#0x3E0549828CCA27E966B301A48FECE2FC,
                                                   server_nonce: server_nonce,#0xA5CF4D33F4A11EA877BA4AA573907330,
                                                   new_nonce: new_nonce,#0x311C85DB234AA2640AFC4A76A735CF5B1F0FD68BD17FA181E1229AD867CC024D
                                                  }, :constructors)

    data_with_hash = :crypto.hash(:sha, serialized) <> serialized
    #IO.inspect :crypto.hash(:sha, serialized)
    padding = 255 - byte_size(data_with_hash)
    hash256 = data_with_hash <> <<0::size(padding)-unit(8)>>
    #crypted = :crypto.public_encrypt :rsa, hash256 , Utils.get_key, :rsa_no_padding
    [e, n] = Utils.get_key
    crypted = :crypto.mod_pow hash256, e, n
    :binary.decode_unsigned crypted
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
