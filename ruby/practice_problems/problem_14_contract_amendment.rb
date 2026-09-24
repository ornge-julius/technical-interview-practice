# =============================================================================
# INTERVIEW PROBLEM 14: Contract Amendment Manager
# Difficulty: Senior Software Engineer | Estimated time: 45 min
# =============================================================================
#
# CONTEXT
# -------
# You're building the amendment-tracking module for a contract platform.
# After a contract is signed, its terms can be modified through formal
# amendments. Each amendment specifies a set of field overrides that take
# effect from a given date. To know the effective terms on any given date,
# you apply the base contract fields and then overlay amendments in
# chronological order up to that date.
#
# For this problem you are building a ContractAmendmentManager class.
# Store all state in instance variables set in `initialize`. Class variables,
# class-level instance variables, and mutable class-body constants will bleed
# between examples and between instances — avoid them.
# You choose the internal data structures; the public interface is what matters.
#
# DATA MODEL
# ----------
# Contract (base):
#   { contract_id:, title:, fields: }   # e.g. { value: 50000, payment_terms: "net-30" }
#
# Amendment:
#   { amendment_id:, contract_id:, effective_on:, overrides:, note: }
#
# Dates are ISO-8601 date strings ("YYYY-MM-DD").
#
# # Example
# #   mgr = ContractAmendmentManager.new
# #   mgr.add_contract("c-001", "Vendor MSA", fields: { value: 50000, payment_terms: "net-30" })
# #
# #   mgr.add_amendment("amd-1", "c-001", effective_on: "2025-03-01",
# #                      overrides: { payment_terms: "net-45" }, note: "extended terms")
# #   mgr.add_amendment("amd-2", "c-001", effective_on: "2025-06-01",
# #                      overrides: { value: 75000 }, note: "scope increase")
# #
# #   mgr.get_effective_contract("c-001", as_of_date: "2025-01-01")
# #   # -> { value: 50000, payment_terms: "net-30" }   (no amendments yet)
# #
# #   mgr.get_effective_contract("c-001", as_of_date: "2025-04-15")
# #   # -> { value: 50000, payment_terms: "net-45" }   (amd-1 applied)
# #
# #   mgr.get_effective_contract("c-001", as_of_date: "2025-07-01")
# #   # -> { value: 75000, payment_terms: "net-45" }   (amd-1 + amd-2 applied)

class ContractAmendmentManager
  def initialize
    raise NotImplementedError
  end

  # ── Part 1 ──────────────────────────────────────────────────────────────

  # Registers a base contract. Stores a copy of fields — never holds a
  # reference to the caller's Hash. Returns the stored contract hash.
  # Raises ArgumentError if contract_id already exists.
  def add_contract(contract_id, title, fields:)
    raise NotImplementedError
  end

  # Returns the base contract hash (original fields, no amendments applied).
  # Raises KeyError if contract_id does not exist.
  def get_base_contract(contract_id)
    raise NotImplementedError
  end

  # ── Part 2 ──────────────────────────────────────────────────────────────

  # Registers an amendment for a contract. Stores a copy of overrides.
  # Returns the stored amendment hash.
  # Raises ArgumentError if amendment_id already exists.
  # Raises KeyError if contract_id does not exist.
  def add_amendment(amendment_id, contract_id, effective_on:, overrides:, note:)
    raise NotImplementedError
  end

  # Returns all amendments for a contract, sorted by effective_on ascending,
  # then amendment_id ascending. Raises KeyError if contract_id does not exist.
  def get_amendments(contract_id)
    raise NotImplementedError
  end

  # Returns the resolved field values for a contract as of as_of_date.
  # Starts with the base fields, then applies amendments in chronological
  # order where effective_on <= as_of_date, overlaying their overrides.
  # Uses get_base_contract and get_amendments internally — do not duplicate
  # their logic. Raises KeyError if contract_id does not exist.
  def get_effective_contract(contract_id, as_of_date:)
    raise NotImplementedError
  end

  # ── Part 3 ──────────────────────────────────────────────────────────────

  # Returns the full history of a specific field's value across base and all
  # amendments that touched it, in chronological order (base always first).
  # Each item: { effective_on:, value:, source: }  ("base" or amendment_id)
  # Raises KeyError if contract_id does not exist, or if the field is not
  # present in the base contract or any amendment for that contract.
  def get_value_history(contract_id, field)
    raise NotImplementedError
  end

  # Returns a summary of amendment activity for a contract. Uses
  # get_amendments and get_effective_contract internally — do not duplicate
  # their logic.
  #   {
  #     contract_id:, amendment_count:, fields_amended: (sorted, unique),
  #     latest_amendment: (ISO date or nil), current_fields:
  #   }
  # For "today" use the most recent amendment's effective_on date if any
  # amendments exist, otherwise "2099-12-31" as a far-future sentinel.
  # Raises KeyError if contract_id does not exist.
  def get_amendment_summary(contract_id)
    raise NotImplementedError
  end
end
