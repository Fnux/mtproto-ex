defmodule MTProto.API do
  alias MTProto.Payload
  @moduledoc """
  @TODO
  """

  def init_connection(device_model, system_version, app_version, lang, query) do
    api_id = Application.get_env(:telegram_tl, :api_id)
    TL.build("initConnection", %{api_id: api_id,
                  device_model: device_model,
                  system_version: system_version,
                  app_version: app_version,
                  lang_code: lang,
                  query: query
                })
  end

  def invoke_with_layer(layer, query) do
    TL.build("invokeWithLayer", %{layer: layer, query: query})
  end
end
