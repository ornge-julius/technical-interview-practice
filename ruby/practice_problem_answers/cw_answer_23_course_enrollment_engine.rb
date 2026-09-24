class CourseEnrollmentEngine
  def initialize
    @courses = {}
    @completed = Hash.new { |h, k| h[k] = [] } # student_id => [course_id, ...]
  end

  # PART 1

  def add_course(course_id, capacity:, prerequisites: [])
    raise ArgumentError, "course #{course_id} already exists" if @courses.key?(course_id)
    raise ArgumentError, "capacity must be a positive integer" unless capacity.is_a?(Integer) && capacity > 0

    @courses[course_id] = {
      capacity: capacity,
      prerequisites: prerequisites,
      enrolled: [],
      waitlist: [],
    }
  end

  def enroll(course_id, student_id)
    course = fetch_course(course_id)
    raise ArgumentError, "#{student_id} is already enrolled in #{course_id}" if course[:enrolled].include?(student_id)
    raise ArgumentError, "#{student_id} is already waitlisted for #{course_id}" if course[:waitlist].include?(student_id)
    unless prerequisites_met?(course_id, student_id)
      raise ArgumentError, "#{student_id} has not completed the prerequisites for #{course_id}"
    end

    if course[:enrolled].size < course[:capacity]
      course[:enrolled] << student_id
      :enrolled
    else
      course[:waitlist] << student_id
      :waitlisted
    end
  end

  def drop(course_id, student_id)
    course = fetch_course(course_id)

    if course[:enrolled].delete(student_id)
      promoted = course[:waitlist].shift
      course[:enrolled] << promoted if promoted
    elsif course[:waitlist].delete(student_id)
      # no promotion needed — the student was never holding a seat
    else
      raise ArgumentError, "#{student_id} is neither enrolled nor waitlisted in #{course_id}"
    end
  end

  def enrolled?(course_id, student_id)
    fetch_course(course_id)[:enrolled].include?(student_id)
  end

  # PART 2

  def waitlist(course_id)
    fetch_course(course_id)[:waitlist].dup
  end

  # PART 3

  def mark_completed(student_id, course_id)
    @completed[student_id] << course_id unless @completed[student_id].include?(course_id)
  end

  def prerequisites_met?(course_id, student_id)
    course = fetch_course(course_id)
    course[:prerequisites].all? { |prereq| @completed[student_id].include?(prereq) }
  end

  private

  def fetch_course(course_id)
    @courses.fetch(course_id) { raise KeyError, "course #{course_id} not found" }
  end
end
