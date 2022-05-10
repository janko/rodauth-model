# frozen_string_literal: true

module Rodauth
  def self.Model(*args, **options)
    Rodauth::Model.new(*args, **options)
  end

  class Model < Module
    Error = Class.new(StandardError)

    autoload :ActiveRecord, "rodauth/model/active_record"
    autoload :Sequel, "rodauth/model/sequel"

    def self.associations
      @associations ||= {}
    end

    def self.register_association(feature, &block)
      associations[feature] ||= []
      associations[feature] << block
    end

    def initialize(auth_class, association_options: {})
      @auth_class = auth_class
      @association_options = association_options
    end

    def included(model)
      if defined?(::ActiveRecord::Base) && model < ::ActiveRecord::Base
        extend Rodauth::Model::ActiveRecord
      elsif defined?(::Sequel::Model) && model < ::Sequel::Model
        extend Rodauth::Model::Sequel
      else
        raise Error, "must be an Active Record or Sequel model"
      end

      define_associations(model)
      define_methods(model)
    end

    def inspect
      "#<#{self.class}(#{@auth_class.inspect})>"
    end

    private

    def feature_associations
      self.class.associations
        .values_at(*rodauth.features)
        .compact
        .flatten
        .map { |block| rodauth.instance_exec(&block) }
    end

    def rodauth
      @auth_class.allocate
    end
  end
end

require "rodauth/model/associations"
