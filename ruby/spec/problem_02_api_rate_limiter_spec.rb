require_relative "../practice_problems/problem_02_api_rate_limiter"

RSpec.describe TieredRateLimiter do
  BASE_TIME = 1_700_000_000.0 # arbitrary fixed "now" for deterministic examples

  let(:plans) do
    {
      "free" => { rpm: 3, rpd: 10 },
      "pro" => { rpm: 100, rpd: 5_000 },
      "unlimited" => { rpm: nil, rpd: nil }
    }
  end
  let(:limiter) { TieredRateLimiter.new(plans) }
  let(:limiter_with_key) do
    limiter.create_key("key_abc", "alice", "pro")
    limiter
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Key management
  # ---------------------------------------------------------------------------
  describe "#create_key" do
    it "creates a key" do
      k = limiter.create_key("k1", "alice", "free")
      expect(k[:owner]).to eq("alice")
      expect(k[:plan]).to eq("free")
      expect(k[:enabled]).to be true
      expect(k[:request_log]).to eq([])
    end

    it "raises ArgumentError on a duplicate key" do
      limiter.create_key("k1", "alice", "free")
      expect { limiter.create_key("k1", "bob", "pro") }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError for an unknown plan" do
      expect { limiter.create_key("k1", "alice", "enterprise") }.to raise_error(ArgumentError)
    end
  end

  describe "#revoke_key" do
    it "disables the key" do
      limiter_with_key.revoke_key("key_abc")
      expect(limiter_with_key.allowed?("key_abc", BASE_TIME)).to be false
    end

    it "raises KeyError for a missing key" do
      expect { limiter.revoke_key("ghost") }.to raise_error(KeyError)
    end
  end

  describe "#update_plan" do
    it "changes the plan" do
      limiter_with_key.update_plan("key_abc", "free")
      expect(limiter_with_key.usage("key_abc", BASE_TIME)[:plan]).to eq("free")
    end

    it "preserves the request log" do
      limiter_with_key.record_request("key_abc", BASE_TIME - 5)
      limiter_with_key.update_plan("key_abc", "free")
      expect(limiter_with_key.usage("key_abc", BASE_TIME)[:rpd_used]).to eq(1)
    end

    it "raises ArgumentError for an unknown plan" do
      expect { limiter_with_key.update_plan("key_abc", "nonexistent") }.to raise_error(ArgumentError)
    end

    it "raises KeyError for a missing key" do
      expect { limiter.update_plan("ghost", "free") }.to raise_error(KeyError)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 2 — count_in_window
  # ---------------------------------------------------------------------------
  describe "#count_in_window" do
    it "returns 0 for an empty log" do
      expect(limiter.count_in_window([], BASE_TIME, 60)).to eq(0)
    end

    it "counts everything within the window" do
      log = [BASE_TIME - 30, BASE_TIME - 10, BASE_TIME]
      expect(limiter.count_in_window(log, BASE_TIME, 60)).to eq(3)
    end

    it "excludes entries outside the window" do
      log = [BASE_TIME - 120, BASE_TIME - 61, BASE_TIME - 30, BASE_TIME]
      expect(limiter.count_in_window(log, BASE_TIME, 60)).to eq(2)
    end

    it "excludes the left edge of the window (exclusive)" do
      log = [BASE_TIME - 60]
      expect(limiter.count_in_window(log, BASE_TIME, 60)).to eq(0)
    end

    it "includes entries just inside the window" do
      log = [BASE_TIME - 59.999]
      expect(limiter.count_in_window(log, BASE_TIME, 60)).to eq(1)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 2 — allowed?
  # ---------------------------------------------------------------------------
  describe "#allowed?" do
    it "is true when under all limits" do
      expect(limiter_with_key.allowed?("key_abc", BASE_TIME)).to be true
    end

    it "is false when the key is not found" do
      expect(limiter.allowed?("ghost", BASE_TIME)).to be false
    end

    it "is false when the key is disabled" do
      limiter_with_key.revoke_key("key_abc")
      expect(limiter_with_key.allowed?("key_abc", BASE_TIME)).to be false
    end

    it "is false when the rpm cap is exceeded" do
      limiter.create_key("k1", "alice", "free") # rpm=3
      limiter.record_request("k1", BASE_TIME - 30)
      limiter.record_request("k1", BASE_TIME - 20)
      limiter.record_request("k1", BASE_TIME - 10)
      expect(limiter.allowed?("k1", BASE_TIME)).to be false
    end

    it "is true again once the rpm window has rolled off" do
      limiter.create_key("k1", "alice", "free") # rpm=3
      limiter.record_request("k1", BASE_TIME - 90)
      limiter.record_request("k1", BASE_TIME - 80)
      limiter.record_request("k1", BASE_TIME - 70)
      expect(limiter.allowed?("k1", BASE_TIME)).to be true
    end

    it "is false when the rpd cap is exceeded" do
      limiter.create_key("k1", "alice", "free") # rpd=10
      10.times { |i| limiter.record_request("k1", BASE_TIME - (i * 100)) }
      expect(limiter.allowed?("k1", BASE_TIME)).to be false
    end

    it "is always true for an unlimited plan" do
      limiter.create_key("k1", "alice", "unlimited")
      1000.times { |i| limiter.record_request("k1", BASE_TIME - i) }
      expect(limiter.allowed?("k1", BASE_TIME)).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # PART 3 — record_request
  # ---------------------------------------------------------------------------
  describe "#record_request" do
    it "appends the timestamp" do
      limiter_with_key.record_request("key_abc", BASE_TIME)
      expect(limiter_with_key.usage("key_abc", BASE_TIME)[:rpd_used]).to eq(1)
    end

    it "prunes entries older than 25 hours" do
      old = BASE_TIME - 90_001
      limiter_with_key.record_request("key_abc", old)
      limiter_with_key.record_request("key_abc", BASE_TIME)
      expect(limiter_with_key.usage("key_abc", BASE_TIME + 90_000)[:rpd_used]).to eq(0)
    end

    it "keeps recent entries" do
      recent = BASE_TIME - 3600
      limiter_with_key.record_request("key_abc", recent)
      limiter_with_key.record_request("key_abc", BASE_TIME)
      expect(limiter_with_key.usage("key_abc", BASE_TIME)[:rpd_used]).to eq(2)
    end

    it "raises KeyError for a missing key" do
      expect { limiter.record_request("ghost", BASE_TIME) }.to raise_error(KeyError)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 4 — handle_request
  # ---------------------------------------------------------------------------
  describe "#handle_request" do
    it "records the request on success" do
      result = limiter_with_key.handle_request("key_abc", BASE_TIME)
      expect(result[:allowed]).to be true
      expect(limiter_with_key.usage("key_abc", BASE_TIME)[:rpd_used]).to eq(1)
    end

    it "reports key_not_found" do
      result = limiter.handle_request("ghost", BASE_TIME)
      expect(result[:allowed]).to be false
      expect(result[:reason]).to eq(:key_not_found)
    end

    it "reports key_disabled" do
      limiter_with_key.revoke_key("key_abc")
      result = limiter_with_key.handle_request("key_abc", BASE_TIME)
      expect(result[:allowed]).to be false
      expect(result[:reason]).to eq(:key_disabled)
    end

    it "reports rpm_exceeded" do
      limiter.create_key("k1", "alice", "free") # rpm=3
      limiter.record_request("k1", BASE_TIME - 10)
      limiter.record_request("k1", BASE_TIME - 5)
      limiter.record_request("k1", BASE_TIME - 1)
      result = limiter.handle_request("k1", BASE_TIME)
      expect(result[:allowed]).to be false
      expect(result[:reason]).to eq(:rpm_exceeded)
    end

    it "reports rpd_exceeded without recording the request" do
      limiter.create_key("k1", "alice", "free") # rpd=10
      10.times { |i| limiter.record_request("k1", BASE_TIME - (i * 100)) }
      usage_before = limiter.usage("k1", BASE_TIME)[:rpd_used]
      result = limiter.handle_request("k1", BASE_TIME)
      expect(result[:allowed]).to be false
      expect(result[:reason]).to eq(:rpd_exceeded)
      expect(limiter.usage("k1", BASE_TIME)[:rpd_used]).to eq(usage_before)
    end

    it "checks rpd only once rpm is within limits" do
      limiter.create_key("k1", "alice", "free") # rpm=3, rpd=10
      (1..10).each { |i| limiter.record_request("k1", BASE_TIME - (3600 * i)) }
      result = limiter.handle_request("k1", BASE_TIME)
      expect(result[:reason]).to eq(:rpd_exceeded)
    end
  end

  # ---------------------------------------------------------------------------
  # PART 4 — usage
  # ---------------------------------------------------------------------------
  describe "#usage" do
    it "returns the correct counts" do
      limiter_with_key.record_request("key_abc", BASE_TIME - 30)     # within minute and day
      limiter_with_key.record_request("key_abc", BASE_TIME - 3_600)  # within day only
      stats = limiter_with_key.usage("key_abc", BASE_TIME)
      expect(stats[:rpm_used]).to eq(1)
      expect(stats[:rpd_used]).to eq(2)
      expect(stats[:plan]).to eq("pro")
      expect(stats[:rpm_limit]).to eq(100)
      expect(stats[:rpd_limit]).to eq(5_000)
    end

    it "shows nil limits for an unlimited plan" do
      limiter.create_key("k1", "alice", "unlimited")
      stats = limiter.usage("k1", BASE_TIME)
      expect(stats[:rpm_limit]).to be_nil
      expect(stats[:rpd_limit]).to be_nil
    end

    it "raises KeyError for a missing key" do
      expect { limiter.usage("ghost", BASE_TIME) }.to raise_error(KeyError)
    end
  end
end
