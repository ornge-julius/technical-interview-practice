# =============================================================================
# INTERVIEW PROBLEM 22: Emergency Dispatch Triage Queue
# Difficulty: Senior Software Engineer | Estimated time: 45 min
# =============================================================================
#
# CONTEXT
# -------
# You're building the call-intake and dispatch engine for an emergency
# response center. Calls arrive with a severity level and must be triaged:
# the dispatcher always wants to send the next responder to the call that
# most urgently needs one, factoring in how long a call has already waited.
#
# You choose the internal data structures — the public interface below is
# what matters. Store all state in instance variables set in `initialize`.
# Class variables (`@@foo`), class-level instance variables, and mutable
# class-body constants will bleed between examples and between instances —
# avoid them.
#
# DATA MODEL
# ----------
# A call has:
#   - a unique call_id (String)
#   - a severity: :critical, :high, :medium, or :low
#   - an intake_time (Numeric, seconds — treat as a plain timeline, not wall clock)
#   - a status: :waiting, :dispatched, or :completed
#
# Each severity has an SLA deadline (seconds after intake by which a call
# should be dispatched):
#   :critical => 60
#   :high     => 300
#   :medium   => 900
#   :low      => 3600
#
# Example
#   queue = DispatchTriageQueue.new
#   queue.intake_call("c1", severity: :medium, at: 0)
#   queue.intake_call("c2", severity: :high, at: 0)
#   queue.next_to_dispatch(at: 10)        # -> "c2" (higher severity, within SLA)
#   queue.dispatch_call("c2", responder_id: "unit_5", at: 10)
#   queue.complete_call("c2", at: 40)
#   queue.sla_breach_stats                # => { total: 1, breached: 0, breach_rate: 0.0 }
#
# =============================================================================

class DispatchTriageQueue
  def initialize
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Call intake and status tracking (~15 min)
  # ---------------------------------------------------------------------------

  # Record a new call. Raise ArgumentError if call_id already exists, or if
  # severity is not one of :critical, :high, :medium, :low.
  def intake_call(call_id, severity:, at:)
    raise NotImplementedError
  end

  # Return :waiting, :dispatched, or :completed.
  # Raise KeyError if call_id is not found.
  def status(call_id)
    raise NotImplementedError
  end

  # Return the severity symbol for a call. Raise KeyError if not found.
  def severity(call_id)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 2 — SLA-aware dispatch selection (~20 min)
  # ---------------------------------------------------------------------------

  # Return the call_id of the single :waiting call with the highest
  # *effective* priority as of time `at`, or nil if no call is :waiting.
  #
  # Effective priority rules:
  #   - Base ranking is by severity: :critical > :high > :medium > :low.
  #   - A call that has been waiting longer than its severity's SLA deadline
  #     is escalated by one severity tier for ranking purposes (e.g. a
  #     breached :medium call ranks as :high; a breached :critical call has
  #     no higher tier to escalate to).
  #   - Ties (same effective tier) are broken by earliest intake_time (FIFO).
  #
  # This should build on top of status/severity from Part 1 rather than
  # tracking a separate parallel data structure.
  def next_to_dispatch(at:)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Responder assignment and SLA reporting (~10 min)
  # ---------------------------------------------------------------------------

  # Move a call from :waiting to :dispatched, recording the responder_id and
  # dispatch time. Raise KeyError if call_id is not found. Raise
  # ArgumentError if the call is not currently :waiting.
  def dispatch_call(call_id, responder_id:, at:)
    raise NotImplementedError
  end

  # Move a call from :dispatched to :completed, recording the completion
  # time. Raise KeyError if call_id is not found. Raise ArgumentError if the
  # call is not currently :dispatched.
  def complete_call(call_id, at:)
    raise NotImplementedError
  end

  # Return SLA statistics across every call that has been :dispatched
  # (whether or not it has since been completed):
  #   { total: Integer, breached: Integer, breach_rate: Float }
  # A call "breached" its SLA if it was dispatched at a time strictly later
  # than intake_time + its severity's SLA deadline. breach_rate is
  # breached / total (0.0 if total is 0).
  def sla_breach_stats
    raise NotImplementedError
  end
end
