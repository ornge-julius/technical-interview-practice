require "set"

# =============================================================================
# INTERVIEW PROBLEM 6: Lab Cadence Compliance Monitor
# Difficulty: Senior Software Engineer | Estimated time: 45 min
# Company context: Health Tech
# =============================================================================
#
# CONTEXT
# -------
# A health tech company requires patients to submit lab work at regular
# intervals so clinicians can track metabolic health markers (HbA1c, fasting
# glucose, lipids, kidney function, etc). Patients who miss lab deadlines need
# follow-up from their health coach.
#
# You are building LabCadenceMonitor — a module of singleton methods (no
# state on the module itself; all state lives inside the monitor Hash you
# create and pass around). All methods receive the monitor Hash as their
# first argument.
#
# PRE-GIVEN (do not modify)
# --------------------------
# make_monitor creates and returns the data store you will work with.
#
# Example
#   m = LabCadenceMonitor.make_monitor
#   LabCadenceMonitor.register_patient(m, "alice", ["hba1c", "bmp"])
#   LabCadenceMonitor.set_lab_deadline(m, "alice", "hba1c", Date.new(2024, 3, 31))
#   LabCadenceMonitor.record_submission(m, "alice", "hba1c", Date.new(2024, 3, 28))
#   LabCadenceMonitor.overdue?(m, "alice", "hba1c", Date.new(2024, 4, 1))  # -> false (submitted on time)
#   LabCadenceMonitor.overdue?(m, "alice", "bmp",   Date.new(2024, 4, 1))  # -> true  (no deadline set yet,
#                                                                          #           but bmp is required)
#
# NOTES
# -----
#   - "overdue" means: a required lab has a deadline that has passed (as_of >
#     due_date) AND no submission exists on or before the due_date.
#   - If a required lab has no deadline set, it is NOT considered overdue.
#   - A submission clears the specific deadline it satisfies (the earliest
#     uncleared deadline on or after the submission date).
#   - Patients can have multiple deadlines per lab type (e.g. quarterly HbA1c).
#   - All state lives inside the Hash returned by make_monitor. No module-level
#     or class-level state.
# =============================================================================

module LabCadenceMonitor
  # ---------------------------------------------------------------------------
  # PRE-GIVEN — do not modify
  # ---------------------------------------------------------------------------

  # Returns a fresh monitor data store.
  #
  # Schema (you may add keys as needed):
  #   {
  #     patients: {
  #       patient_id => {
  #         required_labs: Set[String],
  #         deadlines:     { lab_type => [Date, ...] },  # sorted ascending
  #         submissions:   { lab_type => [Date, ...] },  # sorted ascending
  #       }
  #     }
  #   }
  def self.make_monitor
    { patients: {} }
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Patient & lab registration (~10 min)
  # ---------------------------------------------------------------------------

  # Registers a new patient with a list of required lab types.
  #
  # If the patient already exists, adds any new lab types to their required
  # set (does not remove existing ones). Idempotent for labs already in the
  # set.
  #
  # Raises ArgumentError if required_labs is empty.
  def self.register_patient(monitor, patient_id, required_labs)
    raise NotImplementedError
  end

  # Adds a single required lab type to an existing patient's requirements.
  #
  # Raises KeyError if the patient doesn't exist.
  # No-op if the lab is already required.
  def self.add_required_lab(monitor, patient_id, lab_type)
    raise NotImplementedError
  end

  # Returns the set of required lab types for the patient.
  # Raises KeyError if the patient doesn't exist.
  def self.required_labs(monitor, patient_id)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Deadlines and submissions (~15 min)
  # ---------------------------------------------------------------------------

  # Adds a deadline for a specific lab type for the patient.
  #
  # A patient may have multiple deadlines for the same lab (e.g. quarterly).
  # Duplicate deadlines (same patient + lab + date) are ignored.
  #
  # Raises KeyError if the patient doesn't exist.
  # Raises ArgumentError if lab_type is not in the patient's required labs.
  def self.set_lab_deadline(monitor, patient_id, lab_type, due_date)
    raise NotImplementedError
  end

  # Records that the patient submitted a lab result on submitted_on.
  #
  # Clears the earliest uncleared deadline for this lab type that is
  # >= submitted_on. If no such deadline exists, the submission is still
  # recorded (it may satisfy a future deadline or serve as history).
  #
  # Raises KeyError if the patient doesn't exist.
  # Raises ArgumentError if lab_type is not in the patient's required labs.
  def self.record_submission(monitor, patient_id, lab_type, submitted_on)
    raise NotImplementedError
  end

  # Returns true if the patient has at least one uncleared deadline for
  # lab_type that has passed as of as_of (i.e. due_date < as_of).
  #
  # Returns false if:
  #   - The patient doesn't exist.
  #   - lab_type is not required for the patient.
  #   - No deadline has been set for that lab.
  #   - All past deadlines have been cleared by a submission.
  def self.overdue?(monitor, patient_id, lab_type, as_of)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Compliance reporting (~15 min)
  # ---------------------------------------------------------------------------

  # Returns a sorted array of lab type names that are currently overdue for
  # the patient as of as_of.
  #
  # Returns an empty array if the patient doesn't exist or has no overdue labs.
  def self.overdue_labs(monitor, patient_id, as_of)
    raise NotImplementedError
  end

  # Returns a report of all patients with at least one overdue lab as of as_of.
  #
  # Each entry in the array is a Hash:
  #   {
  #     patient_id:    String,
  #     overdue_labs:  Array[String],  # sorted lab names
  #     overdue_count: Integer,
  #   }
  #
  # Sorted by overdue_count descending (most overdue first), then
  # alphabetically by patient_id for ties.
  #
  # Returns an empty array if no patient has overdue labs.
  def self.compliance_report(monitor, as_of)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 4 — Submission history (~5 min)
  # ---------------------------------------------------------------------------

  # Returns a chronologically sorted array of all submission dates for
  # (patient_id, lab_type).
  #
  # Returns an empty array if the patient doesn't exist or has no submissions
  # for that lab type.
  def self.submission_history(monitor, patient_id, lab_type)
    raise NotImplementedError
  end

  # Returns the number of days between the patient's most recent submission
  # for lab_type and as_of.
  #
  # Returns nil if the patient has never submitted that lab type.
  def self.days_since_last_submission(monitor, patient_id, lab_type, as_of)
    raise NotImplementedError
  end
end
