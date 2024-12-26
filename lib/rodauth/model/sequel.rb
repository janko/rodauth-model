# frozen_string_literal: true

require "sequel"

module Rodauth
  class Model
    module Sequel
      include ::Sequel::Inflections

      ASSOCIATION_TYPES = { one: :one_to_one, many: :one_to_many }

      private

      def define_methods(model)
        rodauth = @auth_class.allocate.freeze

        unless rodauth.account_password_hash_column
          model.plugin :nested_attributes
          model.nested_attributes :password_hash, destroy: true
        end

        attr_reader :password

        define_method(:password=) do |password|
          @password = password
          password_hash = rodauth.password_hash(password) if password
          set_password_hash(password_hash)
        end

        define_method(:set_password_hash) do |password_hash|
          if rodauth.account_password_hash_column
            public_send(:"#{rodauth.account_password_hash_column}=", password_hash)
          else
            return if password_hash.nil? && self.password_hash.nil?

            attributes = { rodauth.password_hash_id_column => self.password_hash&.pk }.compact
            if password_hash
              attributes[rodauth.password_hash_column] = password_hash
            else
              attributes[:_delete] = true
            end
            self.password_hash_attributes = attributes
          end
        end

        define_method(:password?) do
          if rodauth.account_password_hash_column
            !!public_send(rodauth.account_password_hash_column)
          else
            !!password_hash
          end
        end
      end

      def define_associations(model)
        model.plugin :association_dependencies

        define_password_hash_association(model) unless rodauth.account_password_hash_column

        feature_associations.each do |association|
          association[:type] = ASSOCIATION_TYPES.fetch(association[:type])

          define_association(model, **association)
        end
      end

      def define_password_hash_association(model)
        select = [rodauth.password_hash_id_column] if rodauth.send(:use_database_authentication_functions?)

        define_association model,
          type: :one_to_one,
          name: :password_hash,
          table: rodauth.password_hash_table,
          key: rodauth.password_hash_id_column,
          select: select
      end

      def define_association(model, type:, name:, table:, key:, **options)
        associated_model = Class.new(::Sequel::Model)
        associated_model.set_dataset(model.db[table])
        associated_model.many_to_one :account, class: model.name, key: key

        model.const_set(camelize(singularize(name.to_s)), associated_model)

        model.public_send type, name,
          class: associated_model.name,
          key: key,
          **options,
          **association_options(name)

        model.add_association_dependencies name => :delete
      end

      def association_options(name)
        options = @association_options
        options = options.call(name) if options.respond_to?(:call)
        options || {}
      end
    end
  end
end
