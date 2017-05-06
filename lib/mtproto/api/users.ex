defmodule MTProto.API.Users do
  @moduledoc """
  As in [core.telegram.org/methods#working-with-users](https://core.telegram.org/methods#working-with-users).
  """

  @doc """
  Returns basic user info according to their identifiers.

  * `list` - list of
  [InputUser](https://core.telegram.org/type/InputUser) TL objects.
  """
  def get_users(list) do
    TL.build "users.getUsers", %{id: list}
  end

  @doc """
  Returns extended user info by ID.

  * `id` - [InputUser](https://core.telegram.org/type/InputUser) TL object.
  """
  def get_full_user(id) do
    TL.build "users.getFullUser", %{id: id}
  end
end
