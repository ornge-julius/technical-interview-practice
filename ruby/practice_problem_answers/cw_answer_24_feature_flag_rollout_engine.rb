require "digest"

class FeatureFlagEngine
  ALLOWED_TRANSITIONS = {
    draft: [:ramping],
    ramping: [:full, :archived],
    full: [:archived],
    archived: [],
  }.freeze

  def initialize
    @flags = {}
  end

  # PART 1

  def create_flag(flag_id, stage: :draft, allow_list: [], percentage: 0)
    raise ArgumentError, "flag #{flag_id} already exists" if @flags.key?(flag_id)
    raise ArgumentError, "percentage must be an Integer in 0..100" unless valid_percentage?(percentage)

    @flags[flag_id] = {
      stage: stage,
      allow_list: allow_list.dup,
      percentage: percentage,
      killed: false,
      audit_log: [],
    }
  end

  def enabled?(flag_id, user_id)
    flag = fetch_flag(flag_id)
    return false if flag[:killed]
    return false if [:draft, :archived].include?(flag[:stage])
    return true if flag[:allow_list].include?(user_id)
    return true if flag[:stage] == :full

    bucket_for(flag_id, user_id) < flag[:percentage]
  end

  def bucket_for(flag_id, user_id)
    Digest::MD5.hexdigest("#{flag_id}:#{user_id}").to_i(16) % 100
  end

  # PART 2

  def transition!(flag_id, to_stage, at:)
    flag = fetch_flag(flag_id)
    from_stage = flag[:stage]
    unless ALLOWED_TRANSITIONS.fetch(from_stage, []).include?(to_stage)
      raise ArgumentError, "cannot transition #{flag_id} from #{from_stage} to #{to_stage}"
    end

    flag[:stage] = to_stage
    flag[:audit_log] << { event: :transition, from: from_stage, to: to_stage, at: at }
  end

  def set_percentage(flag_id, percentage, at:)
    flag = fetch_flag(flag_id)
    raise ArgumentError, "flag #{flag_id} is not :ramping" unless flag[:stage] == :ramping
    raise ArgumentError, "percentage must be an Integer in 0..100" unless valid_percentage?(percentage)

    previous = flag[:percentage]
    flag[:percentage] = percentage
    flag[:audit_log] << { event: :percentage_change, from: previous, to: percentage, at: at }
  end

  # PART 3

  def kill_switch!(flag_id, at:)
    flag = fetch_flag(flag_id)
    flag[:killed] = true
    flag[:audit_log] << { event: :kill_switch, at: at }
  end

  def audit_log(flag_id)
    fetch_flag(flag_id)[:audit_log].dup
  end

  private

  def fetch_flag(flag_id)
    @flags.fetch(flag_id) { raise KeyError, "flag #{flag_id} not found" }
  end

  def valid_percentage?(percentage)
    percentage.is_a?(Integer) && percentage.between?(0, 100)
  end
end
