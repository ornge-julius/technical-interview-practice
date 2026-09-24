require_relative "../practice_problems/problem_20_dunning_scheduler"

RSpec.describe DunningScheduler do
  # D0         = base
  # D0_PLUS_1  = D0 + 1 day   (1st retry interval)
  # D0_PLUS_4  = D0_PLUS_1 + 3 days  (2nd retry interval)
  # D0_PLUS_11 = D0_PLUS_4 + 7 days (3rd retry interval)
  d0 = "2024-01-01T00:00:00"
  d0_plus_1 = "2024-01-02T00:00:00"
  d0_plus_4 = "2024-01-05T00:00:00"
  d0_plus_11 = "2024-01-12T00:00:00"

  let(:fresh_dm) { described_class.new }

  # Pre-seeded manager:
  #   sub_active:   active, no failed attempts.
  #   sub_past_due: 1 failed attempt at d0 (past_due, consecutive_failures=1).
  let(:dm) do
    m = described_class.new
    m.create_subscription("sub_active", amount: 19.99)
    m.create_subscription("sub_past_due", amount: 29.99)
    m.record_attempt("sub_past_due", d0, succeeded: false)
    m
  end

  # ── Part 1 — Attempt tracking ───────────────────────────────────────────

  describe "attempt tracking" do
    it "starts a new subscription as active" do
      fresh_dm.create_subscription("sub_create_test", amount: 10.0)
      expect(fresh_dm.get_subscription_status("sub_create_test")).to eq("active")
    end

    it "raises on a duplicate subscription" do
      fresh_dm.create_subscription("sub_dup_test", amount: 10.0)
      expect { fresh_dm.create_subscription("sub_dup_test", amount: 10.0) }.to raise_error(ArgumentError)
    end

    it "raises on get_subscription_status for an unknown subscription" do
      expect { fresh_dm.get_subscription_status("sub_ghost") }.to raise_error(KeyError)
    end

    it "raises on record_attempt for an unknown subscription" do
      expect { fresh_dm.record_attempt("sub_ghost", d0, succeeded: true) }.to raise_error(KeyError)
    end

    it "moves to past_due after a failed attempt" do
      fresh_dm.create_subscription("sub_fail_test", amount: 10.0)
      result = fresh_dm.record_attempt("sub_fail_test", d0, succeeded: false)
      expect(result).to eq(status: "past_due", consecutive_failures: 1)
      expect(fresh_dm.get_subscription_status("sub_fail_test")).to eq("past_due")
    end

    it "stays active after a successful attempt" do
      fresh_dm.create_subscription("sub_success_test", amount: 10.0)
      result = fresh_dm.record_attempt("sub_success_test", d0, succeeded: true)
      expect(result).to eq(status: "active", consecutive_failures: 0)
    end

    it "resets the failure streak on success" do
      fresh_dm.create_subscription("sub_reset_test", amount: 10.0)
      fresh_dm.record_attempt("sub_reset_test", d0, succeeded: false)
      fresh_dm.record_attempt("sub_reset_test", d0_plus_1, succeeded: false)
      result = fresh_dm.record_attempt("sub_reset_test", d0_plus_4, succeeded: true)
      expect(result).to eq(status: "active", consecutive_failures: 0)
    end

    it "increments consecutive failures" do
      fresh_dm.create_subscription("sub_incr_test", amount: 10.0)
      fresh_dm.record_attempt("sub_incr_test", d0, succeeded: false)
      result = fresh_dm.record_attempt("sub_incr_test", d0_plus_1, succeeded: false)
      expect(result).to eq(status: "past_due", consecutive_failures: 2)
    end

    it "reports the pre-seeded active subscription's status" do
      expect(dm.get_subscription_status("sub_active")).to eq("active")
    end

    it "reports the pre-seeded past_due subscription's status" do
      expect(dm.get_subscription_status("sub_past_due")).to eq("past_due")
    end
  end

  # ── Part 2 — Backoff scheduling ─────────────────────────────────────────

  describe "backoff scheduling" do
    it "has no next retry time while active" do
      fresh_dm.create_subscription("sub_retry_active_test", amount: 10.0)
      expect(fresh_dm.get_next_retry_time("sub_retry_active_test")).to be_nil
    end

    it "schedules the next retry after the first failure" do
      fresh_dm.create_subscription("sub_retry_1_test", amount: 10.0)
      fresh_dm.record_attempt("sub_retry_1_test", d0, succeeded: false)
      expect(fresh_dm.get_next_retry_time("sub_retry_1_test")).to eq(d0_plus_1)
    end

    it "schedules the next retry after the second failure" do
      fresh_dm.create_subscription("sub_retry_2_test", amount: 10.0)
      fresh_dm.record_attempt("sub_retry_2_test", d0, succeeded: false)
      fresh_dm.record_attempt("sub_retry_2_test", d0_plus_1, succeeded: false)
      expect(fresh_dm.get_next_retry_time("sub_retry_2_test")).to eq(d0_plus_4)
    end

    it "schedules the next retry after the third failure" do
      fresh_dm.create_subscription("sub_retry_3_test", amount: 10.0)
      fresh_dm.record_attempt("sub_retry_3_test", d0, succeeded: false)
      fresh_dm.record_attempt("sub_retry_3_test", d0_plus_1, succeeded: false)
      fresh_dm.record_attempt("sub_retry_3_test", d0_plus_4, succeeded: false)
      expect(fresh_dm.get_next_retry_time("sub_retry_3_test")).to eq(d0_plus_11)
    end

    it "raises on get_next_retry_time for an unknown subscription" do
      expect { fresh_dm.get_next_retry_time("sub_ghost_retry") }.to raise_error(KeyError)
    end

    it "reports a retry as due once the scheduled time is reached" do
      fresh_dm.create_subscription("sub_due_test", amount: 10.0)
      fresh_dm.record_attempt("sub_due_test", d0, succeeded: false)
      expect(fresh_dm.is_retry_due("sub_due_test", d0_plus_1)).to be true
      expect(fresh_dm.is_retry_due("sub_due_test", d0_plus_4)).to be true
    end

    it "reports a retry as not due before the scheduled time" do
      fresh_dm.create_subscription("sub_not_due_test", amount: 10.0)
      fresh_dm.record_attempt("sub_not_due_test", d0, succeeded: false)
      expect(fresh_dm.is_retry_due("sub_not_due_test", "2024-01-01T12:00:00")).to be false
    end

    it "reports a retry as not due while active" do
      fresh_dm.create_subscription("sub_active_due_test", amount: 10.0)
      expect(fresh_dm.is_retry_due("sub_active_due_test", d0)).to be false
    end

    it "reports the pre-seeded past_due subscription's scheduled retry" do
      expect(dm.get_next_retry_time("sub_past_due")).to eq(d0_plus_1)
    end
  end

  # ── Part 3 — Auto-cancellation ──────────────────────────────────────────

  describe "auto-cancellation" do
    it "sets status on manual cancel" do
      fresh_dm.create_subscription("sub_cancel_test", amount: 10.0)
      result = fresh_dm.cancel_subscription("sub_cancel_test", d0)
      expect(result).to eq(status: "canceled", consecutive_failures: 0)
      expect(fresh_dm.get_subscription_status("sub_cancel_test")).to eq("canceled")
    end

    it "is idempotent to cancel twice" do
      fresh_dm.create_subscription("sub_cancel_idem_test", amount: 10.0)
      fresh_dm.cancel_subscription("sub_cancel_idem_test", d0)
      result = fresh_dm.cancel_subscription("sub_cancel_idem_test", d0_plus_1)
      expect(result[:status]).to eq("canceled")
    end

    it "raises when canceling an unknown subscription" do
      expect { fresh_dm.cancel_subscription("sub_ghost_cancel", d0) }.to raise_error(KeyError)
    end

    it "raises when recording an attempt on a canceled subscription" do
      fresh_dm.create_subscription("sub_canceled_attempt_test", amount: 10.0)
      fresh_dm.cancel_subscription("sub_canceled_attempt_test", d0)
      expect do
        fresh_dm.record_attempt("sub_canceled_attempt_test", d0_plus_1, succeeded: true)
      end.to raise_error(ArgumentError)
    end

    it "auto-cancels once the retry schedule is exhausted" do
      sub = "sub_auto_cancel_test"
      fresh_dm.create_subscription(sub, amount: 10.0)
      fresh_dm.record_attempt(sub, d0, succeeded: false)         # 1
      fresh_dm.record_attempt(sub, d0_plus_1, succeeded: false)  # 2
      fresh_dm.record_attempt(sub, d0_plus_4, succeeded: false) # 3
      result = fresh_dm.record_attempt(sub, d0_plus_11, succeeded: false) # 4 - exhausted
      expect(result).to eq(status: "canceled", consecutive_failures: 4)
      expect(fresh_dm.get_subscription_status(sub)).to eq("canceled")
      expect(fresh_dm.get_next_retry_time(sub)).to be_nil
    end

    it "does not cancel before the schedule is exhausted" do
      sub = "sub_not_yet_canceled_test"
      fresh_dm.create_subscription(sub, amount: 10.0)
      fresh_dm.record_attempt(sub, d0, succeeded: false)
      fresh_dm.record_attempt(sub, d0_plus_1, succeeded: false)
      result = fresh_dm.record_attempt(sub, d0_plus_4, succeeded: false)
      expect(result[:status]).to eq("past_due")
    end
  end
end
