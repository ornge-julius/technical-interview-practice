require_relative "../practice_problems/problem_17_claims_pipeline"

RSpec.describe ClaimsPipeline do
  d0 = "2025-01-15"
  t0 = "2025-02-01T09:00:00"
  t1 = "2025-02-03T10:00:00"
  t2 = "2025-02-10T14:00:00"
  t3 = "2025-02-20T11:00:00"
  t4 = "2025-03-01T09:00:00"

  let(:fresh_pipeline) { described_class.new }

  # Pre-seeded pipeline:
  #   clm-001  pol-101  epl   claimed=75_000  reserve=50_000  -> settled (approved=60_000)
  #   clm-002  pol-101  epl   claimed=30_000  reserve=30_000  -> investigating
  #   clm-003  pol-102  do    claimed=200_000 reserve=150_000 -> evaluation
  #   clm-004  pol-103  epl   claimed=10_000  reserve=10_000  -> denied
  let(:pipeline) do
    p = described_class.new

    p.file_claim("clm-001", policy_id: "pol-101", coverage_type: "epl",
                 incident_date: d0, filed_at: t0,
                 claimed_amount: 75_000, reserve_amount: 50_000, actor: "adj-1")
    p.advance_status("clm-001", "investigating", at: t1, actor: "adj-1")
    p.advance_status("clm-001", "evaluation", at: t2, actor: "adj-1")
    p.settle_claim("clm-001", approved_amount: 60_000, settled_at: t3, actor: "adj-1")

    p.file_claim("clm-002", policy_id: "pol-101", coverage_type: "epl",
                 incident_date: d0, filed_at: t0,
                 claimed_amount: 30_000, reserve_amount: 30_000, actor: "adj-2")
    p.advance_status("clm-002", "investigating", at: t1, actor: "adj-2")

    p.file_claim("clm-003", policy_id: "pol-102", coverage_type: "do",
                 incident_date: d0, filed_at: t0,
                 claimed_amount: 200_000, reserve_amount: 150_000, actor: "adj-1")
    p.advance_status("clm-003", "investigating", at: t1, actor: "adj-1")
    p.advance_status("clm-003", "evaluation", at: t2, actor: "adj-1")

    p.file_claim("clm-004", policy_id: "pol-103", coverage_type: "epl",
                 incident_date: d0, filed_at: t0,
                 claimed_amount: 10_000, reserve_amount: 10_000, actor: "adj-3")
    p.advance_status("clm-004", "investigating", at: t1, actor: "adj-3")
    p.advance_status("clm-004", "evaluation", at: t2, actor: "adj-3")
    p.deny_claim("clm-004", reason: "Coverage exclusion applies.", denied_at: t3, actor: "adj-3")

    p
  end

  # ── Part 1 — Claim filing, status transitions, reserve updates ─────────

  describe "#file_claim" do
    it "returns a claim in the filed state" do
      c = fresh_pipeline.file_claim("clm-new", policy_id: "pol-200", coverage_type: "do",
                                     incident_date: d0, filed_at: t0,
                                     claimed_amount: 50_000, reserve_amount: 40_000, actor: "adj-1")
      expect(c[:claim_id]).to eq("clm-new")
      expect(c[:status]).to eq("filed")
      expect(c[:approved_amount]).to be_nil
      expect(c[:claimed_amount]).to eq(50_000)
      expect(c[:reserve_amount]).to eq(40_000)
    end

    it "records an initial filed event" do
      fresh_pipeline.file_claim("clm-evt", policy_id: "pol-200", coverage_type: "epl",
                                 incident_date: d0, filed_at: t0,
                                 claimed_amount: 20_000, reserve_amount: 15_000, actor: "adj-1")
      c = fresh_pipeline.get_claim("clm-evt")
      expect(c[:events].length).to eq(1)
      expect(c[:events][0][:action]).to eq("filed")
      expect(c[:events][0][:actor]).to eq("adj-1")
    end

    it "raises on a duplicate claim_id" do
      fresh_pipeline.file_claim("clm-dup", policy_id: "pol-200", coverage_type: "do",
                                 incident_date: d0, filed_at: t0,
                                 claimed_amount: 10_000, reserve_amount: 10_000, actor: "adj-1")
      expect do
        fresh_pipeline.file_claim("clm-dup", policy_id: "pol-201", coverage_type: "do",
                                   incident_date: d0, filed_at: t1,
                                   claimed_amount: 5_000, reserve_amount: 5_000, actor: "adj-1")
      end.to raise_error(ArgumentError)
    end

    it "raises when claimed_amount is zero" do
      expect do
        fresh_pipeline.file_claim("clm-zero", policy_id: "pol-200", coverage_type: "epl",
                                   incident_date: d0, filed_at: t0,
                                   claimed_amount: 0, reserve_amount: 10_000, actor: "adj-1")
      end.to raise_error(ArgumentError)
    end

    it "raises when reserve_amount is zero" do
      expect do
        fresh_pipeline.file_claim("clm-zero-r", policy_id: "pol-200", coverage_type: "epl",
                                   incident_date: d0, filed_at: t0,
                                   claimed_amount: 10_000, reserve_amount: 0, actor: "adj-1")
      end.to raise_error(ArgumentError)
    end
  end

  describe "#get_claim" do
    it "returns the existing claim" do
      expect(pipeline.get_claim("clm-001")[:claim_id]).to eq("clm-001")
    end

    it "raises on an unknown claim_id" do
      expect { pipeline.get_claim("no-such") }.to raise_error(KeyError)
    end
  end

  describe "#advance_status" do
    it "updates status on a valid transition" do
      fresh_pipeline.file_claim("clm-adv", policy_id: "pol-200", coverage_type: "epl",
                                 incident_date: d0, filed_at: t0,
                                 claimed_amount: 20_000, reserve_amount: 15_000, actor: "adj-1")
      fresh_pipeline.advance_status("clm-adv", "investigating", at: t1, actor: "adj-1")
      expect(fresh_pipeline.get_claim("clm-adv")[:status]).to eq("investigating")
    end

    it "raises on an invalid transition" do
      fresh_pipeline.file_claim("clm-inv", policy_id: "pol-200", coverage_type: "epl",
                                 incident_date: d0, filed_at: t0,
                                 claimed_amount: 20_000, reserve_amount: 15_000, actor: "adj-1")
      expect do
        fresh_pipeline.advance_status("clm-inv", "evaluation", at: t1, actor: "adj-1")
      end.to raise_error(ArgumentError)
    end

    it "raises when trying to settle via advance_status" do
      expect { pipeline.advance_status("clm-003", "settled", at: t3, actor: "adj-1") }.to raise_error(ArgumentError)
    end

    it "raises when trying to deny via advance_status" do
      expect { pipeline.advance_status("clm-003", "denied", at: t3, actor: "adj-1") }.to raise_error(ArgumentError)
    end

    it "appends a status_change event" do
      fresh_pipeline.file_claim("clm-ev2", policy_id: "pol-200", coverage_type: "epl",
                                 incident_date: d0, filed_at: t0,
                                 claimed_amount: 20_000, reserve_amount: 15_000, actor: "adj-1")
      fresh_pipeline.advance_status("clm-ev2", "investigating", at: t1, actor: "adj-2")
      last = fresh_pipeline.get_claim("clm-ev2")[:events].last
      expect(last[:action]).to eq("status_change")
      expect(last[:payload][:from_status]).to eq("filed")
      expect(last[:payload][:to_status]).to eq("investigating")
    end

    it "raises on an unknown claim_id" do
      expect { pipeline.advance_status("no-such", "investigating", at: t1, actor: "adj-1") }.to raise_error(KeyError)
    end
  end

  describe "#update_reserve" do
    it "updates the reserve amount" do
      pipeline.update_reserve("clm-002", 35_000, at: t2, actor: "adj-2")
      expect(pipeline.get_claim("clm-002")[:reserve_amount]).to eq(35_000)
    end

    it "appends a reserve_update event" do
      pipeline.update_reserve("clm-002", 35_000, at: t2, actor: "adj-2")
      last = pipeline.get_claim("clm-002")[:events].last
      expect(last[:action]).to eq("reserve_update")
      expect(last[:payload][:old_reserve]).to eq(30_000)
      expect(last[:payload][:new_reserve]).to eq(35_000)
    end

    it "raises when new_reserve is zero" do
      expect { pipeline.update_reserve("clm-002", 0, at: t2, actor: "adj-2") }.to raise_error(ArgumentError)
    end

    it "raises when the claim is closed" do
      fresh_pipeline.file_claim("clm-cls", policy_id: "pol-200", coverage_type: "epl",
                                 incident_date: d0, filed_at: t0,
                                 claimed_amount: 20_000, reserve_amount: 15_000, actor: "adj-1")
      fresh_pipeline.advance_status("clm-cls", "investigating", at: t1, actor: "adj-1")
      fresh_pipeline.advance_status("clm-cls", "evaluation", at: t2, actor: "adj-1")
      fresh_pipeline.settle_claim("clm-cls", approved_amount: 10_000, settled_at: t3, actor: "adj-1")
      fresh_pipeline.advance_status("clm-cls", "closed", at: t4, actor: "adj-1")
      expect { fresh_pipeline.update_reserve("clm-cls", 5_000, at: t4, actor: "adj-1") }.to raise_error(ArgumentError)
    end

    it "raises on an unknown claim_id" do
      expect { pipeline.update_reserve("no-such", 10_000, at: t2, actor: "adj-1") }.to raise_error(KeyError)
    end
  end

  # ── Part 2 — Settlement, denial, and query methods ──────────────────────

  describe "#settle_claim" do
    it "settles the claim and sets approved_amount" do
      pipeline.settle_claim("clm-003", approved_amount: 150_000, settled_at: t3, actor: "adj-1")
      c = pipeline.get_claim("clm-003")
      expect(c[:status]).to eq("settled")
      expect(c[:approved_amount]).to eq(150_000)
    end

    it "appends a settled event" do
      pipeline.settle_claim("clm-003", approved_amount: 150_000, settled_at: t3, actor: "adj-1")
      last = pipeline.get_claim("clm-003")[:events].last
      expect(last[:action]).to eq("settled")
      expect(last[:payload][:approved_amount]).to eq(150_000)
    end

    it "raises when the claim is not in evaluation" do
      expect do
        pipeline.settle_claim("clm-002", approved_amount: 20_000, settled_at: t3, actor: "adj-2")
      end.to raise_error(ArgumentError)
    end

    it "raises when approved_amount exceeds claimed_amount" do
      expect do
        pipeline.settle_claim("clm-003", approved_amount: 300_000, settled_at: t3, actor: "adj-1")
      end.to raise_error(ArgumentError)
    end

    it "raises when approved_amount is zero" do
      expect { pipeline.settle_claim("clm-003", approved_amount: 0, settled_at: t3, actor: "adj-1") }.to raise_error(ArgumentError)
    end

    it "raises on an unknown claim_id" do
      expect { pipeline.settle_claim("no-such", approved_amount: 10_000, settled_at: t3, actor: "adj-1") }.to raise_error(KeyError)
    end
  end

  describe "#deny_claim" do
    it "denies the claim" do
      pipeline.deny_claim("clm-003", reason: "Outside coverage period.", denied_at: t3, actor: "adj-1")
      expect(pipeline.get_claim("clm-003")[:status]).to eq("denied")
    end

    it "appends a denied event" do
      pipeline.deny_claim("clm-003", reason: "Exclusion.", denied_at: t3, actor: "adj-1")
      last = pipeline.get_claim("clm-003")[:events].last
      expect(last[:action]).to eq("denied")
      expect(last[:payload][:reason]).to eq("Exclusion.")
    end

    it "raises when the claim is not in evaluation" do
      expect { pipeline.deny_claim("clm-002", reason: "Reason.", denied_at: t3, actor: "adj-2") }.to raise_error(ArgumentError)
    end

    it "raises on an unknown claim_id" do
      expect { pipeline.deny_claim("no-such", reason: "Reason.", denied_at: t3, actor: "adj-1") }.to raise_error(KeyError)
    end
  end

  describe "#get_claims_by_policy" do
    it "returns claims for the given policy" do
      claims = pipeline.get_claims_by_policy("pol-101")
      ids = claims.map { |c| c[:claim_id] }
      expect(ids).to include("clm-001")
      expect(ids).to include("clm-002")
      expect(ids).not_to include("clm-003")
    end

    it "sorts claims by filed_at" do
      fresh_pipeline.file_claim("clm-b", policy_id: "pol-sort", coverage_type: "epl",
                                 incident_date: d0, filed_at: t1,
                                 claimed_amount: 10_000, reserve_amount: 8_000, actor: "adj-1")
      fresh_pipeline.file_claim("clm-a", policy_id: "pol-sort", coverage_type: "epl",
                                 incident_date: d0, filed_at: t0,
                                 claimed_amount: 10_000, reserve_amount: 8_000, actor: "adj-1")
      claims = fresh_pipeline.get_claims_by_policy("pol-sort")
      filed_ats = claims.map { |c| c[:filed_at] }
      expect(filed_ats).to eq(filed_ats.sort)
    end

    it "returns an empty array for an unknown policy" do
      expect(pipeline.get_claims_by_policy("pol-999")).to eq([])
    end
  end

  describe "#get_open_claims" do
    it "excludes closed and denied claims" do
      ids = pipeline.get_open_claims.map { |c| c[:claim_id] }
      expect(ids).to include("clm-001")
      expect(ids).to include("clm-002")
      expect(ids).to include("clm-003")
      expect(ids).not_to include("clm-004")
    end

    it "sorts by filed_at" do
      filed_ats = pipeline.get_open_claims.map { |c| c[:filed_at] }
      expect(filed_ats).to eq(filed_ats.sort)
    end
  end

  # ── Part 3 — Reserve adequacy and metrics ───────────────────────────────

  describe "#get_reserve_adequacy" do
    it "sums reserves across all claims" do
      expect(pipeline.get_reserve_adequacy[:total_reserves]).to eq(240_000)
    end

    it "sums approved amounts for settled claims only" do
      expect(pipeline.get_reserve_adequacy[:total_approved]).to eq(60_000)
    end

    it "counts and sums the under-reserved gap" do
      adequacy = pipeline.get_reserve_adequacy
      expect(adequacy[:under_reserved_count]).to eq(1)
      expect(adequacy[:under_reserved_gap]).to eq(10_000)
    end

    it "handles an empty pipeline" do
      adequacy = fresh_pipeline.get_reserve_adequacy
      expect(adequacy[:total_reserves]).to eq(0)
      expect(adequacy[:total_approved]).to eq(0)
      expect(adequacy[:under_reserved_count]).to eq(0)
      expect(adequacy[:under_reserved_gap]).to eq(0)
    end
  end

  describe "#get_claims_metrics" do
    it "counts the total number of claims" do
      expect(pipeline.get_claims_metrics[:total]).to eq(4)
    end

    it "counts claims by status" do
      by_status = pipeline.get_claims_metrics[:by_status]
      expect(by_status["settled"]).to eq(1)
      expect(by_status["investigating"]).to eq(1)
      expect(by_status["evaluation"]).to eq(1)
      expect(by_status["denied"]).to eq(1)
    end

    it "only includes statuses with a nonzero count" do
      pipeline.get_claims_metrics[:by_status].each_value { |count| expect(count).to be > 0 }
    end

    it "sums claimed amounts" do
      expect(pipeline.get_claims_metrics[:total_claimed]).to eq(75_000 + 30_000 + 200_000 + 10_000)
    end

    it "sums paid amounts for settled claims" do
      expect(pipeline.get_claims_metrics[:total_paid]).to eq(60_000)
    end

    it "computes the average settlement ratio" do
      expect(pipeline.get_claims_metrics[:avg_settlement_ratio]).to eq((60_000 / 75_000.0).round(4))
    end

    it "returns zero average ratio when there are no settled claims" do
      fresh_pipeline.file_claim("clm-ns", policy_id: "pol-200", coverage_type: "epl",
                                 incident_date: d0, filed_at: t0,
                                 claimed_amount: 20_000, reserve_amount: 15_000, actor: "adj-1")
      expect(fresh_pipeline.get_claims_metrics[:avg_settlement_ratio]).to eq(0.0)
    end
  end

  describe "#get_policy_loss_history" do
    it "returns correct stats for a known policy" do
      history = pipeline.get_policy_loss_history("pol-101")
      expect(history[:policy_id]).to eq("pol-101")
      expect(history[:claim_count]).to eq(2)
      expect(history[:total_claimed]).to eq(105_000)
      expect(history[:total_paid]).to eq(60_000)
      expect(history[:loss_ratio]).to eq((60_000 / 105_000.0).round(4))
    end

    it "returns zeros for an unknown policy" do
      history = pipeline.get_policy_loss_history("pol-999")
      expect(history[:policy_id]).to eq("pol-999")
      expect(history[:claim_count]).to eq(0)
      expect(history[:total_claimed]).to eq(0)
      expect(history[:total_paid]).to eq(0)
      expect(history[:loss_ratio]).to eq(0.0)
    end
  end
end
