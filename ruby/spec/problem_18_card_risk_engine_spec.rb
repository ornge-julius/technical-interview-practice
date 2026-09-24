require_relative "../practice_problems/problem_18_card_risk_engine"

RSpec.describe CardRiskEngine do
  # Shared timestamps (all naive ISO-8601, lexicographically sortable)
  t0 = "2024-06-01T10:00:00"
  t0_10s = "2024-06-01T10:00:10"
  t0_20s = "2024-06-01T10:00:20"
  t0_30s = "2024-06-01T10:00:30"
  t0_1h = "2024-06-01T11:00:00"
  t0_2h = "2024-06-01T12:00:00"
  t0_2h30m = "2024-06-01T12:30:00"
  t0_plus_27h = "2024-06-02T13:00:00" # 25h after t0_2h — outside the 24h block window

  # Spaced 70s apart: wide enough that no 60s window ever contains more than
  # one of these, so velocity_count_exceeded never fires.
  ta0 = "2024-06-01T09:00:00"
  ta1 = "2024-06-01T09:01:10"
  ta2 = "2024-06-01T09:02:20"
  ta3 = "2024-06-01T09:03:30"
  ta4 = "2024-06-01T09:04:40"

  let(:fresh_engine) { described_class.new }

  # Pre-seeded engine: card_seed has one approved transaction at t0.
  let(:engine) do
    e = described_class.new
    e.evaluate_transaction("card_seed", 100.0, "grocery", t0)
    e
  end

  # ── Part 1 — Static rule evaluation ─────────────────────────────────────

  describe "static rules" do
    it "approves a normal transaction" do
      result = fresh_engine.evaluate_transaction("card_static_approve", 200.0, "grocery", t0)
      expect(result).to eq(decision: "approve", reasons: [])
    end

    it "declines when the amount exceeds the limit" do
      result = fresh_engine.evaluate_transaction("card_amount_limit", 6000.0, "electronics", t0)
      expect(result).to eq(decision: "decline", reasons: ["amount_limit_exceeded"])
    end

    it "declines a blocked merchant category" do
      result = fresh_engine.evaluate_transaction("card_blocked_merchant", 50.0, "gambling", t0)
      expect(result).to eq(decision: "decline", reasons: ["blocked_merchant_category"])
    end

    it "flags a high amount for review" do
      result = fresh_engine.evaluate_transaction("card_high_amount", 1500.0, "travel", t0)
      expect(result).to eq(decision: "review", reasons: ["high_amount"])
    end

    it "flags the high_amount lower bound" do
      result = fresh_engine.evaluate_transaction("card_boundary_low", 1000.0, "travel", t0)
      expect(result).to eq(decision: "review", reasons: ["high_amount"])
    end

    it "flags amount at the limit as high_amount, not decline" do
      result = fresh_engine.evaluate_transaction("card_boundary_high", 5000.0, "travel", t0)
      expect(result).to eq(decision: "review", reasons: ["high_amount"])
    end

    it "approves an amount just below the high_amount threshold" do
      result = fresh_engine.evaluate_transaction("card_below_threshold", 999.0, "travel", t0)
      expect(result).to eq(decision: "approve", reasons: [])
    end

    it "combines multiple matched static rules" do
      result = fresh_engine.evaluate_transaction("card_multi_rule", 6000.0, "gambling", t0)
      expect(result[:decision]).to eq("decline")
      expect(result[:reasons]).to eq(%w[amount_limit_exceeded blocked_merchant_category])
    end

    it "is unaffected by another card's history" do
      result = engine.evaluate_transaction("card_unrelated", 200.0, "grocery", t0)
      expect(result).to eq(decision: "approve", reasons: [])
    end
  end

  # ── Part 2 — Velocity checks ─────────────────────────────────────────────

  describe "velocity checks" do
    it "declines the 4th transaction within a 60s window" do
      card = "card_vel_count"
      r1 = fresh_engine.evaluate_transaction(card, 50.0, "grocery", t0)
      r2 = fresh_engine.evaluate_transaction(card, 50.0, "grocery", t0_10s)
      r3 = fresh_engine.evaluate_transaction(card, 50.0, "grocery", t0_20s)
      r4 = fresh_engine.evaluate_transaction(card, 50.0, "grocery", t0_30s)
      expect(r1[:decision]).to eq("approve")
      expect(r2[:decision]).to eq("approve")
      expect(r3[:decision]).to eq("approve")
      expect(r4[:decision]).to eq("decline")
      expect(r4[:reasons]).to include("velocity_count_exceeded")
    end

    it "tracks velocity count per card" do
      [t0, t0_10s, t0_20s, t0_30s].each do |ts|
        fresh_engine.evaluate_transaction("card_vel_isolated_a", 50.0, "grocery", ts)
      end
      result = fresh_engine.evaluate_transaction("card_vel_isolated_b", 50.0, "grocery", t0_30s)
      expect(result[:decision]).to eq("approve")
    end

    it "flags cumulative spend exceeding the velocity amount window" do
      card = "card_vel_amount"
      results = [ta0, ta1, ta2, ta3, ta4].map do |ts|
        fresh_engine.evaluate_transaction(card, 2200.0, "travel", ts)
      end
      results[0..3].each { |r| expect(r[:reasons]).to eq(["high_amount"]) }
      expect(results[4][:reasons]).to include("velocity_amount_exceeded")
      expect(results[4][:decision]).to eq("review")
    end

    it "ignores wide gaps outside the velocity amount window" do
      # Same per-transaction amount as above, but 20 min apart — far outside
      # the 600s trailing window, so the total never accumulates.
      card = "card_vel_amount_wide"
      ts_list = [
        "2024-06-01T09:00:00",
        "2024-06-01T09:20:00",
        "2024-06-01T09:40:00",
        "2024-06-01T10:00:00",
        "2024-06-01T10:20:00",
      ]
      results = ts_list.map { |ts| fresh_engine.evaluate_transaction(card, 2200.0, "travel", ts) }
      expect(results.all? { |r| !r[:reasons].include?("velocity_amount_exceeded") }).to be true
    end
  end

  # ── Part 3 — Auto-blocking ────────────────────────────────────────────────

  describe "auto-blocking" do
    it "is not blocked initially" do
      expect(fresh_engine.is_card_blocked("card_never_seen")).to be false
    end

    it "is not blocked before the decline threshold" do
      card = "card_block_partial"
      fresh_engine.evaluate_transaction(card, 6000.0, "electronics", t0)
      fresh_engine.evaluate_transaction(card, 6000.0, "electronics", t0_1h)
      expect(fresh_engine.is_card_blocked(card)).to be false
    end

    it "blocks after three declines" do
      card = "card_block_full"
      fresh_engine.evaluate_transaction(card, 6000.0, "electronics", t0)
      fresh_engine.evaluate_transaction(card, 6000.0, "electronics", t0_1h)
      third = fresh_engine.evaluate_transaction(card, 6000.0, "electronics", t0_2h)
      expect(third[:reasons]).to eq(["amount_limit_exceeded"])
      expect(fresh_engine.is_card_blocked(card)).to be true
    end

    it "short-circuits future rules once blocked" do
      card = "card_block_shortcircuit"
      fresh_engine.evaluate_transaction(card, 6000.0, "electronics", t0)
      fresh_engine.evaluate_transaction(card, 6000.0, "electronics", t0_1h)
      fresh_engine.evaluate_transaction(card, 6000.0, "electronics", t0_2h)
      result = fresh_engine.evaluate_transaction(card, 50.0, "grocery", t0_2h30m)
      expect(result).to eq(decision: "decline", reasons: ["card_blocked"])
    end

    it "expires the block once declines age out" do
      card = "card_block_expires"
      fresh_engine.evaluate_transaction(card, 6000.0, "electronics", t0)
      fresh_engine.evaluate_transaction(card, 6000.0, "electronics", t0_1h)
      fresh_engine.evaluate_transaction(card, 6000.0, "electronics", t0_2h)
      expect(fresh_engine.is_card_blocked(card)).to be true

      result = fresh_engine.evaluate_transaction(card, 50.0, "grocery", t0_plus_27h)
      expect(result).to eq(decision: "approve", reasons: [])
      expect(fresh_engine.is_card_blocked(card)).to be false
    end
  end
end
