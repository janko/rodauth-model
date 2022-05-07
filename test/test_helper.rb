require "bundler/setup"

require "minitest/autorun"
require "minitest/pride"
require "minitest/hooks/default"

require "rodauth"
require "rodauth/model"
require "bcrypt"

require_relative "support/active_record"
