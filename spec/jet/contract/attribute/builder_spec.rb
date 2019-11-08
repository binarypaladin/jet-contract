require "spec_helper"

module Jet
  class Contract
    class Attribute
      class BuilderSpec < Minitest::Spec
        def check_each(builder)
          builder.(:http).tap do |a|
            _(a.type.name).must_equal(:array)
            _(a.(%w[1 2]).output).must_equal([1, 2])
          end
        end

        it "creates an attribute builder using options" do
          b = Builder.new(checks: [:positive?, [:lte, 10], { gte: 5 }], type: :integer)
          a = b.call

          _(a.("1").output).must_equal(%i[type_coercion_failure integer])
          _(a.(1).output).must_equal(%i[check_failure gte])
          _(a.(11).output).must_equal(%i[check_failure lte])
          _(a.(5.0).output).must_equal(5)

          _(b.call(Type::Strict).("5").output).must_equal(%i[type_coercion_failure integer])
          _(b.call(:http).("5").output).must_equal(5)
        end

        it "creates an attribute builder with :contract as a contract builder" do
          b = Builder.new(contract: Contract::Builder.new(n: Builder.new(type: :integer)))
          _(b.(:http).("n" => "1").output).must_equal(n: 1)
        end

        it "creates an attribute builder with :each as builder syntax" do
          a = check_each(Builder.new(each: %i[integer positive?]))
          assert a.opts[:each].is?
        end

        it "creates an attribute builder with :each as a builder" do
          each = Builder.new(type: Type::JSON[:integer], maybe: true, checks: [:positive?])
          a = check_each(Builder.new(each: each))
          assert a.opts[:each].maybe?
        end

        it "creates an attribute builder with :each and :contract as DSL" do
          b = Builder.new.each { maybe(:integer, :positive?, lte: 10) }
          a = check_each(b)
          assert a.opts[:each].maybe?

          b = Builder.new.each { contract { required(:color).is(:string, in: %w[r g b]) } }
          r = b.call.([{ "color" => "r" }, { "color" => "g" }])
          _(r.output).must_equal([{ color: "r" }, { color: "g" }])
        end

        it "creates an attribute using the build DSL" do
          a = Attribute.build(:http) { maybe(:integer, :positive?, lte: 10) }
          assert a.(nil).success?
          assert a.("1").success?
        end
      end
    end
  end
end
