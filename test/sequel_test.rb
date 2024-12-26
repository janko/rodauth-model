require "test_helper"
require_relative "support/sequel"

describe "Sequel model mixin" do
  around do |&block|
    DB.transaction(rollback: :always, auto_savepoint: true, &block)
  end

  before do
    account_class = Class.new(Sequel::Model)
    account_class.set_dataset(DB[:accounts])
    Object.const_set(:Account, account_class) # give it a name
  end

  after do
    Object.send(:remove_const, :Account)
  end

  it "defines password attribute with a column" do
    account = build_account { account_password_hash_column :password_hash }

    account.password = "secret"
    assert_equal "secret", account.password
    assert_equal true, account.password?

    refute_nil account.password_hash
    assert_operator BCrypt::Password.new(account.password_hash), :==, "secret"

    account.password = "new secret"
    assert_operator BCrypt::Password.new(account.password_hash), :==, "new secret"

    account.password = ""
    refute_nil account.password_hash

    account.password = nil
    assert_nil account.password_hash
    assert_equal false, account.password?
  end

  it "defines password attribute with a table" do
    account = build_account { account_password_hash_column nil }

    account.password = "secret"
    assert_equal "secret", account.password
    assert_equal true, account.password?

    assert_instance_of Account::PasswordHash, account.password_hash
    assert_operator BCrypt::Password.new(account.password_hash.password_hash), :==, "secret"

    assert account.password_hash.new?
    account.save
    refute account.password_hash.new?

    account.password = "new secret"
    assert_operator BCrypt::Password.new(account.password_hash.password_hash), :==, "new secret"
    assert account.password_hash.modified?(:password_hash)

    account.save
    refute account.password_hash.modified?
    assert_operator BCrypt::Password.new(account.password_hash.password_hash), :==, "new secret"

    account.password = ""
    assert_operator BCrypt::Password.new(account.password_hash.password_hash), :==, ""

    account.password = nil
    assert account.password_hash.exists?
    account.save
    refute account.password_hash.exists?

    account.reload
    assert_nil account.password_hash
    assert_equal false, account.password?
  end

  it "doesn't select password hash column when using database authentication functions" do
    account = build_account { use_database_authentication_functions? true }
    account.update(password: "secret")
    account.reload

    assert_equal Hash[id: account.id], account.password_hash.values
  end

  it "defines feature associations" do
    account = build_account do
      enable :jwt_refresh, :email_auth, :account_expiration, :audit_logging,
        :disallow_password_reuse, :otp, :otp_unlock, :sms_codes, :password_expiration,
        :single_session, :remember, :verify_account, :reset_password,
        :verify_login_change, :lockout, :active_sessions, :recovery_codes

      enable :webauthn unless RUBY_ENGINE == "jruby"
    end

    account.save

    account.remember_key = Account::RememberKey.new(key: "key", deadline: Time.now)
    assert_instance_of Account::RememberKey, account.reload.remember_key

    account.verification_key = Account::VerificationKey.new(key: "key")
    assert_instance_of Account::VerificationKey, account.reload.verification_key

    account.password_reset_key = Account::PasswordResetKey.new(key: "key", deadline: Time.now)
    assert_instance_of Account::PasswordResetKey, account.reload.password_reset_key

    account.login_change_key = Account::LoginChangeKey.new(key: "key", login: "foo@bar.com", deadline: Time.now)
    assert_instance_of Account::LoginChangeKey, account.reload.login_change_key

    account.lockout = Account::Lockout.new(key: "key", deadline: Time.now)
    assert_instance_of Account::Lockout, account.reload.lockout

    account.login_failure = Account::LoginFailure.new
    assert_instance_of Account::LoginFailure, account.reload.login_failure

    account.email_auth_key = Account::EmailAuthKey.new(key: "key", deadline: Time.now)
    assert_instance_of Account::EmailAuthKey, account.reload.email_auth_key

    account.activity_time = Account::ActivityTime.new(last_activity_at: Time.now, last_login_at: Time.now)
    assert_instance_of Account::ActivityTime, account.reload.activity_time

    account.add_active_session_key(session_id: "1")
    assert_instance_of Account::ActiveSessionKey, account.reload.active_session_keys.first

    account.add_authentication_audit_log(message: "Foo")
    assert_instance_of Account::AuthenticationAuditLog, account.reload.authentication_audit_logs.first

    account.add_previous_password_hash(password_hash: "secret")
    assert_instance_of Account::PreviousPasswordHash, account.reload.previous_password_hashes.first

    account.add_jwt_refresh_key(key: "foo", deadline: Time.now)
    assert_instance_of Account::JwtRefreshKey, account.reload.jwt_refresh_keys.first

    account.password_change_time = Account::PasswordChangeTime.new
    assert_instance_of Account::PasswordChangeTime, account.reload.password_change_time

    account.session_key = Account::SessionKey.new(key: "key")
    assert_instance_of Account::SessionKey, account.reload.session_key

    account.otp_key = Account::OtpKey.new(key: "key")
    assert_instance_of Account::OtpKey, account.reload.otp_key

    account.otp_unlock = Account::OtpUnlock.new
    assert_instance_of Account::OtpUnlock, account.reload.otp_unlock

    account.sms_code = Account::SmsCode.new(phone_number: "0123456789")
    assert_instance_of Account::SmsCode, account.reload.sms_code

    account.add_recovery_code(code: "foo")
    assert_instance_of Account::RecoveryCode, account.reload.recovery_codes.first

    unless RUBY_ENGINE == "jruby"
      account.webauthn_user_id = Account::WebauthnUserId.new(webauthn_id: "id")
      assert_instance_of Account::WebauthnUserId, account.reload.webauthn_user_id

      account.add_webauthn_key(webauthn_id: "id", public_key: "key", sign_count: 1)
      assert_instance_of Account::WebauthnKey, account.reload.webauthn_keys.first
    end
  end

  it "automatically deletes associations" do
    account = build_account { enable :audit_logging, :remember, :active_sessions }
    account.update(password: "secret")
    Account::RememberKey.create(account: account, key: "key", deadline: Time.now)
    account.add_active_session_key(session_id: "id")
    account.destroy

    refute account.password_hash.exists?
    refute account.remember_key.exists?
    assert_empty account.active_session_keys
  end

  it "accepts passing association options hash" do
    account = build_account(association_options: { order: Sequel.desc(:created_at) }) do
      enable :active_sessions
      account_password_hash_column :password_hash
    end
    account.save
    account.add_active_session_key(session_id: "1", created_at: Time.now - 10)
    account.add_active_session_key(session_id: "2", created_at: Time.now - 5)
    assert_equal ["2", "1"], account.reload.active_session_keys.map(&:session_id)
  end

  it "accepts passing association options block" do
    account = build_account(association_options: -> (name) {
      { order: Sequel.desc(:created_at) } if name == :active_session_keys
    }) { enable :remember, :active_sessions }

    reflection = Account.association_reflection(:remember_key)
    assert_nil reflection[:order]

    reflection = Account.association_reflection(:active_session_keys)
    refute_nil reflection[:order]
  end

  it "defines inverse associations" do
    account = build_account { enable :remember }
    account.save
    account.remember_key = Account::RememberKey.new(key: "key", deadline: Time.now)
    account.reload

    assert_equal account.object_id, account.remember_key.account.object_id
  end

  private

  def build_account(**options, &block)
    rodauth_class = Class.new(Rodauth::Auth)
    rodauth_class.configure do
      enable :login_password_requirements_base
      use_database_authentication_functions? false
      instance_exec(&block) if block
    end

    Account.include Rodauth::Model(rodauth_class, **options)

    Account::ActiveSessionKey.unrestrict_primary_key if Account.const_defined?(:ActiveSessionKey)
    Account::RecoveryCode.unrestrict_primary_key if Account.const_defined?(:RecoveryCode)
    Account::WebauthnKey.unrestrict_primary_key if Account.const_defined?(:WebauthnKey)

    Account.new(email: "user@example.com")
  end
end
