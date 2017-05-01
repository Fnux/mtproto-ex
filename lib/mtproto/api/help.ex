defmodule MTProto.API.Help do
  @moduledoc """
  As in [core.telegram.org/methods#miscellaneous](https://core.telegram.org/methods#miscellaneous).
  """

  @doc """
  Returns info on data centre nearest to the user.
  """
  def get_config do
    TL.build("help.getConfig", %{})
  end

  @doc """
  Returns support id for the ‘ask a question’ feature.

  * `phone_number` - phone number in international format (string)
  * `user` - TL user object, as explained
  [here](https://core.telegram.org/type/User).
  """
  def get_support(phone, user) do
    TL.build("help.support", %{phone_number: phone, user: user})
  end

  @doc """
  Returns current configuration, including data center configuration.
  """
  def get_nearest_dc do
    TL.build("help.getNearestDc",%{})
  end

  @doc """
  Returns the text of an invitation text message.

  * `lang_code` - language code, `ISO 639-1`
  """
  def get_invite_text(lang_code) do
    TL.build("help.getInviteText", %{lang_code: lang_code})
  end
end
