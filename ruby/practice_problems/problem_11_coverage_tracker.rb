# =============================================================================
# INTERVIEW PROBLEM 11: Sensor Coverage Tracker
# Difficulty: Senior Software Engineer | Estimated time: 45 min
# =============================================================================
#
# CONTEXT
# -------
# You're building the health-monitoring subsystem for a platform that deploys
# radio-receiver sensor stations across geographic regions. Each station
# periodically sends a heartbeat. When a station falls silent, operators need
# to know, and the platform's incident-detection coverage for that region may
# be affected.
#
# For this problem you are building a CoverageTracker class.
# Store all state in instance variables set in `initialize`. Class variables,
# class-level instance variables, and mutable class-body constants will bleed
# between examples and between instances — avoid them.
# You choose the internal data structures; the public interface is what matters.
#
# DATA MODEL
# ----------
# Station:
#   { station_id:, name:, region: }   # region is a logical grouping, e.g. "downtown"
#
# Outage:
#   { station_id:, start_ts:, end_ts: }   # end_ts is nil while the outage is open
#
# Timestamps are ISO-8601 strings without timezone offset (e.g.
# "2024-01-01T10:00:00").
#
# # Example
# #   ct = CoverageTracker.new
# #   ct.register_station("sta-001", "North Tower", region: "downtown")
# #   ct.register_station("sta-002", "South Tower", region: "downtown")
# #   ct.record_heartbeat("sta-001", "2024-01-01T10:00:00")
# #   ct.record_heartbeat("sta-002", "2024-01-01T10:00:05")
# #   ct.get_last_heartbeat("sta-001")                                  # -> "2024-01-01T10:00:00"
# #   ct.get_stale_stations("2024-01-01T10:05:00", stale_after_secs: 120)  # -> []
# #   ct.record_outage_start("sta-001", "2024-01-01T10:10:00")
# #   ct.get_region_coverage("downtown", "2024-01-01T10:10:30", stale_after_secs: 120)
# #   # -> { region: "downtown", total: 2, healthy: 1, stale: 1, has_coverage: true }

require "time"

class CoverageTracker
  def initialize
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Station registration and heartbeats  (~10 min)
  # ---------------------------------------------------------------------------

  # Register a new station and return it. Raises ArgumentError if station_id
  # already exists.
  def register_station(station_id, name, region:)
    raise NotImplementedError
  end

  # Records a heartbeat for the station.
  # - Raises KeyError if station_id does not exist.
  # - Raises ArgumentError if ts is earlier than or equal to the station's
  #   most recent heartbeat (out-of-order and duplicate heartbeats rejected).
  def record_heartbeat(station_id, ts)
    raise NotImplementedError
  end

  # Returns the timestamp of the most recent heartbeat, or nil if the station
  # has never sent one. Raises KeyError if station_id does not exist.
  def get_last_heartbeat(station_id)
    raise NotImplementedError
  end

  # Returns all stations, optionally filtered to a specific region. Sorted by
  # station_id ascending.
  def get_stations(region: nil)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Staleness detection and outage tracking  (~15 min)
  # ---------------------------------------------------------------------------

  # Returns station hashes for all stations that are stale as of as_of_ts.
  # A station is stale if it has never sent a heartbeat, or its last
  # heartbeat was more than stale_after_secs seconds before as_of_ts.
  # Results are sorted by station_id ascending.
  def get_stale_stations(as_of_ts, stale_after_secs:)
    raise NotImplementedError
  end

  # Opens a new outage record for the station (end_ts = nil).
  # - Raises KeyError if station_id does not exist.
  # - Raises ArgumentError if the station already has an open outage.
  def record_outage_start(station_id, ts)
    raise NotImplementedError
  end

  # Closes the most recent open outage for the station by setting end_ts = ts.
  # - Raises KeyError if station_id does not exist.
  # - Raises ArgumentError if the station has no open outage.
  def record_outage_end(station_id, ts)
    raise NotImplementedError
  end

  # Returns all Outage hashes for the station, sorted by start_ts ascending.
  # Raises KeyError if station_id does not exist.
  def get_outages(station_id)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Coverage analysis  (~20 min)
  # ---------------------------------------------------------------------------

  # Returns a coverage summary for the region:
  #   { region:, total:, healthy:, stale:, has_coverage: }
  # Uses get_stations (Part 1) and get_stale_stations (Part 2) internally.
  def get_region_coverage(region, as_of_ts, stale_after_secs:)
    raise NotImplementedError
  end

  # Returns an outage summary for the station:
  #   { station_id:, total_outages:, open_outage:, total_outage_secs: }
  # For an open outage, counts duration from start_ts up to as_of_ts.
  # Uses get_outages (Part 2) internally. Raises KeyError if station_id does
  # not exist.
  def get_outage_summary(station_id, as_of_ts)
    raise NotImplementedError
  end
end
