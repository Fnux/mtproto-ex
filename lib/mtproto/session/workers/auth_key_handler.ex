defmodule MTProto.Session.Workers.AuthKeyHandler do
  alias MTProto.{Method, Crypto, Session}
  alias MTProto.Session.Workers.AuthKeyHandler, as: Auth
  alias TL.Binary
  require Logger
  use GenServer
  use Bitwise

  # @TODO checking that g_a and g_b are between 2^{2048-64} and
  # dh_prime - 2^{2048-64} as well.

  defstruct [:session_id, :nonce, :new_nonce, :server_nonce, :pq,
             :key_fingerprint, :dh_prime, :g, :g_a, :g_b, :tmp_aes_key,
             :tmp_aes_iv]

  def start_link(session_id, opts \\ []) do
     GenServer.start_link(__MODULE__, session_id, [opts])
  end

  def init(session_id) do
    # Register as temporary session auth_client
    Session.update(session_id, auth_client: self())

    # Start authorization key generation procedure
    #send self(), :send_req_pq

    state = %Auth{session_id: session_id}
    {:ok, state}
  end

  def handle_info(:send_req_pq, state) do
    nonce = Crypto.rand_bytes(16)
    req_pq = Method.req_pq(nonce)
    Session.send state.session_id, req_pq, :plain

    state = struct(state, nonce: nonce)
    {:noreply, state}
  end

  def handle_info({:recv_resPQ, msg}, state) do
    [fingerprint] = msg.server_public_key_fingerprints
    <<pq::integer-size(8)-unit(8)>> = msg.pq

    # Validations
    pq_valid? = (pq <= (:math.pow(2, 63 - 1)))
    nonce_valid? = (msg.nonce == state.nonce)
    fingerprint_valid? =
      (Binary.encode_signed(fingerprint) == Crypto.get_key_fingerprint)

    if pq_valid? && nonce_valid? && fingerprint_valid? do
      send self(), :send_req_DH_params

      state = struct(state, %{
        pq: pq, server_nonce: msg.server_nonce, key_fingerprint: fingerprint
      })
      {:noreply, state}
    else
      Logger.warn "AuthKey: resPQ validation failed! Retying..."
      send self(), :send_req_pq

      state = purge(state)
      {:noreply, state}
    end
  end

  def handle_info(:send_req_DH_params, state) do
    new_nonce = Crypto.rand_bytes(32)

    req_DH_params = Method.req_DH_params(
      state.nonce,
      state.server_nonce,
      new_nonce,
      state.pq,
      state.key_fingerprint
    )
    Session.send state.session_id, req_DH_params, :plain

    state = struct(state, new_nonce: new_nonce)
    {:noreply, state}
  end

  def handle_info({:recv_server_DH_params_fail, _msg}, state) do
    #new_nonce_hash = msg.new_nonce_hash

    Logger.warn "AuthKey: req_DH_params failed! Retying..."
    send self(), :send_req_DH_params

    state = purge(state)
    {:noreply, state}
  end

  def handle_info({:recv_server_DH_params_ok, msg}, state) do
    server_nonce = msg.server_nonce
    encrypted_inner_data = msg.encrypted_answer

    # Build keys for decrypting/encrypting AES256 IGE
    {tmp_aes_key, tmp_aes_iv} = Crypto.build_tmp_aes(
      server_nonce, state.new_nonce
    )

    ## Decrypt & parse server_DH_params_ok
    {server_DH_params_ok, _} = server_DH_inner_data(
      encrypted_inner_data, tmp_aes_key, tmp_aes_iv
    )

    dh_prime = server_DH_params_ok.dh_prime
    g = server_DH_params_ok.g
    g_a = server_DH_params_ok.g_a
    #server_time = server_DH_params_ok.server_time

    decoded_dh_prime = :binary.decode_unsigned(dh_prime)
    decoded_g_a = :binary.decode_unsigned(g_a)

    # Validations
    dh_prime_valid? = validate(:dh_prime, decoded_dh_prime)
    g_valid? =  validate(:g, g, decoded_dh_prime)
    g_a_valid? = (decoded_g_a > 1) && (decoded_g_a < decoded_dh_prime - 1)

    if dh_prime_valid? && g_valid? && g_a_valid? do
      send self(), :send_set_client_DH_params

      state = struct(state, %{
        server_nonce: server_nonce,
        dh_prime: dh_prime,
        g: g,
        g_a: g_a,
        tmp_aes_key: tmp_aes_key,
        tmp_aes_iv: tmp_aes_iv
      })
      {:noreply, state}
    else
      Logger.warn "AuthKey: DH_params_ok validation failed! Retrying..."
      send self(), :send_req_pq

      state = purge(state)
      {:noreply, state}
    end
  end

  def handle_info(:send_set_client_DH_params, state) do
    g_b = Crypto.rand_bytes(32)
    g_b_valid? = (g_b > 1) &&
      (g_b < :binary.decode_unsigned(state.dh_prime) - 1)

    if g_b_valid? do
      set_client_DH_params = Method.set_client_DH_params(
        state.nonce,
        state.server_nonce,
        state.g,
        g_b,
        state.dh_prime,
        state.tmp_aes_key,
        state.tmp_aes_iv
      )

      Session.send state.session_id, set_client_DH_params, :plain

      state = struct(state, g_b: g_b)
      {:noreply, state}
    else
      Logger.warn "AuthKey: set_client_DH_params validation failed! Retrying..."
      send self(), :send_req_pq

      state = purge(state)
      {:noreply, state}
    end
  end

  def handle_info({:recv_dh_gen_fail, msg}, state) do
    new_nonce_hash3 = msg.new_nonce_hash3

    # new_nonce_hash check
    authorization_key = build_auth_key(state.g_a, state.g_b, state.dh_prime)
    new_nonce_hash_valid? = validate(
      :new_nonce_hash, new_nonce_hash3, 3, state.new_nonce, authorization_key
    )
    unless new_nonce_hash_valid? do
      Logger.warn "AuthKey : new_nonce_hash3 does not match !"
    end

    Logger.warn "AuthKey: set_client_DH_params fail! Retrying..."
    send self(), :send_set_client_DH_params

    {:noreply, state}
  end

  def handle_info({:recv_dh_gen_retry, msg}, state) do
    new_nonce_hash2 = msg.new_nonce_hash2

    # new_nonce_hash check
    authorization_key = build_auth_key(state.g_a, state.g_b, state.dh_prime)
    new_nonce_hash_valid? = validate(
      :new_nonce_hash, new_nonce_hash2, 2, state.new_nonce, authorization_key
    )
    unless new_nonce_hash_valid? do
      Logger.warn "AuthKey : new_nonce_hash2 does not match !"
    end

    Logger.warn "AuthKey: set_client_DH_params retry! Retrying..."
    send self(), :send_set_client_DH_params

    {:noreply, state}
  end

  def handle_info({:recv_dh_gen_ok, msg}, state) do
    # dh_gen_ok#3bcbf734 nonce:int128 server_nonce:int128 new_nonce_hash1:int128
    new_nonce_hash1 = msg.new_nonce_hash1

    # AuthKey
    authorization_key = build_auth_key(state.g_a, state.g_b, state.dh_prime)

    # Check new_nonce_hash
    new_nonce_hash_valid? = validate(
      :new_nonce_hash, new_nonce_hash1, 1, state.new_nonce, authorization_key
    )

    if new_nonce_hash_valid? do
      # Server salt
      # substr(new_nonce, 0, 8) XOR substr(server_nonce, 0, 8)
      new_nonce_salt_part = build_salt_part(state.new_nonce)
      server_nonce_salt_part = build_salt_part(state.server_nonce)

      raw_server_salt = Bitwise.bxor(new_nonce_salt_part, server_nonce_salt_part)

      # Store a 'serialized' server_salt in order to avoid endianness issues
      # later. Should be serialized as 'long' but it looks like we already have
      # the 'right' endianness ... ? ('long' is a little-endian 128 bits number)
      server_salt = raw_server_salt |> TL.serialize(:int64)

      # Set values into the session's registry
      Session.update(
        state.session_id,
        %{auth_key: authorization_key, server_salt: server_salt}
      )

      # Notify the client process that evrything's ok
      session = Session.get(state.session_id)
      if session.client do
        send state.clientk, :auth_key_generated
      else
        IO.puts "No client for #{state.session_id}, printing to console."
        IO.puts "> The Authorization Key has been generated."
      end
    else
      Logger.warn "AuthKey : new_nonce_hash1 does not match !"
      Logger.error "Abording authorization key genration sequence !"
    end

    {:noreply, state}
  end

  # Catch-all used for development
  #def handle_info(msg, state) do
  #  IO.inspect msg
  #
  #  {:noreply, state}
  #end

  ###

  defp purge(%Auth{}=state) do
    %Auth{session_id: state.session_id}
  end

  # Check that dh_prime is a safe prime number
  def validate(:dh_prime, dh_prime) do
    # @TODO: check that p=dh_prime is prime
    p_prime? = true
    # @TODO: check that q=(dh_prime - 1) / 2 is prime
    q_prime? = true

    upper_bound = Bitwise.<<<(2,2048)
    lower_bound = Bitwise.<<<(2,2046) # should be 2^2047 @TODO

    (dh_prime < upper_bound) && (dh_prime > lower_bound)
                             && (p_prime?)
                             && (q_prime?)
  end

  def validate(:g, g, dh_prime) do
    value_valid? = g in [2,3,4,5,6,7]
    bounds_valid? = (g > 1) && (g < dh_prime - 1)
    cyclic_subgroup_valid? = case g do
      2 -> rem(dh_prime, 8) == 2
      3 -> rem(dh_prime, 3) == 2
      4 -> true
      5 -> rem(dh_prime, 5) in [1,4]
      6 -> rem(dh_prime, 24) in [19,23]
      7 -> rem(dh_prime, 7) in [3,5,6]
      _ -> false
    end

    value_valid? && bounds_valid? && cyclic_subgroup_valid?
  end

  def validate(:new_nonce_hash, new_nonce_hash, number, new_nonce, auth_key) do
    auth_key_aux_hash = :crypto.hash(:sha, auth_key) |> :binary.part(0, 8)
    full_hash = :crypto.hash(
      :sha, Binary.encode_signed(new_nonce) <> <<number>> <> auth_key_aux_hash
    )
    expected_hash = :binary.part(full_hash, byte_size(full_hash) - 16, 16)

    # Return true if they match
    expected_hash == Binary.encode_signed(new_nonce_hash)
  end

  defp server_DH_inner_data(encrypted_answer, tmp_aes_key, tmp_aes_iv) do
    # answer_with_hash := SHA1(answer) + answer + (0-15 random bytes);
    # such that the length be divisible by 16;
    # Encrypted with AES_256_IGE;
    answer_with_hash = :crypto.block_decrypt(
      :aes_ige256, tmp_aes_key, tmp_aes_iv, encrypted_answer
    )

    # Extract answer
    sha_length = 20
    answer = :binary.part(
      answer_with_hash, sha_length, byte_size(answer_with_hash) - sha_length
    )

    # Extract constructor & content from answer
    constructor = :binary.part(answer, 0, 4) |> TL.deserialize(:int)
    content = :binary.part(answer, 4, byte_size(answer) - 4)

    # Parse & deserialize
    TL.parse(constructor, content)
  end

  defp build_auth_key(g_a, g_b, dh_prime) do
    :crypto.mod_pow(g_a, g_b, dh_prime)
  end

  defp build_salt_part(x_nonce) do
      x_nonce |> Binary.encode_signed
              |> :binary.part(0, 8)
              |> Binary.decode_signed
  end
end
