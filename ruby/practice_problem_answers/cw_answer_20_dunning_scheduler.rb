require "time"

class DunningScheduler
  RETRY_INTERVALS_DAYS = [1, 3, 7].freeze

  def initialize
    @subscriptions = {}
  end

  def get_sub(subscription_id)
    raise KeyError, subscription_id unless @subscriptions.key?(subscription_id)

    @subscriptions[subscription_id]
  end
  private :get_sub

  # ── Part 1 ──────────────────────────────────────────────────────────────

  def create_subscription(subscription_id, amount:)
    raise ArgumentError, "subscription already exists: #{subscription_id}" if @subscriptions.key?(subscription_id)

    @subscriptions[subscription_id] = {
      amount: amount,
      status: "active",
      consecutive_failures: 0,
      last_attempt_ts: nil,
    }
  end

  def get_subscription_status(subscription_id)
    get_sub(subscription_id)[:status]
  end

  def record_attempt(subscription_id, timestamp, succeeded:)
    sub = get_sub(subscription_id)
    raise ArgumentError, "subscription is canceled: #{subscription_id}" if sub[:status] == "canceled"

    sub[:last_attempt_ts] = timestamp
    if succeeded
      sub[:consecutive_failures] = 0
      sub[:status] = "active"
    else
      sub[:consecutive_failures] += 1
      sub[:status] = "past_due"
      sub[:status] = "canceled" if get_next_retry_time(subscription_id).nil?
    end

    { status: sub[:status], consecutive_failures: sub[:consecutive_failures] }
  end

  # ── Part 2 ──────────────────────────────────────────────────────────────

  def get_next_retry_time(subscription_id)
    sub = get_sub(subscription_id)
    return nil if %w[active canceled].include?(sub[:status])

    failures = sub[:consecutive_failures]
    return nil if failures < 1 || failures > RETRY_INTERVALS_DAYS.length

    interval_days = RETRY_INTERVALS_DAYS[failures - 1]
    last_ts = Time.parse(sub[:last_attempt_ts])
    (last_ts + (interval_days * 24 * 60 * 60)).strftime("%Y-%m-%dT%H:%M:%S")
  end

  def is_retry_due(subscription_id, current_time)
    next_retry = get_next_retry_time(subscription_id)
    return false if next_retry.nil?

    Time.parse(next_retry) <= Time.parse(current_time)
  end

  # ── Part 3 ──────────────────────────────────────────────────────────────

  def cancel_subscription(subscription_id, _timestamp)
    sub = get_sub(subscription_id)
    sub[:status] = "canceled"
    { status: "canceled", consecutive_failures: sub[:consecutive_failures] }
  end
end
