defmodule MTProto.API.Contacts do
  @moduledoc """
  Working with contacts and blacklists.
  """

  @doc """
  Returns a list of contact statuses.
  """
  def get_statuses do
    TL.build "contacts.getStatuses", %{}
  end

  @doc """
  Returns the current user’s contact list.
  """
  def get_contacts(hash \\ "") do
    TL.build "contacts.getContacts", %{hash: hash}
  end

#  @doc """
#  Imports contacts from an address book, returns added contacts.
#  """
#  def import_contacts(contacts, replace) do
#    TL.build "contacts.importContacts", %{contacts: contacts, replace: replace}
#  end
#
#  @doc """
#  Deletes a single contact from the list.
#  """
#  def delete_contact(id) do
#    TL.build "contacts.deleteContact", %{id: id}
#  end
#
#  @doc """
#  Deletes several contacts from the list.
#  """
#  def delete_contacts(id) do
#    TL.build "contacts.deleteContacts", %{id: id}
#  end
#
#  @doc """
#  Adds a user to the blacklist.
#  """
#  def block(id) do
#    TL.build "contacts.block", %{id: id}
#  end
#
#  @doc """
#  Deletes a user from the blacklist
#  """
#  def unbock(id) do
#    TL.build "contacts.unblock", %{id: id}
#  end
#
#  @doc """
#  Returns a list of blocked users
#  """
#  def get_blocked(offset, limit) do
#    TL.build "contacts.getBlocket", %{offset: offset, limit: limit}
#  end
#
#  def export_card do
#    TL.build "contacts.exportCard", %{}
#  end
#
#  def import_card(export_card) do
#    TL.build "contacts.importCard", %{export_card: export_card}
#  end
#
#  def search(q, limit) do
#    TL.build "contacts.search", %{q: q, limit: limit}
#  end
#
#  def resolve_username(username) do
#    TL.build "contacts.resolveUsername", %{username: username}
#  end
end
