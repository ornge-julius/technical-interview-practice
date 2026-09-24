"""
=============================================================================
INTERVIEW PROBLEM 3: Permission Manager (RBAC)
Difficulty: Senior Software Engineer | Estimated time: 45 min
=============================================================================

CONTEXT
-------
Almost every production application has some form of Role-Based Access Control:
a SaaS product with admin/member/viewer tiers, a dev tool with repo-level
permissions, a document platform with edit/comment/view roles, etc.

You're implementing an in-memory RBAC engine from scratch. The data
structures are up to you — the class's public interface is what matters.

HOW IT WORKS
------------
  - Roles hold a set of permission strings (e.g. "billing:read", "users:write").
  - Users are assigned one or more roles.
  - A user "has" a permission if any of their roles grant it.
  - In Part 2, roles can inherit from a parent role (permissions flow downward).
  - In Part 3, permission strings use "resource:action" format with wildcards.

NOTES
-----
  - Users do not need to be pre-registered. Assigning a role to a user_id
    that hasn't been seen before creates the user implicitly.
  - You may assume no cycles will be introduced in the role hierarchy.
  - Choose whatever internal data structures you like (dicts, sets, etc.).
  - role_id and user_id are caller-supplied string slugs (e.g. "admin", "alice").
  - All mutable state MUST be stored in instance variables set in __init__.
    Class-level variables will bleed state between PermissionManager instances
    and between test runs.

EXAMPLE
-------
  pm = PermissionManager()
  pm.create_role("admin", ["users:write", "billing:read"])
  pm.create_role("viewer", ["posts:read"])
  pm.assign_role("alice", "admin")
  pm.assign_role("bob", "viewer")

  pm.has_permission("alice", "billing:read")   # -> True
  pm.has_permission("alice", "posts:read")     # -> False
  pm.has_permission("bob", "users:write")      # -> False
  pm.get_all_permissions("alice")              # -> {"users:write", "billing:read"}
  pm.get_role_permissions("admin")             # -> {"users:write", "billing:read"}
=============================================================================
"""


