# =============================================================================
# INTERVIEW PROBLEM 1: Geofence Alert Rule Engine
# Difficulty: Senior Software Engineer | Estimated time: 45 min
# =============================================================================
#
# CONTEXT
# -------
# You're building a backend service for an IoT asset-tracking platform. Physical
# assets (forklifts, shipping containers, field equipment) carry GPS sensors that
# periodically report coordinates. The platform tracks which geographic "zone"
# (geofence) each asset is currently inside, and fires configured alert rules
# whenever an asset transitions between zones.
#
# For this problem, zones are axis-aligned bounding boxes — no geospatial
# libraries needed.
#
# This is a Hash-based problem: all state lives in a single tracker Hash
# returned by GeofenceAlertEngine.make_tracker. Every method is a module
# function (GeofenceAlertEngine.some_method) operating on that Hash — there is
# no class to instantiate.
#
# DATA MODEL
# ----------
# All state lives in a single tracker Hash (returned by make_tracker).
#
# Zone:
#   { id:, name:, bounds: { min_lat:, max_lat:, min_lng:, max_lng: } }
#
# Asset:
#   { id:, name:, lat: Float|nil, lng: Float|nil, zone_id: String|nil }
#   - lat/lng are nil until the first GPS update arrives.
#   - zone_id is the id of the zone the asset is currently in, or nil.
#
# AlertRule:
#   { id:, from_zone_id: String|nil, to_zone_id: String|nil, asset_id: String|nil }
#   - nil in from_zone_id matches ANY previous zone (including nil/"no zone").
#   - nil in to_zone_id   matches ANY new zone (including nil/"no zone").
#   - nil in asset_id     matches ANY asset.
#
# TriggeredAlert (appended to alert_log when a rule fires):
#   { rule_id:, asset_id:, from_zone_id: String|nil, to_zone_id: String|nil, timestamp: }
#
# Tracker:
#   {
#     zones: { zone_id => Zone },
#     assets: { asset_id => Asset },
#     alert_rules: [AlertRule],
#     alert_log: [TriggeredAlert],
#   }
#
# Example
#   tracker = GeofenceAlertEngine.make_tracker
#   GeofenceAlertEngine.add_zone(tracker, "warehouse", "Warehouse A", 35.00, 35.10, -106.70, -106.60)
#   GeofenceAlertEngine.add_asset(tracker, "forklift_1", "Forklift #1")
#   GeofenceAlertEngine.add_alert_rule(tracker, "rule_entry", nil, "warehouse", nil)
#   GeofenceAlertEngine.process_location_update(tracker, "forklift_1", 35.05, -106.65, "t1")
#   # -> [{ rule_id: "rule_entry", asset_id: "forklift_1", from_zone_id: nil, to_zone_id: "warehouse", timestamp: "t1" }]
# =============================================================================

module GeofenceAlertEngine
  # Return a fresh, empty tracker.
  def self.make_tracker
    { zones: {}, assets: {}, alert_rules: [], alert_log: [] }
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Zone membership  (warm-up, ~5 min)
  # ---------------------------------------------------------------------------

  # Return true if the asset's lat/lng falls inside the zone's bounding box.
  # - Bounds are inclusive on all edges.
  # - Return false if the asset has no location (lat or lng is nil).
  def self.in_zone?(asset, zone)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Locate an asset  (~5 min)
  # ---------------------------------------------------------------------------

  # Return the id of the first zone in the tracker that contains the asset, or nil.
  # - Return nil if the asset doesn't exist or has no location.
  # - Iterate zones in insertion order (standard Ruby Hash behavior).
  def self.current_zone_id(tracker, asset_id)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Process a location update  (core logic, ~15 min)
  # ---------------------------------------------------------------------------

  # Handle a new GPS reading for an asset:
  #
  # 1. Update the asset's lat and lng in the tracker.
  # 2. Recompute zone_id via current_zone_id and store it on the asset.
  # 3. If zone_id changed (including nil->zone or zone->nil), evaluate all
  #    alert_rules and collect any that match.
  # 4. Append each matched rule as a TriggeredAlert to tracker[:alert_log].
  # 5. Return the array of newly triggered alerts (empty array if no zone
  #    change or no rule matches).
  #
  # Raise KeyError if asset_id is not in tracker[:assets].
  #
  # Alert-rule matching — a rule matches when ALL three conditions hold:
  #   rule[:asset_id].nil?     || rule[:asset_id]     == asset_id
  #   rule[:from_zone_id].nil? || rule[:from_zone_id] == old_zone_id
  #   rule[:to_zone_id].nil?   || rule[:to_zone_id]   == new_zone_id
  def self.process_location_update(tracker, asset_id, lat, lng, timestamp)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 4 — CRUD helpers  (~15 min)
  # ---------------------------------------------------------------------------

  # Create a zone, store it in the tracker, and return it.
  # Raise ArgumentError if zone_id already exists.
  def self.add_zone(tracker, zone_id, name, min_lat, max_lat, min_lng, max_lng)
    raise NotImplementedError
  end

  # Remove a zone from the tracker. Raise KeyError if not found.
  # Any asset currently assigned to the removed zone should have its
  # zone_id set to nil. Do NOT fire alert rules for this forced change.
  def self.remove_zone(tracker, zone_id)
    raise NotImplementedError
  end

  # Create an asset with no initial location (lat: nil, lng: nil, zone_id: nil),
  # store it in the tracker, and return it.
  # Raise ArgumentError if asset_id already exists.
  def self.add_asset(tracker, asset_id, name)
    raise NotImplementedError
  end

  # Add an alert rule to the tracker and return it.
  # Raise ArgumentError if rule_id already exists.
  def self.add_alert_rule(tracker, rule_id, from_zone_id, to_zone_id, asset_id)
    raise NotImplementedError
  end
end
