require "spec_helper"

module Jet
  class ContractSpec < Minitest::Spec
    let(:attributes) do
      {
        age: Contract::Attribute.new(Type::HTTP[:integer]),
        email: Contract::Attribute.new(
          Type::HTTP[:string],
          Contract::Check::Set.new(Contract::Check[:match] => /@/),
          required: false
        ),
        name: Contract::Attribute.new(
          Type::HTTP[:string],
          Contract::Check::Set.new(Contract::Check[:size] => 3..24)
        ),
        pet: pet_attribute,
        role: Contract::Attribute.new(
          Type::HTTP[:string],
          Contract::Check::Set.new(Contract::Check[:in] => role_opts)
        )
      }
    end

    let(:color_opts) { %w[black brown gray orange tan white] }
    let(:contract) { Contract.new(attributes) }

    let(:pet_attribute) do
      Contract::Attribute.new(
        Type::Strict[:hash],
        contract: Contract.new(
          colors: Contract::Attribute.new(
            Type::Strict[:array],
            each: Contract::Attribute.new(
              Type::HTTP[:string],
              Contract::Check::Set.new(Contract::Check[:in] => color_opts)
            )
          ),
          name: Contract::Attribute.new(
            Type::HTTP[:string],
            Contract::Check::Set.new(Contract::Check[:size] => 3..12)
          ),
          type: Contract::Attribute.new(
            Type::HTTP[:string],
            Contract::Check::Set.new(Contract::Check[:in] => pet_opts)
          )
        )
      )
    end

    let(:pet_opts) { %w[cat dog fish] }
    let(:role_opts) { %w[admin user] }
    let(:valid_input) do
      {
        "age" => "30",
        "name" => "John Smith",
        "pet" => {
          "colors" => %w[black white],
          "name" => "Rex",
          "type" => "dog"
        },
        role: "user"
      }
    end

    it "returns coerced and validated output" do
      expected_output = {
        age: 30,
        name: "John Smith",
        pet: {
          colors: %w[black white],
          name: "Rex",
          type: "dog"
        },
        role: "user"
      }

      r = contract.(valid_input.merge(sign: "Aries"))

      assert r.success?
      refute r.output.key?(:email)
      refute r.output.key?(:sign)
      _(r.output).must_equal(expected_output)

      email = { email: "john.smith@example.com" }
      r = contract.(valid_input.merge(email))
      assert r.success?
      _(r.output).must_equal(expected_output.merge(email))

      with_stringified_keys = contract.with(keys_out: :string)
      r = with_stringified_keys.(valid_input)
      assert r.success?
      _(r.output).must_equal(expected_output.transform_keys(&:to_s))
    end

    it "returns errors when input cannot be validated or coerced" do
      invalid_input = {
        "age" => "thirty",
        email: "name@example.com",
        pet: { "colors" => %w[black green white], "type" => "dog" },
        role: "manager"
      }

      r = contract.(invalid_input)
      assert r.failure?
      _(r[:input]).must_equal(invalid_input)

      _(r.errors_at(:age).first.output).must_equal(%i[type_coercion_failure integer])
      _(r.errors_at(:name).first.output).must_equal(:key_missing_failure)
      _(r.errors_at(:role).first.output).must_equal(%i[check_failure in])
      _(r.errors_at(:role).first[:args].first).must_equal(role_opts)
      _(r.errors_at(:pet, :colors, 1).first.output).must_equal(%i[check_failure in])
      _(r.errors_at(:pet, :name).first.output).must_equal(:key_missing_failure)
    end

    it "merges multiple contracts" do
      c = Contract.new({ name: attributes[:name] }, keys_out: :string)

      merged_contract = c.with(
        Contract.new(age: attributes[:age]),
        Contract.new(role: attributes[:role]),
        keys_out: :symbol
      )

      r = merged_contract.(valid_input)
      assert r.success?
      _(r.output).must_equal(age: 30, name: "John Smith", role: "user")
    end

    it "rebuilds a contract with new types" do
      c = Contract.build(:json) { required(:n).is(:integer) }
      assert c.(n: "1").failure?
      assert c.rebuild(:http).(n: "1").success?
    end
  end
end
