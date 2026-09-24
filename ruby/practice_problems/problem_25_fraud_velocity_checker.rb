# =============================================================================
# INTERVIEW PROBLEM 25: Fraud Velocity Checker
# Difficulty: Senior Software Engineer | Estimated time: 45 min
# =============================================================================
#
# CONTEXT
# -------
# You're building real-time fraud detection for a card-transaction platform.
# The system tracks recent transaction "velocity" per account (how many
# transactions, and how much money, moved in a trailing time window) and
# flags accounts whose velocity crosses configured risk thresholds.
#
# All methods are module-level (`self.`) functions operating on a plain
# Hash ledger returned by `make_ledger` — there is no class to instantiate.
# All timestamps are plain numeric seconds on an arbitrary timeline (not
# wall-clock time).
#
# DATA MODEL
# ----------
# Ledger:
#   { transactions: { account_id => [ {amount: Numeric, at: Numeric}, ... ] } }
#   Each account's transaction list may arrive in any order.
#
# Risk thresholds:
#   :high_frequency — more than 5 transactions within a trailing 60-second window
#   :high_amount     — total transaction amount exceeding 5000 within a
#                       trailing 3600-second (1 hour) window
#
# Example
#   ledger = FraudVelocityChecker.make_ledger
#   FraudVelocityChecker.record_transaction(ledger, "acct_1", 100, 0)
#   FraudVelocityChecker.record_transaction(ledger, "acct_1", 200, 10)
#   FraudVelocityChecker.velocity(ledger, "acct_1", window_seconds: 60, as_of: 10)
#   # -> { count: 2, total: 300 }
#   FraudVelocityChecker.flag_risk(ledger, "acct_1", as_of: 10)
#   # -> [] (well under both thresholds)
#
# =============================================================================

module FraudVelocityChecker
  # ---------------------------------------------------------------------------
  # PART 1 — Recording and velocity (~15 min)
  # ---------------------------------------------------------------------------

  # Return a fresh, empty ledger.
  def self.make_ledger
    raise NotImplementedError
  end

  # Append a transaction of `amount` at time `at` for `account_id`.
  def self.record_transaction(ledger, account_id, amount, at)
    raise NotImplementedError
  end

  # Return { count: Integer, total: Numeric } for account_id's transactions
  # falling within the trailing window (as_of - window_seconds, as_of]
  # (half-open: exclusive of the start, inclusive of as_of). An account with
  # no transactions at all returns { count: 0, total: 0 }.
  def self.velocity(ledger, account_id, window_seconds:, as_of:)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Risk rules (~15 min)
  # ---------------------------------------------------------------------------

  # Return an Array of triggered rule symbols (a subset of
  # [:high_frequency, :high_amount], in that order) for account_id as of
  # `as_of`, using `velocity` from Part 1 rather than re-scanning
  # transactions directly:
  #   :high_frequency — velocity over a 60s window has count > 5
  #   :high_amount     — velocity over a 3600s window has total > 5000
  # Return [] if neither threshold is crossed.
  def self.flag_risk(ledger, account_id, as_of:)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Cross-account reporting (~15 min)
  # ---------------------------------------------------------------------------

  # Return true if account_id currently has BOTH :high_frequency AND
  # :high_amount triggered as of `as_of`. This should compose on top of
  # flag_risk from Part 2.
  def self.blocked?(ledger, account_id, as_of:)
    raise NotImplementedError
  end

  # Return an Array of Hashes, one per account with at least one triggered
  # rule as of `as_of`:
  #   { account_id: String, triggered_rules: [Symbol, ...], blocked: bool }
  # Sort by number of triggered rules descending, then by account_id
  # ascending as a tiebreak. Accounts with zero triggered rules are omitted
  # entirely.
  def self.risk_report(ledger, as_of:)
    raise NotImplementedError
  end
end
