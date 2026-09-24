require_relative "../practice_problems/problem_01_geofence_alert_engine"

RSpec.describe GeofenceAlertEngine do
  # A tracker with two adjacent zones and two assets.
  let(:tracker) do
    t = GeofenceAlertEngine.make_tracker
    # Warehouse: lat [35.00, 35.10], lng [-106.70, -106.60]
    GeofenceAlertEngine.add_zone(t, "warehouse", "Warehouse A", 35.00, 35.10, -106.70, -106.60)
    # Loading dock: lat [35.10, 35.20], lng [-106.70, -106.60]
    GeofenceAlertEngine.add_zone(t, "loading_dock", "Loading Dock", 35.10, 35.20, -106.70, -106.60)
    GeofenceAlertEngine.add_asset(t, "forklift_1", "Forklift #1")
    GeofenceAlertEngine.add_asset(t, "drone_1", "Drone #1")
    t
  end

  def zone(min_lat, max_lat, min_lng, max_lng)
    { id: "z1", name: "Z", bounds: { min_lat: min_lat, max_lat: max_lat, min_lng: min_lng, max_lng: max_lng } }
  end

  def asset(lat, lng)
    { id: "a1", name: "A", lat: lat, lng: lng, zone_id: nil }
  end

  # ---------------------------------------------------------------------------
  # PART 1 — in_zone?
  # ---------------------------------------------------------------------------
  describe ".in_zone?" do
    let(:z) { zone(35.0, 35.1, -106.7, -106.6) }

    it "is true when inside" do
      expect(GeofenceAlertEngine.in_zone?(asset(35.05, -106.65), z)).to be true
    end

    it "is true on the min corner (inclusive)" do
      expect(GeofenceAlertEngine.in_zone?(asset(35.0, -106.7), z)).to be true
    end

    it "is true on the max corner (inclusive)" do
      expect(GeofenceAlertEngine.in_zone?(asset(35.1, -106.6), z)).to be true
    end

    it "is false when outside latitude bounds" do
      expect(GeofenceAlertEngine.in_zone?(asset(35.15, -106.65), z)).to be false
    end

    it "is false when outside longitude bounds" do
      expect(GeofenceAlertEngine.in_zone?(asset(35.05, -106.5), z)).to be false
    end

    it "is false with no latitude" do
      expect(GeofenceAlertEngine.in_zone?(asset(nil, -106.65), z)).to be false
    end

    it "is false with no longitude" do
      expect(GeofenceAlertEngine.in_zone?(asset(35.05, nil), z)).to be false
    end

    it "is false with no location at all" do
      expect(GeofenceAlertEngine.in_zone?(asset(nil, nil), z)).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # PART 2 — current_zone_id
  # ---------------------------------------------------------------------------
  describe ".current_zone_id" do
    it "finds the asset in the warehouse" do
      tracker[:assets]["forklift_1"][:lat] = 35.05
      tracker[:assets]["forklift_1"][:lng] = -106.65
      expect(GeofenceAlertEngine.current_zone_id(tracker, "forklift_1")).to eq("warehouse")
    end

    it "finds the asset in the loading dock" do
      tracker[:assets]["forklift_1"][:lat] = 35.15
      tracker[:assets]["forklift_1"][:lng] = -106.65
      expect(GeofenceAlertEngine.current_zone_id(tracker, "forklift_1")).to eq("loading_dock")
    end

    it "returns nil when outside all zones" do
      tracker[:assets]["forklift_1"][:lat] = 36.0
      tracker[:assets]["forklift_1"][:lng] = -106.65
      expect(GeofenceAlertEngine.current_zone_id(tracker, "forklift_1")).to be_nil
    end

    it "returns nil when the asset has no location" do
      expect(GeofenceAlertEngine.current_zone_id(tracker, "forklift_1")).to be_nil
    end

    it "returns nil for an unknown asset id" do
      expect(GeofenceAlertEngine.current_zone_id(tracker, "ghost")).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # PART 3 — process_location_update
  # ---------------------------------------------------------------------------
  describe ".process_location_update" do
    it "fires no alert on first update outside any zone" do
      alerts = GeofenceAlertEngine.process_location_update(tracker, "forklift_1", 36.0, -106.65, "t1")
      expect(alerts).to eq([])
      expect(tracker[:assets]["forklift_1"][:lat]).to eq(36.0)
      expect(tracker[:assets]["forklift_1"][:zone_id]).to be_nil
    end

    it "fires a matching rule on zone entry" do
      GeofenceAlertEngine.add_alert_rule(tracker, "rule_entry", nil, "warehouse", nil)
      alerts = GeofenceAlertEngine.process_location_update(tracker, "forklift_1", 35.05, -106.65, "t1")
      expect(alerts.length).to eq(1)
      expect(alerts[0][:rule_id]).to eq("rule_entry")
      expect(alerts[0][:asset_id]).to eq("forklift_1")
      expect(alerts[0][:from_zone_id]).to be_nil
      expect(alerts[0][:to_zone_id]).to eq("warehouse")
      expect(alerts[0][:timestamp]).to eq("t1")
    end

    it "fires a matching rule on zone exit" do
      tracker[:assets]["forklift_1"][:lat] = 35.05
      tracker[:assets]["forklift_1"][:lng] = -106.65
      tracker[:assets]["forklift_1"][:zone_id] = "warehouse"
      GeofenceAlertEngine.add_alert_rule(tracker, "rule_exit", "warehouse", nil, nil)
      alerts = GeofenceAlertEngine.process_location_update(tracker, "forklift_1", 36.0, -106.65, "t2")
      expect(alerts.length).to eq(1)
      expect(alerts[0][:from_zone_id]).to eq("warehouse")
      expect(alerts[0][:to_zone_id]).to be_nil
    end

    it "fires a matching rule on a zone-to-zone transition" do
      tracker[:assets]["forklift_1"][:lat] = 35.05
      tracker[:assets]["forklift_1"][:lng] = -106.65
      tracker[:assets]["forklift_1"][:zone_id] = "warehouse"
      GeofenceAlertEngine.add_alert_rule(tracker, "rule_wh_to_dock", "warehouse", "loading_dock", nil)
      alerts = GeofenceAlertEngine.process_location_update(tracker, "forklift_1", 35.15, -106.65, "t3")
      expect(alerts.length).to eq(1)
      expect(alerts[0][:from_zone_id]).to eq("warehouse")
      expect(alerts[0][:to_zone_id]).to eq("loading_dock")
    end

    it "fires no alert when the zone is unchanged" do
      tracker[:assets]["forklift_1"][:lat] = 35.05
      tracker[:assets]["forklift_1"][:lng] = -106.65
      tracker[:assets]["forklift_1"][:zone_id] = "warehouse"
      GeofenceAlertEngine.add_alert_rule(tracker, "rule_any", nil, nil, nil)
      alerts = GeofenceAlertEngine.process_location_update(tracker, "forklift_1", 35.06, -106.65, "t4")
      expect(alerts).to eq([])
    end

    it "ignores an asset-specific rule for other assets" do
      GeofenceAlertEngine.add_alert_rule(tracker, "rule_drone_only", nil, "warehouse", "drone_1")
      alerts = GeofenceAlertEngine.process_location_update(tracker, "forklift_1", 35.05, -106.65, "t5")
      expect(alerts).to eq([])
    end

    it "fires an asset-specific rule for the correct asset" do
      GeofenceAlertEngine.add_alert_rule(tracker, "rule_forklift", nil, "warehouse", "forklift_1")
      alerts = GeofenceAlertEngine.process_location_update(tracker, "forklift_1", 35.05, -106.65, "t6")
      expect(alerts.length).to eq(1)
    end

    it "fires every matching rule" do
      GeofenceAlertEngine.add_alert_rule(tracker, "rule_a", nil, "warehouse", nil)
      GeofenceAlertEngine.add_alert_rule(tracker, "rule_b", nil, nil, nil)
      alerts = GeofenceAlertEngine.process_location_update(tracker, "forklift_1", 35.05, -106.65, "t7")
      expect(alerts.length).to eq(2)
    end

    it "appends triggered alerts to the alert log" do
      GeofenceAlertEngine.add_alert_rule(tracker, "rule_1", nil, "warehouse", nil)
      GeofenceAlertEngine.process_location_update(tracker, "forklift_1", 35.05, -106.65, "t8")
      expect(tracker[:alert_log].length).to eq(1)
    end

    it "raises KeyError for an unknown asset id" do
      expect { GeofenceAlertEngine.process_location_update(tracker, "ghost_asset", 35.05, -106.65, "t9") }
        .to raise_error(KeyError)
    end

    it "still updates lat/lng when there is no zone change" do
      tracker[:assets]["forklift_1"][:lat] = 35.05
      tracker[:assets]["forklift_1"][:lng] = -106.65
      tracker[:assets]["forklift_1"][:zone_id] = "warehouse"
      GeofenceAlertEngine.process_location_update(tracker, "forklift_1", 35.06, -106.64, "t10")
      expect(tracker[:assets]["forklift_1"][:lat]).to eq(35.06)
      expect(tracker[:assets]["forklift_1"][:lng]).to eq(-106.64)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 4 — CRUD helpers
  # ---------------------------------------------------------------------------
  describe ".add_zone" do
    it "adds a zone" do
      z = GeofenceAlertEngine.add_zone(tracker, "yard", "Yard", 35.3, 35.4, -106.7, -106.6)
      expect(tracker[:zones]["yard"]).to eq(z)
      expect(z[:name]).to eq("Yard")
    end

    it "raises ArgumentError on a duplicate zone_id" do
      expect { GeofenceAlertEngine.add_zone(tracker, "warehouse", "Duplicate", 0, 1, 0, 1) }
        .to raise_error(ArgumentError)
    end
  end

  describe ".remove_zone" do
    it "removes the zone" do
      GeofenceAlertEngine.remove_zone(tracker, "warehouse")
      expect(tracker[:zones]).not_to have_key("warehouse")
    end

    it "clears zone_id on assets that were in the removed zone" do
      tracker[:assets]["forklift_1"][:zone_id] = "warehouse"
      GeofenceAlertEngine.remove_zone(tracker, "warehouse")
      expect(tracker[:assets]["forklift_1"][:zone_id]).to be_nil
    end

    it "does not affect assets in other zones" do
      tracker[:assets]["forklift_1"][:zone_id] = "loading_dock"
      GeofenceAlertEngine.remove_zone(tracker, "warehouse")
      expect(tracker[:assets]["forklift_1"][:zone_id]).to eq("loading_dock")
    end

    it "raises KeyError for a missing zone" do
      expect { GeofenceAlertEngine.remove_zone(tracker, "nonexistent") }.to raise_error(KeyError)
    end
  end

  describe ".add_asset" do
    it "adds an asset with no location" do
      a = GeofenceAlertEngine.add_asset(tracker, "scanner_1", "Scanner #1")
      expect(tracker[:assets]["scanner_1"]).to eq(a)
      expect(a[:lat]).to be_nil
      expect(a[:lng]).to be_nil
      expect(a[:zone_id]).to be_nil
    end

    it "raises ArgumentError on a duplicate asset_id" do
      expect { GeofenceAlertEngine.add_asset(tracker, "forklift_1", "Duplicate") }.to raise_error(ArgumentError)
    end
  end

  describe ".add_alert_rule" do
    it "adds a rule" do
      r = GeofenceAlertEngine.add_alert_rule(tracker, "r1", "warehouse", "loading_dock", nil)
      expect(tracker[:alert_rules]).to include(r)
      expect(r[:id]).to eq("r1")
    end

    it "raises ArgumentError on a duplicate rule_id" do
      GeofenceAlertEngine.add_alert_rule(tracker, "r1", nil, nil, nil)
      expect { GeofenceAlertEngine.add_alert_rule(tracker, "r1", nil, nil, nil) }.to raise_error(ArgumentError)
    end
  end
end
