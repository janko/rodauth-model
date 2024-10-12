# frozen_string_literal: true

module Rodauth
  Model.register_association(:remember) do
    { name: :remember_key, type: :one, table: remember_table, key: remember_id_column }
  end
  Model.register_association(:verify_account) do
    { name: :verification_key, type: :one, table: verify_account_table, key: verify_account_id_column }
  end
  Model.register_association(:reset_password) do
    { name: :password_reset_key, type: :one, table: reset_password_table, key: reset_password_id_column }
  end
  Model.register_association(:verify_login_change) do
    { name: :login_change_key, type: :one, table: verify_login_change_table, key: verify_login_change_id_column }
  end
  Model.register_association(:lockout) do
    { name: :lockout, type: :one, table: account_lockouts_table, key: account_lockouts_id_column }
  end
  Model.register_association(:lockout) do
    { name: :login_failure, type: :one, table: account_login_failures_table, key: account_login_failures_id_column }
  end
  Model.register_association(:email_auth) do
    { name: :email_auth_key, type: :one, table: email_auth_table, key: email_auth_id_column }
  end
  Model.register_association(:account_expiration) do
    { name: :activity_time, type: :one, table: account_activity_table, key: account_activity_id_column }
  end
  Model.register_association(:active_sessions) do
    { name: :active_session_keys, type: :many, table: active_sessions_table, key: active_sessions_account_id_column }
  end
  Model.register_association(:audit_logging) do
    { name: :authentication_audit_logs, type: :many, table: audit_logging_table, key: audit_logging_account_id_column }
  end
  Model.register_association(:disallow_password_reuse) do
    { name: :previous_password_hashes, type: :many, table: previous_password_hash_table, key: previous_password_account_id_column }
  end
  Model.register_association(:jwt_refresh) do
    { name: :jwt_refresh_keys, type: :many, table: jwt_refresh_token_table, key: jwt_refresh_token_account_id_column }
  end
  Model.register_association(:password_expiration) do
    { name: :password_change_time, type: :one, table: password_expiration_table, key: password_expiration_id_column }
  end
  Model.register_association(:single_session) do
    { name: :session_key, type: :one, table: single_session_table, key: single_session_id_column }
  end
  Model.register_association(:otp) do
    { name: :otp_key, type: :one, table: otp_keys_table, key: otp_keys_id_column }
  end
  Model.register_association(:otp_unlock) do
    { name: :otp_unlock, type: :one, table: otp_unlock_table, key: otp_unlock_id_column }
  end
  Model.register_association(:sms_codes) do
    { name: :sms_code, type: :one, table: sms_codes_table, key: sms_id_column }
  end
  Model.register_association(:recovery_codes) do
    { name: :recovery_codes, type: :many, table: recovery_codes_table, key: recovery_codes_id_column }
  end
  Model.register_association(:webauthn) do
    { name: :webauthn_user_id, type: :one, table: webauthn_user_ids_table, key: webauthn_user_ids_account_id_column }
  end
  Model.register_association(:webauthn) do
    { name: :webauthn_keys, type: :many, table: webauthn_keys_table, key: webauthn_keys_account_id_column }
  end
end
