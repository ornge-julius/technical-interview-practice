# =============================================================================
# INTERVIEW PROBLEM 23: Course Enrollment Engine
# Difficulty: Senior Software Engineer | Estimated time: 45 min
# =============================================================================
#
# CONTEXT
# -------
# You're building the enrollment engine for a university registration system.
# Courses have a fixed number of seats. When a course is full, students join
# a waitlist instead of being turned away outright. Some courses also require
# the student to have already completed certain prerequisite courses.
#
# You choose the internal data structures — the public interface below is
# what matters. Store all state in instance variables set in `initialize`.
# Class variables (`@@foo`), class-level instance variables, and mutable
# class-body constants will bleed between examples and between instances —
# avoid them.
#
# DATA MODEL
# ----------
# A course has:
#   - a unique course_id (String)
#   - a seat capacity (Integer)
#   - zero or more prerequisite course_ids
#
# `enroll` and `drop` below describe their FULL final behavior (capacity,
# waitlist, and prerequisites all apply from the moment they're implemented).
# Implement them a piece at a time: get capacity-only enrollment working
# first using courses with no prerequisites and never exceeding capacity,
# then layer in the waitlist, then the prerequisite gate.
#
# Example
#   engine = CourseEnrollmentEngine.new
#   engine.add_course("cs101", capacity: 1)
#   engine.enroll("cs101", "alice")               # -> :enrolled
#   engine.enroll("cs101", "bob")                  # -> :waitlisted (course is full)
#   engine.drop("cs101", "alice")
#   engine.enrolled?("cs101", "bob")               # -> true (auto-promoted from waitlist)
#
#   engine.add_course("cs201", capacity: 5, prerequisites: ["cs101"])
#   engine.enroll("cs201", "carol")                # -> raises ArgumentError (missing prerequisite)
#   engine.mark_completed("carol", "cs101")
#   engine.enroll("cs201", "carol")                # -> :enrolled
#
# =============================================================================

class CourseEnrollmentEngine
  def initialize
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Enrollment with fixed capacity (~15 min)
  # ---------------------------------------------------------------------------

  # Register a new course. Raise ArgumentError if course_id already exists
  # or if capacity is not a positive integer.
  def add_course(course_id, capacity:, prerequisites: [])
    raise NotImplementedError
  end

  # Enroll student_id in course_id. Returns:
  #   :enrolled   — a seat was available and the student now holds it
  #   :waitlisted — the course is full; the student joins the FIFO waitlist
  #                 (see Part 2 — leave this branch unimplemented until then)
  #
  # Raises:
  #   KeyError      — course_id is unknown
  #   ArgumentError — the student is already enrolled or already waitlisted
  #   ArgumentError — (Part 3) the student has not completed every
  #                   prerequisite for course_id
  #
  # Implement in stages: first get the :enrolled path and capacity tracking
  # working using courses that never exceed capacity in your Part 1 tests;
  # add the :waitlisted branch in Part 2; add the prerequisite check in Part 3.
  def enroll(course_id, student_id)
    raise NotImplementedError
  end

  # Remove student_id from course_id. If the student held an enrolled seat
  # and the waitlist is non-empty, the earliest-waitlisted student is
  # automatically promoted into the newly-open seat (Part 2 behavior — leave
  # unimplemented until then; a Part 1 implementation only needs to free the
  # seat).
  #
  # Raise KeyError if course_id is unknown. Raise ArgumentError if the
  # student is neither enrolled nor waitlisted in course_id.
  def drop(course_id, student_id)
    raise NotImplementedError
  end

  # Return true if student_id currently holds an enrolled seat in course_id.
  # Raise KeyError if course_id is unknown.
  def enrolled?(course_id, student_id)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Waitlist with auto-promotion (~15 min)
  # ---------------------------------------------------------------------------

  # Return the FIFO-ordered list of student_ids currently waitlisted for
  # course_id. Raise KeyError if course_id is unknown.
  #
  # Implementing this alongside enroll/drop's waitlist behavior above
  # completes Part 2.
  def waitlist(course_id)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Prerequisite enforcement (~15 min)
  # ---------------------------------------------------------------------------

  # Record that student_id has completed course_id (does not require the
  # student to have ever been enrolled in it via this engine).
  def mark_completed(student_id, course_id)
    raise NotImplementedError
  end

  # Return true if student_id has completed every prerequisite required by
  # course_id. Raise KeyError if course_id is unknown.
  #
  # `enroll` above should call this and raise ArgumentError before doing any
  # seat/waitlist work if it returns false — compose on top of this method
  # rather than duplicating the prerequisite check inline.
  def prerequisites_met?(course_id, student_id)
    raise NotImplementedError
  end
end
