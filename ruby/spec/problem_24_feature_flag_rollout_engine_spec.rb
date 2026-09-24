require_relative "../practice_problems/problem_24_feature_flag_rollout_engine"

RSpec.describe FeatureFlagEngine do
  let(:engine) { described_class.new }

  describe "Part 1 — evaluation" do
    describe "#create_flag" do
      it "defaults to :draft stage" do
        engine.create_flag("p1_flag1")
        expect(engine.enabled?("p1_flag1", "alice")).to eq(false)
      end

      it "raises ArgumentError on duplicate flag_id" do
        engine.create_flag("p1_dup")
        expect { engine.create_flag("p1_dup") }.to raise_error(ArgumentError)
      end

      it "raises ArgumentError for a percentage outside 0..100" do
        expect { engine.create_flag("p1_bad", percentage: 150) }.to raise_error(ArgumentError)
      end
    end

    describe "#enabled?" do
      it "raises KeyError for an unknown flag" do
        expect { engine.enabled?("p1_ghost", "alice") }.to raise_error(KeyError)
      end

      it "is false in :draft even for an allow-listed user" do
        engine.create_flag("p1_flag2", stage: :draft, allow_list: ["alice"])
        expect(engine.enabled?("p1_flag2", "alice")).to eq(false)
      end

      it "is false in :archived even for an allow-listed user" do
        engine.create_flag("p1_flag3", stage: :archived, allow_list: ["alice"])
        expect(engine.enabled?("p1_flag3", "alice")).to eq(false)
      end

      it "is true for an allow-listed user while :ramping" do
        engine.create_flag("p1_flag4", stage: :ramping, percentage: 0, allow_list: ["alice"])
        expect(engine.enabled?("p1_flag4", "alice")).to eq(true)
      end

      it "is false for a non-allow-listed user while :ramping at 0 percent" do
        engine.create_flag("p1_flag5", stage: :ramping, percentage: 0)
        expect(engine.enabled?("p1_flag5", "bob")).to eq(false)
      end

      it "is true for any user while :ramping at 100 percent" do
        engine.create_flag("p1_flag6", stage: :ramping, percentage: 100)
        expect(engine.enabled?("p1_flag6", "bob")).to eq(true)
        expect(engine.enabled?("p1_flag6", "carol")).to eq(true)
      end

      it "is true for everyone while :full, regardless of allow_list" do
        engine.create_flag("p1_flag7", stage: :full)
        expect(engine.enabled?("p1_flag7", "random_user")).to eq(true)
      end
    end

    describe "#bucket_for" do
      it "is deterministic for the same flag and user" do
        engine.create_flag("p1_flag8", stage: :ramping, percentage: 50)
        first = engine.bucket_for("p1_flag8", "dave")
        second = engine.bucket_for("p1_flag8", "dave")
        expect(first).to eq(second)
      end

      it "returns a value in 0..99" do
        engine.create_flag("p1_flag9", stage: :ramping, percentage: 50)
        expect(engine.bucket_for("p1_flag9", "erin")).to be_between(0, 99)
      end
    end
  end

  describe "Part 2 — stage lifecycle" do
    describe "#transition!" do
      it "allows draft -> ramping -> full -> archived" do
        engine.create_flag("p2_flag1")
        engine.transition!("p2_flag1", :ramping, at: 1)
        engine.transition!("p2_flag1", :full, at: 2)
        engine.transition!("p2_flag1", :archived, at: 3)
        expect(engine.enabled?("p2_flag1", "anyone")).to eq(false)
      end

      it "allows ramping -> archived directly" do
        engine.create_flag("p2_flag2")
        engine.transition!("p2_flag2", :ramping, at: 1)
        expect { engine.transition!("p2_flag2", :archived, at: 2) }.not_to raise_error
      end

      it "raises ArgumentError for an illegal transition (draft -> full)" do
        engine.create_flag("p2_flag3")
        expect { engine.transition!("p2_flag3", :full, at: 1) }.to raise_error(ArgumentError)
      end

      it "raises ArgumentError transitioning out of :archived" do
        engine.create_flag("p2_flag4", stage: :archived)
        expect { engine.transition!("p2_flag4", :ramping, at: 1) }.to raise_error(ArgumentError)
      end

      it "raises KeyError for an unknown flag" do
        expect { engine.transition!("p2_ghost", :ramping, at: 1) }.to raise_error(KeyError)
      end

      it "makes a :ramping flag's percentage take effect once evaluated" do
        engine.create_flag("p2_flag5", percentage: 100)
        engine.transition!("p2_flag5", :ramping, at: 1)
        expect(engine.enabled?("p2_flag5", "anyone")).to eq(true)
      end
    end

    describe "#set_percentage" do
      it "updates the percentage while :ramping" do
        engine.create_flag("p2_flag6", stage: :ramping, percentage: 0)
        engine.set_percentage("p2_flag6", 100, at: 1)
        expect(engine.enabled?("p2_flag6", "anyone")).to eq(true)
      end

      it "raises ArgumentError when the flag is not :ramping" do
        engine.create_flag("p2_flag7", stage: :draft)
        expect { engine.set_percentage("p2_flag7", 50, at: 1) }.to raise_error(ArgumentError)
      end

      it "raises ArgumentError for a percentage outside 0..100" do
        engine.create_flag("p2_flag8", stage: :ramping)
        expect { engine.set_percentage("p2_flag8", 101, at: 1) }.to raise_error(ArgumentError)
      end

      it "raises KeyError for an unknown flag" do
        expect { engine.set_percentage("p2_ghost2", 50, at: 1) }.to raise_error(KeyError)
      end
    end
  end

  describe "Part 3 — kill switch and audit log" do
    describe "#kill_switch!" do
      it "disables the flag for everyone, even in :full stage" do
        engine.create_flag("p3_flag1", stage: :full)
        engine.kill_switch!("p3_flag1", at: 1)
        expect(engine.enabled?("p3_flag1", "anyone")).to eq(false)
      end

      it "disables the flag even for an allow-listed user" do
        engine.create_flag("p3_flag2", stage: :ramping, percentage: 100, allow_list: ["alice"])
        engine.kill_switch!("p3_flag2", at: 1)
        expect(engine.enabled?("p3_flag2", "alice")).to eq(false)
      end

      it "raises KeyError for an unknown flag" do
        expect { engine.kill_switch!("p3_ghost", at: 1) }.to raise_error(KeyError)
      end
    end

    describe "#audit_log" do
      it "raises KeyError for an unknown flag" do
        expect { engine.audit_log("p3_ghost2") }.to raise_error(KeyError)
      end

      it "starts empty for a freshly created flag" do
        engine.create_flag("p3_flag3")
        expect(engine.audit_log("p3_flag3")).to eq([])
      end

      it "records a transition event" do
        engine.create_flag("p3_flag4")
        engine.transition!("p3_flag4", :ramping, at: 5)
        log = engine.audit_log("p3_flag4")
        expect(log.length).to eq(1)
        expect(log.first[:event]).to eq(:transition)
        expect(log.first[:at]).to eq(5)
      end

      it "records events in chronological order across multiple calls" do
        engine.create_flag("p3_flag5", stage: :ramping, percentage: 0)
        engine.set_percentage("p3_flag5", 50, at: 1)
        engine.transition!("p3_flag5", :full, at: 2)
        engine.kill_switch!("p3_flag5", at: 3)
        log = engine.audit_log("p3_flag5")
        expect(log.map { |entry| entry[:event] }).to eq([:percentage_change, :transition, :kill_switch])
      end
    end
  end
end
