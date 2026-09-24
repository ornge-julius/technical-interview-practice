# =============================================================================
# INTERVIEW PROBLEM 12: Contract Expiration Alert Scheduler
# Difficulty: Senior Software Engineer | Estimated time: 45 min
# =============================================================================
#
# CONTEXT
# -------
# You're building the alert-scheduling subsystem for a contract lifecycle
# management (CLM) platform used by legal and operations teams. Contracts
# have expiration dates, and stakeholders need to be notified days in advance
# so they can act before expiry.
#
# For this problem you are building a ContractAlertScheduler class.
# Store all state in instance variables set in `initialize`. Class variables,
# class-level instance variables, and mutable class-body constants will bleed
# between examples and between instances — avoid them.
# You choose the internal data structures; the public interface is what matters.
#
# DATA MODEL
# ----------
# Contract:
#   { contract_id:, title:, owner_email:, expires_on: }   # expires_on is "YYYY-MM-DD"
#
# AlertConfig:
#   { config_id:, days_before:, label: }
#
# SentRecord:
#   { contract_id:, config_id:, sent_on: }   # sent_on is "YYYY-MM-DD"
#
# Dates are ISO-8601 date strings (date-only, no time component).
#
# # Example
# #   scheduler = ContractAlertScheduler.new
# #   scheduler.add_contract("c-001", "Vendor MSA", "legal@acme.com", expires_on: "2025-06-30")
# #   scheduler.add_alert_config("cfg-30", days_before: 30, label: "30-day notice")
# #   scheduler.add_alert_config("cfg-7",  days_before: 7,  label: "final warning")
# #
# #   scheduler.get_contracts_expiring_between("2025-06-01", "2025-06-30")
# #   # -> [{ contract_id: "c-001", title: "Vendor MSA", ... }]
# #
# #   scheduler.compute_alert_schedule("c-001")
# #   # -> [
# #   #      { config_id: "cfg-30", label: "30-day notice", alert_on: "2025-05-31" },
# #   #      { config_id: "cfg-7",  label: "final warning",  alert_on: "2025-06-23" },
# #   #    ]
# #
# #   scheduler.get_due_alerts(as_of_date: "2025-06-01")
# #   # -> [{ contract_id: "c-001", config_id: "cfg-30", alert_on: "2025-05-31", ... }]

require "date"

class ContractAlertScheduler
  def initialize
    raise NotImplementedError
  end

  # ── Part 1 ──────────────────────────────────────────────────────────────

  # Registers a contract. Returns the stored contract hash.
  # Raises ArgumentError if contract_id already exists.
  def add_contract(contract_id, title, owner_email, expires_on:)
    raise NotImplementedError
  end

  # Registers a global alert configuration. Returns the stored config hash.
  # Raises ArgumentError if config_id already exists.
  def add_alert_config(config_id, days_before:, label:)
    raise NotImplementedError
  end

  # Returns all contracts whose expiration date falls within
  # [start_date, end_date], inclusive on both ends, sorted by expires_on
  # ascending.
  def get_contracts_expiring_between(start_date, end_date)
    raise NotImplementedError
  end

  # ── Part 2 ──────────────────────────────────────────────────────────────

  # Computes the full alert schedule for a contract by applying every
  # registered alert config. For each AlertConfig, the alert fires on
  # (expires_on - days_before days). Sorted by alert_on ascending.
  # Raises KeyError if contract_id does not exist.
  def compute_alert_schedule(contract_id)
    raise NotImplementedError
  end

  # Returns all alert schedule entries across all contracts whose alert_on
  # date is on or before as_of_date. Uses compute_alert_schedule internally —
  # do not duplicate its logic. Sorted by alert_on ascending, then
  # contract_id ascending.
  def get_due_alerts(as_of_date)
    raise NotImplementedError
  end

  # ── Part 3 ──────────────────────────────────────────────────────────────

  # Records that an alert was sent for a specific contract/config pair.
  # Raises KeyError if contract_id or config_id does not exist.
  def record_alert_sent(contract_id, config_id, sent_on:)
    raise NotImplementedError
  end

  # Returns the alert schedule for a contract, enriched with a "sent" flag,
  # excluding alerts whose alert_on is strictly before as_of_date. Uses
  # compute_alert_schedule and record_alert_sent state internally.
  # Raises KeyError if contract_id does not exist.
  def get_upcoming_alerts(contract_id, as_of_date)
    raise NotImplementedError
  end
end
