defmodule MTProto.Auth do
  require Logger
  alias MTProto.{Method,Crypto,Session}
  alias MTProto.Session.Handler
  alias TL.Binary

  # Process inputs and answers during the generation of the authentification key.
  # Those functions are directly called by `MTProto.Session.Brain`.
  @moduledoc false

  def generate(session_id) do
    Session.send session_id, Method.req_pq, :plain
  end

  def req_pq(session_id) do
    req_pq = Method.req_pq
    Handler.send_plain req_pq, session_id
  end

  def resPQ(msg, session_id) do
    %{nonce: nonce,
     server_nonce: server_nonce,
     pq: pq,
     server_public_key_fingerprints: key_fingerprint } = msg

    new_nonce = Crypto.rand_bytes(32)

    req_DH_params = Method.req_DH_params(
      nonce,
      server_nonce,
      new_nonce,
      pq,
      Enum.at(key_fingerprint,0))

    Session.update(session_id, %{new_nonce: new_nonce, server_nonce: server_nonce})

    #handler = Registry.get :session, session_id, :handler
    #MTProto.send handler, req_DH_params, :plain
    Handler.send_plain req_DH_params, session_id
  end

  def server_DH_params_ok(msg, session_id) do
    %{encrypted_answer: encrypted_answer,
     server_nonce: server_nonce} = msg
     session = Session.get(session_id)

     # Build keys for decrypting/encrypting AES256 IGE
     {tmp_aes_key, tmp_aes_iv} = Crypto.build_tmp_aes(server_nonce, session.new_nonce)

     ## Decrypt & parse server_DH_params_ok
     {server_DH_params_ok, _} = Method.server_DH_inner_data encrypted_answer, tmp_aes_key, tmp_aes_iv

     %{dh_prime: dh_prime,
      g: g, # g is always equal to 2, 3, 4, 5, 6 or 7
      g_a: g_a,
      nonce: nonce,
      server_nonce: server_nonce,
      server_time: _} = server_DH_params_ok

      # g is always equal to 2, 3, 4, 5, 6 or 7. If not, there was something wrong
      # decrypting the last incoming message.
      unless Enum.member?([2,3,4,5,6,7], g), do: raise("server_DH_params_ok : g (#{g}) is none of : 2,3,4,5,6,7")

      b = Crypto.rand_bytes(32) # random number
      set_client_DH_params = Method.set_client_DH_params(nonce, server_nonce, g, b, dh_prime, tmp_aes_key, tmp_aes_iv)

      Session.set(session_id, struct(session, %{g_a: g_a, b: b, dh_prime: dh_prime}))

      #handler = Registry.get :session, session_id, :handler
      #MTProto.send handler, set_client_DH_params, :plain
      Handler.send_plain set_client_DH_params, session_id
  end

  # Check + Abort ?
  def server_DH_params_fail(msg, session_id) do
    session = Session.get(session_id)
    auth_key = build_auth_key(session_id)

    %{new_nonce_hash: new_nonce_hash} = msg
    check_dh_hash(auth_key, session.new_nonce, new_nonce_hash, 0)

    Logger.error "server_DH_params_fail : abort authorization key generation."
  end

  def dh_gen_ok(msg, session_id) do
    session = Session.get(session_id)
    auth_key = build_auth_key(session)

    %{new_nonce_hash1: new_nonce_hash1} = msg
    check_dh_hash(auth_key, session.new_nonce, new_nonce_hash1, 1)

    # substr(new_nonce, 0, 8) XOR substr(server_nonce, 0, 8)
    salt_left = session.new_nonce |> Binary.encode_signed |> :binary.part(0, 8) |> Binary.decode_signed
    salt_right = session.server_nonce |> Binary.encode_signed |> :binary.part(0, 8) |> Binary.decode_signed
    # The server salt is represented as 'long' in MTProto's Schema, hence must be stored as a 'long' in
    # order to avoid endianess mismatch
    server_salt = :erlang.bxor(salt_left, salt_right) |> TL.serialize(:long)
                                                      |> Binary.reverse_endianness # workaround

    result = %{auth_key: auth_key, server_salt: server_salt}

    # Clean session's registry from temporary values
    temp = %{server_nonce: nil, new_nonce: nil, g_a: nil, dh_prine: nil}
    Session.update(session_id, Map.merge(temp, result))

    Logger.debug "The authorization key was successfully generated."
    # Send notification to the client ?
  end

  # Check + Retry ?
  def dh_gen_retry(msg, session_id) do
    session = Session.get(session_id)
    auth_key = build_auth_key(session)

    %{new_nonce_hash2: new_nonce_hash2} = msg
    check_dh_hash(auth_key, session.new_nonce, new_nonce_hash2, 2)

    Logger.debug "dh_gen_retry : retry authorization key generation"

    # Retry
    Handler.send_plain Method.req_pq, session_id
  end

  # Check + Abort ?
  def dh_gen_fail(msg, session_id) do
    session = Session.get(session_id)
    auth_key = build_auth_key(session)

    %{new_nonce_hash3: new_nonce_hash3} = msg
    check_dh_hash(auth_key, session.new_nonce, new_nonce_hash3, 3)

    Logger.error "dh_gen_fail : abort authorization key generation."
  end

  # Build an authorization key
  defp build_auth_key(session) do
    # compute authorization key
    :crypto.mod_pow session.g_a, session.b, session.dh_prime
  end

  # @TODO
  defp check_dh_hash(_, _, _, _), do: :nothing

  # Check that the given new_nonce_hash is coherent. Broken.
  # https://core.telegram.org/mtproto/auth_key#dh-key-exchange-complete
  #  defp check_dh_hash(auth_key, new_nonce, new_nonce_hash, i) do
  #    # auth_key_aux_hash is the 64 higher-order bits of SHA1(auth_key).
  #    # It must not be confused with auth_key_hasha.
  #    auth_key_aux_hash = :crypto.hash(:sha, auth_key) |> :binary.part(0, 8)
  #
  #    bytes = Integer.to_string(new_nonce) <> <<i>> <> auth_key_aux_hash
  #    sha = :crypto.hash(:sha, bytes)
  #    size = byte_size(sha)
  #    current_new_nonce_hash = :binary.part(sha, size - 16, 16)
  #
  #    unless new_nonce_hash == current_new_nonce_hash do
  #      raise "new_nonce_hash mismatch !"
  #    end
  #  end
end
