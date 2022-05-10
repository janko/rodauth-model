require "sequel"

DB = Sequel.connect("#{"jdbc:" if RUBY_ENGINE == "jruby"}sqlite::memory:")

DB.create_table :accounts do
  primary_key :id
  Integer :status, null: false, default: 1
  String :email, null: false
  index :email, unique: true, where: { status: [1, 2] }
  String :password_hash
end

DB.create_table :account_password_hashes do
  foreign_key :id, :accounts, primary_key: true
  String :password_hash, null: false
end

DB.create_table :account_authentication_audit_logs do
  primary_key :id
  foreign_key :account_id, :accounts, null: false
  DateTime :at, null: false, default: Sequel::CURRENT_TIMESTAMP
  String :message, null: false
  column :metadata, :json
  index [:account_id, :at], name: :audit_account_at_idx
  index :at, name: :audit_at_idx
end

# Used by the password reset feature
DB.create_table :account_password_reset_keys do
  foreign_key :id, :accounts, primary_key: true
  String :key, null: false
  DateTime :deadline, null: false
  DateTime :email_last_sent, null: false, default: Sequel::CURRENT_TIMESTAMP
end

# Used by the jwt refresh feature
DB.create_table :account_jwt_refresh_keys do
  primary_key :id
  foreign_key :account_id, :accounts, null: false
  String :key, null: false
  DateTime :deadline, null: false
  index :account_id, name: :account_jwt_rk_account_id_idx
end

# Used by the disallow_password_reuse feature
DB.create_table :account_previous_password_hashes do
  primary_key :id
  foreign_key :account_id, :accounts
  String :password_hash, null: false
end

# Used by the account verification feature
DB.create_table :account_verification_keys do
  foreign_key :id, :accounts, primary_key: true
  String :key, null: false
  DateTime :requested_at, null: false, default: Sequel::CURRENT_TIMESTAMP
  DateTime :email_last_sent, null: false, default: Sequel::CURRENT_TIMESTAMP
end

# Used by the verify login change feature
DB.create_table :account_login_change_keys do
  foreign_key :id, :accounts, primary_key: true
  String :key, null: false
  String :login, null: false
  DateTime :deadline, null: false
end

# Used by the remember me feature
DB.create_table :account_remember_keys do
  foreign_key :id, :accounts, primary_key: true
  String :key, null: false
  DateTime :deadline, null: false
end

# Used by the lockout feature
DB.create_table :account_login_failures do
  foreign_key :id, :accounts, primary_key: true
  Integer :number, null: false, default: 1
end
DB.create_table :account_lockouts do
  foreign_key :id, :accounts, primary_key: true
  String :key, null: false
  DateTime :deadline, null: false
  DateTime :email_last_sent
end

# Used by the email auth feature
DB.create_table :account_email_auth_keys do
  foreign_key :id, :accounts, primary_key: true
  String :key, null: false
  DateTime :deadline, null: false
  DateTime :email_last_sent, null: false, default: Sequel::CURRENT_TIMESTAMP
end

# Used by the password expiration feature
DB.create_table :account_password_change_times do
  foreign_key :id, :accounts, primary_key: true
  DateTime :changed_at, null: false, default: Sequel::CURRENT_TIMESTAMP
end

# Used by the account expiration feature
DB.create_table :account_activity_times do
  foreign_key :id, :accounts, primary_key: true
  DateTime :last_activity_at, null: false
  DateTime :last_login_at, null: false
  DateTime :expired_at
end

# Used by the single session feature
DB.create_table :account_session_keys do
  foreign_key :id, :accounts, primary_key: true
  String :key, null: false
end

# Used by the active sessions feature
DB.create_table :account_active_session_keys do
  foreign_key :account_id, :accounts
  String :session_id
  Time :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
  Time :last_use, null: false, default: Sequel::CURRENT_TIMESTAMP
  primary_key [:account_id, :session_id]
end

# Used by the webauthn feature
DB.create_table :account_webauthn_user_ids do
  foreign_key :id, :accounts, primary_key: true
  String :webauthn_id, null: false
end
DB.create_table :account_webauthn_keys do
  foreign_key :account_id, :accounts
  String :webauthn_id
  String :public_key, null: false
  Integer :sign_count, null: false
  Time :last_use, null: false, default: Sequel::CURRENT_TIMESTAMP
  primary_key [:account_id, :webauthn_id]
end

# Used by the otp feature
DB.create_table :account_otp_keys do
  foreign_key :id, :accounts, primary_key: true
  String :key, null: false
  Integer :num_failures, null: false, default: 0
  Time :last_use, null: false, default: Sequel::CURRENT_TIMESTAMP
end

# Used by the recovery codes feature
DB.create_table :account_recovery_codes do
  foreign_key :id, :accounts
  String :code
  primary_key [:id, :code]
end

# Used by the sms codes feature
DB.create_table :account_sms_codes do
  foreign_key :id, :accounts, primary_key: true
  String :phone_number, null: false
  Integer :num_failures
  String :code
  DateTime :code_issued_at, null: false, default: Sequel::CURRENT_TIMESTAMP
end
