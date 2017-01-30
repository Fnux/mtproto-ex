defmodule MTProto do
  require Logger
  alias MTProto.{Registry, DC, Session, AuthKey, API, Payload}

  @moduledoc """
  MTProto implementation for Elixir.
  """

  @doc """
    Start the supervision tree and set default values in the registry.
    Automatically started.
  """
  def start(_type, _args) do
    out = MTProto.Supervisor.start_link

    # Register DCs
    Registry.set :dc, 1, %DC{id: 1, address: "149.154.175.50"}
    Registry.set :dc, 2, %DC{id: 2, address: "149.154.167.51"}
    Registry.set :dc, 3, %DC{id: 3, address: "149.154.175.100"}
    Registry.set :dc, 4, %DC{id: 4, address: "149.154.167.91"}
    Registry.set :dc, 5, %DC{id: 5, address: "149.154.171.5"}

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
      init_connection = init_connection_with("en", send_code)
      API.invoke_with_layer(23, init_connection)
    else
      send_code
    end

    Session.send session_id, msg |> Payload.wrap(:encrypted)
  end

  @doc """
    @TODO
  """
  def sign_in(session_id, phone, code, code_hash \\ nil) do
    code_hash = if code_hash == nil do
      session = Registry.get :session, session_id
      session.phone_code_hash
    else
      code_hash
    end

    sign_in = API.Auth.sign_in(phone, code_hash, code)
    sign_in = API.invoke_with_layer(23, sign_in)
    invoke = API.invoke_with_layer(23, sign_in)
    Session.send session_id, invoke |> Payload.wrap(:encrypted)
  end

  @doc """
  @TODO
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
