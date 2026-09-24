require_relative "../practice_problems/problem_09_incident_aggregator"

RSpec.describe IncidentAggregator do
  t0 = "2024-06-01T10:00:00"
  t1 = "2024-06-01T10:01:00"
  t2 = "2024-06-01T10:02:00"
  t3 = "2024-06-01T10:05:00"
  t4 = "2024-06-01T10:10:00"

  let(:fresh_agg) { IncidentAggregator.new }

  let(:agg) do
    a = IncidentAggregator.new
    a.ingest_report("r1", "radio-north", "shooting", "downtown", t0)
    a.ingest_report("r2", "radio-south", "shooting", "downtown", t1)
    a.ingest_report("r3", "social-feed", "car-crash", "midtown", t2)
    a.create_incident("inc-001", "shooting", "downtown")
    a.add_report_to_incident("inc-001", "r1")
    a.add_report_to_incident("inc-001", "r2")
    a
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Report ingestion
  # ---------------------------------------------------------------------------

  describe "#ingest_report" do
    it "stores and returns the report" do
      r = fresh_agg.ingest_report("r_store", "radio-north", "shooting", "downtown", t0)
      expect(r[:report_id]).to eq("r_store")
      expect(r[:source_id]).to eq("radio-north")
      expect(r[:event_type]).to eq("shooting")
      expect(r[:location_key]).to eq("downtown")
      expect(r[:ts]).to eq(t0)
      expect(r[:incident_id]).to be_nil
    end

    it "raises ArgumentError for a duplicate report_id" do
      fresh_agg.ingest_report("r_dup", "src-a", "fire", "east", t0)
      expect { fresh_agg.ingest_report("r_dup", "src-b", "fire", "east", t1) }.to raise_error(ArgumentError)
    end
  end

  describe "#get_report" do
    it "returns nil if missing" do
      expect(fresh_agg.get_report("nonexistent")).to be_nil
    end

    it "returns the stored report" do
      r = agg.get_report("r1")
      expect(r).not_to be_nil
      expect(r[:event_type]).to eq("shooting")
    end
  end

  describe "#get_reports" do
    it "returns all reports with no filter" do
      expect(agg.get_reports.size).to eq(3)
    end

    it "filters by location" do
      reports = agg.get_reports(location_key: "downtown")
      expect(reports.size).to eq(2)
      expect(reports).to all(satisfy { |r| r[:location_key] == "downtown" })
    end

    it "filters by event_type" do
      reports = agg.get_reports(event_type: "car-crash")
      expect(reports.size).to eq(1)
      expect(reports.first[:report_id]).to eq("r3")
    end

    it "applies both filters" do
      reports = agg.get_reports(location_key: "downtown", event_type: "shooting")
      expect(reports.size).to eq(2)
    end

    it "is empty when nothing matches" do
      expect(agg.get_reports(location_key: "mars")).to eq([])
    end

    it "is sorted by ts ascending" do
      fresh_agg.ingest_report("r_sort_b", "src", "fire", "zone-1", t1)
      fresh_agg.ingest_report("r_sort_a", "src", "fire", "zone-1", t0)
      tss = fresh_agg.get_reports.map { |r| r[:ts] }
      expect(tss).to eq(tss.sort)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Manual incident grouping
  # ---------------------------------------------------------------------------

  describe "#create_incident" do
    it "creates an empty incident" do
      inc = fresh_agg.create_incident("inc_create_test", "fire", "east-side")
      expect(inc[:incident_id]).to eq("inc_create_test")
      expect(inc[:event_type]).to eq("fire")
      expect(inc[:location_key]).to eq("east-side")
      expect(inc[:report_count]).to eq(0)
      expect(inc[:report_ids]).to eq([])
      expect(inc[:latest_ts]).to be_nil
    end

    it "raises ArgumentError for a duplicate incident_id" do
      expect { agg.create_incident("inc-001", "shooting", "downtown") }.to raise_error(ArgumentError)
    end
  end

  describe "#add_report_to_incident" do
    it "assigns the report" do
      fresh_agg.ingest_report("r_assign", "src", "fire", "east", t0)
      fresh_agg.create_incident("inc_assign_test", "fire", "east")
      fresh_agg.add_report_to_incident("inc_assign_test", "r_assign")
      inc = fresh_agg.get_incident("inc_assign_test")
      expect(inc[:report_ids]).to include("r_assign")
      expect(inc[:report_count]).to eq(1)
      expect(inc[:latest_ts]).to eq(t0)
    end

    it "updates the report's incident_id" do
      fresh_agg.ingest_report("r_update", "src", "fire", "east", t0)
      fresh_agg.create_incident("inc_update_test", "fire", "east")
      fresh_agg.add_report_to_incident("inc_update_test", "r_update")
      expect(fresh_agg.get_report("r_update")[:incident_id]).to eq("inc_update_test")
    end

    it "raises ArgumentError if already assigned" do
      expect { agg.add_report_to_incident("inc-001", "r1") }.to raise_error(ArgumentError)
    end

    it "raises KeyError for a bad incident" do
      fresh_agg.ingest_report("r_bad_inc", "src", "fire", "east", t0)
      expect { fresh_agg.add_report_to_incident("nonexistent_inc", "r_bad_inc") }.to raise_error(KeyError)
    end

    it "raises KeyError for a bad report" do
      expect { agg.add_report_to_incident("inc-001", "nonexistent_report") }.to raise_error(KeyError)
    end

    it "keeps report_ids sorted by ts" do
      fresh_agg.ingest_report("r_ts_b", "src", "fire", "east", t1)
      fresh_agg.ingest_report("r_ts_a", "src", "fire", "east", t0)
      fresh_agg.create_incident("inc_ts_test", "fire", "east")
      fresh_agg.add_report_to_incident("inc_ts_test", "r_ts_b")
      fresh_agg.add_report_to_incident("inc_ts_test", "r_ts_a")
      expect(fresh_agg.get_incident("inc_ts_test")[:report_ids]).to eq(["r_ts_a", "r_ts_b"])
    end

    it "updates latest_ts to the newest report" do
      fresh_agg.ingest_report("r_lt_a", "src", "fire", "east", t0)
      fresh_agg.ingest_report("r_lt_b", "src", "fire", "east", t2)
      fresh_agg.create_incident("inc_lt_test", "fire", "east")
      fresh_agg.add_report_to_incident("inc_lt_test", "r_lt_a")
      fresh_agg.add_report_to_incident("inc_lt_test", "r_lt_b")
      expect(fresh_agg.get_incident("inc_lt_test")[:latest_ts]).to eq(t2)
    end
  end

  describe "#get_incident" do
    it "returns nil if not found" do
      expect(fresh_agg.get_incident("ghost")).to be_nil
    end

    it "returns the incident" do
      inc = agg.get_incident("inc-001")
      expect(inc).not_to be_nil
      expect(inc[:report_count]).to eq(2)
    end
  end

  describe "#get_unassigned_reports" do
    it "returns unassigned reports" do
      unassigned = agg.get_unassigned_reports
      expect(unassigned.size).to eq(1)
      expect(unassigned.first[:report_id]).to eq("r3")
    end

    it "is empty when all are assigned" do
      fresh_agg.ingest_report("r_all", "src", "fire", "east", t0)
      fresh_agg.create_incident("inc_all_test", "fire", "east")
      fresh_agg.add_report_to_incident("inc_all_test", "r_all")
      expect(fresh_agg.get_unassigned_reports).to eq([])
    end

    it "is sorted by ts ascending" do
      fresh_agg.ingest_report("r_ua_b", "src", "fire", "east", t1)
      fresh_agg.ingest_report("r_ua_a", "src", "fire", "east", t0)
      tss = fresh_agg.get_unassigned_reports.map { |r| r[:ts] }
      expect(tss).to eq(tss.sort)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Automatic deduplication
  # ---------------------------------------------------------------------------

  describe "#auto_ingest_report" do
    it "creates a new incident when there is no match" do
      incident_id = fresh_agg.auto_ingest_report("r_auto_new", "src", "fire", "east-side", t0, 120)
      expect(incident_id).not_to be_nil
      inc = fresh_agg.get_incident(incident_id)
      expect(inc[:report_count]).to eq(1)
      expect(inc[:report_ids]).to include("r_auto_new")
    end

    it "merges into an existing incident within the window" do
      result = agg.auto_ingest_report("r_merge", "radio-east", "shooting", "downtown", t2, 120)
      expect(result).to eq("inc-001")
      expect(agg.get_incident("inc-001")[:report_count]).to eq(3)
    end

    it "does not merge across a different event_type" do
      result = agg.auto_ingest_report("r_diff_type", "src", "car-crash", "downtown", t2, 120)
      expect(result).not_to eq("inc-001")
    end

    it "does not merge across a different location" do
      result = agg.auto_ingest_report("r_diff_loc", "src", "shooting", "uptown", t2, 120)
      expect(result).not_to eq("inc-001")
    end

    it "does not merge outside the window" do
      result = agg.auto_ingest_report("r_expired", "src", "shooting", "downtown", t4, 120)
      expect(result).not_to eq("inc-001")
    end

    it "stores the new report" do
      incident_id = fresh_agg.auto_ingest_report("r_stored", "src", "fire", "east", t0, 60)
      expect(fresh_agg.get_report("r_stored")).not_to be_nil
    end

    it "picks the most recently active match" do
      fresh_agg.ingest_report("ra1", "src", "shooting", "downtown", t0)
      fresh_agg.ingest_report("ra2", "src", "shooting", "downtown", t1)
      fresh_agg.create_incident("inc_older", "shooting", "downtown")
      fresh_agg.add_report_to_incident("inc_older", "ra1")
      fresh_agg.create_incident("inc_newer", "shooting", "downtown")
      fresh_agg.add_report_to_incident("inc_newer", "ra2")

      result = fresh_agg.auto_ingest_report("r_pick", "src", "shooting", "downtown", t2, 300)
      expect(result).to eq("inc_newer")
    end

    it "does not clash auto-generated ids" do
      id1 = fresh_agg.auto_ingest_report("r_id1", "src", "fire", "west", t0, 0)
      id2 = fresh_agg.auto_ingest_report("r_id2", "src", "fire", "east", t1, 0)
      expect(id1).not_to eq(id2)
    end
  end

  describe "#get_active_incidents" do
    it "returns active incidents" do
      active = agg.get_active_incidents(t2, 120)
      expect(active.any? { |i| i[:incident_id] == "inc-001" }).to be(true)
    end

    it "excludes stale incidents" do
      active = agg.get_active_incidents(t4, 120)
      expect(active.any? { |i| i[:incident_id] == "inc-001" }).to be(false)
    end

    it "excludes empty incidents" do
      fresh_agg.create_incident("inc_empty_active", "fire", "north")
      active = fresh_agg.get_active_incidents(t0, 300)
      expect(active.any? { |i| i[:incident_id] == "inc_empty_active" }).to be(false)
    end

    it "sorts by latest_ts descending" do
      fresh_agg.ingest_report("ri1", "src", "fire", "east", t0)
      fresh_agg.ingest_report("ri2", "src", "fire", "west", t2)
      fresh_agg.create_incident("inc_sort_a", "fire", "east")
      fresh_agg.add_report_to_incident("inc_sort_a", "ri1")
      fresh_agg.create_incident("inc_sort_b", "fire", "west")
      fresh_agg.add_report_to_incident("inc_sort_b", "ri2")

      active = fresh_agg.get_active_incidents(t3, 600)
      ids = active.map { |i| i[:incident_id] }
      expect(ids.index("inc_sort_b")).to be < ids.index("inc_sort_a")
    end
  end
end
