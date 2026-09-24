require "set"

module LabCadenceMonitor
  def self.make_monitor
    { patients: {} }
  end

  def self.patient_or_raise(monitor, patient_id)
    patient = monitor[:patients][patient_id]
    raise KeyError, "unknown patient: #{patient_id}" unless patient

    patient
  end
  private_class_method :patient_or_raise

  def self.validate_required_lab(monitor, patient_id, lab_type)
    patient = patient_or_raise(monitor, patient_id)
    unless patient[:required_labs].include?(lab_type)
      raise ArgumentError, "#{lab_type} is not required for #{patient_id}"
    end

    patient
  end
  private_class_method :validate_required_lab

  def self.register_patient(monitor, patient_id, required_labs)
    raise ArgumentError, "required_labs must not be empty" if required_labs.empty?

    patient = monitor[:patients][patient_id]
    if patient
      patient[:required_labs].merge(required_labs)
    else
      monitor[:patients][patient_id] = {
        required_labs: Set.new(required_labs),
        deadlines: {},
        submissions: {}
      }
    end
  end

  def self.add_required_lab(monitor, patient_id, lab_type)
    patient_or_raise(monitor, patient_id)[:required_labs].add(lab_type)
  end

  def self.required_labs(monitor, patient_id)
    patient_or_raise(monitor, patient_id)[:required_labs]
  end

  def self.set_lab_deadline(monitor, patient_id, lab_type, due_date)
    patient = validate_required_lab(monitor, patient_id, lab_type)
    list = (patient[:deadlines][lab_type] ||= [])
    list << due_date unless list.include?(due_date)
  end

  def self.record_submission(monitor, patient_id, lab_type, submitted_on)
    patient = validate_required_lab(monitor, patient_id, lab_type)
    (patient[:submissions][lab_type] ||= []) << submitted_on

    deadlines = patient[:deadlines][lab_type]
    return unless deadlines

    sorted = deadlines.sort
    cleared_index = sorted.index { |due_date| due_date >= submitted_on }
    sorted.delete_at(cleared_index) if cleared_index
    patient[:deadlines][lab_type] = sorted
  end

  def self.overdue?(monitor, patient_id, lab_type, as_of)
    patient = monitor[:patients][patient_id]
    return false unless patient
    return false unless patient[:required_labs].include?(lab_type)

    deadlines = patient[:deadlines][lab_type]
    return false unless deadlines

    deadlines.any? { |due_date| due_date < as_of }
  end

  def self.overdue_labs(monitor, patient_id, as_of)
    patient = monitor[:patients][patient_id]
    return [] unless patient

    patient[:required_labs].select { |lab_type| overdue?(monitor, patient_id, lab_type, as_of) }.sort
  end

  def self.compliance_report(monitor, as_of)
    report = monitor[:patients].keys.filter_map do |patient_id|
      labs = overdue_labs(monitor, patient_id, as_of)
      next if labs.empty?

      { patient_id: patient_id, overdue_labs: labs, overdue_count: labs.size }
    end

    report.sort_by { |entry| [-entry[:overdue_count], entry[:patient_id]] }
  end

  def self.submission_history(monitor, patient_id, lab_type)
    patient = monitor[:patients][patient_id]
    return [] unless patient

    (patient[:submissions][lab_type] || []).sort
  end

  def self.days_since_last_submission(monitor, patient_id, lab_type, as_of)
    history = submission_history(monitor, patient_id, lab_type)
    return nil if history.empty?

    (as_of - history.max).to_i
  end
end
