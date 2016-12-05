defmodule MTProto.Handler do
  use GenServer
  require Logger
  alias MTProto.Registry
  alias MTProto.TCP
  alias MTProto.AuthKey

  def start_link(opts \\ []) do
     GenServer.start(__MODULE__, :ok, [opts])
  end

  def init(:ok) do
    {:ok, nil}
  end

  def handle_info({:recv, msg}, state) do
    predicate = Map.get(msg, :predicate)

    Logger.debug "The Handler received message : #{predicate}."

    case predicate do
      "resPQ" -> AuthKey.resPQ(msg)
      "server_DH_params_ok" -> AuthKey.server_DH_params_ok(msg)
      "server_DH_params_fail" -> AuthKey.server_DH_params_fail(msg)
      "dh_gen_ok" -> AuthKey.dh_gen_ok(msg)
      "dh_gen_fail" -> AuthKey.dh_gen_fail(msg)
      "dh_gen_retry" -> AuthKey.dh_gen_fail(msg)
      _ ->
        Logger.warn "The handler received an unknow message : #{predicate}."
    end
    {:noreply, state}
  end

  def handle_info({:send_plain, payload}, state) do
    socket = Registry.get :socket
    seqno = Registry.get :seqno

    payload |> TCP.wrap(seqno)
            |> TCP.send(socket)

    {:noreply, state}
  end
end
