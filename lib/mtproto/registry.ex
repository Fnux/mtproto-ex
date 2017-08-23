defmodule MTProto.Registry do
  use GenServer

  @moduledoc false

  # Provide a registry to store connection-related informations such as
  # the authorization keys, the TCP sockets, the TCP sequence numbers,
  # the server salts, the sessions handler/listener pids and temporary values during
  # the generation of an authorization key.

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: name)
  end

  def init(name) do
    table = :ets.new(name, [:named_table, :set, :public, read_concurrency: true])
    {:ok, table}
  end

  ###

  def handle_call({:set, key, value}, _from, table) do
    reply = :ets.insert(table, {key, value})

    {:reply, reply, table}
  end

  def handle_call({:get, key}, _from, table) do
    lookup = :ets.lookup(table, key)

    reply = case lookup do
      [{_key, value}] -> value
      [] -> nil
    end

    {:reply, reply, table}
  end

  def handle_call({:drop, key}, _from, table) do
    reply = :ets.delete(table, key)

    {:reply, reply, table}
  end

  def handle_call(:dump, _from, table) do
    reply = :ets.match(table, :"$1")
    {:reply, reply, table}
  end

  def handle_call(:first, _from, table) do
    reply = :ets.first(table)
    {:reply, reply, table}
  end

  def handle_call(:last, _from, table) do
    reply = :ets.last(table)
    {:reply, reply, table}
  end

  def handle_call({:next, key}, _from, table) do
    reply = :ets.next(table, key)
    {:reply, reply, table}
  end

  def handle_call({:prev, key}, _from, table) do
    reply = :ets.prev(table, key)
    {:reply, reply, table}
  end

  ###

  def set(name, key, value) do
    GenServer.call name, {:set, key, value}
  end

  def get(name, key) do
    GenServer.call name, {:get, key}
  end

  def drop(name, key) do
    GenServer.call name, {:drop, key}
  end

  def dump(name) do
    GenServer.call name, :dump
  end

  def first(name) do
    GenServer.call name, :first
  end

  def last(name) do
    GenServer.call name, :last
  end

  def next(name, key) do
    GenServer.call name, {:next, key}
  end

  def prev(name, key) do
    GenServer.call name, {:prec, key}
  end
end
