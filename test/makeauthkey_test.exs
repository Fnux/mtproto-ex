defmodule MakeAuthKeyTest do
  use ExUnit.Case
  alias MTProto.TL
  alias MTProto.TL.Parse

  doctest MTProto

  @data "test/makeauthkey_test.json"

  setup_all do
    {:ok, json} = File.read @data
    {:ok, data} = JSON.decode json
    data
  end

  test "resPQ", data do
    #Payload
    resPQ = data["resPQ"] |> hexStr2Bytes

    # Expected Values
    expected_nonce = data["nonce"] |> hexStr2Int
    expected_pq  = data["pq"] |> hexStr2Bytes
    expected_server_nonce = data["server_nonce"] |> hexStr2Int
    expected_pkey_fingerprint = data["server_public_key_fingerprint"] |> hexStr2Int

    # Decode
    %{
      nonce: nonce,
      pq: pq,
      server_public_key_fingerprints: pkey_fingerprint,
      server_nonce: server_nonce
    } =  Parse.payload resPQ

    # Assert
    assert nonce == expected_nonce
    assert pq == expected_pq
    assert server_nonce == expected_server_nonce
    assert pkey_fingerprint == expected_pkey_fingerprint
  end

  test "p_q_inner_data", data do
    # Expected
    # expected_encrypted_data = data["p_q_inner_data"] |> hexStr2Bytes
    expected_hash = data["p_q_inner_data_sha1"] |> hexStr2Bytes

    # Required values
    nonce = data["nonce"] |> hexStr2Int
    server_nonce = data["server_nonce"] |> hexStr2Int
    new_nonce = data["new_nonce"] |> hexStr2Int
    pq = data["pq"] |> hexStr2Bytes
    p = data["p"] |> hexStr2Bytes
    q = data["q"] |> hexStr2Bytes

    # Compute
    {hash, data_with_hash} = TL.p_q_inner_data nonce, server_nonce, new_nonce, pq, p, q

    # Assert
    assert hash == expected_hash
  end

  test "server_DH_params", data do
    # Get example data
    expected_nonce = data["nonce"] |> hexStr2Int
    expected_dh_prime = data["dh_prime"] |> hexStr2Bytes
    expected_g = data["g"] |> hexStr2Int
    expected_g_a = data["g_a"] |> hexStr2Bytes
    server_nonce = data["server_nonce"] |> hexStr2Int
    new_nonce =  data["new_nonce"] |> hexStr2Int
    server_DH_params = data["server_DH_params_ok"] |> hexStr2Bytes

    # Extract encrypted_data
    %{predicate: req_DH,
      encrypted_answer: encrypted_answer,
      server_nonce: server_nonce} = server_DH_params |> TL.Parse.payload

    # Decypt
    {tmp_aes_key, tmp_aes_iv} = MTProto.Crypto.build_tmp_aes(server_nonce, new_nonce)
    server_DH_inner_data =  TL.server_DH_inner_data encrypted_answer, tmp_aes_key, tmp_aes_iv

    %{dh_prime: dh_prime,
      g: g, # g is always equal to 2, 3, 4, 5, 6 or 7
      g_a: g_a,
      nonce: decrypted_nonce,
      server_nonce: decrypted_server_nonce,
      server_time: server_time,
    } =  server_DH_inner_data

    # Assert
    assert decrypted_nonce == expected_nonce
    assert dh_prime == expected_dh_prime
    assert g == expected_g
    assert g_a == expected_g_a
  end

  test "set_client_DH_params", data do
    # Get Data
    nonce = data["nonce"] |> hexStr2Int
    server_nonce = data["server_nonce"] |> hexStr2Int
    new_nonce = data["new_nonce"] |> hexStr2Int
    g = data["g"] |> hexStr2Int
    dh_prime = data["dh_prime"] |> hexStr2Bytes

    # Compute
    {tmp_aes_key, tmp_aes_iv} = MTProto.Crypto.build_tmp_aes(server_nonce, new_nonce)
    set_client_DH_params = TL.set_client_DH_params(nonce, server_nonce, g, dh_prime, tmp_aes_key, tmp_aes_iv)
    parsed = set_client_DH_params |> Parse.decode(:wrapped, :methods)
    %{
      encrypted_data: encrypted_data,
      nonce: parsed_nonce,
      predicate: predicate,
      server_nonce: parsed_server_nonce
    } = parsed

    decrypted = :crypto.block_decrypt :aes_ige256, tmp_aes_key, tmp_aes_iv, encrypted_data
    decrypted_values = :binary.part(decrypted, 20 + 4, byte_size(decrypted) - 20 - 4)
    decrypted_parsed = %{
       constructor: 0x6643b654,
       values: decrypted_values
    } |> Parse.decode(:non_wrapped)

     %{
       g_b: decrypted_parsed_g_b,
       nonce: decrypted_parsed_nonce,
       retry_id: decrypted_parsed_retry_id,
       server_nonce: decrypted_parsed_server_nonce
     } = decrypted_parsed

    # Assert
    assert parsed_nonce == nonce
    assert decrypted_parsed_nonce == nonce
    assert parsed_server_nonce == server_nonce
    assert decrypted_parsed_server_nonce == server_nonce
  end

  ###########
  # Helpers #
  ###########

  def hexStr2Bytes(hexStr) do
    Base.decode16!(hexStr, case: :mixed)
  end

  def hexStr2Int(hexStr) do
    hexStr |> hexStr2Bytes |> Parse.decode_signed
  end
end
