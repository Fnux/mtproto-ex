defmodule MTProto.API.Contacts do

  def get_statuses do
    TL.build "contacts.getStatuses", %{}
  end

  def get_contacts(hash \\ "") do
    TL.build "contacts.getContacts", %{hash: hash}
  end

  def import_contacts(contacts, replace) do
    Tl.build "contacts.importContacts", %{contacts: contacts, replace: replace}
  end

  def delete_contact(id) do
    TL.build "contacts.deleteContact", %{id: id}
  end

  def delete_contacts(id) do
    TL.build "contacts.deleteContacts", %{id: id}
  end

  def block(id) do
    TL.build "contacts.block", %{id: id}
  end

  def unlock(id) do
    TL.build "contacts.unblock", %{id: id}
  end

  def get_blocked(offset, limit) do
    TL.build "contacts.getBlocket", %{offset: offset, limit: limit}
  end

  def export_card do
    TL.build "contacts.exportCard", %{}
  end

  def import_card(export_card) do
    TL.build "contacts.importCard", %{export_card: export_card}
  end

  def search(q, limit) do
    TL.build "contacts.search", %{q: q, limit: limit}
  end

  def resolve_username(username) do
    TL.build "contacts.resolveUsername", %{username: username}
  end
end
