# Defined at file scope, not nested inside the class, so the spec harness's
# per-example state-reset hook (which walks constants(false) on any loaded
# class) never touches these lookup tables.
DISPATCH_TRIAGE_SLA_DEADLINES = { critical: 60, high: 300, medium: 900, low: 3600 }.freeze
DISPATCH_TRIAGE_TIER_ORDER = [:critical, :high, :medium, :low].freeze

class DispatchTriageQueue
  def initialize
    @calls = {}
  end

  # PART 1

  def intake_call(call_id, severity:, at:)
    raise ArgumentError, "call #{call_id} already exists" if @calls.key?(call_id)
    raise ArgumentError, "unknown severity #{severity}" unless DISPATCH_TRIAGE_SLA_DEADLINES.key?(severity)

    @calls[call_id] = {
      severity: severity,
      intake_time: at,
      status: :waiting,
      dispatch_time: nil,
      completion_time: nil,
      responder_id: nil,
    }
  end

  def status(call_id)
    fetch_call(call_id)[:status]
  end

  def severity(call_id)
    fetch_call(call_id)[:severity]
  end

  # PART 2

  def next_to_dispatch(at:)
    waiting_ids = @calls.select { |_, call| call[:status] == :waiting }.keys
    return nil if waiting_ids.empty?

    waiting_ids.min_by { |call_id| [effective_tier_index(call_id, at), @calls[call_id][:intake_time]] }
  end

  # PART 3

  def dispatch_call(call_id, responder_id:, at:)
    call = fetch_call(call_id)
    raise ArgumentError, "call #{call_id} is not waiting" unless call[:status] == :waiting

    call[:status] = :dispatched
    call[:dispatch_time] = at
    call[:responder_id] = responder_id
  end

  def complete_call(call_id, at:)
    call = fetch_call(call_id)
    raise ArgumentError, "call #{call_id} is not dispatched" unless call[:status] == :dispatched

    call[:status] = :completed
    call[:completion_time] = at
  end

  def sla_breach_stats
    dispatched = @calls.values.select { |call| !call[:dispatch_time].nil? }
    total = dispatched.size
    breached = dispatched.count do |call|
      call[:dispatch_time] > call[:intake_time] + DISPATCH_TRIAGE_SLA_DEADLINES[call[:severity]]
    end
    breach_rate = total.zero? ? 0.0 : breached.to_f / total
    { total: total, breached: breached, breach_rate: breach_rate }
  end

  private

  def fetch_call(call_id)
    @calls.fetch(call_id) { raise KeyError, "call #{call_id} not found" }
  end

  def effective_tier_index(call_id, at)
    call = @calls[call_id]
    base_index = DISPATCH_TRIAGE_TIER_ORDER.index(call[:severity])
    waited = at - call[:intake_time]
    breached = waited > DISPATCH_TRIAGE_SLA_DEADLINES[call[:severity]]
    breached ? [base_index - 1, 0].max : base_index
  end
end
