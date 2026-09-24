require_relative "../practice_problems/problem_10_dispatch_manager"

RSpec.describe DispatchManager do
  t0 = "2024-06-01T10:00:00"
  t1 = "2024-06-01T10:01:00"
  t2 = "2024-06-01T10:02:00"

  let(:fresh_dm) { DispatchManager.new }

  let(:dm) do
    d = DispatchManager.new
    d.register_responder("unit-12", "Alpha Team", ["shooting", "robbery"], 3)
    d.register_responder("unit-14", "Beta Team", ["car-crash", "fire"], 2)
    d.add_incident("inc-seed-1", "shooting", 5, t0)
    d.add_incident("inc-seed-2", "shooting", 3, t1)
    d.add_incident("inc-seed-3", "car-crash", 4, t2)
    d.assign_incident("inc-seed-1", "unit-12")
    d
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Registration and basic queries
  # ---------------------------------------------------------------------------

  describe "#register_responder" do
    it "stores and returns the responder" do
      r = fresh_dm.register_responder("unit_reg_test", "Gamma", ["fire"], 2)
      expect(r[:responder_id]).to eq("unit_reg_test")
      expect(r[:name]).to eq("Gamma")
      expect(r[:subscribed_types]).to eq(["fire"])
      expect(r[:capacity]).to eq(2)
    end

    it "raises ArgumentError for a duplicate" do
      expect { dm.register_responder("unit-12", "Duplicate", ["fire"], 1) }.to raise_error(ArgumentError)
    end
  end

  describe "#add_incident" do
    it "stores and returns the incident" do
      inc = fresh_dm.add_incident("inc_add_test", "fire", 2, t0)
      expect(inc[:incident_id]).to eq("inc_add_test")
      expect(inc[:incident_type]).to eq("fire")
      expect(inc[:severity]).to eq(2)
      expect(inc[:responder_id]).to be_nil
      expect(inc[:resolved]).to be(false)
    end

    it "raises ArgumentError for a duplicate" do
      expect { dm.add_incident("inc-seed-1", "fire", 1, t0) }.to raise_error(ArgumentError)
    end
  end

  describe "#get_incidents_for_responder" do
    it "returns only subscribed types" do
      incidents = dm.get_incidents_for_responder("unit-12")
      expect(incidents).to all(satisfy { |i| %w[shooting robbery].include?(i[:incident_type]) })
    end

    it "sorts by severity descending then ts ascending" do
      incidents = dm.get_incidents_for_responder("unit-12")
      ids = incidents.map { |i| i[:incident_id] }
      expect(ids[0]).to eq("inc-seed-1")
      expect(ids[1]).to eq("inc-seed-2")
    end

    it "sorts same-severity incidents by ts" do
      fresh_dm.register_responder("u_ts_test", "T", ["fire"], 5)
      fresh_dm.add_incident("inc_ts_early", "fire", 3, t0)
      fresh_dm.add_incident("inc_ts_late", "fire", 3, t1)
      incidents = fresh_dm.get_incidents_for_responder("u_ts_test")
      ids = incidents.map { |i| i[:incident_id] }
      expect(ids).to eq(["inc_ts_early", "inc_ts_late"])
    end

    it "raises KeyError for a missing responder" do
      expect { dm.get_incidents_for_responder("ghost") }.to raise_error(KeyError)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Assignment and resolution
  # ---------------------------------------------------------------------------

  describe "#assign_incident" do
    it "sets responder_id" do
      dm.assign_incident("inc-seed-2", "unit-12")
      open_ids = dm.get_open_assignments("unit-12").map { |i| i[:incident_id] }
      expect(open_ids).to include("inc-seed-2")
    end

    it "raises KeyError for a missing incident" do
      expect { dm.assign_incident("ghost-inc", "unit-12") }.to raise_error(KeyError)
    end

    it "raises KeyError for a missing responder" do
      expect { dm.assign_incident("inc-seed-2", "ghost-unit") }.to raise_error(KeyError)
    end

    it "raises ArgumentError when already assigned" do
      expect { dm.assign_incident("inc-seed-1", "unit-12") }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError when at capacity" do
      fresh_dm.register_responder("cap_unit", "Cap", ["fire"], 1)
      fresh_dm.add_incident("cap_inc_1", "fire", 1, t0)
      fresh_dm.add_incident("cap_inc_2", "fire", 1, t1)
      fresh_dm.assign_incident("cap_inc_1", "cap_unit")
      expect { fresh_dm.assign_incident("cap_inc_2", "cap_unit") }.to raise_error(ArgumentError)
    end
  end

  describe "#resolve_incident" do
    it "marks resolved and removes from open assignments" do
      dm.resolve_incident("inc-seed-1")
      open_ids = dm.get_open_assignments("unit-12").map { |i| i[:incident_id] }
      expect(open_ids).not_to include("inc-seed-1")
    end

    it "raises ArgumentError when already resolved" do
      dm.resolve_incident("inc-seed-1")
      expect { dm.resolve_incident("inc-seed-1") }.to raise_error(ArgumentError)
    end

    it "raises KeyError for a missing incident" do
      expect { dm.resolve_incident("ghost") }.to raise_error(KeyError)
    end

    it "frees capacity for the next assignment" do
      fresh_dm.register_responder("cap2_unit", "Cap2", ["fire"], 1)
      fresh_dm.add_incident("cap2_inc_1", "fire", 1, t0)
      fresh_dm.add_incident("cap2_inc_2", "fire", 1, t1)
      fresh_dm.assign_incident("cap2_inc_1", "cap2_unit")
      fresh_dm.resolve_incident("cap2_inc_1")
      expect { fresh_dm.assign_incident("cap2_inc_2", "cap2_unit") }.not_to raise_error
    end
  end

  describe "#get_open_assignments" do
    it "returns open assignments" do
      open_list = dm.get_open_assignments("unit-12")
      expect(open_list.size).to eq(1)
      expect(open_list.first[:incident_id]).to eq("inc-seed-1")
    end

    it "excludes resolved incidents" do
      dm.resolve_incident("inc-seed-1")
      expect(dm.get_open_assignments("unit-12")).to eq([])
    end

    it "raises KeyError for a missing responder" do
      expect { dm.get_open_assignments("ghost") }.to raise_error(KeyError)
    end

    it "sorts by severity descending then ts ascending" do
      fresh_dm.register_responder("u_sort", "S", ["fire"], 5)
      fresh_dm.add_incident("inc_sort_low", "fire", 2, t0)
      fresh_dm.add_incident("inc_sort_high", "fire", 5, t1)
      fresh_dm.assign_incident("inc_sort_low", "u_sort")
      fresh_dm.assign_incident("inc_sort_high", "u_sort")
      open_list = fresh_dm.get_open_assignments("u_sort")
      expect(open_list.first[:incident_id]).to eq("inc_sort_high")
    end
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Auto-assignment
  # ---------------------------------------------------------------------------

  describe "#auto_assign" do
    it "assigns to an eligible responder" do
      result = dm.auto_assign("inc-seed-3")
      expect(result).to eq("unit-14")
      open_ids = dm.get_open_assignments("unit-14").map { |i| i[:incident_id] }
      expect(open_ids).to include("inc-seed-3")
    end

    it "raises KeyError for a missing incident" do
      expect { dm.auto_assign("ghost") }.to raise_error(KeyError)
    end

    it "raises ArgumentError when already assigned" do
      expect { dm.auto_assign("inc-seed-1") }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError when no eligible responder exists" do
      fresh_dm.register_responder("only_unit", "Only", ["shooting"], 1)
      fresh_dm.add_incident("inc_no_sub", "fire", 1, t0)
      expect { fresh_dm.auto_assign("inc_no_sub") }.to raise_error(ArgumentError)
    end

    it "excludes a responder at full capacity" do
      fresh_dm.register_responder("full_unit", "Full", ["fire"], 1)
      fresh_dm.register_responder("open_unit", "Open", ["fire"], 2)
      fresh_dm.add_incident("inc_cap_fill", "fire", 1, t0)
      fresh_dm.add_incident("inc_cap_new", "fire", 1, t1)
      fresh_dm.assign_incident("inc_cap_fill", "full_unit")
      result = fresh_dm.auto_assign("inc_cap_new")
      expect(result).to eq("open_unit")
    end

    it "picks the least loaded responder" do
      fresh_dm.register_responder("u_loaded", "Loaded", ["fire"], 3)
      fresh_dm.register_responder("u_free", "Free", ["fire"], 3)
      fresh_dm.add_incident("inc_load_seed", "fire", 1, t0)
      fresh_dm.add_incident("inc_load_new", "fire", 1, t1)
      fresh_dm.assign_incident("inc_load_seed", "u_loaded")
      result = fresh_dm.auto_assign("inc_load_new")
      expect(result).to eq("u_free")
    end

    it "tie-breaks by highest capacity" do
      fresh_dm.register_responder("u_low_cap", "Low", ["fire"], 1)
      fresh_dm.register_responder("u_high_cap", "High", ["fire"], 5)
      fresh_dm.add_incident("inc_cap_tb", "fire", 1, t0)
      result = fresh_dm.auto_assign("inc_cap_tb")
      expect(result).to eq("u_high_cap")
    end

    it "delegates to assign_incident internally" do
      fresh_dm.register_responder("u_delegate", "D", ["fire"], 1)
      fresh_dm.add_incident("inc_delegate_1", "fire", 1, t0)
      fresh_dm.add_incident("inc_delegate_2", "fire", 1, t1)
      fresh_dm.auto_assign("inc_delegate_1")
      expect { fresh_dm.auto_assign("inc_delegate_2") }.to raise_error(ArgumentError)
    end
  end

  describe "#get_dispatch_summary" do
    it "returns all responders" do
      summary = dm.get_dispatch_summary
      ids = summary.map { |s| s[:responder_id] }
      expect(ids).to include("unit-12", "unit-14")
    end

    it "sorts by responder_id" do
      summary = dm.get_dispatch_summary
      ids = summary.map { |s| s[:responder_id] }
      expect(ids).to eq(ids.sort)
    end

    it "computes open_count and available_capacity" do
      summary = dm.get_dispatch_summary
      u12 = summary.find { |s| s[:responder_id] == "unit-12" }
      expect(u12[:open_count]).to eq(1)
      expect(u12[:available_capacity]).to eq(2)
    end

    it "handles a zero-load responder" do
      summary = dm.get_dispatch_summary
      u14 = summary.find { |s| s[:responder_id] == "unit-14" }
      expect(u14[:open_count]).to eq(0)
      expect(u14[:available_capacity]).to eq(2)
    end
  end
end
