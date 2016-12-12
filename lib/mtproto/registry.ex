defmodule MTProto.Registry do
  @moduledoc false

  # Provide a registry to store connection-related informations such as
  # the authorization keys, the TCP sockets, the TCP sequence numbers,
  # the server salts, the sessions handler/listener pids and temporary values during
  # the generation of an authorization key.

  def start_link(name) do
    Agent.start_link(fn -> Map.new end, name: name)
  end

  # Set a value given its keys.
  def set(registry, id, key, value) do
    Agent.update(registry, fn(map) ->
      initial = Map.get(map, id)
      updated = Map.put(initial, key, value)
      Map.put map, id, updated
    end)
  end

  def set(registry, key, struct) do
    Agent.update(registry, fn(map) -> Map.put(map, key, struct) end)
  end


  # Delete a subtree given its key
  def drop(registry, key) do
    Agent.update(registry, fn(map) -> Map.delete(map, key) end)
  end

  # Delete a value given its keys.
  def drop(registry, id, key) do
    Agent.update(registry, fn(map) ->
                 initial = Map.get(map, id)
                 updated = Map.delete(initial, key)
                 Map.put map, id, updated
    end)
  end

  # Get an element given its keys.
  def get(registry, key) do
    Agent.get(registry, fn(map) -> Map.get(map, key) end)
  end

  # Dump the whole registry (as a map).
  def dump(registry) do
    Agent.get(registry, fn(map) -> map end)
  end
end
