defmodule MTProto do
  alias MTProto.{DC, Session, API}
  require Logger

  @moduledoc """
  MTProto implementation for Elixir. Base module.

  This module provides "high-level" functions for common tasks.
  """

  @doc """
    Start the supervision tree and set default values in the registry.
  """
  def start(), do: start(nil, nil)
  def start(_type, _args) do
    # Ensure API_ID and API_HASH are set in the config
    api_id = Application.get_env(:telegram_mt, :api_id)
    api_hash = Application.get_env(:telegram_mt, :api_hash)

    if api_id == nil, do: Logger.error "API_ID is not set !"
    if api_hash == nil, do: Logger.error "API_HASH is not set !"

    # Start
    Logger.info "Starting Telegram MT."
    out = MTProto.Supervisor.start_link

    # Register DCs
    DC.register

    out
  end

  @doc """
    Connect and create a session on the specified DC.
    If `dc_id` is not provided, connect to a random DC (out of the 5 available
    DC.) If there is no authorization key related to the DC, the authorization
    key generation will be initiated.

    Returns `{:ok, session_id}`.
  """
  def connect(dc_id \\ :random) do
    dc_id = if dc_id == :random, do: :rand.uniform(5), else: dc_id
    session_id = Session.open(dc_id)

    {:ok, session_id}
  end

  @doc """
  Launch the Authorization Key computation sequence.
  """
  def request_authkey(session_id) do
    Logger.debug "Requesting authorization key for session #{session_id}..."

    session = Session.get(session_id)
    Kernel.send session.auth_client, :send_req_pq
  end

  @doc """
    Initiate the authentification procedure by sending a message to the account
    linked to the provided `phone` number on the session `session_id`
    (generated with `connect/1`).
  """
  def send_code(session_id, phone) do
    msg = API.Auth.send_code(phone)
    send_with_initialization(session_id, msg)
  end

  @doc """
    Sign in given the phone number and the code received from Telegram (by SMS,
    call, or via an open client). `phone_code_hash` is returned in the response
    to `MTProto.send_code/2`and is stored in the session. You don't need to
    provide it, but you can override the `phone_code_hash` stored in the
    session by providing it here.
  """
  def sign_in(session_id, phone, code, code_hash \\ :session) do
    code_hash = if code_hash == :session do
      session = Session.get(session_id)
      session.phone_code_hash
    else
      code_hash
    end

    api_layer = TL.Schema.api_layer_version
    sign_in = API.Auth.sign_in(phone, code_hash, code)
    sign_in = API.invoke_with_layer(api_layer, sign_in)
    invoke = API.invoke_with_layer(api_layer, sign_in)
    Session.send session_id, invoke
  end

  @doc """
  Log out the user.
  """
  def sign_out(session_id) do
    Session.send session_id, API.Auth.log_out
  end

  @doc """
    Send an encrypted message to Telegram on the session `sid`. Similar (alias)
    to `MTProto.Session.send(sid, msg, :encrypted)`.
  """
  def send(session_id, msg) do
    Session.send session_id, msg, :encrypted
  end

  @doc """
    Send a text message to an user/group.

    * `session_id`
    * `dst_id` - ID (integer) of the recipient of the message
    * `content` - content of the message (string)
    * `type` - type of the recipient, either an user (`:contact`) or
    a group (`:chat`)
  """
  def send_message(session_id, dst_id, content, type \\ :contact) do
    peer = case type do
      :chat -> TL.build "inputPeerChat", %{chat_id: dst_id}
      _ -> TL.build "inputPeerContact", %{user_id: dst_id}
    end

    msg = API.Messages.send_message(peer, content)
    Session.send session_id, msg
  end

  @doc """
  Fetch the the contact list.
  """
  def get_contacts(session_id) do
    Session.send session_id, API.Contacts.get_contacts
  end

  @doc """
  Initilize the connection (if not initialized yet) with default values
  and the version of API layer to use.
  """
  def send_with_initialization(session_id, msg) do
    session = Session.get(session_id)
    unless session.initialized? do
      api_layer = TL.Schema.api_layer_version
      init_connection = init_connection_with("en", msg)
      query = API.invoke_with_layer(api_layer, init_connection)
      Session.send session_id, query
    else
      Session.send session_id, msg
    end
  end

  @doc false
  def init_connection_with(lang, query) do
    device = "unknow"
    system = "unknow"
    app = "unknow"
    API.init_connection(device, system, app, lang, query)
  end
end
