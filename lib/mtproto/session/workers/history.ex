defmodule MTProto.Session.Workers.History do
  alias MTProto.Registry

  # @TODO proper documentation for this module

  @moduledoc false
  @table_prefix "MTProtoSessionHistory"
  @offset_s 60 # offset in seconds
  @offset @offset_s * :math.pow(2, 32) |> round

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

  def table_for(session_id) do
    (@table_prefix <> Integer.to_string(session_id))
      |> String.to_atom
  end

  defp drop_older_than(session_id, limit) do
    msg_id = table_for(session_id) |> Registry.last()

    if msg_id < limit do
      drop session_id, msg_id
      drop_older_than(session_id, limit)
    end
  end
end
