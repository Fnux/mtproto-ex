defmodule MTProto.API.Auth do
  @moduledoc """
  Auth.*
  See [core.telegram.org/schema](https://core.telegram.org/schema).
  """

  @doc """
  Returns information on whether the passed phone number was registered.

    * `phone` - phone number, international format (ex: `0041760000000`).
  """
  def check_phone(phone) do
    TL.build("auth.checkPhone", %{phone_number: phone})
  end

  @doc """
  Sends an confirmation code message to the specified phone number via SMS.

    * `phone` - phone number, international format (ex: `0041760000000`).
    * `sms_type` - message text type.
      * `0` - message contains a numerical code (Default).
      * `1` (deprecated) - message contains a link `{app_name}://{code}`.
      * `5` - message sent via Telegram instead of SMS.
    * `lang` - code for the language used on a client, ISO 639-1 standard.
    Default value is `"en"`.
  """
  def send_code(phone, sms_type \\ 0, lang \\ "en") do
    api_id = Application.get_env(:telegram_tl, :api_id)
    api_hash = Application.get_env(:telegram_tl, :api_hash)
    TL.build("auth.sendCode",
             %{phone_number: phone, sms_type: sms_type, api_id: api_id,
               api_hash: api_hash, lang_code: lang}
  )
  end

  @doc """
  Makes a voice call to the passed phone number. A robot will repeat the confirmation code from a previously sent SMS message.
  """
  def send_call(phone_number, phone_code_hash) do
    TL.build("auth.sendCall", 
             %{phone_number: phone_number,phone_code_hash: phone_code_hash}
           )
  end

  @doc """
  Registers a validated phone number in the system.
  """
  def sign_up(phone_number, phone_code_hash, phone_code, first_name, last_name) do
    TL.build("auth.signUp",
             %{phone_number: phone_number,
               phone_code_hash: phone_code_hash,
               phone_code: phone_code,
               first_name: first_name,
               last_name: last_name})
  end

  @doc """
  Signs in a user with a validated phone number.
  """
  def sign_in(phone_number, phone_code_hash, phone_code) do
    TL.build("auth.signIn",
             %{phone_number: phone_number,
               phone_code_hash: phone_code_hash,
               phone_code: phone_code})
  end

  @doc """
  Logs out the user.
  """
  def log_out do
    TL.build("auth.logOut", %{})
  end

  @doc """
  Terminates all user's authorized sessions except for the current one.
  """
  def reset_authorizations do
    TL.build("auth.resetAuthorizations", %{})
  end

  @doc """
  Saves information that the current user sent SMS-messages with invitations to its unregistered contacts.
  """
  def send_invites(phone_numbers, message) do
    TL.build("auth.sendInvites", %{phone_numbers: phone_numbers, message: message})
  end

  @doc """
  Returns data for copying authorization to another data-centre.
  """
  def export_authorization(dc_id) do
    TL.build("auth.exportAuthorization", %{dc_id: dc_id})
  end

  @doc """
  Logs in a user using a key transmitted from his native data-centre.
  """
  def import_authorization(user_id, auth_key) do
    TL.build("auth.importAuthorization", %{id: user_id, bytes: auth_key})
  end

  @doc """
  Binds a temporary authorization key `temp_auth_key_id` to the permanent
  authorization key `perm_auth_key_id`. Each permanent key may only be bound
  to one temporary key at a time, binding a new temporary key overwrites
  the previous one.
  """
  def bind_tmp_auth_key(perm_auth_key_id, nonce, expires_at, encrypted_message) do
    TL.build("auth.bindTempAuthKey",
             %{perm_auth_key_id: perm_auth_key_id,
               nonce: nonce,
               expires_at: expires_at,
               encrypted_message: encrypted_message})
  end

  @doc """
  Forces sending an SMS message to the specified phone number.
  """
  def send_sms(phone_number, phone_code_hash) do
    TL.build("auth.sendSms", %{phone_number: phone_number, phone_code_hash: phone_code_hash})
  end
end
