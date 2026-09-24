# =============================================================================
# INTERVIEW PROBLEM 21: Build Job Scheduler
# Difficulty: Senior Software Engineer | Estimated time: 45 min
# =============================================================================
#
# CONTEXT
# -------
# You're building the core scheduling engine for a CI/build system. Build jobs
# are enqueued, may depend on other jobs finishing first, and carry a priority
# used to decide what runs next once multiple jobs are eligible.
#
# You choose the internal data structures — the public interface below is
# what matters. Store all state in instance variables set in `initialize`.
# Class variables (`@@foo`), class-level instance variables, and mutable
# class-body constants will bleed between examples and between instances —
# avoid them.
#
# DATA MODEL
# ----------
# A job has:
#   - a unique job_id (String)
#   - a priority (Integer, higher runs first, default 0)
#   - a status: :queued, :running, or :complete
#   - zero or more dependency job_ids that must reach :complete before this
#     job is eligible to run
#
# Example
#   scheduler = BuildJobScheduler.new
#   scheduler.enqueue_job("lint")
#   scheduler.enqueue_job("build", priority: 5)
#   scheduler.next_job                          # -> "lint" (FIFO, enqueued first)
#   scheduler.add_dependency("deploy", "build")
#   scheduler.enqueue_job("deploy")
#   scheduler.next_runnable_job                 # -> "build" (priority 5, deploy not ready)
#   scheduler.start_job("build")
#   scheduler.complete_job("build")
#   scheduler.next_runnable_job                 # -> "deploy" (dependency now complete)
#
# =============================================================================

class BuildJobScheduler
  def initialize
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Basic FIFO queue (~15 min)
  # ---------------------------------------------------------------------------

  # Enqueue a new job with the given priority (default 0).
  # Raise ArgumentError if job_id already exists.
  def enqueue_job(job_id, priority: 0)
    raise NotImplementedError
  end

  # Return :queued, :running, or :complete.
  # Raise KeyError if job_id is not found.
  def status(job_id)
    raise NotImplementedError
  end

  # Transition a job from :queued to :running.
  # Raise KeyError if job_id is not found.
  # Raise ArgumentError if the job is not currently :queued.
  def start_job(job_id)
    raise NotImplementedError
  end

  # Transition a job from :running to :complete.
  # Raise KeyError if job_id is not found.
  # Raise ArgumentError if the job is not currently :running.
  def complete_job(job_id)
    raise NotImplementedError
  end

  # Return the job_id of the earliest-enqueued job still :queued, ignoring
  # dependencies and priority entirely (a naive FIFO peek). Return nil if no
  # job is :queued.
  def next_job
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Dependencies (~15 min)
  # ---------------------------------------------------------------------------

  # Declare that job_id cannot run until depends_on_job_id is :complete.
  # Raise KeyError if either job_id is not found.
  def add_dependency(job_id, depends_on_job_id)
    raise NotImplementedError
  end

  # Return true if job_id is :queued AND every one of its dependencies is
  # :complete. Return false otherwise.
  # Raise KeyError if job_id is not found.
  def ready?(job_id)
    raise NotImplementedError
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Priority-ordered selection (~15 min)
  # ---------------------------------------------------------------------------

  # Among all jobs for which ready?(job_id) is true, return the job_id with
  # the highest priority. Break ties by earliest enqueue order (FIFO).
  # Return nil if no job is ready.
  #
  # This should compose on top of ready? from Part 2 rather than
  # re-implementing dependency checks.
  def next_runnable_job
    raise NotImplementedError
  end
end
