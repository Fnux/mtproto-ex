defmodule MTProto.API.Messages do
  @moduledoc """
  Working with Messages and Chats.
  """

  # ######## #
  # Messages #
  # ######## #

  @doc """
  Sends a text message.

  * `peer` - user or chat where a message will be sent.
  * `message` - message text.
  * `random_id` - unique client message ID required to prevent message resending.
  """
  def send_message(inputPeer, message) do
    random_id = MTProto.Crypto.rand_bytes(8)
    TL.build "messages.sendMessage", %{peer: inputPeer,
                                       message: message,
                                       random_id: random_id}
  end

  @doc """
  `:not_yet_implemented`
  Sends a non-text message.

  * `` - user or group to receive the message.
  * `` - message contents.
  * `` - unique client message ID, required to prevent message resending.
  """
  def send_media do
  end

  @doc """
  `:not_yet_implemented`
  Sends a current user typing event to a conversation partner or group.

  * ``
  * ``
  * ``
  """
  def set_typing do
  end

  @doc """
  `:not_yet_implemented`
  """
  def get_messages do
  end

  @doc """
  Returns the current user dialog list.

  * `offset` - number of list elements to be skipped.
  * `max_id` - if a positive value was transmitted sent, the method will return
  only dialogs with IDs less than the set one.
  * `limit` - number of list elements to be returned
  """
  def get_dialogs(offset, max_id, limit) do
    TL.build "messages.getDialogs", %{offset: offset,
                                      max_id: max_id,
                                      limit: limit}
  end

  @doc """
    `:not_yet_implemented`
  """
  def get_history do
  end

  @doc """
    `:not_yet_implemented`
  """
  def search do
  end

  @doc """
    `:not_yet_implemented`
  """
  def read_history do
  end

  @doc """
    `:not_yet_implemented`
  """
  def read_message_contents do
  end

  @doc """
    `:not_yet_implemented`
  """
  def delete_history do
  end

  @doc """
    `:not_yet_implemented`
  """
  def delete_messages do
  end

  @doc """
    `:not_yet_implemented`
  """
  def received_messages do
  end

  @doc """
    `:not_yet_implemented`
  """
  def forward_message do
  end

  @doc """
    `:not_yet_implemented`
  """
  def forward_messages do
  end

  @doc """
    `:not_yet_implemented`
  """
  def send_broadcast do
  end

  # ##### #
  # Chats #
  # ##### #

  @doc """
    `:not_yet_implemented`
  """
  def get_chats do
  end

  @doc """
    `:not_yet_implemented`
  """
  def get_full_chat do
  end

  @doc """
    `:not_yet_implemented`
  """
  def edit_chat_title do
  end

  @doc """
    `:not_yet_implemented`
  """
  def echot_chat_photo do
  end

  @doc """
    `:not_yet_implemented`
  """
  def add_chat_user do
  end

  @doc """
    `:not_yet_implemented`
  """
  def delete_chat_user do
  end

  @doc """
    `:not_yet_implemented`
  """
  def create_chat do
  end
end
