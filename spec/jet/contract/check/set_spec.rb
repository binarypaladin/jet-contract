require "spec_helper"

module Jet
  class Contract
    class Check
      class SetSpec < Minitest::Spec
        it "creates a set of checks for an output" do
          set = Set.new(
            Check[:positive?],
            [Check[:gt], 1],
            Check[:lte] => 9,
            Check[:nin] => [4, 7]
          )

          r = set.(2)
          assert r.success?
          _(r.output).must_equal(2)

          r = set.(4)
          assert r.failure?
          _(r.output.last).must_equal(:nin)

          r = set.(10)
          assert r.failure?
          _(r.output.last).must_equal(:lte)

          r = set.(1)
          assert r.failure?
          _(r.output.last).must_equal(:gt)

          r = set.(0)
          assert r.failure?
          _(r.output.last).must_equal(:positive?)
        end
      end
    end
  end
end
