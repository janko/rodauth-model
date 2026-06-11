source "https://rubygems.org"

gemspec

gem "rake", "~> 13.0"

gem "activerecord", ">= 5.1"
gem "sqlite3", ">= 1.3", "< 3", platforms: :mri
gem "activerecord-jdbcsqlite3-adapter", platforms: :jruby
gem "rack", "< 3" if RUBY_VERSION < "2.6" # rack 3.x is incompatible with Ruby 2.5 (Enumerable#to_h)
