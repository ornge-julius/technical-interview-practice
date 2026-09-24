# =============================================================================
# INTERVIEW PROBLEM 13: Contract Lifecycle State Machine
# Difficulty: Senior Software Engineer | Estimated time: 45 min
# =============================================================================
#
# CONTEXT
# -------
# You're building the lifecycle management module for a contract platform.
# Every contract moves through a defined set of states from creation to
# completion or termination. Only specific transitions are allowed — illegal
# transitions must be rejected. All changes are audit-logged.
#
# For this problem you are building a ContractLifecycleManager class.
# Store all state in instance variables set in `initialize`. Class variables,
# class-level instance variables, and mutable class-body constants will bleed
# between examples and between instances — avoid them. (The VALID_TRANSITIONS
# lookup table below is a frozen, read-only constant — never mutated — so it
# is safe to share.)
# You choose the internal data structures; the public interface is what matters.
#
# DATA MODEL
# ----------
# Contract:
#   { contract_id:, title:, state:, created_at:, fields: }   # fields is a Hash of metadata
#
# AuditEntry:
#   { contract_id:, from_state:, to_state:, at:, actor: }   # from_state is nil for the initial entry
#
# STATE MACHINE
# -------------
# Valid states and allowed forward transitions:
#
#   draft          -> in_review
#   in_review      -> approved | draft
#   approved       -> executed
#   executed       -> active
#   active         -> expiring_soon | terminated
#   expiring_soon  -> expired | active | terminated
#   expired        -> (terminal)
#   terminated     -> (terminal)
#
# Timestamps are ISO-8601 strings without timezone offset.
#
# # Example
# #   cl = ContractLifecycleManager.new
# #   cl.create_contract("c-001", "Vendor MSA", created_at: "2025-01-01T09:00:00", actor: "alice")
# #   cl.get_contract("c-001")[:state]  # -> "draft"
# #   cl.transition("c-001", "in_review", at: "2025-01-02T10:00:00", actor: "alice")
# #   cl.transition("c-001", "approved",  at: "2025-01-03T11:00:00", actor: "bob")
# #   cl.get_contract("c-001")[:state]  # -> "approved"
# #   cl.transition("c-001", "draft", at: "2025-01-04T09:00:00", actor: "bob")
# #   # raises ArgumentError — approved -> draft is not a valid transition

class ContractLifecycleManager
  # Valid forward transitions from each state. Frozen and never mutated, so
  # it is safe as a class constant (does not violate the instance-state rule).
  VALID_TRANSITIONS = {
    "draft" => ["in_review"],
    "in_review" => ["approved", "draft"],
    "approved" => ["executed"],
    "executed" => ["active"],
    "active" => ["expiring_soon", "terminated"],
    "expiring_soon" => ["expired", "active", "terminated"],
    "expired" => [],
    "terminated" => [],
  }.freeze

  def initialize
    raise NotImplementedError
  end

  # ── Part 1 ──────────────────────────────────────────────────────────────

  # Creates a new contract in the "draft" state and records the initial
  # audit entry (from_state: nil, to_state: "draft"). Returns the stored
  # contract hash (fields starts empty). Raises ArgumentError if
  # contract_id already exists.
  def create_contract(contract_id, title, created_at:, actor:)
    raise NotImplementedError
  end

  # Sets or updates a field on the contract's fields Hash. Returns the
  # updated contract hash. Raises KeyError if contract_id does not exist.
  def set_field(contract_id, key, value)
    raise NotImplementedError
  end

  # Returns the contract hash. Raises KeyError if contract_id does not exist.
  def get_contract(contract_id)
    raise NotImplementedError
  end

  # Moves a contract to a new state if the transition is valid, and appends
  # an AuditEntry. Returns the updated contract hash.
  # Raises KeyError if contract_id does not exist.
  # Raises ArgumentError if the transition from the current state to
  # to_state is not allowed (consult VALID_TRANSITIONS).
  def transition(contract_id, to_state, at:, actor:)
    raise NotImplementedError
  end

  # ── Part 2 ──────────────────────────────────────────────────────────────

  # Returns the full ordered audit trail for a contract (oldest first).
  # Raises KeyError if contract_id does not exist.
  def get_audit_trail(contract_id)
    raise NotImplementedError
  end

  # Returns all contracts currently in the given state, sorted by
  # contract_id ascending.
  def get_contracts_by_state(state)
    raise NotImplementedError
  end

  # Attempts to transition each contract in contract_ids to to_state. Calls
  # `transition` internally — do not duplicate its logic. Continues
  # processing remaining contracts even if one fails; collects all failures.
  # Returns { succeeded: [contract_id, ...], failed: [{ contract_id:, reason: }, ...] }
  def bulk_advance(contract_ids, to_state, at:, actor:)
    raise NotImplementedError
  end

  # ── Part 3 ──────────────────────────────────────────────────────────────

  # Returns aggregate counts across all contracts:
  #   { total:, by_state: { state => count, ... }, terminal_count: }
  # by_state only includes states with count > 0. terminal_count counts
  # contracts in "expired" or "terminated".
  def get_lifecycle_metrics
    raise NotImplementedError
  end

  # Returns contracts that have been stuck in the same non-terminal state
  # for more than 30 days without any transition, as of `as_of`.
  # "Stuck since" is the `at` timestamp of the most recent AuditEntry.
  # Uses get_audit_trail internally — do not duplicate its logic.
  # Returns a list of { contract_id:, title:, state:, stuck_since:, days_stuck: }
  # sorted by days_stuck descending.
  def get_overdue_contracts(as_of:)
    raise NotImplementedError
  end
end
