require_relative "../practice_problems/problem_22_dispatch_triage_queue"

RSpec.describe DispatchTriageQueue do
  let(:queue) { described_class.new }

  describe "Part 1 — call intake and status tracking" do
    describe "#intake_call" do
      it "records a call as :waiting" do
        queue.intake_call("p1_c1", severity: :medium, at: 0)
        expect(queue.status("p1_c1")).to eq(:waiting)
      end

      it "raises ArgumentError on duplicate call_id" do
        queue.intake_call("p1_dup", severity: :low, at: 0)
        expect { queue.intake_call("p1_dup", severity: :low, at: 5) }.to raise_error(ArgumentError)
      end

      it "raises ArgumentError for an unknown severity" do
        expect { queue.intake_call("p1_bad", severity: :urgent, at: 0) }.to raise_error(ArgumentError)
      end
    end

    describe "#status and #severity" do
      it "raises KeyError for an unknown call" do
        expect { queue.status("p1_ghost") }.to raise_error(KeyError)
        expect { queue.severity("p1_ghost") }.to raise_error(KeyError)
      end

      it "returns the recorded severity" do
        queue.intake_call("p1_sev", severity: :critical, at: 0)
        expect(queue.severity("p1_sev")).to eq(:critical)
      end
    end
  end

  describe "Part 2 — SLA-aware dispatch selection" do
    describe "#next_to_dispatch" do
      it "returns nil when no call is waiting" do
        expect(queue.next_to_dispatch(at: 0)).to be_nil
      end

      it "picks the higher-severity call when both are within SLA" do
        queue.intake_call("p2_med", severity: :medium, at: 0)
        queue.intake_call("p2_high", severity: :high, at: 0)
        expect(queue.next_to_dispatch(at: 10)).to eq("p2_high")
      end

      it "breaks ties within the same effective tier by FIFO intake order" do
        queue.intake_call("p2_first", severity: :high, at: 0)
        queue.intake_call("p2_second", severity: :high, at: 5)
        expect(queue.next_to_dispatch(at: 10)).to eq("p2_first")
      end

      it "escalates a call that has breached its SLA by one severity tier" do
        queue.intake_call("p2_stale_medium", severity: :medium, at: 0)
        queue.intake_call("p2_fresh_high", severity: :high, at: 901)
        # medium SLA is 900s; at t=901 the medium call has breached and
        # escalates to effectively :high, tying with the fresh :high call,
        # so FIFO (earlier intake_time) decides.
        expect(queue.next_to_dispatch(at: 901)).to eq("p2_stale_medium")
      end

      it "does not escalate a call still within its SLA window" do
        queue.intake_call("p2_ok_medium", severity: :medium, at: 0)
        queue.intake_call("p2_ok_high", severity: :high, at: 100)
        expect(queue.next_to_dispatch(at: 899)).to eq("p2_ok_high")
      end

      it "does not escalate :critical calls beyond the top tier" do
        queue.intake_call("p2_stale_critical", severity: :critical, at: 0)
        queue.intake_call("p2_fresh_critical", severity: :critical, at: 61)
        expect(queue.next_to_dispatch(at: 200)).to eq("p2_stale_critical")
      end

      it "ignores calls that are not :waiting" do
        queue.intake_call("p2_taken", severity: :critical, at: 0)
        queue.intake_call("p2_available", severity: :low, at: 0)
        queue.dispatch_call("p2_taken", responder_id: "unit_1", at: 5)
        expect(queue.next_to_dispatch(at: 10)).to eq("p2_available")
      end
    end
  end

  describe "Part 3 — responder assignment and SLA reporting" do
    describe "#dispatch_call" do
      it "moves a waiting call to :dispatched" do
        queue.intake_call("p3_c1", severity: :high, at: 0)
        queue.dispatch_call("p3_c1", responder_id: "unit_2", at: 10)
        expect(queue.status("p3_c1")).to eq(:dispatched)
      end

      it "raises ArgumentError dispatching a non-waiting call" do
        queue.intake_call("p3_c2", severity: :high, at: 0)
        queue.dispatch_call("p3_c2", responder_id: "unit_2", at: 10)
        expect { queue.dispatch_call("p3_c2", responder_id: "unit_3", at: 20) }.to raise_error(ArgumentError)
      end

      it "raises KeyError dispatching an unknown call" do
        expect { queue.dispatch_call("p3_ghost", responder_id: "unit_2", at: 10) }.to raise_error(KeyError)
      end
    end

    describe "#complete_call" do
      it "moves a dispatched call to :completed" do
        queue.intake_call("p3_c3", severity: :low, at: 0)
        queue.dispatch_call("p3_c3", responder_id: "unit_4", at: 10)
        queue.complete_call("p3_c3", at: 40)
        expect(queue.status("p3_c3")).to eq(:completed)
      end

      it "raises ArgumentError completing a call that was never dispatched" do
        queue.intake_call("p3_c4", severity: :low, at: 0)
        expect { queue.complete_call("p3_c4", at: 40) }.to raise_error(ArgumentError)
      end
    end

    describe "#sla_breach_stats" do
      it "reports zero total when nothing has been dispatched" do
        expect(queue.sla_breach_stats).to eq({ total: 0, breached: 0, breach_rate: 0.0 })
      end

      it "counts a call dispatched after its SLA deadline as breached" do
        queue.intake_call("p3_late", severity: :critical, at: 0)
        queue.dispatch_call("p3_late", responder_id: "unit_5", at: 61)
        expect(queue.sla_breach_stats).to eq({ total: 1, breached: 1, breach_rate: 1.0 })
      end

      it "does not count a call dispatched within its SLA deadline as breached" do
        queue.intake_call("p3_ontime", severity: :critical, at: 0)
        queue.dispatch_call("p3_ontime", responder_id: "unit_6", at: 60)
        expect(queue.sla_breach_stats).to eq({ total: 1, breached: 0, breach_rate: 0.0 })
      end

      it "computes a mixed breach rate across multiple dispatched calls" do
        queue.intake_call("p3_a", severity: :high, at: 0)
        queue.intake_call("p3_b", severity: :high, at: 0)
        queue.dispatch_call("p3_a", responder_id: "unit_7", at: 100)
        queue.dispatch_call("p3_b", responder_id: "unit_8", at: 400)
        expect(queue.sla_breach_stats).to eq({ total: 2, breached: 1, breach_rate: 0.5 })
      end

      it "still counts a completed call toward the stats" do
        queue.intake_call("p3_done", severity: :medium, at: 0)
        queue.dispatch_call("p3_done", responder_id: "unit_9", at: 901)
        queue.complete_call("p3_done", at: 950)
        expect(queue.sla_breach_stats).to eq({ total: 1, breached: 1, breach_rate: 1.0 })
      end
    end
  end
end
