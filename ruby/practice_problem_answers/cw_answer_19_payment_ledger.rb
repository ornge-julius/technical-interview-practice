require "set"

class PaymentLedger
  def initialize
    @balances = {}
    @transfers = {} # transaction_id -> transfer record (applied only)
  end

  # ── Part 1 ──────────────────────────────────────────────────────────────

  def open_account(account_id, initial_balance: 0.0)
    raise ArgumentError, "account already exists: #{account_id}" if @balances.key?(account_id)
    raise ArgumentError, "initial_balance must be >= 0" if initial_balance < 0

    @balances[account_id] = initial_balance
  end

  def get_balance(account_id)
    raise KeyError, account_id unless @balances.key?(account_id)

    @balances[account_id]
  end

  def record_transfer(transaction_id, from_account, to_account, amount, timestamp)
    return { status: "duplicate", reason: nil } if @transfers.key?(transaction_id)

    unless @balances.key?(from_account) && @balances.key?(to_account)
      return { status: "rejected", reason: "unknown_account" }
    end
    return { status: "rejected", reason: "invalid_amount" } if amount <= 0
    return { status: "rejected", reason: "insufficient_funds" } if @balances[from_account] < amount

    @balances[from_account] -= amount
    @balances[to_account] += amount
    @transfers[transaction_id] = {
      from_account: from_account,
      to_account: to_account,
      amount: amount,
      timestamp: timestamp,
      reversed: false,
    }
    { status: "applied", reason: nil }
  end

  # ── Part 2 ──────────────────────────────────────────────────────────────

  def reverse_transfer(transaction_id, reversal_id, timestamp)
    original = @transfers[transaction_id]
    raise KeyError, transaction_id if original.nil?
    return { status: "rejected", reason: "already_reversed" } if original[:reversed]

    result = record_transfer(reversal_id, original[:to_account], original[:from_account], original[:amount], timestamp)
    original[:reversed] = true if result[:status] == "applied"
    result
  end

  # ── Part 3 ──────────────────────────────────────────────────────────────

  def reconcile(statement_lines)
    matched = []
    mismatched = []
    missing_from_ledger = []
    seen_transaction_ids = Set.new

    statement_lines.each do |line|
      next unless line[:type] == "debit"

      transaction_id = line[:transaction_id]
      seen_transaction_ids << transaction_id
      transfer = @transfers[transaction_id]

      if transfer.nil?
        missing_from_ledger << transaction_id
      elsif transfer[:from_account] != line[:account_id]
        mismatched << { transaction_id: transaction_id, reason: "account_mismatch" }
      elsif transfer[:amount] != line[:amount]
        mismatched << { transaction_id: transaction_id, reason: "amount_mismatch" }
      else
        matched << transaction_id
      end
    end

    missing_from_statement = @transfers.keys.reject { |transaction_id| seen_transaction_ids.include?(transaction_id) }

    {
      matched: matched,
      mismatched: mismatched,
      missing_from_ledger: missing_from_ledger,
      missing_from_statement: missing_from_statement,
    }
  end
end
