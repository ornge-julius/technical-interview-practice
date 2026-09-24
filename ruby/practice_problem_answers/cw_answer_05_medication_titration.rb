require "date"

class TitrationTracker
  Event = Struct.new(:patient_id, :medication, :direction, :dose_mg, :recorded_on)
  Medication = Struct.new(:name, :current_dose, :last_changed, :total_changes)

  def initialize(events)
    # (patient_id, medication) => [Event, ...] sorted chronologically
    @by_patient_med = Hash.new { |h, k| h[k] = [] }
    events.each { |e| index_event(e) }
  end

  def current_medications(patient_id)
    medications = []
    @by_patient_med.each_key do |pid, medication|
      next unless pid == patient_id

      events = @by_patient_med[[pid, medication]]
      latest = events.last
      next if latest.direction == "stop"

      medications << Medication.new(medication, latest.dose_mg, latest.recorded_on, events.length)
    end
    medications
  end

  def medication_history(patient_id, medication)
    @by_patient_med[[patient_id, medication]].dup
  end

  def titration_count(patient_id, medication, direction: nil)
    events = @by_patient_med[[patient_id, medication]]
    return events.length if direction.nil?

    events.count { |e| e.direction == direction }
  end

  def de_escalation_summary(patient_id)
    summary = {}
    @by_patient_med.each_key do |pid, medication|
      next unless pid == patient_id

      count = @by_patient_med[[pid, medication]].count { |e| %w[decrease stop].include?(e.direction) }
      summary[medication] = count if count > 0
    end
    summary
  end

  def patients_on_medication(medication)
    patients = []
    @by_patient_med.each_key do |pid, med|
      next unless med == medication

      patients << pid if @by_patient_med[[pid, med]].last.direction != "stop"
    end
    patients.sort
  end

  def most_titrated_medications(top_n: 3)
    totals = Hash.new(0)
    @by_patient_med.each do |(_pid, medication), events|
      totals[medication] += events.length
    end
    totals.sort_by { |_name, count| -count }.first(top_n)
  end

  def add_event(event)
    key = [event.patient_id, event.medication]
    events = @by_patient_med[key]
    events.reject! { |e| e.recorded_on == event.recorded_on }
    events << event
    events.sort_by!(&:recorded_on)
  end

  private

  def index_event(event)
    key = [event.patient_id, event.medication]
    @by_patient_med[key] << event
    @by_patient_med[key].sort_by!(&:recorded_on)
  end
end
