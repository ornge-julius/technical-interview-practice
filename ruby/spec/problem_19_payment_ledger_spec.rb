require_relative "../practice_problems/problem_19_payment_ledger"

RSpec.describe PaymentLedger do
  t0 = "2024-06-01T10:00:00"
  t0_1h = "2024-06-01T11:00:00"
  t0_2h = "2024-06-01T12:00:00"

  let(:fresh_ledger) { described_class.new }

  # Pre-seeded ledger:
  #   Accounts: wallet:alice (200.0), wallet:bob (0.0), platform:fees (0.0)
  #   Applied transfers: tx_seed_1 (alice -> bob, 50.0, t0)
  #                       tx_seed_2 (alice -> platform:fees, 5.0, t0_1h)
  let(:ledger) do
    l = described_class.new
    l.open_account("wallet:alice", initial_balance: 200.0)
    l.open_account("wallet:bob")
    l.open_account("platform:fees")
    l.record_transfer("tx_seed_1", "wallet:alice", "wallet:bob", 50.0, t0)
    l.record_transfer("tx_seed_2", "wallet:alice", "platform:fees", 5.0, t0_1h)
    l
  end

  # ── Part 1 — Accounts & idempotent transfers ────────────────────────────

  describe "accounts and transfers" do
    it "sets the initial balance on open_account" do
      fresh_ledger.open_account("wallet:open_test", initial_balance: 25.0)
      expect(fresh_ledger.get_balance("wallet:open_test")).to eq(25.0)
    end

    it "defaults the initial balance to zero" do
      fresh_ledger.open_account("wallet:default_test")
      expect(fresh_ledger.get_balance("wallet:default_test")).to eq(0.0)
    end

    it "raises on a duplicate account" do
      fresh_ledger.open_account("wallet:dup_test")
      expect { fresh_ledger.open_account("wallet:dup_test") }.to raise_error(ArgumentError)
    end

    it "raises on a negative initial balance" do
      expect { fresh_ledger.open_account("wallet:negative_test", initial_balance: -5.0) }.to raise_error(ArgumentError)
    end

    it "raises on get_balance for an unknown account" do
      expect { fresh_ledger.get_balance("wallet:ghost") }.to raise_error(KeyError)
    end

    it "applies a transfer and updates both balances" do
      fresh_ledger.open_account("wallet:a_apply", initial_balance: 100.0)
      fresh_ledger.open_account("wallet:b_apply")
      result = fresh_ledger.record_transfer("tx_apply_test", "wallet:a_apply", "wallet:b_apply", 40.0, t0)
      expect(result).to eq(status: "applied", reason: nil)
      expect(fresh_ledger.get_balance("wallet:a_apply")).to eq(60.0)
      expect(fresh_ledger.get_balance("wallet:b_apply")).to eq(40.0)
    end

    it "does not reapply a duplicate transaction_id" do
      fresh_ledger.open_account("wallet:a_dup", initial_balance: 100.0)
      fresh_ledger.open_account("wallet:b_dup")
      fresh_ledger.record_transfer("tx_dup_test", "wallet:a_dup", "wallet:b_dup", 40.0, t0)
      second = fresh_ledger.record_transfer("tx_dup_test", "wallet:a_dup", "wallet:b_dup", 40.0, t0_1h)
      expect(second).to eq(status: "duplicate", reason: nil)
      expect(fresh_ledger.get_balance("wallet:a_dup")).to eq(60.0)
      expect(fresh_ledger.get_balance("wallet:b_dup")).to eq(40.0)
    end

    it "rejects an unknown account" do
      fresh_ledger.open_account("wallet:a_unknown", initial_balance: 100.0)
      result = fresh_ledger.record_transfer("tx_unknown_test", "wallet:a_unknown", "wallet:ghost", 10.0, t0)
      expect(result).to eq(status: "rejected", reason: "unknown_account")
    end

    it "rejects an invalid amount" do
      fresh_ledger.open_account("wallet:a_invalid", initial_balance: 100.0)
      fresh_ledger.open_account("wallet:b_invalid")
      result = fresh_ledger.record_transfer("tx_invalid_test", "wallet:a_invalid", "wallet:b_invalid", 0.0, t0)
      expect(result).to eq(status: "rejected", reason: "invalid_amount")
    end

    it "rejects insufficient funds" do
      fresh_ledger.open_account("wallet:a_short", initial_balance: 10.0)
      fresh_ledger.open_account("wallet:b_short")
      result = fresh_ledger.record_transfer("tx_short_test", "wallet:a_short", "wallet:b_short", 40.0, t0)
      expect(result).to eq(status: "rejected", reason: "insufficient_funds")
      expect(fresh_ledger.get_balance("wallet:a_short")).to eq(10.0)
    end

    it "evaluates a retried, previously-rejected transaction_id fresh" do
      fresh_ledger.open_account("wallet:a_retry", initial_balance: 0.0)
      fresh_ledger.open_account("wallet:b_retry")
      fresh_ledger.open_account("wallet:c_retry", initial_balance: 100.0)

      first = fresh_ledger.record_transfer("tx_retry_test", "wallet:a_retry", "wallet:b_retry", 50.0, t0)
      expect(first).to eq(status: "rejected", reason: "insufficient_funds")

      fresh_ledger.record_transfer("tx_retry_topup", "wallet:c_retry", "wallet:a_retry", 50.0, t0)
      second = fresh_ledger.record_transfer("tx_retry_test", "wallet:a_retry", "wallet:b_retry", 50.0, t0_1h)
      expect(second).to eq(status: "applied", reason: nil)
      expect(fresh_ledger.get_balance("wallet:b_retry")).to eq(50.0)
    end
  end

  # ── Part 2 — Reversals ────────────────────────────────────────────────────

  describe "reversals" do
    it "reverses an applied transfer" do
      fresh_ledger.open_account("wallet:alice_rev", initial_balance: 100.0)
      fresh_ledger.open_account("wallet:bob_rev")
      fresh_ledger.record_transfer("tx_rev_base", "wallet:alice_rev", "wallet:bob_rev", 40.0, t0)
      result = fresh_ledger.reverse_transfer("tx_rev_base", "tx_rev_base_r", t0_1h)
      expect(result).to eq(status: "applied", reason: nil)
      expect(fresh_ledger.get_balance("wallet:alice_rev")).to eq(100.0)
      expect(fresh_ledger.get_balance("wallet:bob_rev")).to eq(0.0)
    end

    it "raises when reversing an unknown transaction" do
      expect { fresh_ledger.reverse_transfer("nonexistent_tx", "rev_of_nonexistent", t0) }.to raise_error(KeyError)
    end

    it "rejects reversing an already-reversed transfer" do
      fresh_ledger.open_account("wallet:alice_double", initial_balance: 100.0)
      fresh_ledger.open_account("wallet:bob_double")
      fresh_ledger.record_transfer("tx_double_rev", "wallet:alice_double", "wallet:bob_double", 40.0, t0)
      fresh_ledger.reverse_transfer("tx_double_rev", "tx_double_rev_r1", t0_1h)
      result = fresh_ledger.reverse_transfer("tx_double_rev", "tx_double_rev_r2", t0_2h)
      expect(result).to eq(status: "rejected", reason: "already_reversed")
    end

    it "fails the reversal if funds were already spent" do
      fresh_ledger.open_account("wallet:alice_spend", initial_balance: 100.0)
      fresh_ledger.open_account("wallet:bob_spend")
      fresh_ledger.open_account("wallet:carol_spend")
      fresh_ledger.record_transfer("tx_spend_base", "wallet:alice_spend", "wallet:bob_spend", 40.0, t0)
      # bob spends the money elsewhere before the reversal is attempted
      fresh_ledger.record_transfer("tx_spend_away", "wallet:bob_spend", "wallet:carol_spend", 40.0, t0_1h)
      result = fresh_ledger.reverse_transfer("tx_spend_base", "tx_spend_base_r", t0_2h)
      expect(result).to eq(status: "rejected", reason: "insufficient_funds")
    end

    it "treats the reversal itself as a regular idempotent transfer" do
      fresh_ledger.open_account("wallet:alice_idem", initial_balance: 100.0)
      fresh_ledger.open_account("wallet:bob_idem")
      fresh_ledger.record_transfer("tx_idem_base", "wallet:alice_idem", "wallet:bob_idem", 40.0, t0)
      fresh_ledger.reverse_transfer("tx_idem_base", "tx_idem_base_r", t0_1h)
      # Replaying the reversal's own transaction_id directly must be a
      # no-op duplicate, proving reverse_transfer moved money via
      # record_transfer rather than a separate code path.
      replay = fresh_ledger.record_transfer("tx_idem_base_r", "wallet:bob_idem", "wallet:alice_idem", 40.0, t0_2h)
      expect(replay).to eq(status: "duplicate", reason: nil)
      expect(fresh_ledger.get_balance("wallet:alice_idem")).to eq(100.0)
    end
  end

  # ── Part 3 — Reconciliation ────────────────────────────────────────────────

  describe "#reconcile" do
    it "matches a statement line that agrees" do
      statement = [{ transaction_id: "tx_seed_1", account_id: "wallet:alice", amount: 50.0, type: "debit" }]
      report = ledger.reconcile(statement)
      expect(report[:matched]).to eq(["tx_seed_1"])
      expect(report[:mismatched]).to eq([])
      expect(report[:missing_from_ledger]).to eq([])
      expect(report[:missing_from_statement]).to include("tx_seed_2")
    end

    it "flags an amount mismatch" do
      statement = [{ transaction_id: "tx_seed_1", account_id: "wallet:alice", amount: 999.0, type: "debit" }]
      report = ledger.reconcile(statement)
      expect(report[:mismatched]).to eq([{ transaction_id: "tx_seed_1", reason: "amount_mismatch" }])
    end

    it "flags an account mismatch" do
      statement = [{ transaction_id: "tx_seed_1", account_id: "wallet:bob", amount: 50.0, type: "debit" }]
      report = ledger.reconcile(statement)
      expect(report[:mismatched]).to eq([{ transaction_id: "tx_seed_1", reason: "account_mismatch" }])
    end

    it "prioritizes account mismatch over amount mismatch" do
      statement = [{ transaction_id: "tx_seed_1", account_id: "wallet:bob", amount: 999.0, type: "debit" }]
      report = ledger.reconcile(statement)
      expect(report[:mismatched]).to eq([{ transaction_id: "tx_seed_1", reason: "account_mismatch" }])
    end

    it "flags a transaction missing from the ledger" do
      statement = [{ transaction_id: "tx_unknown", account_id: "wallet:alice", amount: 10.0, type: "debit" }]
      report = ledger.reconcile(statement)
      expect(report[:missing_from_ledger]).to eq(["tx_unknown"])
    end

    it "flags transactions missing from the statement" do
      report = ledger.reconcile([])
      expect(report[:missing_from_statement].to_set).to eq(Set["tx_seed_1", "tx_seed_2"])
    end

    it "ignores credit lines" do
      statement = [{ transaction_id: "tx_seed_1", account_id: "wallet:bob", amount: 50.0, type: "credit" }]
      report = ledger.reconcile(statement)
      expect(report[:matched]).to eq([])
      expect(report[:missing_from_statement]).to include("tx_seed_1")
    end

    it "includes reversed transfers in reconciliation" do
      fresh_ledger.open_account("wallet:x_rec", initial_balance: 100.0)
      fresh_ledger.open_account("wallet:y_rec")
      fresh_ledger.record_transfer("tx_rec_rev", "wallet:x_rec", "wallet:y_rec", 20.0, t0)
      fresh_ledger.reverse_transfer("tx_rec_rev", "tx_rec_rev_r", t0_1h)
      statement = [
        { transaction_id: "tx_rec_rev", account_id: "wallet:x_rec", amount: 20.0, type: "debit" },
        { transaction_id: "tx_rec_rev_r", account_id: "wallet:y_rec", amount: 20.0, type: "debit" },
      ]
      report = fresh_ledger.reconcile(statement)
      expect(report[:matched].to_set).to eq(Set["tx_rec_rev", "tx_rec_rev_r"])
    end
  end
end
