require_relative "../practice_problems/problem_13_contract_lifecycle"

RSpec.describe ContractLifecycleManager do
  # Shared timestamps: CL_T0 base, CL_T1=+1d, CL_T2=+5d, CL_T3=+10d, CL_T4=+40d, CL_T5=+45d
  CL_T0 = "2025-01-01T09:00:00"
  CL_T1 = "2025-01-02T10:00:00"
  CL_T2 = "2025-01-06T11:00:00"
  CL_T3 = "2025-01-11T12:00:00"
  CL_T4 = "2025-02-10T09:00:00"
  CL_T5 = "2025-02-15T09:00:00"

  let(:fresh_cl) { described_class.new }

  let(:cl) do
    c = described_class.new
    c.create_contract("c-seed-1", "Vendor MSA", created_at: CL_T0, actor: "alice")
    c.transition("c-seed-1", "in_review", at: CL_T1, actor: "alice")
    c.transition("c-seed-1", "approved", at: CL_T2, actor: "bob")

    c.create_contract("c-seed-2", "NDA Agreement", created_at: CL_T0, actor: "alice")

    c.create_contract("c-seed-3", "SaaS License", created_at: CL_T0, actor: "carol")
    c.transition("c-seed-3", "in_review", at: CL_T1, actor: "carol")
    c.transition("c-seed-3", "approved", at: CL_T2, actor: "bob")
    c.transition("c-seed-3", "executed", at: CL_T3, actor: "carol")
    c.transition("c-seed-3", "active", at: CL_T4, actor: "carol")
    c.transition("c-seed-3", "terminated", at: CL_T5, actor: "carol")
    c
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Contract creation, field management, transitions
  # ---------------------------------------------------------------------------

  describe "#create_contract" do
    it "returns a contract in draft" do
      c = fresh_cl.create_contract("c-cr-1", "Title", created_at: CL_T0, actor: "alice")
      expect(c[:contract_id]).to eq("c-cr-1")
      expect(c[:state]).to eq("draft")
      expect(c[:title]).to eq("Title")
      expect(c[:fields]).to eq({})
    end

    it "stores created_at" do
      c = fresh_cl.create_contract("c-cr-ts", "Title", created_at: CL_T0, actor: "alice")
      expect(c[:created_at]).to eq(CL_T0)
    end

    it "raises on duplicate contract_id" do
      fresh_cl.create_contract("c-dup-lc", "A", created_at: CL_T0, actor: "alice")
      expect {
        fresh_cl.create_contract("c-dup-lc", "B", created_at: CL_T1, actor: "alice")
      }.to raise_error(ArgumentError)
    end

    it "records the initial audit entry" do
      fresh_cl.create_contract("c-audit-init", "T", created_at: CL_T0, actor: "alice")
      trail = fresh_cl.get_audit_trail("c-audit-init")
      expect(trail.length).to eq(1)
      expect(trail[0][:from_state]).to be_nil
      expect(trail[0][:to_state]).to eq("draft")
      expect(trail[0][:actor]).to eq("alice")
    end
  end

  describe "#set_field" do
    it "sets a field" do
      cl.set_field("c-seed-1", :value, 100_000)
      expect(cl.get_contract("c-seed-1")[:fields][:value]).to eq(100_000)
    end

    it "updates an existing field" do
      cl.set_field("c-seed-1", :value, 50_000)
      cl.set_field("c-seed-1", :value, 75_000)
      expect(cl.get_contract("c-seed-1")[:fields][:value]).to eq(75_000)
    end

    it "raises for an unknown contract" do
      expect { cl.set_field("no-such", :key, "val") }.to raise_error(KeyError)
    end
  end

  describe "#get_contract" do
    it "returns the contract" do
      c = cl.get_contract("c-seed-1")
      expect(c[:contract_id]).to eq("c-seed-1")
      expect(c[:state]).to eq("approved")
    end

    it "raises for an unknown contract" do
      expect { cl.get_contract("nonexistent") }.to raise_error(KeyError)
    end
  end

  describe "#transition" do
    it "updates state on a valid transition" do
      fresh_cl.create_contract("c-tr-1", "T", created_at: CL_T0, actor: "alice")
      fresh_cl.transition("c-tr-1", "in_review", at: CL_T1, actor: "alice")
      expect(fresh_cl.get_contract("c-tr-1")[:state]).to eq("in_review")
    end

    it "raises on an invalid transition" do
      fresh_cl.create_contract("c-tr-inv", "T", created_at: CL_T0, actor: "alice")
      expect {
        fresh_cl.transition("c-tr-inv", "approved", at: CL_T1, actor: "alice")
      }.to raise_error(ArgumentError)
    end

    it "raises transitioning out of a terminal state" do
      expect { cl.transition("c-seed-3", "draft", at: CL_T5, actor: "alice") }.to raise_error(ArgumentError)
    end

    it "allows draft -> in_review -> draft" do
      fresh_cl.create_contract("c-back", "T", created_at: CL_T0, actor: "alice")
      fresh_cl.transition("c-back", "in_review", at: CL_T1, actor: "alice")
      fresh_cl.transition("c-back", "draft", at: CL_T2, actor: "alice")
      expect(fresh_cl.get_contract("c-back")[:state]).to eq("draft")
    end

    it "appends an audit entry" do
      fresh_cl.create_contract("c-tr-audit", "T", created_at: CL_T0, actor: "alice")
      fresh_cl.transition("c-tr-audit", "in_review", at: CL_T1, actor: "bob")
      trail = fresh_cl.get_audit_trail("c-tr-audit")
      expect(trail.length).to eq(2)
      last = trail[-1]
      expect(last[:from_state]).to eq("draft")
      expect(last[:to_state]).to eq("in_review")
      expect(last[:actor]).to eq("bob")
    end

    it "raises for an unknown contract" do
      expect { cl.transition("no-such", "in_review", at: CL_T1, actor: "alice") }.to raise_error(KeyError)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Audit trail, by-state query, bulk advance
  # ---------------------------------------------------------------------------

  describe "#get_audit_trail" do
    it "returns all entries in order" do
      trail = cl.get_audit_trail("c-seed-1")
      expect(trail.length).to eq(3)
      expect(trail.map { |e| e[:to_state] }).to eq(%w[draft in_review approved])
    end

    it "returns the full trail for a terminal contract" do
      trail = cl.get_audit_trail("c-seed-3")
      expect(trail.map { |e| e[:to_state] }).to eq(%w[draft in_review approved executed active terminated])
    end

    it "raises for an unknown contract" do
      expect { cl.get_audit_trail("no-such") }.to raise_error(KeyError)
    end
  end

  describe "#get_contracts_by_state" do
    it "returns the correct contracts" do
      ids = cl.get_contracts_by_state("approved").map { |c| c[:contract_id] }
      expect(ids).to include("c-seed-1")
      expect(ids).not_to include("c-seed-2")
    end

    it "sorts by contract_id" do
      fresh_cl.create_contract("c-z", "Z", created_at: CL_T0, actor: "a")
      fresh_cl.create_contract("c-a", "A", created_at: CL_T0, actor: "a")
      fresh_cl.create_contract("c-m", "M", created_at: CL_T0, actor: "a")
      ids = fresh_cl.get_contracts_by_state("draft").map { |c| c[:contract_id] }
      expect(ids).to eq(ids.sort)
    end

    it "returns empty for an unused state" do
      expect(cl.get_contracts_by_state("expired")).to eq([])
    end
  end

  describe "#bulk_advance" do
    it "succeeds for all contracts" do
      3.times { |i| fresh_cl.create_contract("c-bulk-#{i}", "Contract #{i}", created_at: CL_T0, actor: "alice") }
      result = fresh_cl.bulk_advance(%w[c-bulk-0 c-bulk-1 c-bulk-2], "in_review", at: CL_T1, actor: "alice")
      expect(result[:succeeded].length).to eq(3)
      expect(result[:failed].length).to eq(0)
    end

    it "continues after a partial failure" do
      fresh_cl.create_contract("c-ok", "OK", created_at: CL_T0, actor: "alice")
      fresh_cl.create_contract("c-bad", "Bad", created_at: CL_T0, actor: "alice")
      fresh_cl.transition("c-bad", "in_review", at: CL_T1, actor: "alice")
      result = fresh_cl.bulk_advance(%w[c-ok c-bad], "in_review", at: CL_T2, actor: "alice")
      expect(result[:succeeded]).to include("c-ok")
      expect(result[:failed].any? { |f| f[:contract_id] == "c-bad" }).to be true
    end

    it "updates state for successes" do
      fresh_cl.create_contract("c-bs-1", "A", created_at: CL_T0, actor: "alice")
      fresh_cl.create_contract("c-bs-2", "B", created_at: CL_T0, actor: "alice")
      fresh_cl.bulk_advance(%w[c-bs-1 c-bs-2], "in_review", at: CL_T1, actor: "alice")
      expect(fresh_cl.get_contract("c-bs-1")[:state]).to eq("in_review")
      expect(fresh_cl.get_contract("c-bs-2")[:state]).to eq("in_review")
    end

    it "includes a reason for failures" do
      fresh_cl.create_contract("c-fail-r", "X", created_at: CL_T0, actor: "alice")
      result = fresh_cl.bulk_advance(["c-fail-r"], "approved", at: CL_T1, actor: "alice")
      expect(result[:failed].length).to eq(1)
      expect(result[:failed][0][:reason]).not_to eq("")
    end
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Lifecycle metrics and overdue contracts
  # ---------------------------------------------------------------------------

  describe "#get_lifecycle_metrics" do
    it "counts the total" do
      expect(cl.get_lifecycle_metrics[:total]).to eq(3)
    end

    it "counts by state" do
      metrics = cl.get_lifecycle_metrics
      expect(metrics[:by_state]["approved"]).to eq(1)
      expect(metrics[:by_state]["draft"]).to eq(1)
      expect(metrics[:by_state]["terminated"]).to eq(1)
    end

    it "only includes nonzero states" do
      cl.get_lifecycle_metrics[:by_state].each_value { |count| expect(count).to be > 0 }
    end

    it "counts terminal contracts" do
      expect(cl.get_lifecycle_metrics[:terminal_count]).to eq(1)
    end

    it "returns zeros for an empty manager" do
      metrics = fresh_cl.get_lifecycle_metrics
      expect(metrics[:total]).to eq(0)
      expect(metrics[:by_state]).to eq({})
      expect(metrics[:terminal_count]).to eq(0)
    end
  end

  describe "#get_overdue_contracts" do
    it "returns contracts stuck over 30 days" do
      fresh_cl.create_contract("c-overdue", "Old Contract", created_at: CL_T0, actor: "alice")
      fresh_cl.transition("c-overdue", "in_review", at: CL_T0, actor: "alice")
      ids = fresh_cl.get_overdue_contracts(as_of: CL_T4).map { |o| o[:contract_id] }
      expect(ids).to include("c-overdue")
    end

    it "does not flag a recent transition" do
      fresh_cl.create_contract("c-recent", "New Contract", created_at: CL_T0, actor: "alice")
      fresh_cl.transition("c-recent", "in_review", at: CL_T3, actor: "alice")
      ids = fresh_cl.get_overdue_contracts(as_of: CL_T4).map { |o| o[:contract_id] }
      expect(ids).not_to include("c-recent")
    end

    it "excludes terminal contracts" do
      ids = cl.get_overdue_contracts(as_of: CL_T5).map { |o| o[:contract_id] }
      expect(ids).not_to include("c-seed-3")
    end

    it "sorts by days_stuck descending" do
      fresh_cl.create_contract("c-od-a", "A", created_at: CL_T0, actor: "alice")
      fresh_cl.create_contract("c-od-b", "B", created_at: CL_T0, actor: "alice")
      fresh_cl.transition("c-od-a", "in_review", at: CL_T0, actor: "alice")
      fresh_cl.transition("c-od-b", "in_review", at: CL_T1, actor: "alice")
      days = fresh_cl.get_overdue_contracts(as_of: CL_T4).map { |o| o[:days_stuck] }
      expect(days).to eq(days.sort.reverse)
    end

    it "includes the required fields" do
      fresh_cl.create_contract("c-od-f", "Fields Test", created_at: CL_T0, actor: "alice")
      fresh_cl.transition("c-od-f", "in_review", at: CL_T0, actor: "alice")
      entry = fresh_cl.get_overdue_contracts(as_of: CL_T4).find { |o| o[:contract_id] == "c-od-f" }
      expect(entry).to include(:title, :state, :stuck_since, :days_stuck)
      expect(entry[:days_stuck]).to be >= 31
    end
  end
end
