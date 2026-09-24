module GeofenceAlertEngine
  def self.make_tracker
    { zones: {}, assets: {}, alert_rules: [], alert_log: [] }
  end

  def self.in_zone?(asset, zone)
    return false if asset[:lat].nil? || asset[:lng].nil?

    bounds = zone[:bounds]
    asset[:lat].between?(bounds[:min_lat], bounds[:max_lat]) &&
      asset[:lng].between?(bounds[:min_lng], bounds[:max_lng])
  end

  def self.current_zone_id(tracker, asset_id)
    asset = tracker[:assets][asset_id]
    return nil unless asset

    zone = tracker[:zones].values.find { |z| in_zone?(asset, z) }
    zone && zone[:id]
  end

  def self.process_location_update(tracker, asset_id, lat, lng, timestamp)
    asset = tracker[:assets].fetch(asset_id)

    old_zone_id = asset[:zone_id]
    asset[:lat] = lat
    asset[:lng] = lng
    new_zone_id = current_zone_id(tracker, asset_id)
    asset[:zone_id] = new_zone_id

    return [] if old_zone_id == new_zone_id

    triggered = []
    tracker[:alert_rules].each do |rule|
      next unless (rule[:asset_id].nil? || rule[:asset_id] == asset_id) &&
                   (rule[:from_zone_id].nil? || rule[:from_zone_id] == old_zone_id) &&
                   (rule[:to_zone_id].nil? || rule[:to_zone_id] == new_zone_id)

      alert = {
        rule_id: rule[:id],
        asset_id: asset_id,
        from_zone_id: old_zone_id,
        to_zone_id: new_zone_id,
        timestamp: timestamp
      }
      triggered << alert
      tracker[:alert_log] << alert
    end
    triggered
  end

  def self.add_zone(tracker, zone_id, name, min_lat, max_lat, min_lng, max_lng)
    raise ArgumentError, "zone_id already exists: #{zone_id}" if tracker[:zones].key?(zone_id)

    zone = {
      id: zone_id,
      name: name,
      bounds: { min_lat: min_lat, max_lat: max_lat, min_lng: min_lng, max_lng: max_lng }
    }
    tracker[:zones][zone_id] = zone
    zone
  end

  def self.remove_zone(tracker, zone_id)
    raise KeyError, "zone not found: #{zone_id}" unless tracker[:zones].key?(zone_id)

    tracker[:assets].each_value do |asset|
      asset[:zone_id] = nil if asset[:zone_id] == zone_id
    end
    tracker[:zones].delete(zone_id)
    nil
  end

  def self.add_asset(tracker, asset_id, name)
    raise ArgumentError, "asset_id already exists: #{asset_id}" if tracker[:assets].key?(asset_id)

    asset = { id: asset_id, name: name, lat: nil, lng: nil, zone_id: nil }
    tracker[:assets][asset_id] = asset
    asset
  end

  def self.add_alert_rule(tracker, rule_id, from_zone_id, to_zone_id, asset_id)
    if tracker[:alert_rules].any? { |r| r[:id] == rule_id }
      raise ArgumentError, "rule_id already exists: #{rule_id}"
    end

    rule = { id: rule_id, from_zone_id: from_zone_id, to_zone_id: to_zone_id, asset_id: asset_id }
    tracker[:alert_rules] << rule
    rule
  end
end
