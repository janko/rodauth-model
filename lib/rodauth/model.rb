# frozen_string_literal: true

module Rodauth
  def self.Model(*args, **options)
    Rodauth::Model.new(*args, **options)
  end

  class Model < Module
    Error = Class.new(StandardError)

    autoload :ActiveRecord, "rodauth/model/active_record"

    def initialize(auth_class, association_options: {})
      @auth_class = auth_class
      @association_options = association_options
    end

    def included(model)
      if defined?(::ActiveRecord::Base) && model < ::ActiveRecord::Base
        extend Rodauth::Model::ActiveRecord
      else
        raise Error, "must be an Active Record model"
      end

      define_associations(model)
      define_methods(model)
    end

    def inspect
      "#<#{self.class}(#{@auth_class.inspect})>"
    end
  end
end
