defmodule MTProto.Session.History do
  alias MTProto.Registry
  use Supervisor

  @moduledoc false
  @table_prefix "MTProtoSessionHistory"
  @name MTProto.Session.HistorySupervisor

  ###
  # 'HistorySupervisor'

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def init(_) do
    children = [
      worker(MTProto.Registry, [], restart: :transient)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end

  def pop(session_id) do
    table_name = build_table_name(session_id)
    Supervisor.start_child(@name, [table_name])
  end

  def drop(session_id) do
    table_name = build_table_name(session_id)
    Supervisor.terminate_child @name, table_name
  end

  ###
  # History API

  def build_table_name(session_id) do
    (@table_prefix <> Integer.to_string(session_id))
      |> String.to_atom
  end

  def enqueue(session_id, msg_id, msg) do
    table_name = build_table_name(session_id)
    Registry.set table_name, msg_id, msg

    # Remeber that msg_id is time dependent !
    # msg_id = unix_time * 2^32
    # We can use it to remove old messages.
    offset = 0
    #drop_older_than(session_id, msg_id - offset)
  end

  def fetch(session_id, msg_id) do
    table_name = build_table_name(session_id)
    Registry.get table_name, msg_id
  end

  # + fetch_and_dequeue ?

  def dequeue(session_id, msg_id) do
    table_name = build_table_name(session_id)
    Registry.drop table_name, msg_id
  end

  def dump(session_id) do
    table_name = build_table_name(session_id)
    Registry.dump table_name
  end

  defp drop_older_than(session_id, limit) do
    table_name = build_table_name(session_id)
    keys = Registry.get_keys table_name
    for key <- keys do
      if key < limit do
        dequeue session_id, key
      end
    end
  end
end
