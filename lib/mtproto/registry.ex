defmodule MTProto.Registry do
  @name Registry
  @moduledoc false
  # Provide a registry to store connection-related informations such as
  # the authorization key, the TCP socket, the TCP sequence number,
  # the server salt, the session handler pids and temporary values during
  # the generation of the authorization key.

  def start_link do
    Agent.start_link(fn -> Map.new end, name: @name)
  end

  # Set a value given its key.
  def set(key, value) do
    Agent.update(@name, fn(map) -> Map.put(map, key, value) end)
  end

  # Drop multiples values from an Enum. Ex: [:a, :b, :c, :d]
  def drop(keys) do
    Agent.update(@name, fn(map) -> Map.drop(map, keys) end)
  end

  # Delete an element given its key.
  def delete(key) do
    Agent.update(@name, fn(map) -> Map.delete(map, key) end)
  end

  # Get an element given its key.
  def get(key) do
    Agent.get(@name, fn(map) -> Map.get(map, key) end)
  end

  # Dump the whole registry (as a map).
  def dump do
    Agent.get(@name, fn(map) -> map end)
  end
end
