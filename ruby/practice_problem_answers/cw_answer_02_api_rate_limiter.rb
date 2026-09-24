class TieredRateLimiter
  DEFAULT_PLANS = {
    "free"       => { rpm: 60,    rpd: 1_000 },
    "starter"    => { rpm: 300,   rpd: 25_000 },
    "pro"        => { rpm: 1_000, rpd: 200_000 },
    "enterprise" => { rpm: nil,   rpd: nil }
  }.freeze

  def initialize(plans = DEFAULT_PLANS)
    @plans = plans
    @keys = {}
  end

  def create_key(key_id, owner, plan)
    raise ArgumentError, "key already exists: #{key_id}" if @keys.key?(key_id)
    raise ArgumentError, "unknown plan: #{plan}" unless @plans.key?(plan)

    key = { id: key_id, owner: owner, plan: plan, enabled: true, request_log: [] }
    @keys[key_id] = key
    key
  end

  def revoke_key(key_id)
    key = @keys.fetch(key_id)
    key[:enabled] = false
    nil
  end

  def update_plan(key_id, new_plan)
    key = @keys.fetch(key_id)
    raise ArgumentError, "unknown plan: #{new_plan}" unless @plans.key?(new_plan)

    key[:plan] = new_plan
    nil
  end

  def count_in_window(request_log, now, window_seconds)
    request_log.count { |t| t > now - window_seconds && t <= now }
  end

  def allowed?(key_id, now)
    key = @keys[key_id]
    return false unless key
    return false unless key[:enabled]

    limits = @plans[key[:plan]]
    return false if limits[:rpm] && count_in_window(key[:request_log], now, 60) >= limits[:rpm]
    return false if limits[:rpd] && count_in_window(key[:request_log], now, 86_400) >= limits[:rpd]

    true
  end

  def record_request(key_id, now)
    key = @keys.fetch(key_id)
    key[:request_log] << now
    key[:request_log].select! { |t| t > now - 90_000 }
    nil
  end

  def handle_request(key_id, now)
    key = @keys[key_id]
    return { allowed: false, reason: :key_not_found } unless key
    return { allowed: false, reason: :key_disabled } unless key[:enabled]

    limits = @plans[key[:plan]]
    if limits[:rpm] && count_in_window(key[:request_log], now, 60) >= limits[:rpm]
      return { allowed: false, reason: :rpm_exceeded }
    end
    if limits[:rpd] && count_in_window(key[:request_log], now, 86_400) >= limits[:rpd]
      return { allowed: false, reason: :rpd_exceeded }
    end

    record_request(key_id, now)
    { allowed: true, key_id: key_id }
  end

  def usage(key_id, now)
    key = @keys.fetch(key_id)
    limits = @plans[key[:plan]]
    {
      key_id: key_id,
      plan: key[:plan],
      rpm_used: count_in_window(key[:request_log], now, 60),
      rpm_limit: limits[:rpm],
      rpd_used: count_in_window(key[:request_log], now, 86_400),
      rpd_limit: limits[:rpd]
    }
  end
end
