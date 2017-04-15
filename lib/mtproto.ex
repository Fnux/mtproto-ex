defmodule MTProto do
  require Logger
  alias MTProto.{Registry, DC, Session, AuthKey, API}

  @moduledoc """
  MTProto implementation for Elixir. At this time, the project is still far
  from complete : **expect things to break**.

  #### Other resources

  A demo client is avaible
  on [github](https://github.com/Fnux/telegram-client-elixir-demo).
  You may also want to take a look to the
  [README](https://github.com/Fnux/telegram-mt-elixir) page of the project,
  where you can find more detailed informations and examples.


  #### Overview

  This library allows you to handle mutiple users, which is fondamental since
  it was originally designed in order to build bridges between Telegram
  and other messaging services. Each session is equivalent to an user and has
  its own connection to Telegram's servers. Note that you have to set
  (see `MTProto.Session.set_client/2`) a process to be notified of incoming
  messages for every session.

  * `MTProto` (this module) - provides a "friendly" way to interact with
  'low-level' methods. It allow you to connect/login/logout/send messages.
  * `MTProto.API` (and submodules) - implementation of the Telegram API, as explained
  [here](https://core.telegram.org/api#telegram-api) and
  [here](https://core.telegram.org/schema).
  * `MTProto.Session` : Provides manual control over sessions.
  * Many modules **[1]** are not designed to be used by
  the "standard" user hence are not documented here. You're welcome to take a
  look/contribute : everything is on
  [github](https://github.com/Fnux/telegram-mt-elixir).

  **[1]** : `MTProto.Session.Brain`, `MTProto.Session.Handler`,
  `MTProto.Session.HandlerSupervisor`, `MTProto.Session.Listener`,
  `MTProto.Session.ListenerSupervisor`, `MTProto.Auth`, `MTProto.Crypto`,
  `MTProto.DC`, `MTProto.Method`, `MTProto.Payload`, `MTProto.Registry`,
  `MTProto.Supervisor` and `MTProto.TCP`.
  """

  @doc """
    Start the supervision tree and set default values in the registry.
    Automatically started.
  """
  def start(_type, _args) do
    # Ensure API_ID and API_HASH are set in the config
    api_id = Application.get_env(:telegram_tl, :api_id)
    api_hash = Application.get_env(:telegram_tl, :api_hash)

    if api_id == nil, do: Logger.error "API_ID is not set !"
    if api_hash == nil, do: Logger.error "API_HASH is not set !"

    # Start
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
    dc = Registry.get(:dc, dc_id)

    if dc.auth_key == <<0::8*8>> do
      Logger.debug "No authorization key found for DC #{dc_id}. Requesting..."
      AuthKey.generate(session_id)
    end

    {:ok, session_id}
  end

  @doc """
    Initiate the authentification procedure by sending a message to the account
    linked to the provided `phone` number on the session `session_id`
    (generated with `connect/1`).
  """
  def send_code(session_id, phone) do
    session = Registry.get(:session, session_id)
    send_code = API.Auth.send_code(phone)
    msg = unless session.initialized? do
      api_layer = TL.Schema.api_layer_version
      init_connection = init_connection_with("en", send_code)
      API.invoke_with_layer(api_layer, init_connection)
    else
      send_code
    end

    Session.send session_id, msg
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
      session = Registry.get :session, session_id
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
  @TODO
  """
  def sign_out(session_id) do
  #@TODO
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
  @TODO
  """
  def get_contacts do
    # @TODO
  end

  @doc false
  def init_connection_with(lang, query) do
    device = "unknow"
    system = "unknow"
    app = "unknow"
    API.init_connection(device, system, app, lang, query)
  end
end
