# frozen_string_literal: true

module Jet
  class Contract
    class Check
      class Set
        attr_reader :checks

        def initialize(*checks)
          @checks = []
          checks.each { |c| add!(c) }
          @checks.freeze
        end

        def call(output)
          @checks.each do |(check, *args)|
            check.(output, *args).tap { |r| return r if Jet.failure?(r) }
          end
          Result.success(output)
        end

        def to_builder
          @checks.map { |(c, *args)| [c.name].concat(args) }
        end

        private

        def add!(check)
          case check
          when Array
            add_with_args!(check.first, *check[1..-1])
          when Hash
            check.each { |c, args| add_with_args!(c, args) }
          when Check
            add_with_args!(check)
          else
            Jet.type_check!(check.inspect, check, Array, Hash, Check)
          end
          @checks
        end

        def add_with_args!(check, *args)
          Jet.type_check!(check.inspect, check, Check)
          @checks << [check].concat(args)
        end
      end
    end
  end
end
