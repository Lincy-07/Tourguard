# Tagging guardrail. Input = Terraform plan JSON (terraform show -json tfplan).
# Every taggable resource that will be created or updated must carry all required tags.
package main

import rego.v1

taggable := {
	"azurerm_resource_group",
	"azurerm_virtual_network",
	"azurerm_network_security_group",
	"azurerm_public_ip",
	"azurerm_network_interface",
	"azurerm_linux_virtual_machine",
}

deny contains msg if {
	some rc in input.resource_changes
	rc.type in taggable
	some action in rc.change.actions
	action in {"create", "update"}
	tags := object.get(rc.change.after, "tags", {})
	present := {k | some k, v in tags; v != ""}
	missing := {t | some t in data.budget.required_tags} - present
	count(missing) > 0
	msg := sprintf(
		"TAGS: %s is missing required tag(s): %s",
		[rc.address, concat(", ", sort(missing))],
	)
}
