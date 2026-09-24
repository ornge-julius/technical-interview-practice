require "time"
require "securerandom"

class IncidentAggregator
  def initialize
    @reports = {}
    @incidents = {}
  end

  def ingest_report(report_id, source_id, event_type, location_key, ts)
    raise ArgumentError, "duplicate report_id: #{report_id}" if @reports.key?(report_id)

    report = {
      report_id: report_id,
      source_id: source_id,
      event_type: event_type,
      location_key: location_key,
      ts: ts,
      incident_id: nil
    }
    @reports[report_id] = report
    report
  end

  def get_report(report_id)
    @reports[report_id]
  end

  def get_reports(location_key: nil, event_type: nil)
    reports = @reports.values
    reports = reports.select { |r| r[:location_key] == location_key } if location_key
    reports = reports.select { |r| r[:event_type] == event_type } if event_type
    reports.sort_by { |r| Time.parse(r[:ts]) }
  end

  def create_incident(incident_id, event_type, location_key)
    raise ArgumentError, "duplicate incident_id: #{incident_id}" if @incidents.key?(incident_id)

    incident = {
      incident_id: incident_id,
      event_type: event_type,
      location_key: location_key,
      report_ids: [],
      report_count: 0,
      latest_ts: nil
    }
    @incidents[incident_id] = incident
    incident
  end

  def add_report_to_incident(incident_id, report_id)
    incident = @incidents[incident_id]
    report = @reports[report_id]
    raise KeyError, "unknown incident or report" unless incident && report
    raise ArgumentError, "report already assigned: #{report_id}" if report[:incident_id]

    report[:incident_id] = incident_id
    member_reports = incident[:report_ids].map { |rid| @reports[rid] } + [report]
    sorted_reports = member_reports.sort_by { |r| Time.parse(r[:ts]) }

    incident[:report_ids] = sorted_reports.map { |r| r[:report_id] }
    incident[:report_count] += 1
    incident[:latest_ts] = report[:ts]
  end

  def get_incident(incident_id)
    @incidents[incident_id]
  end

  def get_unassigned_reports
    @reports.values.select { |r| r[:incident_id].nil? }.sort_by { |r| Time.parse(r[:ts]) }
  end

  def auto_ingest_report(report_id, source_id, event_type, location_key, ts, time_window_secs)
    ingest_report(report_id, source_id, event_type, location_key, ts)
    ts_time = Time.parse(ts)

    active = @incidents.values.select do |incident|
      incident[:location_key] == location_key &&
        incident[:event_type] == event_type &&
        incident[:latest_ts] &&
        Time.parse(incident[:latest_ts]) >= ts_time - time_window_secs
    end

    matching_incident =
      if active.any?
        active.sort_by { |incident| [-Time.parse(incident[:latest_ts]).to_f, incident[:incident_id]] }.first
      else
        create_incident(SecureRandom.uuid, event_type, location_key)
      end

    add_report_to_incident(matching_incident[:incident_id], report_id)
    matching_incident[:incident_id]
  end

  def get_active_incidents(as_of_ts, time_window_secs)
    as_of_time = Time.parse(as_of_ts)
    @incidents.values
              .select { |incident| incident[:latest_ts] && Time.parse(incident[:latest_ts]) >= as_of_time - time_window_secs }
              .sort_by { |incident| Time.parse(incident[:latest_ts]) }
              .reverse
  end
end
