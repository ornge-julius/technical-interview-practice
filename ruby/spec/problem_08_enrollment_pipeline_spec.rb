require_relative "../practice_problems/problem_08_enrollment_pipeline"

RSpec.describe EnrollmentPipeline do
  let(:fresh_pipeline) { EnrollmentPipeline.new }

  let(:pipeline) do
    p = EnrollmentPipeline.new

    p.add_patient("seed_active", 0.0)
    p.transition("seed_active", "screened", 100.0)
    p.transition("seed_active", "enrolled", 200.0)
    p.transition("seed_active", "active", 300.0)

    p.add_patient("seed_graduated", 0.0)
    p.transition("seed_graduated", "screened", 50.0)
    p.transition("seed_graduated", "enrolled", 150.0)
    p.transition("seed_graduated", "active", 250.0)
    p.transition("seed_graduated", "graduated", 1000.0)

    p.add_patient("seed_ineligible", 0.0)
    p.transition("seed_ineligible", "screened", 10.0)
    p.transition("seed_ineligible", "ineligible", 20.0)

    p.add_patient("seed_referred", 0.0)
    p
  end

  # ---------------------------------------------------------------------------
  # PART 1 — State tracking
  # ---------------------------------------------------------------------------

  describe "#add_patient" do
    it "starts a new patient in referred" do
      fresh_pipeline.add_patient("add_p1", 0.0)
      expect(fresh_pipeline.get_state("add_p1")).to eq("referred")
    end

    it "raises ArgumentError for a duplicate patient id" do
      fresh_pipeline.add_patient("dup_p", 0.0)
      expect { fresh_pipeline.add_patient("dup_p", 10.0) }.to raise_error(ArgumentError)
    end
  end

  describe "#transition" do
    it "changes the state on a valid transition" do
      fresh_pipeline.add_patient("trans_p1", 0.0)
      fresh_pipeline.transition("trans_p1", "screened", 100.0)
      expect(fresh_pipeline.get_state("trans_p1")).to eq("screened")
    end

    it "raises ArgumentError on an invalid transition" do
      fresh_pipeline.add_patient("trans_p2", 0.0)
      expect { fresh_pipeline.transition("trans_p2", "graduated", 100.0) }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError when skipping states" do
      fresh_pipeline.add_patient("trans_p3", 0.0)
      fresh_pipeline.transition("trans_p3", "screened", 10.0)
      expect { fresh_pipeline.transition("trans_p3", "active", 20.0) }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError for an unknown patient" do
      expect { fresh_pipeline.transition("ghost", "screened", 100.0) }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError transitioning from a terminal state" do
      fresh_pipeline.add_patient("trans_p4", 0.0)
      fresh_pipeline.transition("trans_p4", "screened", 10.0)
      fresh_pipeline.transition("trans_p4", "ineligible", 20.0)
      expect { fresh_pipeline.transition("trans_p4", "enrolled", 30.0) }.to raise_error(ArgumentError)
    end

    it "allows both branches from screened" do
      fresh_pipeline.add_patient("branch_p1", 0.0)
      fresh_pipeline.transition("branch_p1", "screened", 10.0)
      fresh_pipeline.transition("branch_p1", "enrolled", 20.0)
      expect(fresh_pipeline.get_state("branch_p1")).to eq("enrolled")

      fresh_pipeline.add_patient("branch_p2", 0.0)
      fresh_pipeline.transition("branch_p2", "screened", 10.0)
      fresh_pipeline.transition("branch_p2", "ineligible", 20.0)
      expect(fresh_pipeline.get_state("branch_p2")).to eq("ineligible")
    end
  end

  describe "#get_state" do
    it "returns the current state for each patient" do
      expect(pipeline.get_state("seed_active")).to eq("active")
      expect(pipeline.get_state("seed_graduated")).to eq("graduated")
      expect(pipeline.get_state("seed_ineligible")).to eq("ineligible")
      expect(pipeline.get_state("seed_referred")).to eq("referred")
    end

    it "raises ArgumentError for an unknown patient" do
      expect { fresh_pipeline.get_state("nobody") }.to raise_error(ArgumentError)
    end
  end

  describe "#get_patients_in_state" do
    it "returns patients in the given state" do
      active_patients = pipeline.get_patients_in_state("active")
      expect(active_patients).to include("seed_active")
      expect(active_patients).not_to include("seed_graduated")
    end

    it "returns a sorted result" do
      result = pipeline.get_patients_in_state("referred")
      expect(result).to eq(result.sort)
    end

    it "returns an empty array for an unpopulated state" do
      expect(pipeline.get_patients_in_state("withdrawn")).to eq([])
    end

    it "excludes a patient after they leave the state" do
      expect(pipeline.get_patients_in_state("screened")).not_to include("seed_ineligible")
    end
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Duration and conversion metrics
  # ---------------------------------------------------------------------------

  describe "#time_in_state" do
    it "returns the exact duration for a completed state" do
      fresh_pipeline.add_patient("dur_p1", 0.0)
      fresh_pipeline.transition("dur_p1", "screened", 1000.0)
      fresh_pipeline.transition("dur_p1", "enrolled", 4000.0)
      expect(fresh_pipeline.time_in_state("dur_p1", "screened", 99999.0)).to eq(3000.0)
    end

    it "counts the current state up to as_of" do
      fresh_pipeline.add_patient("dur_p2", 0.0)
      fresh_pipeline.transition("dur_p2", "screened", 1000.0)
      expect(fresh_pipeline.time_in_state("dur_p2", "screened", 4000.0)).to eq(3000.0)
    end

    it "returns zero for a state never visited" do
      fresh_pipeline.add_patient("dur_p3", 0.0)
      expect(fresh_pipeline.time_in_state("dur_p3", "enrolled", 99999.0)).to eq(0.0)
    end

    it "times the initial referred state from the add_patient timestamp" do
      fresh_pipeline.add_patient("dur_p4", 500.0)
      fresh_pipeline.transition("dur_p4", "screened", 1500.0)
      expect(fresh_pipeline.time_in_state("dur_p4", "referred", 99999.0)).to eq(1000.0)
    end
  end

  describe "#conversion_rate" do
    it "computes a fifty percent conversion" do
      fresh_pipeline.add_patient("conv_p1", 0.0)
      fresh_pipeline.transition("conv_p1", "screened", 10.0)
      fresh_pipeline.transition("conv_p1", "enrolled", 20.0)

      fresh_pipeline.add_patient("conv_p2", 0.0)
      fresh_pipeline.transition("conv_p2", "screened", 10.0)
      fresh_pipeline.transition("conv_p2", "ineligible", 20.0)

      expect(fresh_pipeline.conversion_rate("screened", "enrolled")).to be_within(0.001).of(0.5)
    end

    it "excludes patients still in from_state" do
      fresh_pipeline.add_patient("conv_p3", 0.0)
      fresh_pipeline.transition("conv_p3", "screened", 10.0)

      fresh_pipeline.add_patient("conv_p4", 0.0)
      fresh_pipeline.transition("conv_p4", "screened", 10.0)
      fresh_pipeline.transition("conv_p4", "enrolled", 20.0)

      expect(fresh_pipeline.conversion_rate("screened", "enrolled")).to be_within(0.001).of(1.0)
    end

    it "returns zero when no one has exited from_state" do
      fresh_pipeline.add_patient("conv_p5", 0.0)
      expect(fresh_pipeline.conversion_rate("referred", "screened")).to be_within(0.001).of(0.0)
    end

    it "returns 1.0 when everyone converted" do
      %w[conv_all_1 conv_all_2].each do |pid|
        fresh_pipeline.add_patient(pid, 0.0)
        fresh_pipeline.transition(pid, "screened", 10.0)
        fresh_pipeline.transition(pid, "enrolled", 20.0)
      end
      expect(fresh_pipeline.conversion_rate("screened", "enrolled")).to be_within(0.001).of(1.0)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 3 — SLA monitoring
  # ---------------------------------------------------------------------------

  describe "#patients_overdue" do
    it "returns patients exceeding the threshold" do
      fresh_pipeline.add_patient("over_p1", 0.0)
      fresh_pipeline.transition("over_p1", "screened", 0.0)
      fresh_pipeline.transition("over_p1", "enrolled", 0.0)
      fresh_pipeline.transition("over_p1", "active", 0.0)

      fresh_pipeline.add_patient("over_p2", 0.0)
      fresh_pipeline.transition("over_p2", "screened", 0.0)
      fresh_pipeline.transition("over_p2", "enrolled", 0.0)
      fresh_pipeline.transition("over_p2", "active", 5000.0)

      overdue = fresh_pipeline.patients_overdue("active", 6000.0, 10000.0)
      expect(overdue).to include("over_p1")
      expect(overdue).not_to include("over_p2")
    end

    it "sorts by duration descending" do
      fresh_pipeline.add_patient("sort_p1", 0.0)
      fresh_pipeline.transition("sort_p1", "screened", 0.0)
      fresh_pipeline.transition("sort_p1", "enrolled", 0.0)
      fresh_pipeline.transition("sort_p1", "active", 0.0)

      fresh_pipeline.add_patient("sort_p2", 0.0)
      fresh_pipeline.transition("sort_p2", "screened", 0.0)
      fresh_pipeline.transition("sort_p2", "enrolled", 0.0)
      fresh_pipeline.transition("sort_p2", "active", 3000.0)

      overdue = fresh_pipeline.patients_overdue("active", 5000.0, 10000.0)
      expect(overdue).to eq(["sort_p1", "sort_p2"])
    end

    it "excludes patients not currently in the state" do
      overdue = pipeline.patients_overdue("active", 0.0, 2000.0)
      expect(overdue).not_to include("seed_graduated")
    end

    it "returns an empty array when no one is overdue" do
      fresh_pipeline.add_patient("noover_p", 0.0)
      fresh_pipeline.transition("noover_p", "screened", 0.0)
      fresh_pipeline.transition("noover_p", "enrolled", 0.0)
      fresh_pipeline.transition("noover_p", "active", 9900.0)
      expect(fresh_pipeline.patients_overdue("active", 500.0, 10000.0)).to eq([])
    end
  end

  describe "#average_time_in_state" do
    it "averages over all exited patients" do
      fresh_pipeline.add_patient("avg_pa", 0.0)
      fresh_pipeline.transition("avg_pa", "screened", 0.0)
      fresh_pipeline.transition("avg_pa", "enrolled", 1000.0)

      fresh_pipeline.add_patient("avg_pb", 0.0)
      fresh_pipeline.transition("avg_pb", "screened", 0.0)
      fresh_pipeline.transition("avg_pb", "enrolled", 3000.0)

      expect(fresh_pipeline.average_time_in_state("screened", 99999.0)).to be_within(0.001).of(2000.0)
    end

    it "excludes patients still in the state" do
      fresh_pipeline.add_patient("avg_pc", 0.0)
      fresh_pipeline.transition("avg_pc", "screened", 0.0)
      fresh_pipeline.transition("avg_pc", "enrolled", 1000.0)

      fresh_pipeline.add_patient("avg_pd", 0.0)
      fresh_pipeline.transition("avg_pd", "screened", 0.0)

      expect(fresh_pipeline.average_time_in_state("screened", 5000.0)).to be_within(0.001).of(1000.0)
    end

    it "returns zero when no one has exited" do
      fresh_pipeline.add_patient("avg_pe", 0.0)
      fresh_pipeline.transition("avg_pe", "screened", 0.0)
      expect(fresh_pipeline.average_time_in_state("screened", 5000.0)).to be_within(0.001).of(0.0)
    end
  end
end
