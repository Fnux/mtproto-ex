defmodule MTProto.AuthKey do
  require Logger
  alias TL.Binary
  alias MTProto.{TL, Crypto, Registry}
  alias MTProto.Session.Handler

  @moduledoc false
  # Process inputs and answers during the generation of the authentification key.

  def req_pq(session_id) do
    req_pq = TL.req_pq
    Handler.send_plain req_pq, session_id
  end

  def resPQ(msg, session_id) do
    %{nonce: nonce,
     server_nonce: server_nonce,
     pq: pq,
     server_public_key_fingerprints: key_fingerprint } = msg

    new_nonce = Crypto.rand_bytes(32)
    req_DH_params = TL.req_DH_params(
      nonce,
      server_nonce,
      new_nonce,
      pq,
      Enum.at(key_fingerprint,0))

    Registry.set :session, session_id, :new_nonce, new_nonce
    Registry.set :session, session_id, :server_nonce, server_nonce

    #handler = Registry.get :session, session_id, :handler
    #MTProto.send handler, req_DH_params, :plain
    Handler.send_plain req_DH_params, session_id
  end

  def server_DH_params_ok(msg, session_id) do
    %{encrypted_answer: encrypted_answer,
     server_nonce: server_nonce} = msg
     session = Registry.get :session, session_id

     # Build keys for decrypting/encrypting AES256 IGE
     {tmp_aes_key, tmp_aes_iv} = Crypto.build_tmp_aes(server_nonce, session.new_nonce)

     ## Decrypt & parse server_DH_params_ok
     {server_DH_params_ok, _} = TL.server_DH_inner_data encrypted_answer, tmp_aes_key, tmp_aes_iv

     %{dh_prime: dh_prime,
      g: g, # g is always equal to 2, 3, 4, 5, 6 or 7
      g_a: g_a,
      nonce: nonce,
      server_nonce: server_nonce,
      server_time: _} = server_DH_params_ok

      b = Crypto.rand_bytes(32) # random number
      set_client_DH_params = TL.set_client_DH_params(nonce, server_nonce, g, b, dh_prime, tmp_aes_key, tmp_aes_iv)

      Registry.set :session, session_id, :g_a, g_a
      Registry.set :session, session_id, :b, b
      Registry.set :session, session_id, :dh_prime, dh_prime

      #handler = Registry.get :session, session_id, :handler
      #MTProto.send handler, set_client_DH_params, :plain
      Handler.send_plain set_client_DH_params, session_id
  end

  # Check + Abort ?
  def server_DH_params_fail(msg, session_id) do
    session = Registry.get :session, session_id
    auth_key = build_auth_key(session_id)

    %{new_nonce_hash: new_nonce_hash} = msg
    check_dh_hash(auth_key, session.new_nonce, new_nonce_hash, 0)

    Logger.error "server_DH_params_fail : abort authorization key generation."
  end

  def dh_gen_ok(msg, session_id) do
    session = Registry.get :session, session_id
    auth_key = build_auth_key(session)

    %{new_nonce_hash1: new_nonce_hash1} = msg
    check_dh_hash(auth_key, session.new_nonce, new_nonce_hash1, 1)

    # substr(new_nonce, 0, 8) XOR substr(server_nonce, 0, 8)
    salt_left = session.new_nonce |> Binary.encode_signed |> :binary.part(0, 8) |> Binary.decode_signed
    salt_right = session.server_nonce |> Binary.encode_signed |> :binary.part(0, 8) |> Binary.decode_signed
    server_salt = :erlang.bxor salt_left, salt_right

    Registry.set :dc, session.dc, :auth_key, auth_key
    Registry.set :dc, session.dc, :server_salt, server_salt

    Registry.drop :session, session_id, [:server_nonce, :new_nonce, :g_a, :b, :dh_prime]

    Logger.info "The authorization key was successfully generated."
  end

  # Check + Retry ?
  def dh_gen_retry(msg, session_id) do
    session = Registry.get :session, session_id
    auth_key = build_auth_key(session)

    %{new_nonce_hash2: new_nonce_hash2} = msg
    check_dh_hash(auth_key, session.new_nonce, new_nonce_hash2, 2)

    Logger.warn "dh_gen_retry : retry authorization key generation"

    # Retry
    Handler.send_plain MTProto.TL.req_pq, session_id
  end

  # Check + Abort ?
  def dh_gen_fail(msg, session_id) do
    session = Registry.get :session, session_id
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
