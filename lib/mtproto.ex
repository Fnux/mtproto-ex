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

  def init_connection_with(lang, query) do
    device = "unknow"
    system = "unknow"
    app = "unknow"
    API.init_connection(device, system, app, lang, query)
  end

  def sign_in(session) do

  end
end
