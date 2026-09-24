class BuildJobScheduler
  def initialize
    @jobs = {}
    @sequence = 0
  end

  # PART 1

  def enqueue_job(job_id, priority: 0)
    raise ArgumentError, "job #{job_id} already exists" if @jobs.key?(job_id)

    @sequence += 1
    @jobs[job_id] = {
      priority: priority,
      status: :queued,
      dependencies: [],
      sequence: @sequence,
    }
  end

  def status(job_id)
    fetch_job(job_id)[:status]
  end

  def start_job(job_id)
    job = fetch_job(job_id)
    raise ArgumentError, "job #{job_id} is not queued" unless job[:status] == :queued

    job[:status] = :running
  end

  def complete_job(job_id)
    job = fetch_job(job_id)
    raise ArgumentError, "job #{job_id} is not running" unless job[:status] == :running

    job[:status] = :complete
  end

  def next_job
    queued = @jobs.select { |_, job| job[:status] == :queued }
    return nil if queued.empty?

    queued.min_by { |_, job| job[:sequence] }.first
  end

  # PART 2

  def add_dependency(job_id, depends_on_job_id)
    job = fetch_job(job_id)
    fetch_job(depends_on_job_id)
    job[:dependencies] << depends_on_job_id
  end

  def ready?(job_id)
    job = fetch_job(job_id)
    return false unless job[:status] == :queued

    job[:dependencies].all? { |dep_id| status(dep_id) == :complete }
  end

  # PART 3

  def next_runnable_job
    ready_ids = @jobs.keys.select { |job_id| ready?(job_id) }
    return nil if ready_ids.empty?

    ready_ids.min_by { |job_id| [-@jobs[job_id][:priority], @jobs[job_id][:sequence]] }
  end

  private

  def fetch_job(job_id)
    @jobs.fetch(job_id) { raise KeyError, "job #{job_id} not found" }
  end
end
