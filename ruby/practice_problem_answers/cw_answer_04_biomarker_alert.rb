require "date"

class BiomarkerMonitor
  GLUCOSE_RANGE = (70.0..180.0)
  KETONE_RANGE = (0.5..3.0)

  Reading = Struct.new(:patient_id, :reading_type, :value, :recorded_on)

  def initialize(readings)
    @readings = []
    # index: [patient_id, reading_type] => { date => [Reading, ...] }
    @by_patient_type_date = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }
    readings.each { |r| index_reading(r) }
  end

  def out_of_range?(reading)
    case reading.reading_type
    when "glucose" then !GLUCOSE_RANGE.cover?(reading.value)
    when "ketone" then !KETONE_RANGE.cover?(reading.value)
    else false
    end
  end

  def max_consecutive_out_of_range_days(patient_id, reading_type)
    by_date = @by_patient_type_date[[patient_id, reading_type]]
    out_of_range_dates = by_date.select { |_date, readings| readings.any? { |r| out_of_range?(r) } }.keys.sort

    best = 0
    streak = 0
    prev_date = nil
    out_of_range_dates.each do |d|
      streak = (prev_date && d == prev_date + 1) ? streak + 1 : 1
      best = streak if streak > best
      prev_date = d
    end
    best
  end

  def outreach_list(min_consecutive_days: 3)
    entries = []
    @by_patient_type_date.each_key do |patient_id, reading_type|
      next if reading_type == "weight"

      streak = max_consecutive_out_of_range_days(patient_id, reading_type)
      next if streak < min_consecutive_days

      latest = @by_patient_type_date[[patient_id, reading_type]]
                 .flat_map { |_date, readings| readings }
                 .select { |r| out_of_range?(r) }
                 .max_by(&:recorded_on)

      entries << {
        patient_id: patient_id,
        reading_type: reading_type,
        consecutive_days: streak,
        latest_value: latest.value
      }
    end
    entries.sort_by { |e| -e[:consecutive_days] }
  end

  def add_reading(reading)
    by_date = @by_patient_type_date[[reading.patient_id, reading.reading_type]]
    same_day = by_date[reading.recorded_on]
    return false if same_day.any? { |r| (r.value - reading.value).abs <= 0.5 }

    index_reading(reading)
    true
  end

  private

  def index_reading(reading)
    @readings << reading
    @by_patient_type_date[[reading.patient_id, reading.reading_type]][reading.recorded_on] << reading
  end
end
