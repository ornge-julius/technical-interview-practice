require_relative "../practice_problems/problem_11_coverage_tracker"

RSpec.describe CoverageTracker do
  # Shared timestamps, scoped to this example group to avoid colliding with
  # other spec files' constants when the full suite runs in one process.
  # CT_T0 = base, CT_T1 = CT_T0+60s, CT_T2 = CT_T0+120s, CT_T3 = CT_T0+300s, CT_T4 = CT_T0+600s
  CT_T0 = "2024-06-01T10:00:00"
  CT_T1 = "2024-06-01T10:01:00"
  CT_T2 = "2024-06-01T10:02:00"
  CT_T3 = "2024-06-01T10:05:00"
  CT_T4 = "2024-06-01T10:10:00"

  let(:fresh_ct) { described_class.new }

  let(:ct) do
    c = described_class.new
    c.register_station("sta-seed-1", "North Tower", region: "downtown")
    c.register_station("sta-seed-2", "South Tower", region: "downtown")
    c.register_station("sta-seed-3", "East Hub", region: "eastside")
    c.record_heartbeat("sta-seed-1", CT_T0)
    c.record_heartbeat("sta-seed-2", CT_T1)
    c
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Station registration and heartbeats
  # ---------------------------------------------------------------------------

  describe "#register_station" do
    it "stores and returns the station" do
      s = fresh_ct.register_station("sta_reg_test", "Tower", region: "north")
      expect(s[:station_id]).to eq("sta_reg_test")
      expect(s[:name]).to eq("Tower")
      expect(s[:region]).to eq("north")
    end

    it "raises on duplicate station_id" do
      expect { ct.register_station("sta-seed-1", "Dup", region: "downtown") }.to raise_error(ArgumentError)
    end
  end

  describe "#record_heartbeat" do
    it "updates the last heartbeat" do
      ct.record_heartbeat("sta-seed-1", CT_T2)
      expect(ct.get_last_heartbeat("sta-seed-1")).to eq(CT_T2)
    end

    it "raises KeyError for a missing station" do
      expect { ct.record_heartbeat("ghost", CT_T0) }.to raise_error(KeyError)
    end

    it "raises on an equal timestamp" do
      expect { ct.record_heartbeat("sta-seed-1", CT_T0) }.to raise_error(ArgumentError)
    end

    it "raises on an earlier timestamp" do
      expect { ct.record_heartbeat("sta-seed-2", CT_T0) }.to raise_error(ArgumentError)
    end

    it "accepts the first heartbeat" do
      ct.record_heartbeat("sta-seed-3", CT_T0)
      expect(ct.get_last_heartbeat("sta-seed-3")).to eq(CT_T0)
    end
  end

  describe "#get_last_heartbeat" do
    it "returns nil if never sent" do
      expect(ct.get_last_heartbeat("sta-seed-3")).to be_nil
    end

    it "returns the latest timestamp" do
      expect(ct.get_last_heartbeat("sta-seed-1")).to eq(CT_T0)
    end

    it "raises KeyError for a missing station" do
      expect { ct.get_last_heartbeat("ghost") }.to raise_error(KeyError)
    end
  end

  describe "#get_stations" do
    it "returns all stations with no filter" do
      expect(ct.get_stations.length).to eq(3)
    end

    it "filters by region" do
      downtown = ct.get_stations(region: "downtown")
      expect(downtown.length).to eq(2)
      expect(downtown.all? { |s| s[:region] == "downtown" }).to be true
    end

    it "returns empty for an unknown region" do
      expect(ct.get_stations(region: "nowhere")).to eq([])
    end

    it "sorts by station_id" do
      ids = ct.get_stations.map { |s| s[:station_id] }
      expect(ids).to eq(ids.sort)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Staleness detection and outage tracking
  # ---------------------------------------------------------------------------

  describe "#get_stale_stations" do
    it "considers a station with no heartbeat stale" do
      stale_ids = ct.get_stale_stations(CT_T2, stale_after_secs: 120).map { |s| s[:station_id] }
      expect(stale_ids).to include("sta-seed-3")
    end

    it "does not consider a recent heartbeat stale" do
      stale_ids = ct.get_stale_stations(CT_T2, stale_after_secs: 120).map { |s| s[:station_id] }
      expect(stale_ids).not_to include("sta-seed-2")
    end

    it "considers an old heartbeat stale" do
      stale_ids = ct.get_stale_stations(CT_T3, stale_after_secs: 120).map { |s| s[:station_id] }
      expect(stale_ids).to include("sta-seed-1")
    end

    it "marks all stations stale when the threshold is tiny" do
      expect(ct.get_stale_stations(CT_T4, stale_after_secs: 5).length).to eq(3)
    end

    it "sorts by station_id" do
      ids = ct.get_stale_stations(CT_T4, stale_after_secs: 5).map { |s| s[:station_id] }
      expect(ids).to eq(ids.sort)
    end
  end

  describe "#record_outage_start and #record_outage_end" do
    it "records an open outage" do
      fresh_ct.register_station("sta_out_test", "T", region: "north")
      fresh_ct.record_outage_start("sta_out_test", CT_T0)
      outages = fresh_ct.get_outages("sta_out_test")
      expect(outages.length).to eq(1)
      expect(outages[0][:start_ts]).to eq(CT_T0)
      expect(outages[0][:end_ts]).to be_nil
    end

    it "raises on a duplicate open outage" do
      fresh_ct.register_station("sta_dup_out", "T", region: "north")
      fresh_ct.record_outage_start("sta_dup_out", CT_T0)
      expect { fresh_ct.record_outage_start("sta_dup_out", CT_T1) }.to raise_error(ArgumentError)
    end

    it "closes an outage on end" do
      fresh_ct.register_station("sta_end_out", "T", region: "north")
      fresh_ct.record_outage_start("sta_end_out", CT_T0)
      fresh_ct.record_outage_end("sta_end_out", CT_T1)
      expect(fresh_ct.get_outages("sta_end_out")[0][:end_ts]).to eq(CT_T1)
    end

    it "raises ending an outage with none open" do
      expect { ct.record_outage_end("sta-seed-1", CT_T2) }.to raise_error(ArgumentError)
    end

    it "raises starting on a missing station" do
      expect { ct.record_outage_start("ghost", CT_T0) }.to raise_error(KeyError)
    end

    it "raises ending on a missing station" do
      expect { ct.record_outage_end("ghost", CT_T0) }.to raise_error(KeyError)
    end

    it "allows a second outage after the first is closed" do
      fresh_ct.register_station("sta_2nd_out", "T", region: "north")
      fresh_ct.record_outage_start("sta_2nd_out", CT_T0)
      fresh_ct.record_outage_end("sta_2nd_out", CT_T1)
      fresh_ct.record_outage_start("sta_2nd_out", CT_T2)
      expect(fresh_ct.get_outages("sta_2nd_out").length).to eq(2)
    end

    it "sorts outages by start_ts" do
      fresh_ct.register_station("sta_sort_out", "T", region: "north")
      fresh_ct.record_outage_start("sta_sort_out", CT_T0)
      fresh_ct.record_outage_end("sta_sort_out", CT_T1)
      fresh_ct.record_outage_start("sta_sort_out", CT_T2)
      fresh_ct.record_outage_end("sta_sort_out", CT_T3)
      outages = fresh_ct.get_outages("sta_sort_out")
      expect(outages[0][:start_ts]).to eq(CT_T0)
      expect(outages[1][:start_ts]).to eq(CT_T2)
    end

    it "raises get_outages on a missing station" do
      expect { ct.get_outages("ghost") }.to raise_error(KeyError)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Coverage analysis
  # ---------------------------------------------------------------------------

  describe "#get_region_coverage" do
    it "reports partial coverage" do
      result = ct.get_region_coverage("downtown", CT_T2, stale_after_secs: 90)
      expect(result[:region]).to eq("downtown")
      expect(result[:total]).to eq(2)
      expect(result[:healthy]).to eq(1)
      expect(result[:stale]).to eq(1)
      expect(result[:has_coverage]).to be true
    end

    it "reports full coverage" do
      result = ct.get_region_coverage("downtown", CT_T2, stale_after_secs: 300)
      expect(result[:healthy]).to eq(2)
      expect(result[:stale]).to eq(0)
      expect(result[:has_coverage]).to be true
    end

    it "reports no coverage when all stale" do
      result = ct.get_region_coverage("downtown", CT_T4, stale_after_secs: 30)
      expect(result[:healthy]).to eq(0)
      expect(result[:has_coverage]).to be false
    end

    it "returns zeros for an empty region" do
      result = fresh_ct.get_region_coverage("ghost-region", CT_T0, stale_after_secs: 60)
      expect(result[:total]).to eq(0)
      expect(result[:healthy]).to eq(0)
      expect(result[:has_coverage]).to be false
    end

    it "returns the correct total for a region" do
      result = ct.get_region_coverage("eastside", CT_T0, stale_after_secs: 60)
      expect(result[:total]).to eq(1)
    end
  end

  describe "#get_outage_summary" do
    it "reports zero outages" do
      summary = ct.get_outage_summary("sta-seed-1", CT_T4)
      expect(summary[:station_id]).to eq("sta-seed-1")
      expect(summary[:total_outages]).to eq(0)
      expect(summary[:open_outage]).to be false
      expect(summary[:total_outage_secs]).to eq(0)
    end

    it "computes a closed outage's duration" do
      fresh_ct.register_station("sta_dur_test", "T", region: "north")
      fresh_ct.record_outage_start("sta_dur_test", CT_T0)
      fresh_ct.record_outage_end("sta_dur_test", CT_T2)
      summary = fresh_ct.get_outage_summary("sta_dur_test", CT_T3)
      expect(summary[:total_outages]).to eq(1)
      expect(summary[:open_outage]).to be false
      expect(summary[:total_outage_secs]).to eq(120)
    end

    it "counts an open outage up to as_of" do
      fresh_ct.register_station("sta_open_test", "T", region: "north")
      fresh_ct.record_outage_start("sta_open_test", CT_T0)
      summary = fresh_ct.get_outage_summary("sta_open_test", CT_T3)
      expect(summary[:open_outage]).to be true
      expect(summary[:total_outage_secs]).to eq(300)
    end

    it "cumulates multiple closed outages" do
      fresh_ct.register_station("sta_cumul_test", "T", region: "north")
      fresh_ct.record_outage_start("sta_cumul_test", CT_T0)
      fresh_ct.record_outage_end("sta_cumul_test", CT_T1)
      fresh_ct.record_outage_start("sta_cumul_test", CT_T2)
      fresh_ct.record_outage_end("sta_cumul_test", CT_T3)
      summary = fresh_ct.get_outage_summary("sta_cumul_test", CT_T4)
      expect(summary[:total_outages]).to eq(2)
      expect(summary[:open_outage]).to be false
      expect(summary[:total_outage_secs]).to eq(60 + 180)
    end

    it "raises on a missing station" do
      expect { ct.get_outage_summary("ghost", CT_T0) }.to raise_error(KeyError)
    end
  end
end
