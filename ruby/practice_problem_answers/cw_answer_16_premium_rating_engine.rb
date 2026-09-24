class PremiumRatingEngine
  def initialize
    @submissions = {}
  end

  # ── Part 1 ──────────────────────────────────────────────────────────────

  def add_submission(
    submission_id, coverage_type, company_name,
    employee_count:, annual_revenue:, years_in_business:,
    industry_risk:, requested_limit:, deductible:
  )
    raise ArgumentError, "duplicate submission_id: #{submission_id}" if @submissions.key?(submission_id)
    unless %w[epl do fiduciary].include?(coverage_type)
      raise ArgumentError, "invalid coverage_type: #{coverage_type}"
    end
    unless %w[low medium high].include?(industry_risk)
      raise ArgumentError, "invalid industry_risk: #{industry_risk}"
    end

    submission = {
      submission_id: submission_id,
      coverage_type: coverage_type,
      company_name: company_name,
      employee_count: employee_count,
      annual_revenue: annual_revenue,
      years_in_business: years_in_business,
      industry_risk: industry_risk,
      requested_limit: requested_limit,
      deductible: deductible,
      prior_claims: [],
    }
    @submissions[submission_id] = submission
    submission
  end

  def get_submission(submission_id)
    @submissions.fetch(submission_id) { raise KeyError, "no such submission: #{submission_id}" }
  end

  def calculate_base_premium(submission_id)
    s = get_submission(submission_id)

    base = case s[:coverage_type]
           when "epl"
             1200 + (15 * s[:employee_count]) + (s[:annual_revenue] * 0.0008)
           when "do"
             2500 + (s[:annual_revenue] * 0.0010)
           when "fiduciary"
             800 + (s[:annual_revenue] * 0.0004)
           end

    cap = s[:requested_limit] * 0.03
    base = [base, cap].min
    base = [base, 500].max
    base.round
  end

  # ── Part 2 ──────────────────────────────────────────────────────────────

  def record_prior_claim(submission_id, year:, amount:, claim_type:)
    s = get_submission(submission_id)
    s[:prior_claims] << { year: year, amount: amount, claim_type: claim_type }
    s
  end

  def calculate_final_premium(submission_id, current_year:)
    s = get_submission(submission_id)
    base = calculate_base_premium(submission_id)

    industry_modifier = { "low" => 0.85, "medium" => 1.00, "high" => 1.35 }.fetch(s[:industry_risk])

    tenure_modifier =
      if s[:years_in_business] < 3
        1.25
      elsif s[:years_in_business] <= 10
        1.00
      else
        0.90
      end

    qualifying_claims = s[:prior_claims].count do |claim|
      matches_type = claim[:claim_type] == s[:coverage_type] || claim[:claim_type] == "any"
      recent = claim[:year] >= current_year - 2
      matches_type && recent
    end
    claims_modifier = [1.0 + (0.15 * qualifying_claims), 1.60].min

    computed = base * industry_modifier * tenure_modifier * claims_modifier
    final_premium = [computed, s[:deductible] / 10, 500].max.round

    {
      base_premium: base,
      industry_modifier: industry_modifier,
      tenure_modifier: tenure_modifier,
      claims_modifier: claims_modifier,
      final_premium: final_premium,
    }
  end

  # ── Part 3 ──────────────────────────────────────────────────────────────

  def get_submissions_by_coverage_type
    grouped = {}
    @submissions.values.each do |s|
      (grouped[s[:coverage_type]] ||= []) << s
    end
    grouped.each_value { |list| list.sort_by! { |s| s[:submission_id] } }
    grouped
  end

  def get_portfolio_metrics(current_year:)
    by_coverage_type = {}
    total_premium = 0

    @submissions.each_key do |submission_id|
      final = calculate_final_premium(submission_id, current_year: current_year)[:final_premium]
      total_premium += final
      coverage_type = get_submission(submission_id)[:coverage_type]
      entry = (by_coverage_type[coverage_type] ||= { count: 0, total_premium: 0 })
      entry[:count] += 1
      entry[:total_premium] += final
    end

    total_submissions = @submissions.size
    {
      total_submissions: total_submissions,
      total_premium: total_premium,
      average_premium: total_submissions.zero? ? 0 : (total_premium.to_f / total_submissions).round,
      by_coverage_type: by_coverage_type,
    }
  end

  def get_high_risk_submissions(current_year:, modifier_threshold:)
    results = @submissions.each_value.filter_map do |s|
      breakdown = calculate_final_premium(s[:submission_id], current_year: current_year)
      effective_modifier = (breakdown[:final_premium].to_f / breakdown[:base_premium]).round(4)
      next unless effective_modifier > modifier_threshold

      {
        submission_id: s[:submission_id],
        company_name: s[:company_name],
        coverage_type: s[:coverage_type],
        effective_modifier: effective_modifier,
        final_premium: breakdown[:final_premium],
      }
    end

    results.sort_by { |r| [-r[:effective_modifier], r[:submission_id]] }
  end
end
