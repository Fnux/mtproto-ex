defmodule MTProto.Registry do
  @moduledoc false
  # Provide a registry to store connection-related informations such as
  # the authorization key, the TCP socket, the TCP sequence number,
  # the server salt, the session handler pids and temporary values during
  # the generation of the authorization key.

  def start_link(name) do
    Agent.start_link(fn -> Map.new end, name: name)
  end

  # Set a value given its key.
  def set(registry, key_1, key_2, value) do
    Agent.update(registry, fn(map) ->
                 unless Map.has_key?(map, key_1) do
                  map = Map.put(map, key_1, Map.new)
                 end
                  Kernel.put_in(map, [key_1, key_2], value)
                 end)
  end

  # Delete a subtree given its key.
  def delete(registry, key_1) do
    Agent.update(registry, fn(map) -> Map.delete(map, key_1) end)
  end

  # Get an element given its key.
  def get(registry, key_1, key_2) do
    Agent.get(registry, fn(map) -> Kernel.get_in(map, [key_1, key_2]) end)
  end

  # Dump the whole registry (as a map).
  def dump(registry) do
    Agent.get(registry, fn(map) -> map end)
  end
end
