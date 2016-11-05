defmodule MTProto.Registry do
  def new do
    Agent.start_link(fn -> %{} end)
  end

  def set(pid, new_value) do
    Agent.update(pid, fn(_n) -> new_value end)
  end

  def get(pid) do
    Agent.get(pid, fn(n) -> n end)
  end
end
