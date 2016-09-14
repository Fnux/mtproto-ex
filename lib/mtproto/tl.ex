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
    Build.encode("req_pq", %{nonce: nonce})
  end

  def schema(sub \\ :constructors) do
    {:ok, json} = File.read @mtproto_schema
    {:ok, schema} = JSON.decode json
    schema[Atom.to_string sub]
  end

end
