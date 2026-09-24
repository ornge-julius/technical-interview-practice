require "time"

class ContractLifecycleManager
  VALID_TRANSITIONS = {
    "draft" => ["in_review"],
    "in_review" => ["approved", "draft"],
    "approved" => ["executed"],
    "executed" => ["active"],
    "active" => ["expiring_soon", "terminated"],
    "expiring_soon" => ["expired", "active", "terminated"],
    "expired" => [],
    "terminated" => [],
  }.freeze

  TERMINAL_STATES = %w[expired terminated].freeze

  def initialize
    @contracts = {}
    @audit = {}
  end

  def create_contract(contract_id, title, created_at:, actor:)
    raise ArgumentError, "contract #{contract_id} already exists" if @contracts.key?(contract_id)

    contract = { contract_id: contract_id, title: title, state: "draft", created_at: created_at, fields: {} }
    @contracts[contract_id] = contract
    @audit[contract_id] = [
      { contract_id: contract_id, from_state: nil, to_state: "draft", at: created_at, actor: actor },
    ]
    contract
  end

  def set_field(contract_id, key, value)
    raise KeyError, contract_id unless @contracts.key?(contract_id)

    @contracts[contract_id][:fields][key] = value
    @contracts[contract_id]
  end

  def get_contract(contract_id)
    raise KeyError, contract_id unless @contracts.key?(contract_id)

    @contracts[contract_id]
  end

  def transition(contract_id, to_state, at:, actor:)
    contract = get_contract(contract_id)
    current = contract[:state]
    unless VALID_TRANSITIONS.fetch(current, []).include?(to_state)
      raise ArgumentError, "cannot transition from #{current} to #{to_state}"
    end

    contract[:state] = to_state
    @audit[contract_id] << { contract_id: contract_id, from_state: current, to_state: to_state, at: at, actor: actor }
    contract
  end

  def get_audit_trail(contract_id)
    raise KeyError, contract_id unless @contracts.key?(contract_id)

    @audit[contract_id]
  end

  def get_contracts_by_state(state)
    @contracts.values.select { |c| c[:state] == state }.sort_by { |c| c[:contract_id] }
  end

  def bulk_advance(contract_ids, to_state, at:, actor:)
    succeeded = []
    failed = []

    contract_ids.each do |contract_id|
      begin
        transition(contract_id, to_state, at: at, actor: actor)
        succeeded << contract_id
      rescue KeyError, ArgumentError => e
        failed << { contract_id: contract_id, reason: e.message }
      end
    end

    { succeeded: succeeded, failed: failed }
  end

  def get_lifecycle_metrics
    by_state = @contracts.values.group_by { |c| c[:state] }.transform_values(&:size)
    terminal_count = TERMINAL_STATES.sum { |s| by_state.fetch(s, 0) }

    { total: @contracts.size, by_state: by_state, terminal_count: terminal_count }
  end

  def get_overdue_contracts(as_of:)
    as_of_time = Time.parse(as_of)

    results = @contracts.values.filter_map do |contract|
      next if TERMINAL_STATES.include?(contract[:state])

      stuck_since = get_audit_trail(contract[:contract_id]).last[:at]
      days_stuck = ((as_of_time - Time.parse(stuck_since)) / 86_400).to_i
      next unless days_stuck > 30

      {
        contract_id: contract[:contract_id],
        title: contract[:title],
        state: contract[:state],
        stuck_since: stuck_since,
        days_stuck: days_stuck,
      }
    end

    results.sort_by { |r| -r[:days_stuck] }
  end
end
