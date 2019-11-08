# frozen_string_literal: true

module Jet
  class Contract
    class Attribute
      class Builder
        def initialize(opts = {})
          @opts = { required: true }.merge(opts)
          checks(opts[:checks]) if opts[:checks]
          contract(opts[:contract]) if opts[:contract]
          each(*opts[:each]) if opts[:each]
        end

        def call(types = nil, checks = nil)
          types = types.nil? ? Contract.types : Contract.types!(types)
          checks = checks.nil? ? Contract.checks : Contract.checks!(checks)

          Attribute.new(
            type_with(types),
            check_set_with(checks),
            contract: @opts[:contract]&.(types, checks),
            each: @opts[:each]&.(types, checks),
            required: @opts[:required]
          )
        end

        def checks(checks)
          @opts[:checks] = checks.each_with_object([]) do |check, a|
            case check
            when Hash
              check.each { |(k, v)| a << [k.to_sym, v] }
            when Array
              a << [check.first.to_sym].concat(check[1..-1])
            else
              a << [check.to_sym]
            end
          end
          self
        end

        def contract(contract = nil, &blk)
          raise ArgumentError, "cannot provide :contract if :each is set" if @opts[:each]
          auto_type!("contract", :hash)
          raise ArgumentError, "must provide either `contract` or a block" unless
            !contract.nil? ^ block_given?

          @opts[:contract] =
            if block_given?
              Contract::Builder.new.tap { |b| b.instance_eval(&blk) }
            else
              Jet.type_check!(":contract", contract, Contract, Contract::Builder)
            end
          self
        end

        def each(*args, &blk)
          raise ArgumentError, "cannot provide :each if :contract is set" if @opts[:contract]
          auto_type!("each", :array)
          raise ArgumentError, "must provide either `args` or a block" unless
            args.any? ^ block_given?

          @opts[:each] =
            if block_given?
              self.class.new.instance_eval(&blk)
            elsif args.size == 1 && args.first.is_a?(self.class)
              args.first
            else
              self.class.new.is(*args)
            end
          self
        end

        def is(type, *checks)
          @opts[:maybe] = false
          type(type, *checks)
          self
        end

        def maybe(type, *checks)
          @opts[:maybe] = true
          type(type, *checks)
          self
        end

        def type(type, *checks)
          @opts[:type] = Jet.type_check!("`type`", type, Symbol, Type).to_sym
          checks(checks)
          self
        end

        def opts
          @opts.dup
        end

        private

        def auto_type!(method, type)
          type(type) unless @opts[:type]
          raise ArgumentError, "##{method} can only be used with type :#{type}" unless
            @opts[:type] == type
          type
        end

        def check_set_with(checks)
          return unless @opts[:checks]&.any?
          Check::Set.new(*@opts[:checks].map { |name, *args| [checks[name]].concat(args) })
        end

        def type_with(types)
          type = types.fetch(@opts[:type].to_sym)
          return type.maybe if @opts[:maybe]
          raise "#{type.inspect} is a maybe? type (hint: use #maybe instead of #is)" if
            type.maybe?
          type
        end
      end
    end
  end
end
