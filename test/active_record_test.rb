require "test_helper"
require_relative "support/active_record"

describe "Active Record model mixin" do
  around do |&block|
    ActiveRecord::Base.transaction do
      super(&block)
      # skip rolling back record state, since it crashes on composite primary keys
      ActiveRecord::Base.connection.current_transaction.records&.clear
      raise ActiveRecord::Rollback
    end
  end

  before do
    account_class = Class.new(ActiveRecord::Base)
    account_class.table_name = :accounts
    Object.const_set(:Account, account_class) # give it a name
  end

  after do
    Object.send(:remove_const, :Account)
    ActiveRecord::Base.clear_cache! # clear schema cache
    if ActiveRecord.version < Gem::Version.new("7.0")
      ActiveSupport::Dependencies.clear # clear cache used for :class_name association option
    end
  end

  it "defines password attribute with a column" do
    account = build_account { account_password_hash_column :password_hash }

    account.password = "secret"
    assert_equal "secret", account.password

    refute_nil account.password_hash
    assert_operator BCrypt::Password.new(account.password_hash), :==, "secret"

    account.password = "new secret"
    assert_operator BCrypt::Password.new(account.password_hash), :==, "new secret"

    account.password = ""
    refute_nil account.password_hash

    account.password = nil
    assert_nil account.password_hash
  end

  it "defines password attribute with a table" do
    account = build_account { account_password_hash_column nil }

    account.password = "secret"
    assert_equal "secret", account.password

    assert_instance_of Account::PasswordHash, account.password_hash
    assert_operator BCrypt::Password.new(account.password_hash.password_hash), :==, "secret"

    refute account.password_hash.persisted?
    account.save!
    assert account.password_hash.persisted?

    account.password = "new secret"
    assert_operator BCrypt::Password.new(account.password_hash.password_hash), :==, "new secret"
    assert account.password_hash.password_hash_changed?

    account.save!
    refute account.password_hash.changed?
    assert_operator BCrypt::Password.new(account.password_hash.password_hash), :==, "new secret"

    account.password = ""
    assert_operator BCrypt::Password.new(account.password_hash.password_hash), :==, ""

    account.password = nil
    refute account.password_hash.destroyed?
    account.save!
    assert account.password_hash.destroyed?

    account.reload
    assert_nil account.password_hash
  end

  it "doesn't select password hash column when using database authentication functions" do
    account = build_account { use_database_authentication_functions? true }
    account.update(password: "secret")
    account.reload

    assert_equal account.id, account.password_hash.id
    assert_raises ActiveModel::MissingAttributeError do
      account.password_hash.password_hash
    end
  end

  it "defines feature associations" do
    account = build_account do
      enable :jwt_refresh, :email_auth, :account_expiration, :audit_logging,
        :disallow_password_reuse, :otp, :sms_codes, :password_expiration,
        :single_session, :remember, :verify_account, :reset_password,
        :verify_login_change, :lockout, :active_sessions, :recovery_codes

      enable :webauthn unless RUBY_ENGINE == "jruby"
    end

    account.save!

    account.create_remember_key!(id: account.id, key: "key", deadline: Time.now)
    assert_instance_of Account::RememberKey, account.remember_key

    account.create_verification_key(id: account.id, key: "key")
    assert_instance_of Account::VerificationKey, account.verification_key

    account.create_password_reset_key(id: account.id, key: "key", deadline: Time.now)
    assert_instance_of Account::PasswordResetKey, account.password_reset_key

    account.create_login_change_key(id: account.id, key: "key", login: "foo@bar.com", deadline: Time.now)
    assert_instance_of Account::LoginChangeKey, account.login_change_key

    account.create_lockout!(id: account.id, key: "key", deadline: Time.now)
    assert_instance_of Account::Lockout, account.lockout

    account.create_login_failure!(id: account.id)
    assert_instance_of Account::LoginFailure, account.login_failure

    account.create_email_auth_key!(id: account.id, key: "key", deadline: Time.now)
    assert_instance_of Account::EmailAuthKey, account.email_auth_key

    account.create_activity_time!(id: account.id, last_activity_at: Time.now, last_login_at: Time.now)
    assert_instance_of Account::ActivityTime, account.activity_time

    account.active_session_keys.create!(session_id: "1")
    assert_instance_of Account::ActiveSessionKey, account.active_session_keys.first

    account.authentication_audit_logs.create!(message: "Foo")
    assert_instance_of Account::AuthenticationAuditLog, account.authentication_audit_logs.first

    account.previous_password_hashes.create!(password_hash: "secret")
    assert_instance_of Account::PreviousPasswordHash, account.previous_password_hashes.first

    account.jwt_refresh_keys.create!(key: "foo", deadline: Time.now)
    assert_instance_of Account::JwtRefreshKey, account.jwt_refresh_keys.first

    account.create_password_change_time!(id: account.id)
    assert_instance_of Account::PasswordChangeTime, account.password_change_time

    account.create_session_key!(id: account.id, key: "key")
    assert_instance_of Account::SessionKey, account.session_key

    account.create_otp_key!(id: account.id, key: "key")
    assert_instance_of Account::OtpKey, account.otp_key

    account.create_sms_code!(id: account.id, phone_number: "0123456789")
    assert_instance_of Account::SmsCode, account.sms_code

    if ActiveRecord.version >= Gem::Version.new("5.0")
      Account::RecoveryCode.create!(id_value: account.id, code: "foo")
      assert_instance_of Account::RecoveryCode, account.recovery_codes.first
    end

    unless RUBY_ENGINE == "jruby"
      account.create_webauthn_user_id!(id: account.id, webauthn_id: "id")
      assert_instance_of Account::WebauthnUserId, account.webauthn_user_id

      if ActiveRecord.version >= Gem::Version.new("5.0")
        account.webauthn_keys.create!(webauthn_id: "id", public_key: "key", sign_count: 1)
        assert_instance_of Account::WebauthnKey, account.webauthn_keys.first
      end
    end
  end

  it "automatically deletes associations" do
    account = build_account { enable :audit_logging, :remember, :active_sessions }
    account.update!(password: "secret")
    account.create_remember_key!(id: account.id, key: "key", deadline: Time.now)
    account.active_session_keys.create!(account_id: account.id, session_id: "id")
    account.destroy

    assert account.password_hash.destroyed?
    assert account.remember_key.destroyed?
    assert_equal 0, account.active_session_keys.reload.count
  end

  it "accepts passing association options hash" do
    account = build_account(association_options: { dependent: :nullify }) { enable :remember }
    association = Account.reflect_on_association(:remember_key)
    assert_equal :nullify, association.options[:dependent]
  end

  it "accepts passing association options block" do
    account = build_account(association_options: -> (name) {
      { dependent: :nullify } if name == :remember_key
    }) { enable :remember, :verify_account }

    remember_association = Account.reflect_on_association(:remember_key)
    assert_equal :nullify, remember_association.options[:dependent]

    verification_association = Account.reflect_on_association(:verification_key)
    assert_equal :delete, verification_association.options[:dependent]
  end

  it "defines inverse associations" do
    account = build_account { enable :remember }
    account.save!
    account.create_remember_key!(id: account.id, key: "key", deadline: Time.now)
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
    Account.new(email: "user@example.com")
  end
end
