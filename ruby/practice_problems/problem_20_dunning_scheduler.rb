# =============================================================================
# INTERVIEW PROBLEM 20: Subscription Dunning & Retry Scheduler
# Difficulty: Senior Software Engineer | Estimated time: 45 min
# =============================================================================
#
# CONTEXT
# -------
# You're building the recurring-billing retry logic for a subscription
# platform. When a scheduled charge fails (card declined, insufficient
# funds), the platform must not give up immediately — it retries on a
# backoff schedule, and if all retries fail, moves the subscription into
# dunning and eventually cancels it.
#
# For this problem you are building a DunningScheduler class.
# Store all state in instance variables set in `initialize`.
# Class variables and class-level instance variables will bleed between
# examples and between instances — avoid them.
# You choose the internal data structures; the public interface is what
# matters.
#
# Timestamps are ISO-8601 strings without timezone offset, e.g.
# "2024-01-01T00:00:00". Use Time.parse (from the "time" stdlib) for
# arithmetic.
#
# RETRY SCHEDULE
# -----------------
# RETRY_INTERVALS_DAYS = [1, 3, 7]
# After the Nth consecutive failed attempt (N = 1, 2, 3, ...), the next
# retry is scheduled RETRY_INTERVALS_DAYS[N - 1] days after that failed
# attempt's timestamp. Once N exceeds RETRY_INTERVALS_DAYS.length (i.e. a
# 4th consecutive failure has occurred), the schedule is exhausted — no
# further retry is scheduled.
#
# Example
#   dm = DunningScheduler.new
#   dm.create_subscription("sub_1", amount: 29.99)
#   dm.record_attempt("sub_1", "2024-01-01T00:00:00", succeeded: false)
#   # -> { status: "past_due", consecutive_failures: 1 }
#   dm.get_next_retry_time("sub_1")
#   # -> "2024-01-02T00:00:00"   (1 day later)
#   dm.record_attempt("sub_1", "2024-01-02T00:00:00", succeeded: true)
#   # -> { status: "active", consecutive_failures: 0 }
# =============================================================================

require "time"

class DunningScheduler
  def initialize
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Attempt tracking  (~12 min)
  # ---------------------------------------------------------------------------

  # Register a new subscription with status "active" and 0 consecutive
  # failures.
  #
  # @raise [ArgumentError] if subscription_id already exists
  def create_subscription(subscription_id, amount:)
    raise NotImplementedError
  end

  # Return the current status: "active" | "past_due" | "canceled".
  #
  # @raise [KeyError] if subscription_id does not exist
  def get_subscription_status(subscription_id)
    raise NotImplementedError
  end

  # Record the outcome of a charge attempt for subscription_id.
  #
  # - Raise KeyError if subscription_id does not exist.
  # - If succeeded is true: consecutive_failures resets to 0 and status
  #   becomes "active".
  # - If succeeded is false: consecutive_failures increments by 1 and
  #   status becomes "past_due" (whether it was already "active" or
  #   already "past_due").
  #
  # @return [Hash] { status: String, consecutive_failures: Integer }
  def record_attempt(subscription_id, timestamp, succeeded:)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Backoff scheduling  (~15 min)
  # ---------------------------------------------------------------------------

  # Return the ISO-8601 timestamp of the next scheduled retry for
  # subscription_id, computed from RETRY_INTERVALS_DAYS (see file header)
  # and the timestamp + consecutive_failures recorded by record_attempt
  # (Part 1).
  #
  # - Raise KeyError if subscription_id does not exist.
  # - Return nil if the subscription is "active" (nothing to retry),
  #   "canceled", or if consecutive_failures exceeds
  #   RETRY_INTERVALS_DAYS.length (schedule exhausted).
  #
  # @return [String, nil]
  def get_next_retry_time(subscription_id)
    raise NotImplementedError
  end

  # Return true if get_next_retry_time(subscription_id) is not nil and is
  # at or before current_time. Return false otherwise (including when
  # get_next_retry_time returns nil).
  def is_retry_due(subscription_id, current_time)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Auto-cancellation  (~18 min)
  # ---------------------------------------------------------------------------

  # Manually cancel subscription_id.
  # Raise KeyError if subscription_id does not exist.
  # Idempotent: canceling an already-canceled subscription just returns its
  # current state without error.
  #
  # @return [Hash] { status: "canceled", consecutive_failures: Integer }
  def cancel_subscription(subscription_id, timestamp)
    raise NotImplementedError
  end

  # Extend record_attempt (Part 1) once more:
  #   - Raise ArgumentError if record_attempt is called on a subscription
  #     whose status is already "canceled".
  #   - After recording a failed attempt (succeeded: false), check whether
  #     the retry schedule is now exhausted for this subscription (i.e.
  #     get_next_retry_time would return nil because consecutive_failures
  #     exceeds RETRY_INTERVALS_DAYS.length). If so, the subscription's
  #     status becomes "canceled" instead of "past_due", and the returned
  #     hash reflects that.
end
