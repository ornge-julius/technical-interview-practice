require "set"

class EnrollmentPipeline
  ALLOWED_TRANSITIONS = {
    "referred" => Set["screened"],
    "screened" => Set["enrolled", "ineligible"],
    "enrolled" => Set["active", "withdrawn"],
    "active" => Set["graduated", "churned", "withdrawn"]
  }.freeze

  TERMINAL_STATES = Set["ineligible", "withdrawn", "graduated", "churned"].freeze

  def initialize
    @patients = {}  # patient_id => { current_state:, last_state_change:, state_history: { state => seconds } }
  end

  def add_patient(patient_id, timestamp = 0.0)
    raise ArgumentError, "patient already registered: #{patient_id}" if @patients.key?(patient_id)

    @patients[patient_id] = {
      current_state: "referred",
      last_state_change: timestamp,
      state_history: {}
    }
  end

  def transition(patient_id, new_state, timestamp)
    patient = patient_or_raise(patient_id)
    current_state = patient[:current_state]

    if TERMINAL_STATES.include?(current_state) || !ALLOWED_TRANSITIONS[current_state].include?(new_state)
      raise ArgumentError, "cannot transition #{patient_id} from #{current_state} to #{new_state}"
    end

    patient[:state_history][current_state] = timestamp - patient[:last_state_change]
    patient[:current_state] = new_state
    patient[:last_state_change] = timestamp
  end

  def get_state(patient_id)
    patient_or_raise(patient_id)[:current_state]
  end

  def get_patients_in_state(state)
    @patients.select { |_, p| p[:current_state] == state }.keys.sort
  end

  def time_in_state(patient_id, state, as_of)
    patient = patient_or_raise(patient_id)
    if patient[:state_history].key?(state)
      patient[:state_history][state]
    elsif patient[:current_state] == state
      as_of - patient[:last_state_change]
    else
      0.0
    end
  end

  def conversion_rate(from_state, to_state)
    exited = @patients.select { |_, p| p[:state_history].key?(from_state) }
    return 0.0 if exited.empty?

    converted = exited.count do |_, p|
      p[:current_state] == to_state || p[:state_history].key?(to_state)
    end
    converted.to_f / exited.size
  end

  def patients_overdue(state, max_seconds, as_of)
    @patients.select { |_, p| p[:current_state] == state }
             .keys
             .select { |patient_id| time_in_state(patient_id, state, as_of) > max_seconds }
             .sort_by { |patient_id| -time_in_state(patient_id, state, as_of) }
  end

  def average_time_in_state(state, as_of)
    exited = @patients.select { |_, p| p[:state_history].key?(state) }
    return 0.0 if exited.empty?

    total = exited.sum { |_, p| p[:state_history][state] }
    total / exited.size
  end

  private

  def patient_or_raise(patient_id)
    @patients[patient_id] or raise ArgumentError, "unknown patient: #{patient_id}"
  end
end
