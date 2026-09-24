require "time"
require "set"

class CoverageTracker
  def initialize
    @stations = {}
    @heartbeats = {}
    @outages = {}
  end

  def register_station(station_id, name, region:)
    raise ArgumentError, "station #{station_id} already exists" if @stations.key?(station_id)

    station = { station_id: station_id, name: name, region: region }
    @stations[station_id] = station
    @heartbeats[station_id] = nil
    @outages[station_id] = []
    station
  end

  def record_heartbeat(station_id, ts)
    raise KeyError, station_id unless @stations.key?(station_id)

    last = @heartbeats[station_id]
    raise ArgumentError, "out-of-order heartbeat" if last && ts <= last

    @heartbeats[station_id] = ts
  end

  def get_last_heartbeat(station_id)
    raise KeyError, station_id unless @stations.key?(station_id)

    @heartbeats[station_id]
  end

  def get_stations(region: nil)
    stations = @stations.values
    stations = stations.select { |s| s[:region] == region } if region
    stations.sort_by { |s| s[:station_id] }
  end

  def get_stale_stations(as_of_ts, stale_after_secs:)
    as_of = Time.parse(as_of_ts)
    get_stations.select do |s|
      last = @heartbeats[s[:station_id]]
      last.nil? || (as_of - Time.parse(last)) > stale_after_secs
    end
  end

  def record_outage_start(station_id, ts)
    raise KeyError, station_id unless @stations.key?(station_id)

    if @outages[station_id].any? { |o| o[:end_ts].nil? }
      raise ArgumentError, "station #{station_id} already has an open outage"
    end

    @outages[station_id] << { station_id: station_id, start_ts: ts, end_ts: nil }
  end

  def record_outage_end(station_id, ts)
    raise KeyError, station_id unless @stations.key?(station_id)

    open_outage = @outages[station_id].find { |o| o[:end_ts].nil? }
    raise ArgumentError, "station #{station_id} has no open outage" unless open_outage

    open_outage[:end_ts] = ts
  end

  def get_outages(station_id)
    raise KeyError, station_id unless @stations.key?(station_id)

    @outages[station_id].sort_by { |o| o[:start_ts] }
  end

  def get_region_coverage(region, as_of_ts, stale_after_secs:)
    stations = get_stations(region: region)
    stale_ids = get_stale_stations(as_of_ts, stale_after_secs: stale_after_secs).map { |s| s[:station_id] }.to_set
    stale_count = stations.count { |s| stale_ids.include?(s[:station_id]) }
    healthy = stations.length - stale_count

    {
      region: region,
      total: stations.length,
      healthy: healthy,
      stale: stale_count,
      has_coverage: healthy >= 1,
    }
  end

  def get_outage_summary(station_id, as_of_ts)
    outages = get_outages(station_id)
    as_of = Time.parse(as_of_ts)
    open_outage = outages.find { |o| o[:end_ts].nil? }

    total_secs = outages.sum do |o|
      finish = o[:end_ts].nil? ? as_of : Time.parse(o[:end_ts])
      (finish - Time.parse(o[:start_ts])).round
    end

    {
      station_id: station_id,
      total_outages: outages.length,
      open_outage: !open_outage.nil?,
      total_outage_secs: total_secs,
    }
  end
end
