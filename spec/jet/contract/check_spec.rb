require "spec_helper"

module Jet
  class Contract
    class CheckSpec < Minitest::Spec
      it "creates a check" do
        c = Check.new(:respond_to?) { |output, method_name| output.respond_to?(method_name) }

        assert c.("0", :to_i).success?
        r = c.([], :to_i)
        assert r.failure?
        _(r.output).must_equal(%i[check_failure respond_to?])
      end

      it "returns specific failure details" do
        c = Check.new(:exact_number) do |output, size|
          case output <=> size
          when 1
            Result.failure(:too_large)
          when -1
            Result.failure(:too_small)
          else
            Result.success
          end
        end

        assert c.(1, 1).success?

        r = c.(1, 0)
        assert r.failure?
        _(r.output).must_equal(%i[check_failure exact_number too_large])

        r = c.(0, 1)
        assert r.failure?
        _(r.output).must_equal(%i[check_failure exact_number too_small])
      end

      it "checks for any?" do
        assert Check[:any?].([]).failure?
        assert Check[:any?].([1]).success?
      end

      it "checks empty?" do
        assert Check[:empty?].([1]).failure?
        assert Check[:empty?].([]).success?
      end

      it "checks eql" do
        assert Check[:eql].(1, 0).failure?
        assert Check[:eql].(1, 1).success?
      end

      it "checks gt" do
        assert Check[:gt].(1, 2).failure?
        assert Check[:gt].(1, 0).success?
      end

      it "checks gte" do
        assert Check[:gte].(1, 2).failure?
        assert Check[:gte].(1, 1).success?
        assert Check[:gte].(1, 0).success?
      end

      it "checks in" do
        assert Check[:in].("a", %w[a b c]).success?
        assert Check[:in].("d", %w[a b c]).failure?
      end

      it "checks lt" do
        assert Check[:lt].(1, 0).failure?
        assert Check[:lt].(1, 2).success?
      end

      it "checks lte" do
        assert Check[:lte].(1, 0).failure?
        assert Check[:lte].(1, 1).success?
        assert Check[:lte].(1, 2).success?
      end

      it "checks match" do
        assert Check[:match].("a", /a/).success?
        assert Check[:match].("d", /b/).failure?
      end

      it "checks max_size" do
        assert Check[:max_size].("a", 1).success?
        assert Check[:max_size].("ab", 1).failure?
      end

      it "checks min_size" do
        assert Check[:min_size].("ab", 2).success?
        assert Check[:min_size].("a", 2).failure?
      end

      it "checks negative?" do
        assert Check[:negative?].(-1).success?
        assert Check[:negative?].(0).failure?
      end

      it "checks nin" do
        assert Check[:nin].("d", %w[a b c]).success?
        assert Check[:nin].("a", %w[a b c]).failure?
      end

      it "checks not" do
        assert Check[:not].("a", "b").success?
        assert Check[:not].("a", "a").failure?
      end

      it "checks positive?" do
        assert Check[:positive?].(1).success?
        assert Check[:positive?].(0).failure?
      end

      it "checks size" do
        assert Check[:size].(%w[a], 1..5).success?
        assert Check[:size].(%w[a b c d e], 1..5).success?
        r = Check[:size].("abcdef", 1..5)
        assert r.failure?
        _(r.output).must_equal(%i[check_failure size range])
        _(r[:min]).must_equal(1)
        _(r[:max]).must_equal(5)

        assert Check[:size].("a", 1).success?
        r = Check[:size].(%w[a b], 1)
        assert r.failure?
        _(r.output).must_equal(%i[check_failure size exact])
        _(r[:size]).must_equal(1)
      end
    end
  end
end
