require_relative "../practice_problems/problem_23_course_enrollment_engine"

RSpec.describe CourseEnrollmentEngine do
  let(:engine) { described_class.new }

  describe "Part 1 — enrollment with fixed capacity" do
    describe "#add_course" do
      it "registers a course" do
        engine.add_course("p1_cs101", capacity: 2)
        expect(engine.enrolled?("p1_cs101", "alice")).to eq(false)
      end

      it "raises ArgumentError on duplicate course_id" do
        engine.add_course("p1_dup", capacity: 2)
        expect { engine.add_course("p1_dup", capacity: 3) }.to raise_error(ArgumentError)
      end

      it "raises ArgumentError for a non-positive capacity" do
        expect { engine.add_course("p1_bad", capacity: 0) }.to raise_error(ArgumentError)
      end
    end

    describe "#enroll" do
      it "enrolls a student when a seat is available" do
        engine.add_course("p1_cs102", capacity: 2)
        expect(engine.enroll("p1_cs102", "alice")).to eq(:enrolled)
        expect(engine.enrolled?("p1_cs102", "alice")).to eq(true)
      end

      it "raises KeyError for an unknown course" do
        expect { engine.enroll("p1_ghost", "alice") }.to raise_error(KeyError)
      end

      it "raises ArgumentError enrolling the same student twice" do
        engine.add_course("p1_cs103", capacity: 2)
        engine.enroll("p1_cs103", "alice")
        expect { engine.enroll("p1_cs103", "alice") }.to raise_error(ArgumentError)
      end

      it "allows multiple distinct students up to capacity" do
        engine.add_course("p1_cs104", capacity: 2)
        expect(engine.enroll("p1_cs104", "alice")).to eq(:enrolled)
        expect(engine.enroll("p1_cs104", "bob")).to eq(:enrolled)
      end
    end

    describe "#drop" do
      it "frees a student's seat" do
        engine.add_course("p1_cs105", capacity: 1)
        engine.enroll("p1_cs105", "alice")
        engine.drop("p1_cs105", "alice")
        expect(engine.enrolled?("p1_cs105", "alice")).to eq(false)
      end

      it "raises ArgumentError dropping a student who was never enrolled" do
        engine.add_course("p1_cs106", capacity: 1)
        expect { engine.drop("p1_cs106", "ghost") }.to raise_error(ArgumentError)
      end

      it "raises KeyError for an unknown course" do
        expect { engine.drop("p1_ghost2", "alice") }.to raise_error(KeyError)
      end
    end

    describe "#enrolled?" do
      it "raises KeyError for an unknown course" do
        expect { engine.enrolled?("p1_ghost3", "alice") }.to raise_error(KeyError)
      end
    end
  end

  describe "Part 2 — waitlist with auto-promotion" do
    describe "#enroll and #waitlist" do
      it "waitlists a student once the course is full" do
        engine.add_course("p2_cs201", capacity: 1)
        engine.enroll("p2_cs201", "alice")
        expect(engine.enroll("p2_cs201", "bob")).to eq(:waitlisted)
        expect(engine.waitlist("p2_cs201")).to eq(["bob"])
      end

      it "orders the waitlist FIFO" do
        engine.add_course("p2_cs202", capacity: 1)
        engine.enroll("p2_cs202", "alice")
        engine.enroll("p2_cs202", "bob")
        engine.enroll("p2_cs202", "carol")
        expect(engine.waitlist("p2_cs202")).to eq(["bob", "carol"])
      end

      it "raises ArgumentError enrolling an already-waitlisted student" do
        engine.add_course("p2_cs203", capacity: 1)
        engine.enroll("p2_cs203", "alice")
        engine.enroll("p2_cs203", "bob")
        expect { engine.enroll("p2_cs203", "bob") }.to raise_error(ArgumentError)
      end

      it "raises KeyError for an unknown course" do
        expect { engine.waitlist("p2_ghost") }.to raise_error(KeyError)
      end
    end

    describe "#drop" do
      it "promotes the earliest-waitlisted student when an enrolled student drops" do
        engine.add_course("p2_cs204", capacity: 1)
        engine.enroll("p2_cs204", "alice")
        engine.enroll("p2_cs204", "bob")
        engine.drop("p2_cs204", "alice")
        expect(engine.enrolled?("p2_cs204", "bob")).to eq(true)
        expect(engine.waitlist("p2_cs204")).to eq([])
      end

      it "removes a waitlisted student without promoting anyone" do
        engine.add_course("p2_cs205", capacity: 1)
        engine.enroll("p2_cs205", "alice")
        engine.enroll("p2_cs205", "bob")
        engine.drop("p2_cs205", "bob")
        expect(engine.waitlist("p2_cs205")).to eq([])
        expect(engine.enrolled?("p2_cs205", "alice")).to eq(true)
      end

      it "does not promote anyone when the waitlist is empty" do
        engine.add_course("p2_cs206", capacity: 2)
        engine.enroll("p2_cs206", "alice")
        engine.drop("p2_cs206", "alice")
        expect(engine.enrolled?("p2_cs206", "alice")).to eq(false)
        expect(engine.waitlist("p2_cs206")).to eq([])
      end
    end
  end

  describe "Part 3 — prerequisite enforcement" do
    describe "#prerequisites_met?" do
      it "is true when a course has no prerequisites" do
        engine.add_course("p3_cs301", capacity: 1)
        expect(engine.prerequisites_met?("p3_cs301", "alice")).to eq(true)
      end

      it "is false when a required prerequisite has not been completed" do
        engine.add_course("p3_cs302", capacity: 1, prerequisites: ["p3_cs301"])
        expect(engine.prerequisites_met?("p3_cs302", "alice")).to eq(false)
      end

      it "is true once every prerequisite is marked completed" do
        engine.add_course("p3_cs303", capacity: 1, prerequisites: ["p3_cs301"])
        engine.mark_completed("alice", "p3_cs301")
        expect(engine.prerequisites_met?("p3_cs303", "alice")).to eq(true)
      end

      it "requires ALL prerequisites, not just one" do
        engine.add_course("p3_cs304", capacity: 1, prerequisites: ["p3_math", "p3_physics"])
        engine.mark_completed("alice", "p3_math")
        expect(engine.prerequisites_met?("p3_cs304", "alice")).to eq(false)
        engine.mark_completed("alice", "p3_physics")
        expect(engine.prerequisites_met?("p3_cs304", "alice")).to eq(true)
      end

      it "raises KeyError for an unknown course" do
        expect { engine.prerequisites_met?("p3_ghost", "alice") }.to raise_error(KeyError)
      end
    end

    describe "#enroll" do
      it "raises ArgumentError when prerequisites are not met" do
        engine.add_course("p3_cs305", capacity: 1, prerequisites: ["p3_cs301"])
        expect { engine.enroll("p3_cs305", "alice") }.to raise_error(ArgumentError)
      end

      it "succeeds once the prerequisite has been marked completed" do
        engine.add_course("p3_cs306", capacity: 1, prerequisites: ["p3_cs301"])
        engine.mark_completed("alice", "p3_cs301")
        expect(engine.enroll("p3_cs306", "alice")).to eq(:enrolled)
      end

      it "still enforces capacity/waitlist behavior once prerequisites are met" do
        engine.add_course("p3_cs307", capacity: 1, prerequisites: ["p3_cs301"])
        engine.mark_completed("alice", "p3_cs301")
        engine.mark_completed("bob", "p3_cs301")
        engine.enroll("p3_cs307", "alice")
        expect(engine.enroll("p3_cs307", "bob")).to eq(:waitlisted)
      end
    end
  end
end
