require_relative "../practice_problems/problem_25_fraud_velocity_checker"

RSpec.describe FraudVelocityChecker do
  describe "Part 1 — recording and velocity" do
    describe ".make_ledger" do
      it "returns an empty ledger" do
        ledger = described_class.make_ledger
        expect(described_class.velocity(ledger, "p1_empty", window_seconds: 60, as_of: 0)).to eq({ count: 0, total: 0 })
      end
    end

    describe ".velocity" do
      let(:ledger) { described_class.make_ledger }

      it "counts and sums transactions within the trailing window" do
        described_class.record_transaction(ledger, "p1_acct1", 100, 0)
        described_class.record_transaction(ledger, "p1_acct1", 200, 10)
        expect(described_class.velocity(ledger, "p1_acct1", window_seconds: 60, as_of: 10)).to eq({ count: 2, total: 300 })
      end

      it "excludes transactions before the window" do
        described_class.record_transaction(ledger, "p1_acct2", 100, 0)
        described_class.record_transaction(ledger, "p1_acct2", 200, 100)
        expect(described_class.velocity(ledger, "p1_acct2", window_seconds: 60, as_of: 100)).to eq({ count: 1, total: 200 })
      end

      it "is a half-open window: excludes the exact left boundary, includes as_of" do
        described_class.record_transaction(ledger, "p1_acct3", 50, 0)
        described_class.record_transaction(ledger, "p1_acct3", 75, 60)
        expect(described_class.velocity(ledger, "p1_acct3", window_seconds: 60, as_of: 60)).to eq({ count: 1, total: 75 })
      end

      it "does not mix transactions across different accounts" do
        described_class.record_transaction(ledger, "p1_acct4", 100, 0)
        described_class.record_transaction(ledger, "p1_other", 999, 0)
        expect(described_class.velocity(ledger, "p1_acct4", window_seconds: 60, as_of: 0)).to eq({ count: 1, total: 100 })
      end
    end
  end

  describe "Part 2 — risk rules" do
    describe ".flag_risk" do
      let(:ledger) { described_class.make_ledger }

      it "returns no rules for a quiet account" do
        described_class.record_transaction(ledger, "p2_quiet", 10, 0)
        expect(described_class.flag_risk(ledger, "p2_quiet", as_of: 0)).to eq([])
      end

      it "triggers :high_frequency after more than 5 transactions in 60 seconds" do
        6.times { |i| described_class.record_transaction(ledger, "p2_freq", 10, i) }
        expect(described_class.flag_risk(ledger, "p2_freq", as_of: 5)).to eq([:high_frequency])
      end

      it "does not trigger :high_frequency at exactly 5 transactions" do
        5.times { |i| described_class.record_transaction(ledger, "p2_exactly5", 10, i) }
        expect(described_class.flag_risk(ledger, "p2_exactly5", as_of: 4)).to eq([])
      end

      it "triggers :high_amount when the trailing hour's total exceeds 5000" do
        described_class.record_transaction(ledger, "p2_amount", 6000, 0)
        expect(described_class.flag_risk(ledger, "p2_amount", as_of: 0)).to eq([:high_amount])
      end

      it "does not trigger :high_amount at exactly 5000" do
        described_class.record_transaction(ledger, "p2_exactly5000", 5000, 0)
        expect(described_class.flag_risk(ledger, "p2_exactly5000", as_of: 0)).to eq([])
      end

      it "can trigger both rules at once, in [:high_frequency, :high_amount] order" do
        6.times { |i| described_class.record_transaction(ledger, "p2_both", 1000, i) }
        expect(described_class.flag_risk(ledger, "p2_both", as_of: 5)).to eq([:high_frequency, :high_amount])
      end
    end
  end

  describe "Part 3 — cross-account reporting" do
    describe ".blocked?" do
      let(:ledger) { described_class.make_ledger }

      it "is false when only one rule is triggered" do
        described_class.record_transaction(ledger, "p3_onerule", 6000, 0)
        expect(described_class.blocked?(ledger, "p3_onerule", as_of: 0)).to eq(false)
      end

      it "is true when both rules are triggered" do
        6.times { |i| described_class.record_transaction(ledger, "p3_bothrules", 1000, i) }
        expect(described_class.blocked?(ledger, "p3_bothrules", as_of: 5)).to eq(true)
      end

      it "is false for a clean account" do
        described_class.record_transaction(ledger, "p3_clean", 10, 0)
        expect(described_class.blocked?(ledger, "p3_clean", as_of: 0)).to eq(false)
      end
    end

    describe ".risk_report" do
      let(:ledger) { described_class.make_ledger }

      it "returns an empty report when no account is flagged" do
        described_class.record_transaction(ledger, "p3_r_clean", 10, 0)
        expect(described_class.risk_report(ledger, as_of: 0)).to eq([])
      end

      it "omits accounts with zero triggered rules" do
        described_class.record_transaction(ledger, "p3_r_clean2", 10, 0)
        described_class.record_transaction(ledger, "p3_r_flagged", 6000, 0)
        report = described_class.risk_report(ledger, as_of: 0)
        expect(report.map { |entry| entry[:account_id] }).to eq(["p3_r_flagged"])
      end

      it "sorts accounts with more triggered rules first" do
        described_class.record_transaction(ledger, "p3_r_onerule", 6000, 0)
        6.times { |i| described_class.record_transaction(ledger, "p3_r_tworules", 1000, i) }
        report = described_class.risk_report(ledger, as_of: 5)
        expect(report.map { |entry| entry[:account_id] }).to eq(["p3_r_tworules", "p3_r_onerule"])
      end

      it "breaks ties in triggered-rule count by account_id ascending" do
        described_class.record_transaction(ledger, "p3_r_zebra", 6000, 0)
        described_class.record_transaction(ledger, "p3_r_apple", 6000, 0)
        report = described_class.risk_report(ledger, as_of: 0)
        expect(report.map { |entry| entry[:account_id] }).to eq(["p3_r_apple", "p3_r_zebra"])
      end

      it "includes the blocked flag consistent with .blocked?" do
        6.times { |i| described_class.record_transaction(ledger, "p3_r_blockcheck", 1000, i) }
        report = described_class.risk_report(ledger, as_of: 5)
        expect(report.first[:blocked]).to eq(true)
      end
    end
  end
end
