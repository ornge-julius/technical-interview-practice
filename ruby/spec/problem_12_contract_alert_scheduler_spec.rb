require_relative "../practice_problems/problem_12_contract_alert_scheduler"

RSpec.describe ContractAlertScheduler do
  # Shared dates: D0 base, D30 = D0+30d, D60 = D0+60d, D90 = D0+90d
  D0  = "2025-01-01"
  D30 = "2025-01-31"
  D60 = "2025-03-02"
  D90 = "2025-04-01"

  let(:fresh_sched) { described_class.new }

  let(:sched) do
    s = described_class.new
    s.add_contract("c-seed-1", "Vendor MSA",        "legal@acme.com", expires_on: "2025-06-30")
    s.add_contract("c-seed-2", "SaaS Subscription", "ops@acme.com",   expires_on: "2025-09-15")
    s.add_contract("c-seed-3", "NDA Agreement",     "legal@acme.com", expires_on: "2025-12-31")
    s.add_alert_config("cfg-30", days_before: 30, label: "30-day notice")
    s.add_alert_config("cfg-7",  days_before: 7,  label: "final warning")
    s
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Contract and alert-config management
  # ---------------------------------------------------------------------------

  describe "#add_contract" do
    it "returns the contract hash" do
      c = fresh_sched.add_contract("c-add-1", "Test Contract", "a@b.com", expires_on: "2025-06-01")
      expect(c[:contract_id]).to eq("c-add-1")
      expect(c[:title]).to eq("Test Contract")
      expect(c[:owner_email]).to eq("a@b.com")
      expect(c[:expires_on]).to eq("2025-06-01")
    end

    it "raises on duplicate contract_id" do
      fresh_sched.add_contract("c-dup-1", "A", "a@b.com", expires_on: "2025-06-01")
      expect {
        fresh_sched.add_contract("c-dup-1", "B", "b@c.com", expires_on: "2025-07-01")
      }.to raise_error(ArgumentError)
    end

    it "stores multiple contracts" do
      results = sched.get_contracts_expiring_between("2025-01-01", "2025-12-31")
      ids = results.map { |r| r[:contract_id] }
      expect(ids).to include("c-seed-1", "c-seed-2", "c-seed-3")
    end
  end

  describe "#add_alert_config" do
    it "returns the config hash" do
      cfg = fresh_sched.add_alert_config("cfg-add-1", days_before: 14, label: "two-week notice")
      expect(cfg[:config_id]).to eq("cfg-add-1")
      expect(cfg[:days_before]).to eq(14)
      expect(cfg[:label]).to eq("two-week notice")
    end

    it "raises on duplicate config_id" do
      fresh_sched.add_alert_config("cfg-dup-1", days_before: 30, label: "notice")
      expect {
        fresh_sched.add_alert_config("cfg-dup-1", days_before: 60, label: "other")
      }.to raise_error(ArgumentError)
    end
  end

  describe "#get_contracts_expiring_between" do
    it "matches an exact range" do
      results = sched.get_contracts_expiring_between("2025-06-30", "2025-06-30")
      expect(results.length).to eq(1)
      expect(results[0][:contract_id]).to eq("c-seed-1")
    end

    it "spans multiple contracts" do
      results = sched.get_contracts_expiring_between("2025-06-01", "2025-09-30")
      ids = results.map { |r| r[:contract_id] }
      expect(ids).to include("c-seed-1", "c-seed-2")
      expect(ids).not_to include("c-seed-3")
    end

    it "sorts ascending" do
      dates = sched.get_contracts_expiring_between("2025-01-01", "2025-12-31").map { |r| r[:expires_on] }
      expect(dates).to eq(dates.sort)
    end

    it "returns empty when none are in range" do
      expect(sched.get_contracts_expiring_between("2024-01-01", "2024-12-31")).to eq([])
    end

    it "includes the start boundary" do
      ids = sched.get_contracts_expiring_between("2025-06-30", "2025-12-31").map { |r| r[:contract_id] }
      expect(ids).to include("c-seed-1")
    end

    it "includes the end boundary" do
      ids = sched.get_contracts_expiring_between("2025-01-01", "2025-06-30").map { |r| r[:contract_id] }
      expect(ids).to include("c-seed-1")
    end
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Alert schedule computation
  # ---------------------------------------------------------------------------

  describe "#compute_alert_schedule" do
    it "returns one entry per config" do
      expect(sched.compute_alert_schedule("c-seed-1").length).to eq(2)
    end

    it "computes correct alert_on dates" do
      by_cfg = sched.compute_alert_schedule("c-seed-1").to_h { |e| [e[:config_id], e] }
      expect(by_cfg["cfg-30"][:alert_on]).to eq("2025-05-31")
      expect(by_cfg["cfg-7"][:alert_on]).to eq("2025-06-23")
    end

    it "sorts by alert_on ascending" do
      dates = sched.compute_alert_schedule("c-seed-1").map { |e| e[:alert_on] }
      expect(dates).to eq(dates.sort)
    end

    it "includes the label" do
      labels = sched.compute_alert_schedule("c-seed-1").map { |e| e[:label] }
      expect(labels).to include("30-day notice", "final warning")
    end

    it "raises for an unknown contract" do
      expect { sched.compute_alert_schedule("no-such-contract") }.to raise_error(KeyError)
    end

    it "returns an empty list with no configs" do
      fresh_sched.add_contract("c-no-cfg", "Bare Contract", "a@b.com", expires_on: "2025-06-01")
      expect(fresh_sched.compute_alert_schedule("c-no-cfg")).to eq([])
    end
  end

  describe "#get_due_alerts" do
    it "returns alerts on or before the date" do
      due = sched.get_due_alerts("2025-05-31")
      entries = due.map { |e| [e[:contract_id], e[:config_id]] }
      expect(entries).to include(["c-seed-1", "cfg-30"])
    end

    it "excludes future alerts" do
      expect(sched.get_due_alerts("2025-01-01")).to eq([])
    end

    it "includes owner_email and expires_on" do
      due = sched.get_due_alerts("2025-05-31")
      entry = due.find { |e| e[:contract_id] == "c-seed-1" && e[:config_id] == "cfg-30" }
      expect(entry[:owner_email]).to eq("legal@acme.com")
      expect(entry[:expires_on]).to eq("2025-06-30")
    end

    it "sorts by alert_on then contract_id" do
      dates = sched.get_due_alerts("2025-12-31").map { |e| e[:alert_on] }
      expect(dates).to eq(dates.sort)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Sent records and upcoming alerts
  # ---------------------------------------------------------------------------

  describe "#record_alert_sent" do
    it "returns the sent record" do
      rec = sched.record_alert_sent("c-seed-1", "cfg-30", sent_on: "2025-05-31")
      expect(rec[:contract_id]).to eq("c-seed-1")
      expect(rec[:config_id]).to eq("cfg-30")
      expect(rec[:sent_on]).to eq("2025-05-31")
    end

    it "raises for an unknown contract" do
      expect {
        sched.record_alert_sent("no-contract", "cfg-30", sent_on: "2025-05-31")
      }.to raise_error(KeyError)
    end

    it "raises for an unknown config" do
      expect {
        sched.record_alert_sent("c-seed-1", "no-cfg", sent_on: "2025-05-31")
      }.to raise_error(KeyError)
    end

    it "stores multiple sends" do
      sched.record_alert_sent("c-seed-1", "cfg-30", sent_on: "2025-05-31")
      sched.record_alert_sent("c-seed-1", "cfg-7", sent_on: "2025-06-23")
      upcoming = sched.get_upcoming_alerts("c-seed-1", "2025-05-01")
      sent_ids = upcoming.select { |e| e[:sent] }.map { |e| e[:config_id] }
      expect(sent_ids).to include("cfg-30", "cfg-7")
    end
  end

  describe "#get_upcoming_alerts" do
    it "excludes past alerts" do
      config_ids = sched.get_upcoming_alerts("c-seed-1", "2025-06-01").map { |e| e[:config_id] }
      expect(config_ids).not_to include("cfg-30")
    end

    it "includes future alerts" do
      config_ids = sched.get_upcoming_alerts("c-seed-1", "2025-06-01").map { |e| e[:config_id] }
      expect(config_ids).to include("cfg-7")
    end

    it "defaults sent to false" do
      upcoming = sched.get_upcoming_alerts("c-seed-1", "2025-05-01")
      expect(upcoming.all? { |e| e[:sent] == false }).to be true
    end

    it "flags sent as true after recording" do
      sched.record_alert_sent("c-seed-1", "cfg-30", sent_on: "2025-05-31")
      upcoming = sched.get_upcoming_alerts("c-seed-1", "2025-05-01")
      entry = upcoming.find { |e| e[:config_id] == "cfg-30" }
      expect(entry[:sent]).to be true
    end

    it "sorts by alert_on ascending" do
      dates = sched.get_upcoming_alerts("c-seed-1", "2025-01-01").map { |e| e[:alert_on] }
      expect(dates).to eq(dates.sort)
    end

    it "raises for an unknown contract" do
      expect { sched.get_upcoming_alerts("no-such", "2025-01-01") }.to raise_error(KeyError)
    end
  end
end
