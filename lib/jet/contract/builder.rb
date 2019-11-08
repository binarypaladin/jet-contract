# frozen_string_literal: true

module Jet
  class Contract
    class Builder
      attr_reader :checks, :types

      def initialize(attribute_builders = {})
        @attribute_builders = attribute_builders.dup
      end

      def [](key)
        @attribute_builders[key]
      end

      def call(*args)
        Contract.new(@attribute_builders.transform_values { |ab| ab.(*args) })
      end

      def attribute_builders
        @attribute_builders.dup
      end
      alias to_h attribute_builders

      def optional(key)
        attribute_builder(key, false)
      end

      def required(key)
        attribute_builder(key, true)
      end

      private

      def attribute_builder(key, required)
        @attribute_builders[key.to_sym] = Attribute::Builder.new(required: required)
      end
    end
  end
end
