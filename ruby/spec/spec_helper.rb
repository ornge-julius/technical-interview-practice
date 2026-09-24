# frozen_string_literal: true
#
# Loaded before any *_spec.rb file via `--require spec_helper` in ruby/.rspec.
#
# Spec files always do:
#   require_relative "../practice_problems/problem_NN_<name>"
# and never change. When ENV["PRACTICE_ANSWER"] names that same problem
# (e.g. "cw_answer_03_permission_manager"), the stub require is redirected to
# ../practice_problem_answers/<PRACTICE_ANSWER>.rb instead.
#
# Usage:
#   PRACTICE_ANSWER=cw_answer_03_permission_manager \
#     bundle exec rspec spec/problem_03_permission_manager_spec.rb
#
# Or via run_tests.sh from the repo root:
#   ./run_tests.sh \
#     -f ruby/practice_problem_answers/cw_answer_03_permission_manager.rb \
#     -c bundle exec rspec spec/problem_03_permission_manager_spec.rb

require "set"

module PracticeAnswerRedirect
  RUBY_ROOT    = File.expand_path("..", __dir__) # .../ruby
  PROBLEMS_DIR = File.join(RUBY_ROOT, "practice_problems")
  ANSWERS_DIR  = File.join(RUBY_ROOT, "practice_problem_answers")

  # Extracts the trailing "NN_<name>" segment from a filename, ignoring
  # whatever prefix precedes it (problem_, cw_answer_, en_answer_, my_answer_...).
  ID_RE = /(\d{2}_[a-z0-9_]+)\z/

  # Top-level constant names introduced by files loaded through our
  # #require_relative override. Consumed by the state-reset hook below.
  def self.loaded_top_level_constants
    @loaded_top_level_constants ||= []
  end

  # Given the absolute path a spec file asked to require_relative, return the
  # absolute path of the configured answer file if PRACTICE_ANSWER names the
  # same problem, else nil (meaning: load the literal path unmodified).
  def self.redirect_target(target_abs_path)
    answer_env = ENV["PRACTICE_ANSWER"]
    return nil unless answer_env
    return nil unless target_abs_path.start_with?(PROBLEMS_DIR + File::SEPARATOR)
    return nil unless File.basename(target_abs_path).start_with?("problem_")

    stub_match   = ID_RE.match(File.basename(target_abs_path, ".rb"))
    answer_match = ID_RE.match(answer_env)
    return nil unless stub_match && answer_match
    return nil unless stub_match[1] == answer_match[1]

    answer_path = File.join(ANSWERS_DIR, "#{answer_env}.rb")
    unless File.file?(answer_path)
      raise LoadError, "PRACTICE_ANSWER=#{answer_env.inspect} but no such file: #{answer_path}"
    end
    answer_path
  end

  # Overrides Kernel#require_relative for every object in the process.
  #
  # IMPORTANT: this does NOT call `super`. CRuby's require_relative resolves
  # its base directory by walking the VM call-frame stack for the nearest
  # frame backed by a Ruby source file (rb_current_realfilepath). Once this
  # override sits ahead of Kernel#require_relative in the method resolution
  # order, `super` would land in that C function with *this method's own*
  # frame (spec_helper.rb) treated as "the caller" — not the real spec file —
  # so paths would resolve relative to the wrong directory for every call,
  # not just the ones we intend to redirect. Instead we resolve the caller's
  # directory ourselves via `caller_locations` (a plain Ruby-level
  # introspection call, unaffected by that C-level quirk) and hand a
  # fully-resolved absolute path to plain `require`.
  def require_relative(path)
    caller_loc  = caller_locations(1, 1)&.first
    caller_file = caller_loc&.absolute_path
    unless caller_file
      raise LoadError, "require_relative: cannot infer basepath for #{path.inspect}"
    end

    target = File.expand_path(path, File.dirname(caller_file))
    target += ".rb" unless target.end_with?(".rb")
    target = File.realpath(target) if File.exist?(target)

    resolved = PracticeAnswerRedirect.redirect_target(target) || target

    before = Object.constants
    result = require(resolved)
    PracticeAnswerRedirect.loaded_top_level_constants.concat(Object.constants - before)
    result
  end
  private :require_relative
end

Object.prepend(PracticeAnswerRedirect)

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Diagnostic safety net, NOT a correctness guarantee — the Ruby analog of
  # python/conftest.py's `_reset_class_level_state` autouse fixture. A
  # correct implementation keeps all mutable state in instance variables,
  # making this a no-op. If removing it causes test bleed between examples,
  # that's a bug in the implementation under test — most likely a class
  # variable, class-level ivar, or class-body constant holding shared state:
  #
  #   class Foo
  #     @@seen_ids = Set.new    # shared by every instance
  #     SEEN_IDS   = Set.new    # also shared by every instance
  #     @seen_ids  = Set.new    # class-level ivar, also shared
  #   end
  #
  # Note: Ruby has no equivalent of Python's "mutable default argument" bug
  # class. `def initialize(roles = Set.new)` allocates a fresh Set on every
  # call, because Ruby evaluates default-argument expressions per invocation
  # rather than once at def-time.
  config.before(:each) do
    PracticeAnswerRedirect.loaded_top_level_constants.each do |name|
      next unless Object.const_defined?(name)

      klass = Object.const_get(name)
      next unless klass.is_a?(Class)

      klass.class_variables.each do |cv|
        val = klass.class_variable_get(cv)
        val.clear if val.respond_to?(:clear) && !val.frozen?
      end

      klass.instance_variables.each do |iv|
        val = klass.instance_variable_get(iv)
        val.clear if val.respond_to?(:clear) && !val.frozen?
      end

      # Skip frozen constants (e.g. `FOO = { ... }.freeze`) — those are
      # intentional shared configuration, not accidentally-shared mutable
      # state, and clearing them would raise FrozenError.
      klass.constants(false).each do |c|
        val = klass.const_get(c)
        val.clear if val.respond_to?(:clear) && !val.frozen?
      end
    end
  end
end
