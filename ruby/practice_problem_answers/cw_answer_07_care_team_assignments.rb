class CareTeamAssignmentManager
  class CapacityError < StandardError; end

  Assignment = Struct.new(:member_id, :role, :assigned_at, :unassigned_at)

  def initialize
    @members = {}  # member_id => { role:, max_patients: }
    @history = {}  # patient_id => [Assignment, ...] (all roles, chronological)
  end

  def add_member(member_id, role, max_patients)
    @members[member_id] = { role: role, max_patients: max_patients }
  end

  def assign(patient_id, member_id, assigned_at)
    member = member_or_raise(member_id)
    role = member[:role]
    entries = (@history[patient_id] ||= [])
    current_entry = active_entry_for_role(entries, role)

    return if current_entry && current_entry.member_id == member_id

    if current_entry.nil? || current_entry.member_id != member_id
      if get_patients(member_id).size >= member[:max_patients]
        raise CapacityError, "#{member_id} is at capacity"
      end
    end

    current_entry.unassigned_at = assigned_at if current_entry
    entries << Assignment.new(member_id, role, assigned_at, nil)
  end

  def get_assignment(patient_id, role)
    entries = @history[patient_id] || []
    active_entry_for_role(entries, role)&.member_id
  end

  def get_patients(member_id)
    member_or_raise(member_id)
    @history.select { |_, entries| entries.any? { |e| e.member_id == member_id && e.unassigned_at.nil? } }
            .keys
            .sort
  end

  def available_members(role)
    @members.select { |_, m| m[:role] == role }
            .keys
            .select { |member_id| get_patients(member_id).size < @members[member_id][:max_patients] }
            .sort
  end

  def get_history(patient_id, role)
    entries = @history[patient_id] || []
    entries.select { |e| e.role == role }
           .sort_by(&:assigned_at)
           .map { |e| [e.member_id, e.assigned_at, e.unassigned_at] }
  end

  def get_assignment_at(patient_id, role, timestamp)
    entry = get_history(patient_id, role).find do |_member_id, assigned_at, unassigned_at|
      assigned_at <= timestamp && (unassigned_at.nil? || timestamp < unassigned_at)
    end
    entry&.first
  end

  private

  def member_or_raise(member_id)
    @members[member_id] or raise ArgumentError, "unknown member: #{member_id}"
  end

  def active_entry_for_role(entries, role)
    entries.find { |e| e.role == role && e.unassigned_at.nil? }
  end
end
