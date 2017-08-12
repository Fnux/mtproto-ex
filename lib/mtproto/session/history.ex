defmodule MTProto.Session.History do
  alias MTProto.Registry
  use Supervisor

  # @TODO proper documentation for this module

  @moduledoc false
  @table_prefix "MTProtoSessionHistory"
  @name MTProto.Session.HistorySupervisor
  @offset_s 60 # offset in seconds
  @offset @offset_s * :math.pow(2, 32) |> round
  # Number of retry before giving up

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
    Supervisor.start_child(@name, [table_for(session_id)])
  end

  def drop(session_id) do
    Supervisor.terminate_child @name, table_for(session_id)
  end

  ###
  # History API

  def put(session_id, msg_id, value) do
    Registry.set table_for(session_id), msg_id, value

    # Remeber that msg_id is time dependent !
    # msg_id = unix_time * 2^32
    # We can use it to remove old messages.
    drop_older_than(session_id, msg_id - @offset)
  end

  def get(session_id, msg_id) do
    Registry.get table_for(session_id), msg_id
  end

  # + fetch_and_dequeue ?

  def drop(session_id, msg_id) do
    Registry.drop table_for(session_id), msg_id
  end

  def dump(session_id) do
    Registry.dump table_for(session_id)
  end

  ###
  # Internals

  defp table_for(session_id) do
    (@table_prefix <> Integer.to_string(session_id))
      |> String.to_atom
  end

  defp drop_older_than(session_id, limit) do
    keys = Registry.get_keys table_for(session_id)
    for msg_id <- keys do
      if msg_id < limit do
        drop session_id, msg_id
      end
    end
  end
end
