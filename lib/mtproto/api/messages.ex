defmodule MTProto.API.Messages do
  @moduledoc """
  Working with Messages and Chats as explained in :

  * [core.telegram.org/methods#working-with-messages](https://core.telegram.org/methods#working-with-messages)
  * [core.telegram.org/methods#working-with-chats](https://core.telegram.org/methods#working-with-chats)
  """

  # ######## #
  # Messages #
  # ######## #

  @doc """
  Sends a text message.

  * `dst` - user or chat where a message will be sent,
  TL [InputPeer](https://core.telegram.org/type/InputPeer) object.
  * `message` - message text.
  """
  def send_message(dst, message) do
    random_id = MTProto.Crypto.rand_bytes(8)
    TL.build "messages.sendMessage", %{peer: dst,
                                       message: message,
                                       random_id: random_id}
  end

  @doc """
  Sends a non-text message.

  * `dst` - user or group to receive the message,
  TL [InputPeer](https://core.telegram.org/type/InputPeer) object.
  * `media` - message content, TL
  [InputMedia](https://core.telegram.org/type/InputMedia) object.
  """
  def send_media(dst, media) do
    random_id = MTProto.Crypto.rand_bytes(8)
    TL.build "messages.sendMedia", %{peer: dst,
                                     media: media,
                                     random_id: random_id}
  end

  @doc """
  Sends a current user typing event to a conversation partner or group.

  * `dst` - Target user or group, TL
  [InputPeer](https://core.telegram.org/type/InputPeer) object.
  * `typing` - Typing status, boolean.
  * `action` - Type of action, TL
  [SendMessageAction](https://core.telegram.org/type/SendMessageAction) object.
  """
  def set_typing(dst, typing, action) do
    TL.build "messages.setTyping", %{peer: dst,
                                     typing: typing,
                                     action: action}
  end

  @doc """
  Returns the list of messages by their IDs.

  * `list` - Message ID list.
  """
  def get_messages(list) do
    TL.build "messages.getMessages", %{id: list}
  end

  @doc """
  Returns the current user dialog list.

  * `offset` - number of list elements to be skipped.
  * `max_id` - if a positive value was transmitted sent, the method will return
  only dialogs with IDs less than the set one.
  * `limit` - number of list elements to be returned.
  """
  def get_dialogs(offset, max_id, limit) do
    TL.build "messages.getDialogs", %{offset: offset,
      max_id: max_id,
      limit: limit}
  end

  @doc """
  Returns message history for a chat.

  * `peer` - Target user or group
  * `offset` - Number of list elements to be skipped
  * `max_id` - only messages with IDs less than max_id
  * `limit` - Number of list elements to be returned
  """
  def get_history(peer, offset, max_id, limit) do
    TL.build "messages.getHistory", %{
      peer: peer,
      offset: offset,
      max_id: max_id,
      limit:  limit
    }
  end

  @doc """
  Returns search messages.

  * `peer` - User or chat, histories with which are searched, or (inputPeerEmpty)
  constructor for global search
  * `q` - Text search request
  * `filter` - Additional filter
  * `min_date` -  only messages with a sending date bigger than the transferred
  one will be returned
  * `max_date` - only messages with a sending date less than the transferred one
  will be returned
  * `offset` - 	Number of list elements to be skipped
  * `max_id` - If a positive value was transferred, the method will return only
  messages with IDs less than the set one
  * `limit` - Number of list elements to be returned
  """
  def search(peer, q, filter, min_date, max_date, offset, max_id, limit) do
    TL.build "messages.search", %{
      peer: peer,
      q: q,
      filter: filter,
      min_date: min_date,
      max_date: max_date,
      offset: offset,
      max_id: max_id,
      limit: limit
    }
  end

  @doc """
  Marks message history as read.

  * `peer` - Target user or group
  * `max_id` - only messages with identifiers less or equal than the given
  one will be read
  * `offset` - Value from
  ([messages.affectedHistory](https://core.telegram.org/constructor/messages.affectedHistory))
  * `read_contents` - boolean
  """
  def read_history(peer, max_id, offset, read_contents) do
    TL.build "messages.redHistory", %{
      peer: peer,
      max_id: max_id,
      offset: offset,
      read_contents: read_contents
    }
  end

  @doc """
  Notifies the sender about the recipient having listened a voice message or
  watched a video.

  * `list` - Message ID list
  """
  def read_message_contents(list) do
    TL.build "messages.readMessageContents", %{id: list}
  end

  @doc """
  Deletes communication history.

  * `peer` - User or chat, communication history of which will be deleted
  * `offset` - Value from
  ([messages.affectedHistory](https://core.telegram.org/constructor/messages.affectedHistory))
  or `0`
  """
  def delete_history(peer, offset) do
    TL.build "messages.deleteHistory", %{peer: peer, offset: offset}
  end

  @doc """
  Deletes messages by their identifiers.

  * `list` - Message ID list
  """
  def delete_messages(list) do
    TL.build "messages.deleteMessages", %{id: list}
  end

  @doc """
  Confirms receipt of messages by a client, cancels PUSH-notification sending.

  `max_id` - Maximum message ID available in a client
  """
  def received_messages(max_id) do
    TL.build "messsages.receivedMessages", %{max_id: max_id}
  end

  @doc """
  Forwards single messages.

  * `peer` - User or chat where a message will be forwarded
  * `id` - Forwarded message ID
  """
  def forward_message(peer, id) do
    random_id = MTProto.Crypto.rand_bytes(8)
    TL.build "messages.forwardMessage", %{
      peer: peer,
      id: id,
      random_id: random_id
    }
  end

  @doc """
  Forwards messages by their IDs.

  * `peer` - User or chat where messages will be forwarded
  * `list` - Message ID list
  """
  def forward_messages(peer, list) do
    TL.build "messages.forwardMessages", %{peer: peer, id: list}
  end

  @doc """
  Sends multiple messages to contacts.

  * `contacts` - List of user ID to whom a message will be sent
  * `message` - Message text
  * `media` - Message media-contents
  """
  def send_broadcast(contacts, message, media) do
    TL.build "messages.sendBroadcast", %{
      contacts: contacts,
      message: message,
      media: media
    }
  end

  # ##### #
  # Chats #
  # ##### #

  @doc """
  Returns basic chat information by chat identifiers.

  * `chats` - list of chats IDs
  """
  def get_chats(chats) do
    TL.build("messages.chats", %{id: chats})
  end

  @doc """
  Returns complete chat information by chat identifier.

  * `chat` - ID of the chat (integer)
  """
  def get_full_chats(chat) do
    TL.build("messages.chats", %{chat_id: chat})
  end

  @doc """
  Changes chat name and sends a service message on it.

  * `chat` - ID of the chat (integer)
  * `title` - new title of the chat (string)
  """
  def edit_chat_title(chat, title) do
    TL.build("messages.chats", %{chat_id: chat, title: title})
  end

  @doc """
  Changes chat photo and sends a service message on it.

  * `chat` - ID of the chat (integer)
  * `photo` - new photo, TL
  [InputChatPhoto](https://core.telegram.org/type/InputChatPhoto) object
  """
  def change_chat_photo(chat, photo) do
    TL.build("messages.editChatPhoto", %{chat_id: chat, photo: photo})
  end

  @doc """
  Adds a user to a chat and sends a service message on it.

  * `chat` - ID of the chat (integer)
  * `user_id` - ID of the user to be added
  * `fwd_limit` - Number of last messages to be forwarded
  """
  def add_chat_user(chat, user_id, fwd_limit) do
    TL.build("messages.addChatUser", %{
               chat_id: chat,
               user_id: user_id,
               fwd_limit: fwd_limit
             })
  end

  @doc """
  Deletes a user from a chat and sends a service message on it.

  * `chat` - ID of the chat (integer)
  * `user_id` - ID of the user to be removed
  """
  def delete_chat_user(chat, user_id) do
    TL.build("messages.deleteChatUser", %{
               chat_id: chat,
               user_id: user_id,
             })
  end

  @doc """
  Creates a new chat.

  * `users` - List of user IDs to be invited (List of
  [InputUser](https://core.telegram.org/type/InputUser))
  * `title` - chat name
  """
  def create_chat(users, title) do
  TL.build("messages.createChat", %{
               users: users,
               title: title
             })

  end
end
