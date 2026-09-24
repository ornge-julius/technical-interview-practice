require "time"

class DispatchManager
  def initialize
    @responders = {}
    @incidents = {}
  end

  def register_responder(responder_id, name, subscribed_types, capacity)
    raise ArgumentError, "duplicate responder_id: #{responder_id}" if @responders.key?(responder_id)

    responder = {
      responder_id: responder_id,
      name: name,
      subscribed_types: subscribed_types,
      capacity: capacity
    }
    @responders[responder_id] = responder
    responder
  end

  def add_incident(incident_id, incident_type, severity, ts)
    raise ArgumentError, "duplicate incident_id: #{incident_id}" if @incidents.key?(incident_id)

    incident = {
      incident_id: incident_id,
      incident_type: incident_type,
      severity: severity,
      ts: ts,
      responder_id: nil,
      resolved: false
    }
    @incidents[incident_id] = incident
    incident
  end

  def get_incidents_for_responder(responder_id)
    responder = responder_or_raise(responder_id)
    matching = @incidents.values.select { |i| responder[:subscribed_types].include?(i[:incident_type]) }
    sort_incidents(matching)
  end

  def assign_incident(incident_id, responder_id)
    incident = incident_or_raise(incident_id)
    responder = responder_or_raise(responder_id)
    raise ArgumentError, "incident already assigned: #{incident_id}" if incident[:responder_id]

    if open_assignment_count(responder_id) >= responder[:capacity]
      raise ArgumentError, "responder at capacity: #{responder_id}"
    end

    incident[:responder_id] = responder_id
  end

  def resolve_incident(incident_id)
    incident = incident_or_raise(incident_id)
    raise ArgumentError, "incident already resolved: #{incident_id}" if incident[:resolved]

    incident[:resolved] = true
  end

  def get_open_assignments(responder_id)
    responder_or_raise(responder_id)
    open = @incidents.values.select { |i| i[:responder_id] == responder_id && !i[:resolved] }
    sort_incidents(open)
  end

  def auto_assign(incident_id)
    incident = incident_or_raise(incident_id)
    raise ArgumentError, "incident already assigned: #{incident_id}" if incident[:responder_id]

    eligible = @responders.values.select do |responder|
      responder[:subscribed_types].include?(incident[:incident_type]) &&
        open_assignment_count(responder[:responder_id]) < responder[:capacity]
    end
    raise ArgumentError, "no eligible responder for incident: #{incident_id}" if eligible.empty?

    chosen = eligible.min_by do |responder|
      [open_assignment_count(responder[:responder_id]), -responder[:capacity], responder[:responder_id]]
    end

    assign_incident(incident_id, chosen[:responder_id])
    chosen[:responder_id]
  end

  def get_dispatch_summary
    @responders.values.sort_by { |r| r[:responder_id] }.map do |responder|
      open_count = open_assignment_count(responder[:responder_id])
      {
        responder_id: responder[:responder_id],
        name: responder[:name],
        capacity: responder[:capacity],
        open_count: open_count,
        available_capacity: responder[:capacity] - open_count
      }
    end
  end

  private

  def responder_or_raise(responder_id)
    @responders[responder_id] or raise KeyError, "unknown responder: #{responder_id}"
  end

  def incident_or_raise(incident_id)
    @incidents[incident_id] or raise KeyError, "unknown incident: #{incident_id}"
  end

  def open_assignment_count(responder_id)
    @incidents.values.count { |i| i[:responder_id] == responder_id && !i[:resolved] }
  end

  def sort_incidents(incidents)
    incidents.sort_by { |i| [-i[:severity], Time.parse(i[:ts])] }
  end
end
