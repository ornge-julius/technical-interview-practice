require "date"
require_relative "../practice_problems/problem_06_lab_cadence"

RSpec.describe LabCadenceMonitor do
  let(:m) { LabCadenceMonitor.make_monitor }

  let(:seeded) do
    monitor = LabCadenceMonitor.make_monitor
    LabCadenceMonitor.register_patient(monitor, "alice", ["hba1c", "bmp", "lipids"])
    LabCadenceMonitor.register_patient(monitor, "bob", ["hba1c", "bmp"])
    LabCadenceMonitor.register_patient(monitor, "carol", ["hba1c"])

    LabCadenceMonitor.set_lab_deadline(monitor, "alice", "hba1c", Date.new(2024, 3, 31))
    LabCadenceMonitor.set_lab_deadline(monitor, "alice", "hba1c", Date.new(2024, 6, 30))
    LabCadenceMonitor.record_submission(monitor, "alice", "hba1c", Date.new(2024, 3, 28))

    LabCadenceMonitor.set_lab_deadline(monitor, "alice", "bmp", Date.new(2024, 4, 15))

    LabCadenceMonitor.set_lab_deadline(monitor, "bob", "hba1c", Date.new(2024, 3, 31))
    LabCadenceMonitor.record_submission(monitor, "bob", "hba1c", Date.new(2024, 3, 25))
    LabCadenceMonitor.set_lab_deadline(monitor, "bob", "bmp", Date.new(2024, 3, 31))

    LabCadenceMonitor.set_lab_deadline(monitor, "carol", "hba1c", Date.new(2024, 3, 31))
    LabCadenceMonitor.record_submission(monitor, "carol", "hba1c", Date.new(2024, 3, 15))

    monitor
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Patient & lab registration
  # ---------------------------------------------------------------------------

  describe ".register_patient" do
    it "registers a new patient" do
      LabCadenceMonitor.register_patient(m, "dave", ["hba1c"])
      expect(LabCadenceMonitor.required_labs(m, "dave")).to eq(Set.new(["hba1c"]))
    end

    it "raises ArgumentError for empty required_labs" do
      expect { LabCadenceMonitor.register_patient(m, "eve", []) }.to raise_error(ArgumentError)
    end

    it "is idempotent for an existing lab" do
      LabCadenceMonitor.register_patient(m, "frank", ["hba1c"])
      LabCadenceMonitor.register_patient(m, "frank", ["hba1c"])
      expect(LabCadenceMonitor.required_labs(m, "frank")).to eq(Set.new(["hba1c"]))
    end

    it "adds new labs to an existing patient" do
      LabCadenceMonitor.register_patient(m, "grace", ["hba1c"])
      LabCadenceMonitor.register_patient(m, "grace", ["bmp"])
      expect(LabCadenceMonitor.required_labs(m, "grace")).to eq(Set.new(["hba1c", "bmp"]))
    end

    it "does not remove existing labs" do
      LabCadenceMonitor.register_patient(m, "hank", ["hba1c", "bmp"])
      LabCadenceMonitor.register_patient(m, "hank", ["lipids"])
      labs = LabCadenceMonitor.required_labs(m, "hank")
      expect(labs).to include("hba1c", "bmp")
    end
  end

  describe ".add_required_lab" do
    it "adds a lab to an existing patient" do
      LabCadenceMonitor.register_patient(m, "iris", ["hba1c"])
      LabCadenceMonitor.add_required_lab(m, "iris", "bmp")
      expect(LabCadenceMonitor.required_labs(m, "iris")).to include("bmp")
    end

    it "is idempotent" do
      LabCadenceMonitor.register_patient(m, "jack", ["hba1c"])
      LabCadenceMonitor.add_required_lab(m, "jack", "hba1c")
      expect(LabCadenceMonitor.required_labs(m, "jack")).to eq(Set.new(["hba1c"]))
    end

    it "raises KeyError for an unknown patient" do
      expect { LabCadenceMonitor.add_required_lab(m, "nobody", "hba1c") }.to raise_error(KeyError)
    end
  end

  describe ".required_labs" do
    it "returns the correct set" do
      LabCadenceMonitor.register_patient(m, "kate", ["hba1c", "lipids"])
      expect(LabCadenceMonitor.required_labs(m, "kate")).to eq(Set.new(["hba1c", "lipids"]))
    end

    it "raises KeyError for an unknown patient" do
      expect { LabCadenceMonitor.required_labs(m, "nobody") }.to raise_error(KeyError)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Deadlines and submissions
  # ---------------------------------------------------------------------------

  describe ".set_lab_deadline" do
    it "sets a deadline" do
      expect { LabCadenceMonitor.set_lab_deadline(seeded, "alice", "lipids", Date.new(2024, 5, 1)) }.not_to raise_error
    end

    it "ignores a duplicate deadline" do
      LabCadenceMonitor.set_lab_deadline(seeded, "alice", "lipids", Date.new(2024, 5, 1))
      LabCadenceMonitor.set_lab_deadline(seeded, "alice", "lipids", Date.new(2024, 5, 1))
      expect(LabCadenceMonitor.overdue?(seeded, "alice", "lipids", Date.new(2024, 5, 2))).to be(true)
    end

    it "raises KeyError for an unknown patient" do
      expect { LabCadenceMonitor.set_lab_deadline(m, "nobody", "hba1c", Date.new(2024, 3, 31)) }.to raise_error(KeyError)
    end

    it "raises ArgumentError for an unrequired lab" do
      LabCadenceMonitor.register_patient(m, "leo", ["hba1c"])
      expect { LabCadenceMonitor.set_lab_deadline(m, "leo", "bmp", Date.new(2024, 3, 31)) }.to raise_error(ArgumentError)
    end
  end

  describe ".record_submission" do
    it "clears the deadline it satisfies" do
      expect(LabCadenceMonitor.overdue?(seeded, "carol", "hba1c", Date.new(2024, 4, 1))).to be(false)
    end

    it "clears only the earliest applicable deadline" do
      expect(LabCadenceMonitor.overdue?(seeded, "alice", "hba1c", Date.new(2024, 7, 1))).to be(true)
    end

    it "raises KeyError for an unknown patient" do
      expect { LabCadenceMonitor.record_submission(m, "nobody", "hba1c", Date.new(2024, 3, 28)) }.to raise_error(KeyError)
    end

    it "raises ArgumentError for an unrequired lab" do
      LabCadenceMonitor.register_patient(m, "mia", ["hba1c"])
      expect { LabCadenceMonitor.record_submission(m, "mia", "bmp", Date.new(2024, 3, 28)) }.to raise_error(ArgumentError)
    end

    it "does not clear a past deadline when submitted late" do
      LabCadenceMonitor.register_patient(m, "noah", ["hba1c"])
      LabCadenceMonitor.set_lab_deadline(m, "noah", "hba1c", Date.new(2024, 3, 31))
      LabCadenceMonitor.record_submission(m, "noah", "hba1c", Date.new(2024, 4, 15))
      expect(LabCadenceMonitor.overdue?(m, "noah", "hba1c", Date.new(2024, 4, 1))).to be(true)
    end
  end

  describe ".overdue?" do
    it "is true for an overdue deadline with no submission" do
      expect(LabCadenceMonitor.overdue?(seeded, "bob", "bmp", Date.new(2024, 4, 1))).to be(true)
    end

    it "is false when submitted on time" do
      expect(LabCadenceMonitor.overdue?(seeded, "bob", "hba1c", Date.new(2024, 4, 1))).to be(false)
    end

    it "is false when the deadline has not yet passed" do
      expect(LabCadenceMonitor.overdue?(seeded, "alice", "bmp", Date.new(2024, 4, 14))).to be(false)
    end

    it "is true the day after the deadline" do
      expect(LabCadenceMonitor.overdue?(seeded, "alice", "bmp", Date.new(2024, 4, 16))).to be(true)
    end

    it "is false when no deadline has been set" do
      expect(LabCadenceMonitor.overdue?(seeded, "alice", "lipids", Date.new(2024, 6, 1))).to be(false)
    end

    it "is false for an unknown patient" do
      expect(LabCadenceMonitor.overdue?(seeded, "nobody", "hba1c", Date.new(2024, 4, 1))).to be(false)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Compliance reporting
  # ---------------------------------------------------------------------------

  describe ".overdue_labs" do
    it "returns sorted overdue labs" do
      labs = LabCadenceMonitor.overdue_labs(seeded, "alice", Date.new(2024, 7, 1))
      expect(labs).to eq(labs.sort)
      expect(labs).to include("bmp", "hba1c")
    end

    it "returns an empty array when nothing is overdue" do
      expect(LabCadenceMonitor.overdue_labs(seeded, "carol", Date.new(2024, 4, 1))).to eq([])
    end

    it "returns an empty array for an unknown patient" do
      expect(LabCadenceMonitor.overdue_labs(seeded, "nobody", Date.new(2024, 4, 1))).to eq([])
    end
  end

  describe ".compliance_report" do
    it "contains overdue patients" do
      report = LabCadenceMonitor.compliance_report(seeded, Date.new(2024, 4, 16))
      patient_ids = report.map { |e| e[:patient_id] }
      expect(patient_ids).to include("alice", "bob")
    end

    it "excludes compliant patients" do
      report = LabCadenceMonitor.compliance_report(seeded, Date.new(2024, 4, 16))
      patient_ids = report.map { |e| e[:patient_id] }
      expect(patient_ids).not_to include("carol")
    end

    it "has the expected entry fields" do
      report = LabCadenceMonitor.compliance_report(seeded, Date.new(2024, 4, 16))
      bob_entry = report.find { |e| e[:patient_id] == "bob" }
      expect(bob_entry.keys.sort).to eq([:overdue_count, :overdue_labs, :patient_id].sort)
      expect(bob_entry[:overdue_count]).to eq(bob_entry[:overdue_labs].size)
    end

    it "sorts by overdue_count descending" do
      report = LabCadenceMonitor.compliance_report(seeded, Date.new(2024, 7, 1))
      counts = report.map { |e| e[:overdue_count] }
      expect(counts).to eq(counts.sort.reverse)
    end

    it "returns an empty array when nobody is overdue" do
      LabCadenceMonitor.register_patient(m, "perfectly_compliant_06", ["hba1c"])
      LabCadenceMonitor.set_lab_deadline(m, "perfectly_compliant_06", "hba1c", Date.new(2024, 3, 31))
      LabCadenceMonitor.record_submission(m, "perfectly_compliant_06", "hba1c", Date.new(2024, 3, 20))
      expect(LabCadenceMonitor.compliance_report(m, Date.new(2024, 4, 1))).to eq([])
    end
  end

  # ---------------------------------------------------------------------------
  # PART 4 — Submission history
  # ---------------------------------------------------------------------------

  describe ".submission_history" do
    it "returns chronologically sorted dates" do
      LabCadenceMonitor.register_patient(m, "quinn", ["hba1c"])
      LabCadenceMonitor.set_lab_deadline(m, "quinn", "hba1c", Date.new(2024, 3, 31))
      LabCadenceMonitor.set_lab_deadline(m, "quinn", "hba1c", Date.new(2024, 6, 30))
      LabCadenceMonitor.record_submission(m, "quinn", "hba1c", Date.new(2024, 3, 20))
      LabCadenceMonitor.record_submission(m, "quinn", "hba1c", Date.new(2024, 6, 15))
      history = LabCadenceMonitor.submission_history(m, "quinn", "hba1c")
      expect(history).to eq(history.sort)
      expect(history.size).to eq(2)
    end

    it "returns an empty array when there are no submissions" do
      expect(LabCadenceMonitor.submission_history(seeded, "alice", "lipids")).to eq([])
    end

    it "returns an empty array for an unknown patient" do
      expect(LabCadenceMonitor.submission_history(m, "nobody", "hba1c")).to eq([])
    end
  end

  describe ".days_since_last_submission" do
    it "computes the correct number of days" do
      LabCadenceMonitor.register_patient(m, "rita", ["hba1c"])
      LabCadenceMonitor.set_lab_deadline(m, "rita", "hba1c", Date.new(2024, 3, 31))
      LabCadenceMonitor.record_submission(m, "rita", "hba1c", Date.new(2024, 3, 20))
      expect(LabCadenceMonitor.days_since_last_submission(m, "rita", "hba1c", Date.new(2024, 4, 20))).to eq(31)
    end

    it "returns nil when there is no submission" do
      expect(LabCadenceMonitor.days_since_last_submission(seeded, "alice", "lipids", Date.new(2024, 5, 1))).to be_nil
    end

    it "returns nil for an unknown patient" do
      expect(LabCadenceMonitor.days_since_last_submission(m, "nobody", "hba1c", Date.new(2024, 4, 1))).to be_nil
    end
  end
end
