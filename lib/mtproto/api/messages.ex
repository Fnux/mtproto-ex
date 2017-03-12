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
  def send_message(peer, message, random_id) do
  end

  @doc """
  Sends a non-text message.

  * `` - user or group to receive the message.
  * `` - message contents.
  * `` - unique client message ID, required to prevent message resending.
  """
  def send_media do
  end

  @doc """
  Sends a current user typing event to a conversation partner or group.

  * ``
  * ``
  * ``
  """
  def set_typing do
  end

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

  def get_history do
  end

  def search do
  end

  def read_history do
  end

  def read_message_contents do
  end

  def delete_history do
  end

  def delete_messages do
  end

  def received_messages do
  end

  def forward_message do
  end

  def forward_messages do
  end

  def send_broadcast do
  end

  # ##### #
  # Chats #
  # ##### #

  def get_chats do
  end

  def get_full_chat do
  end

  def edit_chat_title do

  end

  def echot_chat_photo do
  end

  def add_chat_user do
  end

  def delete_chat_user do
  end

  def create_chat do
  end
end
