class ContractAmendmentManager
  def initialize
    @contracts = {}
    @amendments_by_contract = {}
    @amendment_ids = {}
  end

  def add_contract(contract_id, title, fields:)
    raise ArgumentError, "contract #{contract_id} already exists" if @contracts.key?(contract_id)

    contract = { contract_id: contract_id, title: title, fields: fields.dup }
    @contracts[contract_id] = contract
    @amendments_by_contract[contract_id] = []
    contract
  end

  def get_base_contract(contract_id)
    raise KeyError, contract_id unless @contracts.key?(contract_id)

    @contracts[contract_id]
  end

  def add_amendment(amendment_id, contract_id, effective_on:, overrides:, note:)
    raise ArgumentError, "amendment #{amendment_id} already exists" if @amendment_ids.key?(amendment_id)
    raise KeyError, contract_id unless @contracts.key?(contract_id)

    amendment = {
      amendment_id: amendment_id,
      contract_id: contract_id,
      effective_on: effective_on,
      overrides: overrides.dup,
      note: note,
    }
    @amendment_ids[amendment_id] = amendment
    @amendments_by_contract[contract_id] << amendment
    amendment
  end

  def get_amendments(contract_id)
    raise KeyError, contract_id unless @contracts.key?(contract_id)

    @amendments_by_contract[contract_id].sort_by { |a| [a[:effective_on], a[:amendment_id]] }
  end

  def get_effective_contract(contract_id, as_of_date:)
    fields = get_base_contract(contract_id)[:fields].dup

    get_amendments(contract_id).each do |amendment|
      next if amendment[:effective_on] > as_of_date

      fields.merge!(amendment[:overrides])
    end

    fields
  end

  def get_value_history(contract_id, field)
    base = get_base_contract(contract_id)
    touched = get_amendments(contract_id).select { |a| a[:overrides].key?(field) }

    unless base[:fields].key?(field) || touched.any?
      raise KeyError, field
    end

    history = []
    history << { effective_on: "base", value: base[:fields][field], source: "base" } if base[:fields].key?(field)
    touched.each do |a|
      history << { effective_on: a[:effective_on], value: a[:overrides][field], source: a[:amendment_id] }
    end
    history
  end

  def get_amendment_summary(contract_id)
    amendments = get_amendments(contract_id)
    fields_amended = amendments.flat_map { |a| a[:overrides].keys }.uniq.sort_by(&:to_s)
    latest_amendment = amendments.empty? ? nil : amendments.max_by { |a| a[:effective_on] }[:effective_on]
    as_of = latest_amendment || "2099-12-31"

    {
      contract_id: contract_id,
      amendment_count: amendments.length,
      fields_amended: fields_amended,
      latest_amendment: latest_amendment,
      current_fields: get_effective_contract(contract_id, as_of_date: as_of),
    }
  end
end
