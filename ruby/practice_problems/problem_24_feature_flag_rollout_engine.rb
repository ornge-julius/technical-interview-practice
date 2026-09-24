require "digest"

# =============================================================================
# INTERVIEW PROBLEM 24: Feature Flag Rollout Engine
# Difficulty: Senior Software Engineer | Estimated time: 45 min
# =============================================================================
#
# CONTEXT
# -------
# You're building the feature-flag evaluation engine for a SaaS platform's
# internal tooling. A flag's schema is fixed and given to you below — this
# problem is about the application logic on top of it, not about designing
# your own data structures.
#
# Store all state in instance variables set in `initialize`. Class variables
# (`@@foo`), class-level instance variables, and mutable class-body constants
# will bleed between examples and between instances — avoid them.
#
# DATA MODEL
# ----------
# A flag has:
#   - a unique flag_id (String)
#   - a stage: :draft, :ramping, :full, or :archived
#   - an allow_list (Array of user_id Strings always enabled, stage permitting)
#   - a percentage (Integer 0-100, used only while stage == :ramping)
#   - a killed flag (bool, set by the Part 3 kill switch)
#
# Legal stage transitions: draft -> ramping -> full -> archived, and
# ramping -> archived directly (cancelling a rollout). No other transition
# is legal (including any transition out of :archived).
#
# Example
#   engine = FeatureFlagEngine.new
#   engine.create_flag("new_dashboard", stage: :ramping, percentage: 0, allow_list: ["alice"])
#   engine.enabled?("new_dashboard", "alice")   # -> true (allow-listed)
#   engine.enabled?("new_dashboard", "bob")     # -> false (percentage is 0)
#   engine.set_percentage("new_dashboard", 100, at: 1)
#   engine.enabled?("new_dashboard", "bob")     # -> true
#   engine.transition!("new_dashboard", :full, at: 2)
#   engine.transition!("new_dashboard", :archived, at: 3)
#   engine.enabled?("new_dashboard", "bob")     # -> false (archived is always off)
#
# =============================================================================

class FeatureFlagEngine
  def initialize
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Evaluation (~15 min)
  # ---------------------------------------------------------------------------

  # Register a new flag. Raise ArgumentError if flag_id already exists, or
  # if percentage is not an Integer in 0..100.
  def create_flag(flag_id, stage: :draft, allow_list: [], percentage: 0)
    raise NotImplementedError
  end

  # Return whether the flag is enabled for user_id, evaluated in this order:
  #   1. :draft or :archived stage -> always false, regardless of allow_list
  #      or percentage.
  #   2. user_id in the flag's allow_list -> true.
  #   3. stage == :full -> true (fully rolled out to everyone).
  #   4. stage == :ramping -> true if user_id's deterministic bucket (see
  #      `bucket_for` below) is less than the flag's current percentage.
  # Raise KeyError if flag_id is not found.
  def enabled?(flag_id, user_id)
    raise NotImplementedError
  end

  # Return a deterministic Integer in 0..99 for (flag_id, user_id) — the
  # same pair must always produce the same bucket. Suggested implementation:
  # hash "#{flag_id}:#{user_id}" with Digest::MD5 and reduce mod 100.
  def bucket_for(flag_id, user_id)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Stage lifecycle (~15 min)
  # ---------------------------------------------------------------------------

  # Move flag_id from its current stage to to_stage. Raise KeyError if
  # flag_id is not found. Raise ArgumentError if the transition is not in
  # the legal-transitions list above. Record an entry in the flag's audit
  # log (see Part 3).
  def transition!(flag_id, to_stage, at:)
    raise NotImplementedError
  end

  # Update a flag's rollout percentage. Raise KeyError if flag_id is not
  # found. Raise ArgumentError if the flag's stage is not :ramping, or if
  # percentage is not an Integer in 0..100. Record an entry in the audit log.
  def set_percentage(flag_id, percentage, at:)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Kill switch and audit log (~15 min)
  # ---------------------------------------------------------------------------

  # Force-disable a flag: enabled? must return false for every user
  # regardless of stage, allow_list, or percentage, until the flag is
  # un-killed (there is no un-kill method — this is a one-way emergency
  # switch for this problem). Raise KeyError if flag_id is not found.
  # Record an entry in the audit log.
  def kill_switch!(flag_id, at:)
    raise NotImplementedError
  end

  # Return the flag's audit log: an Array of Hashes, oldest first, one per
  # transition!, set_percentage, and kill_switch! call made against this
  # flag, each including at minimum an :event key and an :at key. Raise
  # KeyError if flag_id is not found.
  def audit_log(flag_id)
    raise NotImplementedError
  end
end
