# =============================================================================
# INTERVIEW PROBLEM 19: Payment Ledger & Reconciliation
# Difficulty: Senior Software Engineer | Estimated time: 45 min
# =============================================================================
#
# CONTEXT
# -------
# You're building the internal ledger for a payments platform. The ledger
# tracks balances for internal accounts (user wallets, merchant accounts,
# platform fee accounts) and records every transfer between them. Because
# callers may retry a request after a network timeout, transfers must be
# idempotent. The ledger must also be reconciled nightly against a statement
# of transfers reported by an external processor.
#
# For this problem you are building a PaymentLedger class.
# Store all state in instance variables set in `initialize`.
# Class variables and class-level instance variables will bleed between
# examples and between instances — avoid them.
# You choose the internal data structures; the public interface is what
# matters.
#
# Timestamps are ISO-8601 strings without timezone offset, e.g.
# "2024-01-01T10:00:00". They are not used for arithmetic in this problem —
# just stored for record-keeping.
#
# Example
#   ledger = PaymentLedger.new
#   ledger.open_account("wallet:alice", initial_balance: 100.0)
#   ledger.open_account("wallet:bob")
#   ledger.record_transfer("tx1", "wallet:alice", "wallet:bob", 40.0, "2024-01-01T10:00:00")
#   # -> { status: "applied", reason: nil }
#   ledger.get_balance("wallet:alice")  # -> 60.0
#   ledger.get_balance("wallet:bob")    # -> 40.0
#   ledger.record_transfer("tx1", "wallet:alice", "wallet:bob", 40.0, "2024-01-01T10:00:05")
#   # -> { status: "duplicate", reason: nil }   (replay of tx1, no balance change)
#   ledger.reverse_transfer("tx1", "tx1-reversal", "2024-01-01T10:05:00")
#   # -> { status: "applied", reason: nil }     (moves 40.0 back from bob to alice)
# =============================================================================

class PaymentLedger
  def initialize
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Accounts & idempotent transfers  (~15 min)
  # ---------------------------------------------------------------------------

  # Create a new account with the given starting balance.
  #
  # @param account_id [String]
  # @param initial_balance [Float]
  # @raise [ArgumentError] if account_id already exists or initial_balance < 0
  def open_account(account_id, initial_balance: 0.0)
    raise NotImplementedError
  end

  # Return the current balance for account_id.
  #
  # @raise [KeyError] if account_id is unknown
  def get_balance(account_id)
    raise NotImplementedError
  end

  # Move amount from from_account to to_account.
  #
  # - If transaction_id has already been applied, do NOT move money again;
  #   return { status: "duplicate", reason: nil }. (A transaction_id that
  #   was previously rejected has not been applied, so retrying it is
  #   evaluated fresh, not treated as a duplicate.)
  # - Otherwise, reject (do not move any money) if:
  #     - from_account or to_account does not exist
  #         -> { status: "rejected", reason: "unknown_account" }
  #     - amount <= 0
  #         -> { status: "rejected", reason: "invalid_amount" }
  #     - from_account's balance < amount
  #         -> { status: "rejected", reason: "insufficient_funds" }
  # - Otherwise, debit from_account, credit to_account, record the transfer
  #   as applied (needed by Parts 2 and 3), and return
  #   { status: "applied", reason: nil }.
  #
  # @return [Hash] { status: "applied" | "rejected" | "duplicate", reason: String? }
  def record_transfer(transaction_id, from_account, to_account, amount, timestamp)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Reversals  (~15 min)
  # ---------------------------------------------------------------------------

  # Reverse a previously applied transfer by moving its amount back from the
  # original to_account to the original from_account.
  #
  # - Raise KeyError if transaction_id was never applied (unknown, only seen
  #   as a rejected/duplicate attempt, or never recorded at all).
  # - Return { status: "rejected", reason: "already_reversed" } if
  #   transaction_id has already been reversed once.
  # - Otherwise, perform the reversal by calling record_transfer with
  #   reversal_id as the new transaction_id and the accounts swapped, and
  #   return whatever record_transfer returns (e.g. a reversal can itself
  #   come back "rejected"/"insufficient_funds" if to_account's balance has
  #   since dropped). Only mark the original transaction_id as reversed if
  #   the reversal was "applied".
  def reverse_transfer(transaction_id, reversal_id, timestamp)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Reconciliation  (~15 min)
  # ---------------------------------------------------------------------------

  # Compare applied transfers recorded via record_transfer/reverse_transfer
  # (Parts 1-2) against an external statement and return a report.
  #
  # Each statement line is a Hash:
  #   { transaction_id: String, account_id: String (the debited account),
  #     amount: Float, type: "debit" | "credit" }
  # Only "debit" lines need to be reconciled against the ledger's
  # from_account/amount for that transaction_id; ignore "credit" lines.
  #
  # For each "debit" statement line:
  #   - If transaction_id is not an applied transfer in the ledger
  #         -> add transaction_id to missing_from_ledger
  #   - Else if the ledger transfer's from_account or amount differs
  #         -> add { transaction_id:, reason: "account_mismatch" } or
  #            { transaction_id:, reason: "amount_mismatch" } to mismatched
  #            (account_mismatch takes priority if both differ)
  #   - Else
  #         -> add transaction_id to matched
  #
  # Finally, any transaction_id applied in the ledger that never appeared as
  # a "debit" statement line goes into missing_from_statement.
  #
  # @param statement_lines [Array<Hash>]
  # @return [Hash] {
  #   matched: Array<String>, mismatched: Array<Hash>,
  #   missing_from_ledger: Array<String>, missing_from_statement: Array<String>
  # }
  def reconcile(statement_lines)
    raise NotImplementedError
  end
end
