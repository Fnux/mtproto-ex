defmodule MTProto.API.Auth do
  alias MTProto.TL.Build

  @moduledoc """
  Auth.*
  """

  def check_phone(phone) do
    Build.payload("auth.checkPhone", %{phone_number: phone})
  end
end
