# Ruby — Agent Guidelines

## Setup

```bash
cd ruby
bundle install
```

## Workflow per problem

1. The problem file has the prompt plus empty stubs that `raise NotImplementedError`.
2. Copy the problem file to `practice_problem_answers/cw_answer_NN_<name>.rb` and implement it there.
3. Run `bundle exec rspec spec/problem_NN_<name>_spec.rb` from the `ruby/` directory.

Spec files **always** `require_relative "../practice_problems/problem_NN_<name>"` (the
stub). `ruby/spec/spec_helper.rb` overrides `require_relative` so that, when the
`PRACTICE_ANSWER` environment variable names the same problem, it loads your answer
file instead. No spec file ever needs manual import changes.

```bash
PRACTICE_ANSWER=cw_answer_03_permission_manager \
  bundle exec rspec spec/problem_03_permission_manager_spec.rb
```

Or from the repo root, use `run_tests.sh` the same way as the other languages:

```bash
./run_tests.sh \
  -f ruby/practice_problem_answers/cw_answer_03_permission_manager.rb \
  -c bundle exec rspec spec/problem_03_permission_manager_spec.rb
```

## Problem design rules

### Parts must be self-contained
- Specs for Part N must only call methods defined in Parts 1-N.
- Never verify a Part 1 result by calling a Part 2 helper.
- Any introspection method needed to check state in specs must live in the
  **earliest Part that requires it**.

### Methods must compose — no parallel implementations
Design the call chain so Part N methods **call** Part N-1 methods instead of
re-implementing the same logic with a different return type. Before finalizing the
return type of a Part N-1 method, ask whether a later Part could use its return
value directly, or would need to re-run the same check. If it would need to
re-run the check, either enrich the lower-level method's return type or add a
private helper method both can call.

### Include a concrete usage example
Add a short `# Example` block in the problem's top comment showing the data in
use and expected return values for 2-3 key operations.

```ruby
# Example
#   pm = PermissionManager.new
#   pm.create_role("admin", ["users:write", "billing:read"])
#   pm.assign_role("alice", "admin")
#   pm.has_permission?("alice", "billing:read")  # -> true
#   pm.has_permission?("alice", "posts:read")    # -> false
```

### Use string or symbol IDs, not auto-incrementing integers
IDs like `"admin"`, `"viewer"`, or `:admin` are more readable in specs and do not
require the caller to track state. If the problem intentionally models a
database entity, call that out explicitly in the problem's comment.

### All mutable state must be instance-level
Include this note in every class-based problem's top comment:

> Store all state in instance variables set in `initialize`. Class variables
> (`@@foo`), class-level instance variables (`@foo` set directly on the class),
> and mutable class-body constants will bleed between examples and between
> instances — avoid them.

This is the Ruby-specific footgun to warn against. (Ruby has no equivalent of a
Python mutable default argument bug: `def initialize(roles = Set.new)` allocates
a fresh `Set` on every call, since Ruby evaluates default-argument expressions
per invocation, not once at `def` time.)

### Problem style
- Class-based problems (no existing data structure given): the candidate chooses
  internal data structures. Say so explicitly in the problem comment.
- Class-based problems (existing data structure given): the problem provides a
  predefined structure, and the task is application logic on top of it.
- Hash-based problems: provide a `make_<thing>` factory method and a clear
  schema comment for every entity. **Wrap every method in a `module <Name>`
  namespace using `def self.<method>`** (e.g. `GeofenceAlertEngine.make_tracker`),
  never as bare top-level `def` methods. Ruby has no per-file module isolation
  like Python: a bare top-level `def add_event` becomes a private method on
  `Object`, shared by the entire process, so two hash-based problems that both
  declared a bare `add_event` would silently overwrite one another. A `module`
  namespace with `self.`-qualified methods avoids this entirely and is the
  idiomatic Ruby equivalent of Python's per-file top-level functions.

## Test writing rules

### Use `let` — never inline `Foo.new` inside an `it` block

```ruby
# BAD — bleeds if the implementation uses class-level state
it "creates a role" do
  pm = PermissionManager.new
  pm.create_role("mod", [...])
end

# GOOD
let(:fresh_pm) { PermissionManager.new }

it "creates a role" do
  fresh_pm.create_role("mod", [...])
end
```

Provide both:
- a `let` pre-seeded with a realistic set of roles/data
- a bare `let` for a clean, empty instance for tests that need one

### Use unique identifiers per example
When multiple examples create objects with string/symbol IDs, give each a
distinct ID (e.g. `"role_creates_test"`, `"role_dup_test"`) instead of a shared
generic name. This reduces false passes when an implementation accidentally
stores state at the class level.

### The spec_helper safety net
`ruby/spec/spec_helper.rb` has a `config.before(:each)` hook that clears
`.clear`-able class variables, class-level instance variables, and class
constants on any class loaded through the answer-redirect. This guards against
implementation bugs where state is accidentally shared across instances. It is
a diagnostic aid, not a substitute for fixing the implementation. If specs only
pass because of it, there is a bug to fix. Do not remove this hook.

### Always duplicate module-level test data in `let`
When a spec file defines module-level data and a `let` passes it to a
constructor, always pass a defensive copy (`.dup`, `.map(&:dup)`, or
`Marshal.load(Marshal.dump(data))` for deeply nested structures) so an
implementation that mutates the object it was given does not corrupt data
shared across examples.

### Test ordering = implementation ordering
Order `context`/`describe` blocks to match the Part order. A developer who
finishes Part 1 and runs the full spec file should see only Part 1 examples
passing, with Part 2/3 failing cleanly via `NotImplementedError` — not because
of test coupling.

### No cross-part dependencies in assertions
A Part 1 example must not fail simply because Part 2 has not been implemented.
If checking a Part 1 result requires a method slated for Part 2, move that
method to Part 1.

## A note on top-level name uniqueness

Ruby's top-level classes, modules, constants, and bare methods share one
global namespace across the whole process. Unlike Python (each stub is its
own module) or Jest (each test file has its own module registry), two Ruby
problems must never define the same top-level name, or loading both in the
same RSpec process would reopen/overwrite the first definition. Keep every
problem's top-level class, module, and constant names unique across the
whole `ruby/` section. In practice this means:

- Hash-based problems must use a `module` namespace rather than bare
  top-level `def` methods — see "Problem style" above.
- Lookup tables (e.g. a valid-state-transitions map) belong inside the
  class as a frozen class constant (`ContractLifecycleManager::VALID_TRANSITIONS`),
  never as a bare top-level constant.
