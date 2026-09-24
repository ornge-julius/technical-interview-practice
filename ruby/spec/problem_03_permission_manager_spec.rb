require_relative "../practice_problems/problem_03_permission_manager"

RSpec.describe PermissionManager do
  let(:fresh_pm) { PermissionManager.new }
  let(:pm) do
    p = PermissionManager.new
    p.create_role("viewer", ["posts:read", "comments:read"])
    p.create_role("editor", ["posts:read", "posts:write", "comments:read", "comments:write"])
    p.create_role("admin", ["posts:read", "posts:write", "posts:delete", "users:read", "users:write", "billing:read"])
    p
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Flat RBAC
  # ---------------------------------------------------------------------------
  describe "#create_role" do
    it "creates a role with the given permissions" do
      fresh_pm.create_role("role_creates", ["reports:read"])
      expect(fresh_pm.role_permissions("role_creates")).to eq(Set.new(["reports:read"]))
    end

    it "defaults to an empty permission set" do
      fresh_pm.create_role("role_empty")
      expect(fresh_pm.role_permissions("role_empty")).to eq(Set.new)
    end

    it "raises ArgumentError on a duplicate role" do
      fresh_pm.create_role("role_dup")
      expect { fresh_pm.create_role("role_dup") }.to raise_error(ArgumentError)
    end
  end

  describe "#grant_permission / #revoke_permission" do
    it "grant adds a permission" do
      pm.grant_permission("viewer", "posts:write")
      expect(pm.role_permissions("viewer")).to include("posts:write")
    end

    it "grant is idempotent" do
      expect { pm.grant_permission("viewer", "posts:read") }.not_to raise_error
    end

    it "grant raises KeyError for a missing role" do
      expect { pm.grant_permission("ghost", "posts:read") }.to raise_error(KeyError)
    end

    it "revoke removes a permission" do
      pm.revoke_permission("viewer", "posts:read")
      expect(pm.role_permissions("viewer")).not_to include("posts:read")
    end

    it "revoke is idempotent" do
      expect { pm.revoke_permission("viewer", "nonexistent") }.not_to raise_error
    end

    it "revoke raises KeyError for a missing role" do
      expect { pm.revoke_permission("ghost", "posts:read") }.to raise_error(KeyError)
    end
  end

  describe "#assign_role / #unassign_role" do
    it "assigning gives the role's permissions" do
      pm.assign_role("alice_assign", "viewer")
      expect(pm.has_permission?("alice_assign", "posts:read")).to be true
    end

    it "supports assigning multiple roles" do
      pm.assign_role("alice_multi", "viewer")
      pm.assign_role("alice_multi", "admin")
      expect(pm.has_permission?("alice_multi", "billing:read")).to be true
      expect(pm.has_permission?("alice_multi", "posts:read")).to be true
    end

    it "is idempotent and does not inflate permissions" do
      pm.assign_role("alice_idem", "viewer")
      pm.assign_role("alice_idem", "viewer")
      expect(pm.all_permissions("alice_idem")).not_to include("billing:read")
    end

    it "raises KeyError for a missing role" do
      expect { pm.assign_role("alice_missing", "ghost_role") }.to raise_error(KeyError)
    end

    it "unassign removes the role's permissions" do
      pm.assign_role("alice_unassign", "admin")
      pm.unassign_role("alice_unassign", "admin")
      expect(pm.has_permission?("alice_unassign", "billing:read")).to be false
    end

    it "unassign raises KeyError for a missing role" do
      expect { pm.unassign_role("alice_unassign2", "ghost_role") }.to raise_error(KeyError)
    end

    it "unassign raises KeyError if the user doesn't have that role" do
      pm.assign_role("alice_wrong_role", "viewer")
      expect { pm.unassign_role("alice_wrong_role", "admin") }.to raise_error(KeyError)
    end
  end

  describe "#has_permission? / #all_permissions" do
    it "is true for a granted permission" do
      pm.assign_role("alice_has", "viewer")
      expect(pm.has_permission?("alice_has", "posts:read")).to be true
    end

    it "is false for a permission not granted" do
      pm.assign_role("alice_missing_perm", "viewer")
      expect(pm.has_permission?("alice_missing_perm", "billing:read")).to be false
    end

    it "is false for an unknown user" do
      expect(pm.has_permission?("nobody", "posts:read")).to be false
    end

    it "unions permissions across multiple roles" do
      pm.assign_role("alice_union", "viewer")
      pm.assign_role("alice_union", "admin")
      perms = pm.all_permissions("alice_union")
      expect(perms).to include("billing:read")
      expect(perms).to include("posts:read")
    end

    it "returns an empty set for an unknown user" do
      expect(pm.all_permissions("nobody")).to eq(Set.new)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Role inheritance
  # ---------------------------------------------------------------------------
  describe "role inheritance" do
    it "lets a child inherit the parent's permissions" do
      pm.set_parent_role("editor", "viewer")
      perms = pm.role_permissions("editor")
      expect(perms).to include("posts:read")    # own
      expect(perms).to include("comments:read") # inherited from viewer
    end

    it "inherits transitively through a grandparent" do
      fresh_pm.create_role("base", ["base:read"])
      fresh_pm.create_role("mid", ["mid:write"])
      fresh_pm.create_role("top", ["top:admin"])
      fresh_pm.set_parent_role("mid", "base")
      fresh_pm.set_parent_role("top", "mid")
      perms = fresh_pm.role_permissions("top")
      expect(perms).to include("base:read")
      expect(perms).to include("mid:write")
      expect(perms).to include("top:admin")
    end

    it "gives an assigned user the inherited permissions" do
      pm.set_parent_role("editor", "viewer")
      pm.assign_role("alice_inherit", "editor")
      expect(pm.has_permission?("alice_inherit", "posts:read")).to be true    # own
      expect(pm.has_permission?("alice_inherit", "comments:read")).to be true # inherited
    end

    it "does not leak sibling permissions to a parent's assignee" do
      pm.set_parent_role("editor", "viewer")
      pm.assign_role("alice_sibling", "viewer")
      expect(pm.has_permission?("alice_sibling", "posts:write")).to be false # editor-only
    end

    it "replacing the parent drops the old parent's permissions" do
      fresh_pm.create_role("base_a", ["a:read"])
      fresh_pm.create_role("base_b", ["b:read"])
      fresh_pm.create_role("child", ["c:read"])
      fresh_pm.set_parent_role("child", "base_a")
      fresh_pm.set_parent_role("child", "base_b") # replace parent
      perms = fresh_pm.role_permissions("child")
      expect(perms).to include("b:read")
      expect(perms).not_to include("a:read") # old parent no longer applies
    end

    it "raises KeyError for a missing parent role" do
      expect { pm.set_parent_role("viewer", "nonexistent") }.to raise_error(KeyError)
    end

    it "raises KeyError for a missing child role" do
      expect { pm.set_parent_role("nonexistent", "viewer") }.to raise_error(KeyError)
    end

    it "role_permissions raises KeyError for a missing role" do
      expect { pm.role_permissions("ghost") }.to raise_error(KeyError)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Scoped permissions with wildcards
  # ---------------------------------------------------------------------------
  describe "#has_scoped_permission?" do
    let(:scoped_pm) do
      p = PermissionManager.new
      p.create_role("reader", ["posts:read", "comments:read"])
      p.create_role("post_owner", ["posts:*"])
      p.create_role("moderator", ["*:delete"])
      p.create_role("superadmin", ["*:*"])
      p.create_role("mixed", ["billing:read", "plain_permission"])
      p
    end

    it "matches an exact permission" do
      scoped_pm.assign_role("alice_exact", "reader")
      expect(scoped_pm.has_scoped_permission?("alice_exact", "posts", "read")).to be true
    end

    it "misses when the action doesn't match" do
      scoped_pm.assign_role("alice_exact_miss", "reader")
      expect(scoped_pm.has_scoped_permission?("alice_exact_miss", "posts", "write")).to be false
    end

    it "grants every action via an action wildcard" do
      scoped_pm.assign_role("alice_action_wc", "post_owner")
      expect(scoped_pm.has_scoped_permission?("alice_action_wc", "posts", "read")).to be true
      expect(scoped_pm.has_scoped_permission?("alice_action_wc", "posts", "write")).to be true
      expect(scoped_pm.has_scoped_permission?("alice_action_wc", "posts", "delete")).to be true
    end

    it "does not let an action wildcard leak to other resources" do
      scoped_pm.assign_role("alice_action_wc_scope", "post_owner")
      expect(scoped_pm.has_scoped_permission?("alice_action_wc_scope", "billing", "read")).to be false
    end

    it "grants every resource via a resource wildcard" do
      scoped_pm.assign_role("alice_resource_wc", "moderator")
      expect(scoped_pm.has_scoped_permission?("alice_resource_wc", "posts", "delete")).to be true
      expect(scoped_pm.has_scoped_permission?("alice_resource_wc", "comments", "delete")).to be true
      expect(scoped_pm.has_scoped_permission?("alice_resource_wc", "users", "delete")).to be true
    end

    it "does not let a resource wildcard leak to other actions" do
      scoped_pm.assign_role("alice_resource_wc_scope", "moderator")
      expect(scoped_pm.has_scoped_permission?("alice_resource_wc_scope", "posts", "write")).to be false
    end

    it "grants everything to a superadmin" do
      scoped_pm.assign_role("alice_superadmin", "superadmin")
      expect(scoped_pm.has_scoped_permission?("alice_superadmin", "posts", "read")).to be true
      expect(scoped_pm.has_scoped_permission?("alice_superadmin", "billing", "write")).to be true
      expect(scoped_pm.has_scoped_permission?("alice_superadmin", "anything", "everything")).to be true
    end

    it "ignores plain permissions with no colon" do
      scoped_pm.assign_role("alice_plain", "mixed")
      expect(scoped_pm.has_scoped_permission?("alice_plain", "plain_permission", "read")).to be false
    end

    it "returns false for an unknown user" do
      expect(scoped_pm.has_scoped_permission?("nobody", "posts", "read")).to be false
    end

    it "sees scoped permissions granted via inheritance" do
      scoped_pm.create_role("child_role", ["comments:write"])
      scoped_pm.set_parent_role("child_role", "superadmin")
      scoped_pm.assign_role("alice_inherited_scoped", "child_role")
      expect(scoped_pm.has_scoped_permission?("alice_inherited_scoped", "billing", "delete")).to be true
    end
  end
end