class PermissionManager:
    """In-memory Role-Based Access Control (RBAC) engine."""

    def __init__(self):
        # TODO: initialize your internal state here.
        # All state must be instance variables (not class variables).
        #roles = {'permissions': [], 'parent_role_id': 'admin'}
        self.roles = {}
        self.users = {}
        raise NotImplementedError

    # -------------------------------------------------------------------------
    # PART 1 — Flat role/permission model  (~15 min)
    # -------------------------------------------------------------------------

    def create_role(self, role_id: str, permissions: list = None) -> None:
        """
        Create a role with an optional initial list of permission strings.
        Raise ValueError if role_id already exists.
        Permissions default to an empty set if not provided.
        """
        if role_id in self.roles.keys():
            raise ValueError
        else:
            # add new role to roles  
            self.roles[role_id]['permissions'] = permissions or list()

    def grant_permission(self, role_id: str, permission: str) -> None:
        """
        Add a permission string to a role.
        Raise KeyError if role_id doesn't exist.
        No-op if the role already has that permission.
        """
        if role_id not in self.roles.keys():
            raise KeyError
        else:
            # get the role
            # check if role already has permission string
            # add permission string to list of permission strings
            permissions = self.roles[role_id]['permissions']
            if permission not in permissions:
                permissions.append(permission)

    def revoke_permission(self, role_id: str, permission: str) -> None:
        """
        Remove a permission string from a role.
        Raise KeyError if role_id doesn't exist.
        No-op if the permission wasn't on the role.
        """
        if role_id not in self.roles.keys():
            raise KeyError
        else:
            # get the role (permissions list)
            # check if permission is in the list
            # if permission is in list, remove the value from the persmissions list
            if permission in self.roles[role_id]['permissions']:
                self.roles[role_id]['permissions'].remove(permission)
            

    def assign_role(self, user_id: str, role_id: str) -> None:
        """
        Assign a role to a user. A user may hold multiple roles.
        Raise KeyError if role_id doesn't exist.
        No-op if the user already has that role.
        """
        # users = {'alice': ['admin', 'staff', 'reader']}
        if role_id not in self.roles.keys():
            raise KeyError
        elif role_id not in self.users[user_id]:
            self.users[user_id].append(role_id)
                    
    def unassign_role(self, user_id: str, role_id: str) -> None:
        """
        Remove a role from a user.
        Raise KeyError if role_id doesn't exist.
        Raise KeyError if the user doesn't have that role.
        """
        if role_id not in self.roles.keys():
            raise KeyError
        elif role_id not in self.users[user_id]:
            raise KeyError
        else:
            self.users[user_id].remove(role_id)

    def has_permission(self, user_id: str, permission: str) -> bool:
        """
        Return True if the user holds the given permission string through
        any of their assigned roles.
        Return False if the user doesn't exist or no role grants it.

        Parts 1 + 2: checks both direct and inherited permissions (once
        set_parent_role is implemented).
        Part 3 scoped wildcards are NOT applied here — only exact string match.
        """
        if user_id not in self.users.keys():
            return False
        #else
        #get the user
        #get roles
        #loop through all user roles
        #check permissions on each role
        #if permission is in permissions return true
        user_roles = self.users[user_id]
        for role in user_roles:
            permissions = self.roles[role]['permissions']
            parent_perms = []
            parent_role_id = self.roles[role]['parent_role_id']
            parents_perms = self.roles[parent_role_id]['permissions']
            permissions.extend(parent_perms)

            if permission in permissions:
                return True
        return False 

    def get_all_permissions(self, user_id: str) -> set:
        """
        Return the complete set of permission strings available to user_id,
        across all their roles (and, after Part 2, all ancestor roles).
        Return an empty set if the user doesn't exist.
        """
        perms = set()
        # get user
        # loop through user roles
        # get permissions for each role and add to set
        user_roles = self.users[user_id]
        for role in user_roles:
            permissions = self.roles[role]['permissions']
            for permission in permissions:
                perms.add(permission)

    def get_role_permissions(self, role_id: str) -> set:
        """
        Return the set of permissions directly on a role.
        Raise KeyError if role_id doesn't exist.

        Note: in Part 1 this returns only the role's own permissions.
        After implementing Part 2 (set_parent_role), update this to also
        include permissions inherited from ancestor roles.
        """
        perm_set = set()
        if role_id not in self.roles.keys():
            raise KeyError
        else:
            for perm in self.roles[role_id]['permissions']:
                perm_set.add(perm)
        return perm_set


    # -------------------------------------------------------------------------
    # PART 2 — Role inheritance  (~15 min)
    # -------------------------------------------------------------------------

    def set_parent_role(self, role_id: str, parent_role_id: str) -> None:
        """
        Make role_id inherit all permissions from parent_role_id, and
        transitively from the parent's ancestors.

        Raise KeyError if either role doesn't exist.
        A role may have at most one parent; calling this again replaces the
        existing parent.

        After implementing this, update has_permission, get_all_permissions,
        and get_role_permissions to include inherited permissions.
        """
        # store the parent_role_id on the role
        self.roles[role_id]['parent_role_id'] = parent_role_id

    # -------------------------------------------------------------------------
    # PART 3 — Scoped permissions with wildcards  (~15 min)
    # -------------------------------------------------------------------------

    def has_scoped_permission(self, user_id: str, resource: str, action: str) -> bool:
        """
        Check whether the user has a permission that covers (resource, action).

        Permission strings are in "resource:action" format. A permission P
        covers (resource, action) if any of the following match:
          - P == "resource:action"   (exact match)
          - P == "resource:*"        (wildcard action)
          - P == "*:action"          (wildcard resource)
          - P == "*:*"               (superadmin — grants everything)

        Only "resource:action" formatted permissions are evaluated here.
        Plain strings without ":" are ignored.

        Inherited permissions (from Part 2) are included in the check.
        Return False if no matching permission is found or user doesn't exist.
        """
        raise NotImplementedError
