require "date"

class ContractAlertScheduler
  def initialize
    @contracts = {}
    @alert_configs = {}
    @sent = {}
  end

  def add_contract(contract_id, title, owner_email, expires_on:)
    raise ArgumentError, "contract #{contract_id} already exists" if @contracts.key?(contract_id)

    contract = { contract_id: contract_id, title: title, owner_email: owner_email, expires_on: expires_on }
    @contracts[contract_id] = contract
    contract
  end

  def add_alert_config(config_id, days_before:, label:)
    raise ArgumentError, "config #{config_id} already exists" if @alert_configs.key?(config_id)

    config = { config_id: config_id, days_before: days_before, label: label }
    @alert_configs[config_id] = config
    config
  end

  def get_contracts_expiring_between(start_date, end_date)
    @contracts.values
              .select { |c| c[:expires_on] >= start_date && c[:expires_on] <= end_date }
              .sort_by { |c| c[:expires_on] }
  end

  def compute_alert_schedule(contract_id)
    raise KeyError, contract_id unless @contracts.key?(contract_id)

    contract = @contracts[contract_id]
    expires_on = Date.parse(contract[:expires_on])

    @alert_configs.values.map { |cfg|
      {
        config_id: cfg[:config_id],
        label: cfg[:label],
        alert_on: (expires_on - cfg[:days_before]).iso8601,
      }
    }.sort_by { |e| e[:alert_on] }
  end

  def get_due_alerts(as_of_date)
    entries = @contracts.keys.flat_map do |contract_id|
      contract = @contracts[contract_id]
      compute_alert_schedule(contract_id)
        .select { |e| e[:alert_on] <= as_of_date }
        .map { |e|
          {
            contract_id: contract_id,
            config_id: e[:config_id],
            label: e[:label],
            alert_on: e[:alert_on],
            owner_email: contract[:owner_email],
            expires_on: contract[:expires_on],
          }
        }
    end

    entries.sort_by { |e| [e[:alert_on], e[:contract_id]] }
  end

  def record_alert_sent(contract_id, config_id, sent_on:)
    raise KeyError, contract_id unless @contracts.key?(contract_id)
    raise KeyError, config_id unless @alert_configs.key?(config_id)

    record = { contract_id: contract_id, config_id: config_id, sent_on: sent_on }
    @sent[[contract_id, config_id]] = record
    record
  end

  def get_upcoming_alerts(contract_id, as_of_date)
    compute_alert_schedule(contract_id)
      .select { |e| e[:alert_on] >= as_of_date }
      .map { |e|
        {
          config_id: e[:config_id],
          label: e[:label],
          alert_on: e[:alert_on],
          sent: @sent.key?([contract_id, e[:config_id]]),
        }
      }
      .sort_by { |e| e[:alert_on] }
  end
end
