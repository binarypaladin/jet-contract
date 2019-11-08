# frozen_string_literal: true

require "jet/type"
require "jet/contract/attribute"

module Jet
  class Contract
    FLATTEN_ERROR_TYPES = %i[
      contract_validation_failure
      check_each_failure
    ].freeze

    @checks = Contract::Check::BuiltIn
    @types = Type::JSON

    class << self
      attr_reader :checks, :types

      def build(*args, &blk)
        raise ArgumentError, "no block given" unless block_given?
        Builder.new.tap { |b| b.instance_eval(&blk) }.call(*args)
      end

      def checks!(checks)
        validate_registry!("checks", checks, Check, :eql)
      end

      def checks=(checks)
        @checks = checks!(checks)
      end

      def types!(types)
        case types
        when :http
          Type::HTTP
        when :json
          Type::JSON
        when :strict
          Type::Strict
        else
          validate_registry!("types", types, Type, :string)
        end
      end

      def types=(types)
        @types = types!(types)
      end

      private

      def validate_registry!(name, registry, type, key)
        return registry if registry.respond_to?(:[]) && registry[key].is_a?(type)
        raise ArgumentError, "`#{name}` must be a registry of #{type}"
      end
    end

    def initialize(attributes, keys_in: [String, Symbol], keys_out: :to_sym, **)
      @attributes = Jet.type_check_hash!("`attributes`", attributes, Attribute)
                       .transform_keys(&:to_s)

      @opts = { keys_in: _keys_in(keys_in), keys_out: _keys_out(keys_out) }
    end

    def call(input, **)
      results = check_attributes(filter_keys(input.to_h))
      failure(results, input) || success(results)
    end

    def [](key)
      @attributes[key]
    end

    def attributes
      @attributes.dup
    end

    def opts
      @opts.dup
    end

    def rebuild(*args)
      to_builder.(*args)
    end

    def to_builder
      Builder.new(@attributes.transform_values(&:to_builder))
    end

    def with(*other_contracts, **opts)
      Jet.type_check_each!("`other_contracts`", other_contracts, Contract)

      self.class.new(
        other_contracts.each_with_object(attributes) { |c, atts| atts.merge!(c.attributes) },
        **self.opts.merge(opts)
      )
    end

    private

    def _keys_in(classes)
      Array(classes).map do |c|
        next String if c == :string
        next Symbol if c == :symbol
        Jet.type_check!(":keys_in element #{c}", Class, Module)
        c
      end.uniq
    end

    def _keys_out(key_type)
      if [Symbol, :symbol, :to_sym].include?(key_type)
        :to_sym
      elsif [String, :string, :to_s].include?(key_type)
        :to_s
      else
        raise ArgumentError, ":keys_out must equal either :symbol or :string"
      end
    end

    def check_attributes(input)
      @attributes.each_with_object({}) do |(k, att), h|
        if input.key?(k)
          h[k] = att.(input[k], k.to_sym)
        else
          next if att.optional?
          h[k] = Result.failure(:key_missing_failure, at: k.to_sym)
        end
      end
    end

    def failure(results, input)
      return unless results.values.any?(&:failure?)
      Result.failure(
        :contract_validation_failure,
        errors: flatten_errors(results.values),
        input: input
      )
    end

    def filter_keys(input)
      input.select { |k, _| @opts[:keys_in].any? { |t| k.is_a?(t) } }
           .transform_keys(&:to_s)
           .select { |k, _| attributes.keys.include?(k) }
    end

    def flatten_errors(results)
      results.select(&:failure?).each_with_object([]) do |r, errs|
        next errs.concat(flatten_errors(r.errors)) if FLATTEN_ERROR_TYPES.include?(r.output)
        errs << r
      end
    end

    def success(results)
      results
        .each_with_object({}) { |(k, r), h| h[k.send(opts[:keys_out])] = r.output }
        .yield_self { |output| Result.success(output) }
    end
  end
end

require "jet/contract/builder"
