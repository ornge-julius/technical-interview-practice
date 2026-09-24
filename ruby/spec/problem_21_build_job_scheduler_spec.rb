require_relative "../practice_problems/problem_21_build_job_scheduler"

RSpec.describe BuildJobScheduler do
  let(:scheduler) { described_class.new }

  describe "Part 1 — basic FIFO queue" do
    describe "#enqueue_job" do
      it "enqueues a job with default priority and :queued status" do
        scheduler.enqueue_job("p1_lint")
        expect(scheduler.status("p1_lint")).to eq(:queued)
      end

      it "accepts an explicit priority" do
        scheduler.enqueue_job("p1_build", priority: 5)
        expect(scheduler.status("p1_build")).to eq(:queued)
      end

      it "raises ArgumentError on duplicate job_id" do
        scheduler.enqueue_job("p1_dup")
        expect { scheduler.enqueue_job("p1_dup") }.to raise_error(ArgumentError)
      end
    end

    describe "#status" do
      it "raises KeyError for an unknown job" do
        expect { scheduler.status("p1_missing") }.to raise_error(KeyError)
      end
    end

    describe "#start_job and #complete_job" do
      it "transitions :queued -> :running -> :complete" do
        scheduler.enqueue_job("p1_flow")
        scheduler.start_job("p1_flow")
        expect(scheduler.status("p1_flow")).to eq(:running)
        scheduler.complete_job("p1_flow")
        expect(scheduler.status("p1_flow")).to eq(:complete)
      end

      it "raises ArgumentError starting a job that is not :queued" do
        scheduler.enqueue_job("p1_notqueued")
        scheduler.start_job("p1_notqueued")
        expect { scheduler.start_job("p1_notqueued") }.to raise_error(ArgumentError)
      end

      it "raises ArgumentError completing a job that is not :running" do
        scheduler.enqueue_job("p1_notrunning")
        expect { scheduler.complete_job("p1_notrunning") }.to raise_error(ArgumentError)
      end

      it "raises KeyError starting an unknown job" do
        expect { scheduler.start_job("p1_ghost") }.to raise_error(KeyError)
      end
    end

    describe "#next_job" do
      it "returns nil when nothing is queued" do
        expect(scheduler.next_job).to be_nil
      end

      it "returns the earliest-enqueued queued job, ignoring priority" do
        scheduler.enqueue_job("p1_first")
        scheduler.enqueue_job("p1_second", priority: 100)
        expect(scheduler.next_job).to eq("p1_first")
      end

      it "skips jobs that are no longer :queued" do
        scheduler.enqueue_job("p1_running_job")
        scheduler.enqueue_job("p1_next_up")
        scheduler.start_job("p1_running_job")
        expect(scheduler.next_job).to eq("p1_next_up")
      end
    end
  end

  describe "Part 2 — dependencies" do
    describe "#add_dependency" do
      it "raises KeyError if job_id is unknown" do
        scheduler.enqueue_job("p2_dep")
        expect { scheduler.add_dependency("p2_ghost", "p2_dep") }.to raise_error(KeyError)
      end

      it "raises KeyError if the dependency job is unknown" do
        scheduler.enqueue_job("p2_job")
        expect { scheduler.add_dependency("p2_job", "p2_ghost") }.to raise_error(KeyError)
      end
    end

    describe "#ready?" do
      it "raises KeyError for an unknown job" do
        expect { scheduler.ready?("p2_missing") }.to raise_error(KeyError)
      end

      it "is true for a queued job with no dependencies" do
        scheduler.enqueue_job("p2_free")
        expect(scheduler.ready?("p2_free")).to eq(true)
      end

      it "is false while a dependency is not yet :complete" do
        scheduler.enqueue_job("p2_base")
        scheduler.enqueue_job("p2_dependent")
        scheduler.add_dependency("p2_dependent", "p2_base")
        expect(scheduler.ready?("p2_dependent")).to eq(false)
      end

      it "is true once every dependency is :complete" do
        scheduler.enqueue_job("p2_base2")
        scheduler.enqueue_job("p2_dependent2")
        scheduler.add_dependency("p2_dependent2", "p2_base2")
        scheduler.start_job("p2_base2")
        scheduler.complete_job("p2_base2")
        expect(scheduler.ready?("p2_dependent2")).to eq(true)
      end

      it "is false if the job itself is not :queued, even with satisfied dependencies" do
        scheduler.enqueue_job("p2_base3")
        scheduler.enqueue_job("p2_dependent3")
        scheduler.add_dependency("p2_dependent3", "p2_base3")
        scheduler.start_job("p2_base3")
        scheduler.complete_job("p2_base3")
        scheduler.start_job("p2_dependent3")
        expect(scheduler.ready?("p2_dependent3")).to eq(false)
      end

      it "requires ALL dependencies to be complete, not just one" do
        scheduler.enqueue_job("p2_dep_a")
        scheduler.enqueue_job("p2_dep_b")
        scheduler.enqueue_job("p2_multi")
        scheduler.add_dependency("p2_multi", "p2_dep_a")
        scheduler.add_dependency("p2_multi", "p2_dep_b")
        scheduler.start_job("p2_dep_a")
        scheduler.complete_job("p2_dep_a")
        expect(scheduler.ready?("p2_multi")).to eq(false)
      end
    end
  end

  describe "Part 3 — priority-ordered selection" do
    describe "#next_runnable_job" do
      it "returns nil when nothing is ready" do
        expect(scheduler.next_runnable_job).to be_nil
      end

      it "only returns the base job when the dependent job is still blocked" do
        scheduler.enqueue_job("p3_base")
        scheduler.enqueue_job("p3_blocked")
        scheduler.add_dependency("p3_blocked", "p3_base")
        expect(scheduler.next_runnable_job).to eq("p3_base")
      end

      it "picks the highest-priority ready job" do
        scheduler.enqueue_job("p3_low", priority: 1)
        scheduler.enqueue_job("p3_high", priority: 10)
        expect(scheduler.next_runnable_job).to eq("p3_high")
      end

      it "breaks priority ties by FIFO enqueue order" do
        scheduler.enqueue_job("p3_tie_first", priority: 5)
        scheduler.enqueue_job("p3_tie_second", priority: 5)
        expect(scheduler.next_runnable_job).to eq("p3_tie_first")
      end

      it "excludes jobs that are not ready even if they have higher priority" do
        scheduler.enqueue_job("p3_dep")
        scheduler.enqueue_job("p3_gated", priority: 100)
        scheduler.enqueue_job("p3_available", priority: 1)
        scheduler.add_dependency("p3_gated", "p3_dep")
        expect(scheduler.next_runnable_job).to eq("p3_available")
      end

      it "becomes eligible once its dependency completes" do
        scheduler.enqueue_job("p3_dep2")
        scheduler.enqueue_job("p3_gated2", priority: 100)
        scheduler.add_dependency("p3_gated2", "p3_dep2")
        scheduler.start_job("p3_dep2")
        scheduler.complete_job("p3_dep2")
        expect(scheduler.next_runnable_job).to eq("p3_gated2")
      end
    end
  end
end
