require "date"
require "set"
require_relative "../practice_problems/problem_04_biomarker_alert"

RSpec.describe BiomarkerMonitor do
  Reading = BiomarkerMonitor::Reading

  ALICE_READINGS = [
    # All in range — no outreach needed
    Reading.new("alice", "glucose", 105.0, Date.new(2024, 1, 1)),
    Reading.new("alice", "glucose", 98.0, Date.new(2024, 1, 2)),
    Reading.new("alice", "glucose", 112.0, Date.new(2024, 1, 3)),
    Reading.new("alice", "glucose", 91.0, Date.new(2024, 1, 4))
  ].freeze

  BOB_READINGS = [
    # 4 consecutive high-glucose days -> needs outreach
    Reading.new("bob", "glucose", 195.0, Date.new(2024, 1, 1)),
    Reading.new("bob", "glucose", 210.0, Date.new(2024, 1, 2)),
    Reading.new("bob", "glucose", 188.0, Date.new(2024, 1, 3)),
    Reading.new("bob", "glucose", 202.0, Date.new(2024, 1, 4))
  ].freeze

  CAROL_READINGS = [
    # Streak of 1 (Jan 1), in-range on Jan 2, then streak of 2 (Jan 3-4) -> max=2
    Reading.new("carol", "glucose", 190.0, Date.new(2024, 1, 1)),
    Reading.new("carol", "glucose", 150.0, Date.new(2024, 1, 2)), # in range
    Reading.new("carol", "glucose", 185.0, Date.new(2024, 1, 3)),
    Reading.new("carol", "glucose", 191.0, Date.new(2024, 1, 4))
  ].freeze

  DAVE_READINGS = [
    # 2 consecutive high-glucose days — below default threshold of 3
    Reading.new("dave", "glucose", 199.0, Date.new(2024, 1, 3)),
    Reading.new("dave", "glucose", 205.0, Date.new(2024, 1, 4))
  ].freeze

  EVE_READINGS = [
    # One dangerous low glucose (below 70) on Jan 1 — streak of 1 for glucose
    Reading.new("eve", "glucose", 62.0, Date.new(2024, 1, 1)),
    # 3 consecutive days with ketones below target (< 0.5) -> ketone outreach
    Reading.new("eve", "ketone", 0.3, Date.new(2024, 1, 2)),
    Reading.new("eve", "ketone", 0.2, Date.new(2024, 1, 3)),
    Reading.new("eve", "ketone", 0.4, Date.new(2024, 1, 4)),
    # Weight readings — never out of range
    Reading.new("eve", "weight", 165.0, Date.new(2024, 1, 1)),
    Reading.new("eve", "weight", 164.5, Date.new(2024, 1, 2))
  ].freeze

  ALL_READINGS = (ALICE_READINGS + BOB_READINGS + CAROL_READINGS + DAVE_READINGS + EVE_READINGS).freeze

  # BiomarkerMonitor seeded with the full pre-existing dataset.
  let(:monitor) { BiomarkerMonitor.new(ALL_READINGS.dup) }
  # Empty BiomarkerMonitor.
  let(:fresh_monitor) { BiomarkerMonitor.new([]) }

  # ---------------------------------------------------------------------------
  # PART 1 — single-reading classification
  # ---------------------------------------------------------------------------
  describe "#out_of_range?" do
    it "is true for glucose above range" do
      r = Reading.new("p1", "glucose", 181.0, Date.new(2024, 1, 1))
      expect(fresh_monitor.out_of_range?(r)).to be true
    end

    it "is true for glucose below range" do
      r = Reading.new("p1", "glucose", 69.9, Date.new(2024, 1, 1))
      expect(fresh_monitor.out_of_range?(r)).to be true
    end

    it "is false at the glucose upper boundary" do
      r = Reading.new("p1", "glucose", 180.0, Date.new(2024, 1, 1))
      expect(fresh_monitor.out_of_range?(r)).to be false
    end

    it "is false at the glucose lower boundary" do
      r = Reading.new("p1", "glucose", 70.0, Date.new(2024, 1, 1))
      expect(fresh_monitor.out_of_range?(r)).to be false
    end

    it "is false for glucose in range" do
      r = Reading.new("p1", "glucose", 120.0, Date.new(2024, 1, 1))
      expect(fresh_monitor.out_of_range?(r)).to be false
    end

    it "is true for ketone above range" do
      r = Reading.new("p1", "ketone", 3.1, Date.new(2024, 1, 1))
      expect(fresh_monitor.out_of_range?(r)).to be true
    end

    it "is true for ketone below range" do
      r = Reading.new("p1", "ketone", 0.4, Date.new(2024, 1, 1))
      expect(fresh_monitor.out_of_range?(r)).to be true
    end

    it "is false for ketone in range" do
      r = Reading.new("p1", "ketone", 1.5, Date.new(2024, 1, 1))
      expect(fresh_monitor.out_of_range?(r)).to be false
    end

    it "is false at ketone boundaries" do
      lo = Reading.new("p1", "ketone", 0.5, Date.new(2024, 1, 1))
      hi = Reading.new("p1", "ketone", 3.0, Date.new(2024, 1, 1))
      expect(fresh_monitor.out_of_range?(lo)).to be false
      expect(fresh_monitor.out_of_range?(hi)).to be false
    end

    it "is false for weight no matter the value" do
      r = Reading.new("p1", "weight", 9999.0, Date.new(2024, 1, 1))
      expect(fresh_monitor.out_of_range?(r)).to be false
    end

    it "classifies independent of monitor state" do
      in_range = Reading.new("alice", "glucose", 100.0, Date.new(2024, 1, 5))
      out_of_range = Reading.new("bob", "glucose", 250.0, Date.new(2024, 1, 5))
      expect(monitor.out_of_range?(in_range)).to be false
      expect(monitor.out_of_range?(out_of_range)).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # PART 2 — streak detection
  # ---------------------------------------------------------------------------
  describe "#max_consecutive_out_of_range_days" do
    it "returns 0 for an unknown patient" do
      expect(monitor.max_consecutive_out_of_range_days("unknown_patient", "glucose")).to eq(0)
    end

    it "returns 0 when all readings are in range" do
      expect(monitor.max_consecutive_out_of_range_days("alice", "glucose")).to eq(0)
    end

    it "finds a consecutive streak" do
      expect(monitor.max_consecutive_out_of_range_days("bob", "glucose")).to eq(4)
    end

    it "resets the streak on an in-range day" do
      expect(monitor.max_consecutive_out_of_range_days("carol", "glucose")).to eq(2)
    end

    it "finds a short streak" do
      expect(monitor.max_consecutive_out_of_range_days("dave", "glucose")).to eq(2)
    end

    it "counts a single low reading as a streak of one" do
      expect(monitor.max_consecutive_out_of_range_days("eve", "glucose")).to eq(1)
    end

    it "finds the ketone streak" do
      expect(monitor.max_consecutive_out_of_range_days("eve", "ketone")).to eq(3)
    end

    it "never streaks for weight" do
      expect(monitor.max_consecutive_out_of_range_days("eve", "weight")).to eq(0)
    end

    it "collapses same-day readings into one day" do
      readings = [
        Reading.new("frank", "glucose", 200.0, Date.new(2024, 2, 1)),
        Reading.new("frank", "glucose", 210.0, Date.new(2024, 2, 1)), # same day
        Reading.new("frank", "glucose", 195.0, Date.new(2024, 2, 2))
      ]
      m = BiomarkerMonitor.new(readings)
      expect(m.max_consecutive_out_of_range_days("frank", "glucose")).to eq(2)
    end

    it "breaks the streak across a gap day" do
      readings = [
        Reading.new("grace", "glucose", 200.0, Date.new(2024, 3, 1)),
        Reading.new("grace", "glucose", 200.0, Date.new(2024, 3, 3)) # skip Mar 2
      ]
      m = BiomarkerMonitor.new(readings)
      expect(m.max_consecutive_out_of_range_days("grace", "glucose")).to eq(1)
    end

    it "keeps reading types independent" do
      expect(monitor.max_consecutive_out_of_range_days("eve", "glucose")).to eq(1)
      expect(monitor.max_consecutive_out_of_range_days("eve", "ketone")).to eq(3)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 3 — outreach list
  # ---------------------------------------------------------------------------
  describe "#outreach_list" do
    it "filters correctly at the default threshold" do
      result = monitor.outreach_list
      patient_types = result.map { |e| [e[:patient_id], e[:reading_type]] }
      expect(patient_types).to include(["bob", "glucose"])
      expect(patient_types).to include(["eve", "ketone"])
      expect(patient_types).not_to include(["alice", "glucose"])
      expect(patient_types).not_to include(["carol", "glucose"])
      expect(patient_types).not_to include(["dave", "glucose"])
    end

    it "never includes weight" do
      result = monitor.outreach_list(min_consecutive_days: 1)
      expect(result.map { |e| e[:reading_type] }).not_to include("weight")
    end

    it "sorts by consecutive_days descending" do
      result = monitor.outreach_list(min_consecutive_days: 1)
      days = result.map { |e| e[:consecutive_days] }
      expect(days).to eq(days.sort.reverse)
    end

    it "has the expected fields" do
      result = monitor.outreach_list
      bob_entry = result.find { |e| e[:patient_id] == "bob" }
      expect(bob_entry.keys.to_set).to eq(Set[:patient_id, :reading_type, :consecutive_days, :latest_value])
      expect(bob_entry[:consecutive_days]).to eq(4)
      expect(bob_entry[:reading_type]).to eq("glucose")
      expect(bob_entry[:latest_value]).to be_a(Float)
    end

    it "reports the most recent out-of-range value" do
      result = monitor.outreach_list
      bob_entry = result.find { |e| e[:patient_id] == "bob" }
      expect(bob_entry[:latest_value]).to eq(202.0)
    end

    it "lets a patient appear twice for different reading types" do
      readings = [
        # 3-day glucose streak
        Reading.new("hank", "glucose", 200.0, Date.new(2024, 1, 1)),
        Reading.new("hank", "glucose", 210.0, Date.new(2024, 1, 2)),
        Reading.new("hank", "glucose", 195.0, Date.new(2024, 1, 3)),
        # 3-day ketone streak
        Reading.new("hank", "ketone", 0.2, Date.new(2024, 1, 1)),
        Reading.new("hank", "ketone", 0.3, Date.new(2024, 1, 2)),
        Reading.new("hank", "ketone", 0.1, Date.new(2024, 1, 3))
      ]
      m = BiomarkerMonitor.new(readings)
      result = m.outreach_list(min_consecutive_days: 3)
      patient_types = result.map { |e| [e[:patient_id], e[:reading_type]] }
      expect(patient_types).to include(["hank", "glucose"])
      expect(patient_types).to include(["hank", "ketone"])
    end

    it "respects a custom threshold" do
      result = monitor.outreach_list(min_consecutive_days: 2)
      patient_types = result.map { |e| [e[:patient_id], e[:reading_type]] }
      expect(patient_types).to include(["carol", "glucose"])
      expect(patient_types).to include(["dave", "glucose"])
    end

    it "returns an empty array for an empty monitor" do
      expect(fresh_monitor.outreach_list).to eq([])
    end
  end

  # ---------------------------------------------------------------------------
  # PART 4 — deduplication on ingestion
  # ---------------------------------------------------------------------------
  describe "#add_reading" do
    it "returns true for a new reading" do
      r = Reading.new("alice", "glucose", 100.0, Date.new(2024, 1, 10))
      expect(monitor.add_reading(r)).to be true
    end

    it "returns false for an exact duplicate" do
      r = Reading.new("alice", "glucose", 105.0, Date.new(2024, 1, 1))
      expect(monitor.add_reading(r)).to be false
    end

    it "returns false for a duplicate within tolerance" do
      # alice jan 1 = 105.0; 105.4 is within +/-0.5
      r = Reading.new("alice", "glucose", 105.4, Date.new(2024, 1, 1))
      expect(monitor.add_reading(r)).to be false
    end

    it "returns true just outside the tolerance" do
      # alice jan 1 = 105.0; 105.6 is outside +/-0.5
      r = Reading.new("alice", "glucose", 105.6, Date.new(2024, 1, 1))
      expect(monitor.add_reading(r)).to be true
    end

    it "is not a duplicate on a different date" do
      r = Reading.new("alice", "glucose", 105.0, Date.new(2024, 1, 5))
      expect(monitor.add_reading(r)).to be true
    end

    it "is not a duplicate for a different reading type" do
      r = Reading.new("alice", "ketone", 1.0, Date.new(2024, 1, 1))
      expect(monitor.add_reading(r)).to be true
    end

    it "is not a duplicate for a different patient" do
      r = Reading.new("frank", "glucose", 105.0, Date.new(2024, 1, 1))
      expect(monitor.add_reading(r)).to be true
    end

    it "updates the streak after adding a new out-of-range day" do
      # bob's current streak is Jan 1-4 (4 days). Add Jan 5.
      r = Reading.new("bob", "glucose", 195.0, Date.new(2024, 1, 5))
      monitor.add_reading(r)
      expect(monitor.max_consecutive_out_of_range_days("bob", "glucose")).to eq(5)
    end

    it "does not let a rejected duplicate inflate the streak" do
      r = Reading.new("bob", "glucose", 195.0, Date.new(2024, 1, 1))
      monitor.add_reading(r) # duplicate, rejected
      expect(monitor.max_consecutive_out_of_range_days("bob", "glucose")).to eq(4)
    end
  end
end
