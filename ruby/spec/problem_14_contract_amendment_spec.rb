require_relative "../practice_problems/problem_14_contract_amendment"

RSpec.describe ContractAmendmentManager do
  D_BASE  = "2025-01-01"
  D_AMD1  = "2025-03-01"
  D_AMD2  = "2025-06-01"
  D_AMD3  = "2025-09-01"
  D_AFTER = "2025-12-31"

  let(:fresh_mgr) { described_class.new }

  let(:mgr) do
    m = described_class.new
    m.add_contract("c-seed-1", "Vendor MSA", fields: { value: 50_000, payment_terms: "net-30", currency: "USD" })
    m.add_contract("c-seed-2", "NDA Agreement", fields: { term_years: 2, auto_renew: true })
    m.add_amendment("amd-s1", "c-seed-1", effective_on: D_AMD1, overrides: { payment_terms: "net-45" }, note: "extended payment terms")
    m.add_amendment("amd-s2", "c-seed-1", effective_on: D_AMD2, overrides: { value: 75_000 }, note: "scope increase")
    m
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Base contract management
  # ---------------------------------------------------------------------------

  describe "#add_contract" do
    it "returns the contract hash" do
      c = fresh_mgr.add_contract("c-add-1", "Test", fields: { x: 1 })
      expect(c[:contract_id]).to eq("c-add-1")
      expect(c[:title]).to eq("Test")
      expect(c[:fields][:x]).to eq(1)
    end

    it "stores a copy of fields" do
      original = { x: 1 }
      fresh_mgr.add_contract("c-copy-1", "Test", fields: original)
      original[:x] = 999
      expect(fresh_mgr.get_base_contract("c-copy-1")[:fields][:x]).to eq(1)
    end

    it "raises on duplicate contract_id" do
      fresh_mgr.add_contract("c-dup-am", "A", fields: {})
      expect { fresh_mgr.add_contract("c-dup-am", "B", fields: {}) }.to raise_error(ArgumentError)
    end
  end

  describe "#get_base_contract" do
    it "returns the original fields" do
      base = mgr.get_base_contract("c-seed-1")
      expect(base[:fields][:payment_terms]).to eq("net-30")
      expect(base[:fields][:value]).to eq(50_000)
    end

    it "raises for an unknown contract" do
      expect { mgr.get_base_contract("no-such") }.to raise_error(KeyError)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Amendments and effective contract
  # ---------------------------------------------------------------------------

  describe "#add_amendment" do
    it "returns the amendment hash" do
      amd = mgr.add_amendment("amd-add-1", "c-seed-1", effective_on: D_AMD3, overrides: { currency: "EUR" }, note: "switch currency")
      expect(amd[:amendment_id]).to eq("amd-add-1")
      expect(amd[:contract_id]).to eq("c-seed-1")
      expect(amd[:effective_on]).to eq(D_AMD3)
      expect(amd[:overrides]).to eq({ currency: "EUR" })
      expect(amd[:note]).to eq("switch currency")
    end

    it "stores a copy of overrides" do
      fresh_mgr.add_contract("c-amd-copy", "T", fields: { x: 1 })
      overrides = { x: 2 }
      fresh_mgr.add_amendment("amd-copy-1", "c-amd-copy", effective_on: D_AMD1, overrides: overrides, note: "")
      overrides[:x] = 999
      expect(fresh_mgr.get_amendments("c-amd-copy")[0][:overrides][:x]).to eq(2)
    end

    it "raises on a duplicate amendment_id" do
      expect { mgr.add_amendment("amd-s1", "c-seed-1", effective_on: D_AMD3, overrides: {}, note: "") }.to raise_error(ArgumentError)
    end

    it "raises for an unknown contract" do
      expect { mgr.add_amendment("amd-new", "no-such", effective_on: D_AMD1, overrides: {}, note: "") }.to raise_error(KeyError)
    end
  end

  describe "#get_amendments" do
    it "sorts by effective_on" do
      dates = mgr.get_amendments("c-seed-1").map { |a| a[:effective_on] }
      expect(dates).to eq(dates.sort)
    end

    it "returns empty when there are none" do
      expect(mgr.get_amendments("c-seed-2")).to eq([])
    end

    it "raises for an unknown contract" do
      expect { mgr.get_amendments("no-such") }.to raise_error(KeyError)
    end

    it "orders same-date amendments by amendment_id" do
      fresh_mgr.add_contract("c-same-dt", "T", fields: { x: 0 })
      fresh_mgr.add_amendment("amd-z", "c-same-dt", effective_on: D_AMD1, overrides: { x: 2 }, note: "")
      fresh_mgr.add_amendment("amd-a", "c-same-dt", effective_on: D_AMD1, overrides: { x: 1 }, note: "")
      ids = fresh_mgr.get_amendments("c-same-dt").map { |a| a[:amendment_id] }
      expect(ids).to eq(ids.sort)
    end
  end

  describe "#get_effective_contract" do
    it "returns base fields before any amendments" do
      fields = mgr.get_effective_contract("c-seed-1", as_of_date: D_BASE)
      expect(fields[:payment_terms]).to eq("net-30")
      expect(fields[:value]).to eq(50_000)
    end

    it "applies the first amendment" do
      fields = mgr.get_effective_contract("c-seed-1", as_of_date: "2025-04-15")
      expect(fields[:payment_terms]).to eq("net-45")
      expect(fields[:value]).to eq(50_000)
    end

    it "applies all amendments" do
      fields = mgr.get_effective_contract("c-seed-1", as_of_date: D_AFTER)
      expect(fields[:payment_terms]).to eq("net-45")
      expect(fields[:value]).to eq(75_000)
    end

    it "preserves unamended fields" do
      fields = mgr.get_effective_contract("c-seed-1", as_of_date: D_AFTER)
      expect(fields[:currency]).to eq("USD")
    end

    it "returns base when there are no amendments" do
      fields = mgr.get_effective_contract("c-seed-2", as_of_date: D_AFTER)
      expect(fields[:term_years]).to eq(2)
      expect(fields[:auto_renew]).to be true
    end

    it "treats the exact effective date as inclusive" do
      fields = mgr.get_effective_contract("c-seed-1", as_of_date: D_AMD1)
      expect(fields[:payment_terms]).to eq("net-45")
    end

    it "does not mutate the base contract" do
      mgr.get_effective_contract("c-seed-1", as_of_date: D_AFTER)
      expect(mgr.get_base_contract("c-seed-1")[:fields][:payment_terms]).to eq("net-30")
    end

    it "raises for an unknown contract" do
      expect { mgr.get_effective_contract("no-such", as_of_date: D_AFTER) }.to raise_error(KeyError)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Value history and amendment summary
  # ---------------------------------------------------------------------------

  describe "#get_value_history" do
    it "includes the base value first" do
      history = mgr.get_value_history("c-seed-1", :value)
      expect(history[0][:source]).to eq("base")
      expect(history[0][:value]).to eq(50_000)
    end

    it "includes an amendment override" do
      sources = mgr.get_value_history("c-seed-1", :payment_terms).map { |e| e[:source] }
      expect(sources).to include("amd-s1")
    end

    it "excludes amendments that did not touch the field" do
      sources = mgr.get_value_history("c-seed-1", :payment_terms).map { |e| e[:source] }
      expect(sources).not_to include("amd-s2")
    end

    it "sorts chronologically" do
      history = mgr.get_value_history("c-seed-1", :value)
      expect(history[0][:source]).to eq("base")
      dates = history.select { |e| e[:source] != "base" }.map { |e| e[:effective_on] }
      expect(dates).to eq(dates.sort)
    end

    it "raises when the field is not present" do
      expect { mgr.get_value_history("c-seed-1", :nonexistent_field) }.to raise_error(KeyError)
    end

    it "raises for an unknown contract" do
      expect { mgr.get_value_history("no-such", :value) }.to raise_error(KeyError)
    end
  end

  describe "#get_amendment_summary" do
    it "counts amendments" do
      expect(mgr.get_amendment_summary("c-seed-1")[:amendment_count]).to eq(2)
    end

    it "sorts fields_amended" do
      summary = mgr.get_amendment_summary("c-seed-1")
      expect(summary[:fields_amended]).to eq([:payment_terms, :value].sort_by(&:to_s))
    end

    it "reports the latest amendment date" do
      expect(mgr.get_amendment_summary("c-seed-1")[:latest_amendment]).to eq(D_AMD2)
    end

    it "reflects all amendments in current_fields" do
      summary = mgr.get_amendment_summary("c-seed-1")
      expect(summary[:current_fields][:payment_terms]).to eq("net-45")
      expect(summary[:current_fields][:value]).to eq(75_000)
    end

    it "returns a nil latest_amendment with none" do
      summary = mgr.get_amendment_summary("c-seed-2")
      expect(summary[:latest_amendment]).to be_nil
      expect(summary[:amendment_count]).to eq(0)
      expect(summary[:fields_amended]).to eq([])
    end

    it "raises for an unknown contract" do
      expect { mgr.get_amendment_summary("no-such") }.to raise_error(KeyError)
    end
  end
end
