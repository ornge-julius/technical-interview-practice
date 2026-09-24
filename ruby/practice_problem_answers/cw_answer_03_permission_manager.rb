require "set"

class PermissionManager
  def initialize
    @roles = {}       # role_id => { permissions: Set, parent: role_id|nil }
    @user_roles = {}   # user_id => Set of role_ids
  end

  def create_role(role_id, permissions = [])
    raise ArgumentError, "role already exists: #{role_id}" if @roles.key?(role_id)

    @roles[role_id] = { permissions: Set.new(permissions), parent: nil }
    nil
  end

  def grant_permission(role_id, permission)
    role = @roles.fetch(role_id)
    role[:permissions] << permission
    nil
  end

  def revoke_permission(role_id, permission)
    role = @roles.fetch(role_id)
    role[:permissions].delete(permission)
    nil
  end

  def assign_role(user_id, role_id)
    raise KeyError, "role not found: #{role_id}" unless @roles.key?(role_id)

    (@user_roles[user_id] ||= Set.new) << role_id
    nil
  end

  def unassign_role(user_id, role_id)
    raise KeyError, "role not found: #{role_id}" unless @roles.key?(role_id)

    user_roles = @user_roles[user_id]
    raise KeyError, "user #{user_id} does not have role #{role_id}" unless user_roles&.include?(role_id)

    user_roles.delete(role_id)
    nil
  end

  def has_permission?(user_id, permission)
    all_permissions(user_id).include?(permission)
  end

  def all_permissions(user_id)
    role_ids = @user_roles[user_id]
    return Set.new unless role_ids

    role_ids.each_with_object(Set.new) { |role_id, acc| acc.merge(role_permissions(role_id)) }
  end

  def role_permissions(role_id)
    role = @roles.fetch(role_id)
    perms = role[:permissions].dup
    perms.merge(role_permissions(role[:parent])) if role[:parent]
    perms
  end

  def set_parent_role(role_id, parent_role_id)
    raise KeyError, "role not found: #{role_id}" unless @roles.key?(role_id)
    raise KeyError, "role not found: #{parent_role_id}" unless @roles.key?(parent_role_id)

    @roles[role_id][:parent] = parent_role_id
    nil
  end

  def has_scoped_permission?(user_id, resource, action)
    all_permissions(user_id).any? do |perm|
      next false unless perm.include?(":")

      perm_resource, perm_action = perm.split(":", 2)
      (perm_resource == "*" || perm_resource == resource) &&
        (perm_action == "*" || perm_action == action)
    end
  end
end
