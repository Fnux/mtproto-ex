defmodule MTProto.Session.Brain do
  require Logger
  alias MTProto.AuthKey
  alias MTProto.Crypto

  def process_plain(msg, session_id) do
    predicate = Map.get(msg, :predicate)

    case predicate do
      "resPQ" -> AuthKey.resPQ(msg, session_id)
      "server_DH_params_ok" -> AuthKey.server_DH_params_ok(msg, session_id)
      "server_DH_params_fail" -> AuthKey.server_DH_params_fail(msg, session_id)
      "dh_gen_ok" -> AuthKey.dh_gen_ok(msg, session_id)
      "dh_gen_fail" -> AuthKey.dh_gen_fail(msg, session_id)
      "dh_gen_retry" -> AuthKey.dh_gen_fail(msg, session_id)
      _ ->
        Logger.warn "#{session_id} : received an unknow predicate #{predicate}."
    end
  end

  def process_encrypted(message, session_id) do
    IO.inspect message
  end
 end
