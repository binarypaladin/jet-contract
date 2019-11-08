# frozen_string_literal: true

require "jet/contract/check"
require "jet/contract/check/set"

module Jet
  class Contract
    class Attribute
      attr_reader :checks, :type

      def self.build(*args, &blk)
        raise ArgumentError, "no block given" unless block_given?
        Builder.new.instance_eval(&blk).call(*args)
      end

      def initialize(type, checks = nil, contract: nil, each: nil, required: true, **)
        @type = Jet.type_check!("`type`", type, Type)
        @checks = Jet.type_check!("`checks`", checks, Check::Set, NilClass)

        raise ArgumentError, "cannot set both :contract and :each" if contract && each

        @opts = {
          contract: Jet.type_check!(":contract", contract, Contract, NilClass),
          each: Jet.type_check!(":each", each, Attribute, NilClass),
          required: required ? true : false
        }
      end

      def call(input, at = [])
        coerce(input).yield_self { |r| result_at(Jet.failure?(r) ? r : check(r.output), at) }
      end

      def check(output)
        return Result.success if output.nil?
        checks&.(output)&.tap { |r| return r if r.failure? }
        check_contract(output) || check_each(output) || Result.success(output)
      end

      def coerce(input)
        type.(input)
      end

      def is?
        !maybe?
      end

      def maybe?
        type.maybe?
      end

      def optional?
        !required?
      end

      def opts
        @opts.dup
      end

      def required?
        @opts[:required]
      end

      def to_builder
        Builder.new(
          checks: @checks&.to_builder,
          contract: @opts[:contract]&.to_builder,
          each: @opts[:each]&.to_builder,
          is: is?,
          required: required?,
          type: type.name
        )
      end

      def to_sym
        name
      end

      private

      def check_contract(output)
        @opts[:contract]&.(output)
      end

      def check_each(output)
        return unless @opts[:each]
        results = output.map.with_index { |v, i| @opts[:each].(v).with(at: [i]) }
        return Result.success(results.map(&:output)) if results.all?(&:success?)
        Result.failure(
          :check_each_failure,
          errors: results.select(&:failure?),
          input: output
        )
      end

      def result_at(result, at)
        new_at = Array(at) + Array(result.at)
        result.with(
          at: new_at,
          errors: result.errors.map { |r| result_at(r, new_at) }
        )
      end
    end
  end
end

require "jet/contract/attribute/builder"
