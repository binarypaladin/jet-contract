# frozen_string_literal: true

module Jet
  class Contract
    class Check
      def self.[](key)
        BuiltIn[key]
      end

      attr_reader :check, :name

      def initialize(name, &check)
        raise ArgumentError, "no block given" unless block_given?
        @check = lambda(&check)
        @name = name
      end

      def call(output, *args)
        result = check.(output, *args)
        return Result.success(output, args: args) if Jet.success?(result)
        Result.failure(error(result), Jet.context(result, args: args, input: output))
      end

      def inspect
        "#<#{self.class.name}:#{name}>"
      end

      def to_sym
        name
      end

      private

      def error(result)
        [:check_failure, name].tap { |errors| errors << result.output if result }
      end

      module BuiltIn
        extend Core::InstanceRegistry
        type Check

        [
          Check.new(:any?, &:any?),
          Check.new(:empty?, &:empty?),
          Check.new(:eql) { |output, other| output == other },
          Check.new(:gt) { |output, other| output > other },
          Check.new(:gte) { |output, other| output >= other },
          Check.new(:in) { |output, collection| collection.include?(output) },
          Check.new(:lt) { |output, other| output < other },
          Check.new(:lte) { |output, other| output <= other },
          Check.new(:match) { |output, regex| output.match?(regex) },
          Check.new(:max_size) { |output, size| output.size <= size },
          Check.new(:min_size) { |output, size| output.size >= size },
          Check.new(:negative?, &:negative?),
          Check.new(:nin) { |output, collection| !collection.include?(output) },
          Check.new(:not) { |output, other| output != other },
          Check.new(:positive?, &:positive?),
          Check.new(:size) do |output, size_or_range|
            case size_or_range
            when Range
              return true if size_or_range.include?(output.size)
              Result.failure(:range, max: size_or_range.max, min: size_or_range.min)
            else
              return true if output.size == size_or_range
              Result.failure(:exact, size: size_or_range)
            end
          end
        ].map { |c| [c.name, c] }.to_h.tap { |checks| register(checks).freeze }
      end
    end
  end
end
