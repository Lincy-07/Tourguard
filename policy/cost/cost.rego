# Cost guardrail. Input = Infracost JSON (infracost breakdown --format json).
# Limits come from policy/data.json so finance can change them without touching code.
package main

import rego.v1

total := to_number(object.get(input, "totalMonthlyCost", 0))

deny contains msg if {
	total > data.budget.monthly_usd
	msg := sprintf(
		"COST: estimated monthly cost $%.2f exceeds the budget of $%v",
		[total, data.budget.monthly_usd],
	)
}

deny contains msg if {
	some project in input.projects
	some resource in project.breakdown.resources
	cost := to_number(object.get(resource, "monthlyCost", 0))
	cost > data.budget.max_resource_monthly_usd
	msg := sprintf(
		"COST: resource %s costs $%.2f per month, above the per-resource limit of $%v",
		[resource.name, cost, data.budget.max_resource_monthly_usd],
	)
}

warn contains msg if {
	total <= data.budget.monthly_usd
	total > data.budget.monthly_usd * data.budget.warn_at_fraction
	msg := sprintf(
		"COST: estimated $%.2f per month is above %v%% of the $%v budget",
		[total, data.budget.warn_at_fraction * 100, data.budget.monthly_usd],
	)
}
