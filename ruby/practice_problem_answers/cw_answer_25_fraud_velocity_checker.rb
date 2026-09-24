module FraudVelocityChecker
  HIGH_FREQUENCY_WINDOW_SECONDS = 60
  HIGH_FREQUENCY_COUNT_THRESHOLD = 5
  HIGH_AMOUNT_WINDOW_SECONDS = 3600
  HIGH_AMOUNT_TOTAL_THRESHOLD = 5000

  # PART 1

  def self.make_ledger
    { transactions: Hash.new { |hash, key| hash[key] = [] } }
  end

  def self.record_transaction(ledger, account_id, amount, at)
    ledger[:transactions][account_id] << { amount: amount, at: at }
  end

  def self.velocity(ledger, account_id, window_seconds:, as_of:)
    txns = ledger[:transactions][account_id].select do |txn|
      txn[:at] > as_of - window_seconds && txn[:at] <= as_of
    end
    { count: txns.size, total: txns.sum { |txn| txn[:amount] } }
  end

  # PART 2

  def self.flag_risk(ledger, account_id, as_of:)
    rules = []

    frequency = velocity(ledger, account_id, window_seconds: HIGH_FREQUENCY_WINDOW_SECONDS, as_of: as_of)
    rules << :high_frequency if frequency[:count] > HIGH_FREQUENCY_COUNT_THRESHOLD

    amount = velocity(ledger, account_id, window_seconds: HIGH_AMOUNT_WINDOW_SECONDS, as_of: as_of)
    rules << :high_amount if amount[:total] > HIGH_AMOUNT_TOTAL_THRESHOLD

    rules
  end

  # PART 3

  def self.blocked?(ledger, account_id, as_of:)
    triggered = flag_risk(ledger, account_id, as_of: as_of)
    triggered.include?(:high_frequency) && triggered.include?(:high_amount)
  end

  def self.risk_report(ledger, as_of:)
    ledger[:transactions].keys.filter_map do |account_id|
      triggered = flag_risk(ledger, account_id, as_of: as_of)
      next if triggered.empty?

      {
        account_id: account_id,
        triggered_rules: triggered,
        blocked: blocked?(ledger, account_id, as_of: as_of),
      }
    end.sort_by { |entry| [-entry[:triggered_rules].size, entry[:account_id]] }
  end
end
