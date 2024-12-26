# rodauth-model

Extension for [Rodauth] providing a mixin for the account model that defines password attribute and associations based on enabled authentication features. Supports both Active Record and Sequel models.

## Installation

```sh
$ bundle add rodauth-model
```

## Usage

The model mixin is built by calling `Rodauth::Model(...)` with the Rodauth auth class, and included into the account model:

```rb
require "rodauth/model" # require before enabling any authentication features

class RodauthApp < Roda
  plugin :rodauth do
    # ...
  end
end
```
```rb
class Account < ActiveRecord::Base # Sequel::Model
  include Rodauth::Model(RodauthApp.rodauth)
end
```

### Password attribute

Regardless of whether you're storing the password hash in a column in the accounts table, or in a separate table, the `#password` attribute can be used to set or clear the password hash.

```rb
account = Account.create(email: "user@example.com", password: "secret")

# when password hash is stored in a column on the accounts table
account.password_hash #=> "$2a$12$k/Ub1I2iomi84RacqY89Hu4.M0vK7klRnRtzorDyvOkVI.hKhkNw."

# when password hash is stored in a separate table
account.password_hash #=> #<Account::PasswordHash...> (record from `account_password_hashes` table)
account.password_hash.password_hash #=> "$2a$12$k/Ub1..." (inaccessible when using database authentication functions)

# whether a password is set
account.password? #=> true

account.password = nil # clears password hash
account.password_hash #=> nil
account.password? #=> false
```

Note that the password attribute doesn't come with validations, making it unsuitable for forms. It was primarily intended to allow easily creating accounts in development console and in tests.

### Associations

The mixin defines associations for Rodauth tables associated to the accounts table:

```rb
account.remember_key #=> #<Account::RememberKey> (record from `account_remember_keys` table)
account.active_session_keys #=> [#<Account::ActiveSessionKey>,...] (records from `account_active_session_keys` table)
```

You can also reference the associated models directly:

```rb
# model referencing the `account_authentication_audit_logs` table
Account::AuthenticationAuditLog.where(message: "login").group(:account_id)
```

The associated models define the inverse `account` association:

```rb
Account::ActiveSessionKey.eager(:account).map(&:account)
```

### Association options

By default, all associations are configured to be deleted when the associated account record is deleted. When using Active Record, you can use `:association_options` to modify global or per-association options:

```rb
# don't auto-delete associations when account model is deleted (Active Record)
Rodauth::Model(RodauthApp.rodauth, association_options: { dependent: nil })

# require authentication audit logs to be eager loaded before retrieval (Sequel)
Rodauth::Model(RodauthApp.rodauth, association_options: -> (name) {
  { forbid_lazy_load: true } if name == :authentication_audit_logs
})
```

### Extending models

When using Zeitwerk autoloading, extending an associated model in a separate file won't work, because Zeitwerk has no reason to load it, since the constant was already defined. You can work around this by extending the model in the parent file:

```rb
class Account < ActiveRecord::Base
  include Rodauth::Model(RodauthApp.rodauth) # defines associated models

  class ActiveSessionKey < ActiveRecord::Base
    # extend the model
  end
end
```

## Association reference

Below is a list of all associations defined depending on the features loaded:

