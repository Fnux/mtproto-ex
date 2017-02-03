defmodule MTProto do
  require Logger
  alias MTProto.{Registry, DC, Session, AuthKey, API, Payload}

  @moduledoc """
  MTProto implementation for Elixir. At this time, the project is still far 
  from complete : **expect things to break**.

  ## Example

  ```
  » iex -S mix

  Interactive Elixir (1.4.0) - press Ctrl+C to exit (type h() ENTER for help)
  iex> {:ok, session_id} = MTProto.connect(4) # Connect to DC 4
  {:ok, 0000000000000000000}

  19:10:07.231 [info]  The authorization key was successfully generated.

  iex> MTProto.send_code(session_id, "0041000000000")
  No client for 0000000000000000000, printing to console.
  {0000000000000000000,
    %{name: "rpc_result", req_msg_id: 0000000000000000000,
      result: %{is_password: %{name: "boolFalse"}, name: "auth.sentCode",
        phone_code_hash: "000000000000000000",
        phone_registered: %{name: "boolTrue"}, send_call_timeout: 120}}}

  iex> MTProto.sign_in(session_id, "0041000000000", "00000")
  No client for 0000000000000000000, printing to console.
  {0000000000000000000,
     %{name: "rpc_result", req_msg_id: 0000000000000000000,
      result: %{expires: 0000000000, name: "auth.authorization",
        user: %{first_name: "XXXX", id: 000000000, inactive: %{name: "boolFalse"},
          last_name: "", name: "userSelf", phone: "41000000000",
          photo: %{name: "userProfilePhoto",
            photo_big: %{dc_id: 4, local_id: 00000, name: "fileLocation",
              secret: 0000000000000000000, volume_id: 000000000},
            photo_id: 000000000000000000,
            photo_small: %{dc_id: 4, local_id: 00000, name: "fileLocation",
              secret: 0000000000000000000, volume_id: 000000000}},
          status: %{name: "userStatusOffline", was_online: 0000000000},
          username: "xxxxxxx"}}}}
```

  """

  @doc """
    Start the supervision tree and set default values in the registry.
    Automatically started.
  """
  def start(_type, _args) do
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
      Logger.info "No authorization key found for DC #{dc_id}. Requesting..."
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

    Session.send session_id, msg |> Payload.wrap(:encrypted)
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
    Session.send session_id, invoke |> Payload.wrap(:encrypted)
  end

  @doc """
    Send an encrypted message to Telegram on the session `sid`. Similar (alias)
    to `MTProto.Session.send(sid, msg, :encrypted)`.
  """
  def send(sid, msg) do
    Session.send sid, msg, :encrypted
  end

  @doc false
  def init_connection_with(lang, query) do
    device = "unknow"
    system = "unknow"
    app = "unknow"
    API.init_connection(device, system, app, lang, query)
  end
end
