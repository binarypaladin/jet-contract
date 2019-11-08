require "spec_helper"

module Jet
  class Contract
    class BuilderSpec < Minitest::Spec
      it "builds a contract using the build DSL" do
        c = Contract.build(:http) do
          required(:name).is(:string)
          required(:age).is(:integer, :positive?)
          required(:pets).each do
            contract do
              required(:name).is(:string)
              required(:type).is(:string, in: %w[cat dog fish])
            end
          end
        end

        input = {
          "name" => "John Smith",
          "age" => "35",
          "pets" => [{ "name" => "Fido", "type" => "dog" }]
        }

        r = c.(input)
        assert r.success?
        _(r.output).must_equal(name: "John Smith", age: 35, pets: [{ name: "Fido", type: "dog" }])

        input["pets"][0]["type"] = "DEAD PARROT"
        r = c.(input)
        assert r.failure?
        _(r.errors_at(:pets, 0, :type).first.output).must_equal(%i[check_failure in])
      end

      it "builds a contract from attribute builders" do
        b = Builder.new(
          name: Attribute::Builder.new(type: :string),
          date_of_birth: Attribute::Builder.new(type: :date, required: false)
        )

        c = b.(:http)
        _(c.("name" => "John Doe").output).must_equal(name: "John Doe")
        _(c.("name" => "John Doe", "date_of_birth" => "1980-01-01").output)
          .must_equal(name: "John Doe", date_of_birth: Date.new(1980, 1, 1))
      end
    end
  end
end