| Feature                 | Association                  | Type       | Model                    | Table (default)                     |
| :------                 | :----------                  | :---       | :----                    | :----                               |
| account_expiration      | `:activity_time`             | `has_one`  | `ActivityTime`           | `account_activity_times`            |
| active_sessions         | `:active_session_keys`       | `has_many` | `ActiveSessionKey`       | `account_active_session_keys`       |
| audit_logging           | `:authentication_audit_logs` | `has_many` | `AuthenticationAuditLog` | `account_authentication_audit_logs` |
| disallow_password_reuse | `:previous_password_hashes`  | `has_many` | `PreviousPasswordHash`   | `account_previous_password_hashes`  |
| email_auth              | `:email_auth_key`            | `has_one`  | `EmailAuthKey`           | `account_email_auth_keys`           |
| jwt_refresh             | `:jwt_refresh_keys`          | `has_many` | `JwtRefreshKey`          | `account_jwt_refresh_keys`          |
| lockout                 | `:lockout`                   | `has_one`  | `Lockout`                | `account_lockouts`                  |
| lockout                 | `:login_failure`             | `has_one`  | `LoginFailure`           | `account_login_failures`            |
| otp                     | `:otp_key`                   | `has_one`  | `OtpKey`                 | `account_otp_keys`                  |
| otp_unlock              | `:otp_unlock`                | `has_one`  | `OtpUnlock`              | `account_otp_unlocks`               |
| password_expiration     | `:password_change_time`      | `has_one`  | `PasswordChangeTime`     | `account_password_change_times`     |
| recovery_codes          | `:recovery_codes`            | `has_many` | `RecoveryCode`           | `account_recovery_codes`            |
| remember                | `:remember_key`              | `has_one`  | `RememberKey`            | `account_remember_keys`             |
| reset_password          | `:password_reset_key`        | `has_one`  | `PasswordResetKey`       | `account_password_reset_keys`       |
| single_session          | `:session_key`               | `has_one`  | `SessionKey`             | `account_session_keys`              |
| sms_codes               | `:sms_code`                  | `has_one`  | `SmsCode`                | `account_sms_codes`                 |
| verify_account          | `:verification_key`          | `has_one`  | `VerificationKey`        | `account_verification_keys`         |
| verify_login_change     | `:login_change_key`          | `has_one`  | `LoginChangeKey`         | `account_login_change_keys`         |
| webauthn                | `:webauthn_keys`             | `has_many` | `WebauthnKey`            | `account_webauthn_keys`             |
| webauthn                | `:webauthn_user_id`          | `has_one`  | `WebauthnUserId`         | `account_webauthn_user_ids`         |

> [!NOTE]
> Some Rodauth tables use composite primary keys, which are supported in Active Record 7.1+. If you're on an older version of Active Record, you might need to add the [composite_primary_keys] gem to your Gemfile. Sequel has always natively supported composite primary keys.

## Extending associations

It's possible to register custom associations for an external feature, which the model mixin would pick up and automatically define the association on the model if the feature is enabled.

```rb
# lib/rodauth/features/foo.rb
module Rodauth
  Feature.define(:foo, :Foo) do
    auth_value_method :foo_table, :account_foos
    auth_value_method :foo_id_column, :id
    # ...
  end
end

if defined?(Rodauth::Model)
  Rodauth::Model.register_association(:foo) do
    { name: :foo, type: :one, table: foo_table, key: foo_id_column }
  end
end
```

The `Rodauth::Model.register_association` method receives the feature name and a block, which is evaluted in the context of a Rodauth instance and should return the association definition with the following items:

* `:name` – association name
* `:type` – relationship type (`:one` for one-to-one, `:many` for one-to-many)
* `:table` – associated table name
* `:key` – foreign key on the associated table

It's possible to register multiple associations for the same Rodauth feature.

## Examples

### Checking whether account has multifactor authentication enabled

```rb
class Account < ActiveRecord::Base
  include Rodauth::Model(RodauthApp.rodauth)

  def mfa_enabled?
    otp_key || (sms_code && sms_code.num_failures.nil?) || recovery_codes.any?
  end
end
```

### Retrieving all accounts with multifactor authentication enabled

```rb
class Account < ActiveRecord::Base
  include Rodauth::Model(RodauthApp.rodauth)

  scope :otp_setup, -> { where(otp_key: OtpKey.all) }
  scope :sms_codes_setup, -> { where(sms_code: SmsCode.where(num_failures: nil)) }
  scope :recovery_codes_setup, -> { where(recovery_codes: RecoveryCode.all) }
  scope :mfa_enabled, -> { merge(otp_setup.or(sms_codes_setup).or(recovery_codes_setup)) }
end
```

## Future plans

### Joined associations

It's possible to have multiple Rodauth configurations that operate on the same tables, but it's currently possible to define associations just for a single configuration. I would like to support grabbing associations from multiple associations.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/janko/rodauth-model. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/janko/rodauth-model/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Rodauth::Model project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/janko/rodauth-model/blob/main/CODE_OF_CONDUCT.md).

[Rodauth]: https://rodauth.jeremyevans.net
[composite_primary_keys]: https://github.com/composite-primary-keys/composite_primary_keys
