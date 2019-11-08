require "spec_helper"

module Jet
  class Contract
    class AttributeSpec < Minitest::Spec
      it "creates an attribute with checks" do
        att = Attribute.new(
          Type::HTTP::Integer.maybe,
          Check::Set.new(Check[:positive?], Check[:lte] => 9)
        )

        assert att.required?
        refute att.optional?

        assert att.maybe?
        refute att.is?

        r = att.("5.5")
        assert r.failure?
        _(r.output.first).must_equal(:type_coercion_failure)
        _(r[:input]).must_equal("5.5")

        r = att.("10")
        assert r.failure?
        _(r.output).must_equal(%i[check_failure lte])
        _(r[:input]).must_equal(10)

        r = att.(0)
        assert r.failure?
        _(r.output).must_equal(%i[check_failure positive?])
        _(r[:input]).must_equal(0)

        r = att.("1")
        assert r.success?
        _(r.output).must_equal(1)

        r = att.(nil)
        assert r.success?
        _(r.output).must_be_nil
      end

      it "creates an optional attribute with no checks" do
        att = Attribute.new(Type::Strict::String, required: false)

        assert att.optional?
        refute att.required?

        assert att.is?
        refute att.maybe?

        r = att.(nil)
        assert r.failure?
        _(r.output.first).must_equal(:type_coercion_failure)
        _(r[:input]).must_be_nil

        r = att.("x")
        assert r.success?
        _(r.output).must_equal("x")
      end

      it "checks each output of an array attribute" do
        each_att = Attribute.new(
          Type::HTTP::Integer,
          Check::Set.new(Check[:positive?])
        )

        att = Attribute.new(
          Type::Strict::Array,
          Check::Set.new(Check[:any?]),
          each: each_att
        )

        r = att.({})
        assert r.failure?
        _(r.output.first).must_equal(:type_coercion_failure)

        r = att.([])
        assert r.failure?
        _(r.output).must_equal(%i[check_failure any?])

        r = att.(%w[1 2 3])
        assert r.success?
        _(r.output).must_equal([1, 2, 3])

        r = att.(%w[-1 2 x], :key)
        assert r.failure?
        _(r.output).must_equal(:check_each_failure)
        _(r[:at]).must_equal([:key])

        err1 = r.errors[0]
        _(err1.output).must_equal(%i[check_failure positive?])
        _(err1[:at]).must_equal([:key, 0])

        err2 = r.errors[1]
        _(err2.output.first).must_equal(:type_coercion_failure)
        _(err2[:at]).must_equal([:key, 2])
      end

      it "checks a hash output using a Contract" do
        att = Attribute.new(
          Type::Strict::Hash,
          Check::Set.new(Check[:any?]),
          contract: Contract.new(
            boolean: Attribute.new(Type::HTTP::Boolean),
            number: Attribute.new(Type::HTTP::Integer, Check::Set.new(Check[:positive?]))
          )
        )

        r = att.([])
        assert r.failure?
        _(r.output.first).must_equal(:type_coercion_failure)

        r = att.("boolean" => "true", "number" => "1")
        assert r.success?
        _(r.output).must_equal(boolean: true, number: 1)

        r = att.("boolean" => "maybe", "number" => "-1")
        assert r.failure?

        err1 = r.errors[0]
        _(err1[:at]).must_equal(%i[boolean])
        _(err1.output.first).must_equal(:type_coercion_failure)

        err2 = r.errors[1]
        _(err2[:at]).must_equal(%i[number])
        _(err2.output).must_equal(%i[check_failure positive?])
      end
    end
  end
end
