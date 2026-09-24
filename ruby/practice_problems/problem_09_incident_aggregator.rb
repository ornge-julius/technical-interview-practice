require "time"
require "securerandom"

# =============================================================================
# INTERVIEW PROBLEM 9: Multi-Source Incident Aggregator
# Difficulty: Senior Software Engineer | Estimated time: 45 min
# =============================================================================
#
# CONTEXT
# -------
# You're building the incident aggregation layer for a public safety
# intelligence platform. The platform ingests incident reports from multiple
# independent data sources (radio dispatch transcriptions, field sensors,
# social media monitors). Different sources frequently report the same
# real-world event, so the system must deduplicate and group raw reports into
# unified incidents.
#
# For this problem you are building an IncidentAggregator class.
# Store all state in instance variables set in `initialize`. Class variables
# and class-level instance variables will bleed between examples and between
# IncidentAggregator instances — avoid them.
# You choose the internal data structures; the public interface is what
# matters.
#
# DATA MODEL
# ----------
# Report (Hash with symbol keys):
#   {
#     report_id:    String,
#     source_id:    String,
#     event_type:   String,        # e.g. "shooting", "car-crash", "fire"
#     location_key: String,        # opaque string, e.g. "downtown", "sector-7"
#     ts:           String,        # ISO-8601 timestamp (no timezone offset),
#                                  # e.g. "2024-01-01T10:00:00"
#     incident_id:  String or nil  # nil until assigned to an incident
#   }
#
# Incident (Hash with symbol keys):
#   {
#     incident_id:  String,
#     event_type:   String,        # set at creation time
#     location_key: String,        # set at creation time
#     report_ids:   Array[String], # report IDs in ts-ascending order
#     report_count: Integer,
#     latest_ts:    String or nil  # ts of the most recently added report, or nil
#   }
#
# Timestamps are ISO-8601 strings without timezone offset. Use Time.parse (from
# the "time" stdlib) for arithmetic when comparing or computing durations.
#
# Example
#   agg = IncidentAggregator.new
#   agg.ingest_report("r1", "radio-north", "shooting", "downtown", "2024-01-01T10:00:00")
#   agg.ingest_report("r2", "radio-south", "shooting", "downtown", "2024-01-01T10:00:45")
#   agg.ingest_report("r3", "social-feed", "car-crash", "midtown",  "2024-01-01T10:01:00")
#   agg.create_incident("inc-001", "shooting", "downtown")
#   agg.add_report_to_incident("inc-001", "r1")
#   agg.add_report_to_incident("inc-001", "r2")
#   agg.get_incident("inc-001")[:report_count]  # -> 2
#   agg.get_unassigned_reports                  # -> [r3 report Hash]
#   agg.auto_ingest_report("r4", "radio-east", "shooting", "downtown",
#                           "2024-01-01T10:01:30", 120)
#   # -> "inc-001"  (within 120 s window, same type + location)

class IncidentAggregator
  def initialize
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Report ingestion (~10 min)
  # ---------------------------------------------------------------------------

  # Stores a new raw report and returns it.
  # The report's incident_id starts as nil.
  # Raises ArgumentError if report_id already exists.
  def ingest_report(report_id, source_id, event_type, location_key, ts)
    raise NotImplementedError
  end

  # Returns the report Hash, or nil if not found.
  def get_report(report_id)
    raise NotImplementedError
  end

  # Returns all reports, optionally filtered by location_key and/or
  # event_type (both filters applied when both are given).
  # Results are sorted by ts ascending.
  def get_reports(location_key: nil, event_type: nil)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Manual incident grouping (~15 min)
  # ---------------------------------------------------------------------------

  # Creates and returns a new, empty incident with the given event_type and
  # location_key.
  # Raises ArgumentError if incident_id already exists.
  def create_incident(incident_id, event_type, location_key)
    raise NotImplementedError
  end

  # Assigns a report to an incident.
  # - Raises KeyError if incident_id or report_id does not exist.
  # - Raises ArgumentError if the report is already assigned to any incident.
  # - Sets report[:incident_id] = incident_id.
  # - Updates the incident's report_ids (kept in ts-ascending order),
  #   report_count, and latest_ts.
  def add_report_to_incident(incident_id, report_id)
    raise NotImplementedError
  end

  # Returns the incident Hash (including up-to-date report_ids, report_count,
  # and latest_ts), or nil if not found.
  # report_ids must be ordered by the corresponding report's ts, ascending.
  def get_incident(incident_id)
    raise NotImplementedError
  end

  # Returns all reports whose incident_id is still nil, sorted by ts
  # ascending.
  def get_unassigned_reports
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Automatic deduplication (~20 min)
  # ---------------------------------------------------------------------------

  # Ingests a new report and automatically assigns it to an incident:
  #
  # 1. Calls ingest_report to store the report.
  # 2. Finds all *active* incidents whose event_type and location_key match
  #    the incoming report's. An incident is "active" if its latest_ts is
  #    within time_window_secs of the new report's ts:
  #        latest_ts >= ts - time_window_secs
  #    Incidents with no reports (latest_ts is nil) are not active.
  # 3. If one or more matches exist, picks the one whose latest_ts is closest
  #    to ts (i.e. most recently active). Breaks ties by incident_id
  #    lexicographically ascending.
  # 4. If no active match exists, creates a new incident (auto-generates a
  #    unique incident_id; any scheme is fine as long as it doesn't clash
  #    with existing IDs).
  # 5. Calls add_report_to_incident to assign the report.
  # 6. Returns the incident_id.
  def auto_ingest_report(report_id, source_id, event_type, location_key, ts, time_window_secs)
    raise NotImplementedError
  end

  # Returns all incidents that have a latest_ts within time_window_secs of
  # as_of_ts:
  #     latest_ts >= as_of_ts - time_window_secs
  #
  # Sorted by latest_ts descending (most-recently-active first).
  # Incidents with no reports (latest_ts is nil) are excluded.
  def get_active_incidents(as_of_ts, time_window_secs)
    raise NotImplementedError
  end
end
