require "time"

class CardRiskEngine
  BLOCKED_MERCHANT_CATEGORIES = %w[gambling cash_advance crypto_exchange].freeze
  AMOUNT_LIMIT = 5000
  HIGH_AMOUNT_MIN = 1000

  VELOCITY_COUNT_WINDOW_SECS = 60
  VELOCITY_COUNT_MAX = 3
  VELOCITY_AMOUNT_WINDOW_SECS = 600
  VELOCITY_AMOUNT_MAX = 10_000

  BLOCK_WINDOW_SECS = 24 * 60 * 60
  BLOCK_DECLINE_THRESHOLD = 3

  SEVERITY = { "approve" => 0, "review" => 1, "decline" => 2 }.freeze

  def initialize
    @history = {} # card_id -> Array<{ amount:, ts:, decision: }>
  end

  # ---------------------------------------------------------------------------
  # PART 1 + 2 — Static rules + velocity checks
  # ---------------------------------------------------------------------------

  def evaluate_transaction(card_id, amount, merchant_category, timestamp)
    ts = Time.parse(timestamp)
    history = (@history[card_id] ||= [])

    if blocked?(history, ts)
      history << { amount: amount, ts: ts, decision: "decline" }
      return { decision: "decline", reasons: ["card_blocked"] }
    end

    reasons = []
    decision = "approve"
    flag = lambda do |reason, level|
      reasons << reason
      decision = level if SEVERITY[level] > SEVERITY[decision]
    end

    flag.call("amount_limit_exceeded", "decline") if amount > AMOUNT_LIMIT
    flag.call("blocked_merchant_category", "decline") if BLOCKED_MERCHANT_CATEGORIES.include?(merchant_category)
    flag.call("high_amount", "review") if amount >= HIGH_AMOUNT_MIN && amount <= AMOUNT_LIMIT

    count_window = window(history, ts, VELOCITY_COUNT_WINDOW_SECS)
    flag.call("velocity_count_exceeded", "decline") if count_window.length + 1 > VELOCITY_COUNT_MAX

    amount_window = window(history, ts, VELOCITY_AMOUNT_WINDOW_SECS)
    total = amount_window.sum { |h| h[:amount] } + amount
    flag.call("velocity_amount_exceeded", "review") if total > VELOCITY_AMOUNT_MAX

    history << { amount: amount, ts: ts, decision: decision }
    { decision: decision, reasons: reasons }
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Auto-blocking
  # ---------------------------------------------------------------------------

  def is_card_blocked(card_id)
    history = @history[card_id]
    return false if history.nil? || history.empty?

    latest_ts = history.last[:ts]
    blocked?(history, latest_ts)
  end

  private

  def window(history, ts, window_secs)
    earliest = ts - window_secs
    history.select { |h| h[:ts] >= earliest && h[:ts] <= ts }
  end

  def blocked?(history, ts)
    declines = window(history, ts, BLOCK_WINDOW_SECS).count { |h| h[:decision] == "decline" }
    declines >= BLOCK_DECLINE_THRESHOLD
  end
end
