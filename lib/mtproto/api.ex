defmodule MTProto.API do
  @moduledoc """
  Provides basics methods of Telegram's API. You may want to take a look to
  the [current TL-schema](https://core.telegram.org/schema).

  *Note :* the latest API layer on Telegram's documentation is API layer 23. A
  more recent (but undocumented?) schema can be found in [the sources of the
  official Telegram Desktop client](https://github.com/telegramdesktop/tdesktop/blob/7b7b9db20bcdf6c8d9e81d8d77f4af3bd50961cd/Telegram/Resources/scheme.tl)
  , currently (Apr. 2017) layer 66.
  """

  @doc """
  Initializes connection and save information on the user's device and application.
  """
  def init_connection(device_model, system_version, app_version, lang, query) do
    api_id = Application.get_env(:telegram_mt, :api_id)
    TL.build("initConnection", %{api_id: api_id,
                  device_model: device_model,
                  system_version: system_version,
                  app_version: app_version,
                  lang_code: lang,
                  query: query
                })
  end

  @doc """
  This method wrap the given `query` telling receiver (Telegram) that we use
  the API layer number `layer`.

  A layer is a collection of updated methods or constructors in a TL schema.
  Each layer is numbered with sequentially increasing numbers starting with 2.
  The first layer is the base layer — the TL schema without any changes.
  """
  def invoke_with_layer(layer, query) do
    TL.build("invokeWithLayer", %{layer: layer, query: query})
  end
end
