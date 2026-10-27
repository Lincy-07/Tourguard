# VM size allow-list and a basic network hygiene warning.
package main

import rego.v1

deny contains msg if {
	some rc in input.resource_changes
	rc.type == "azurerm_linux_virtual_machine"
	some action in rc.change.actions
	action in {"create", "update"}
	size := rc.change.after.size
	not size in data.budget.allowed_vm_sizes
	msg := sprintf(
		"SIZE: %s uses VM size %s, which is not in the approved list %v",
		[rc.address, size, data.budget.allowed_vm_sizes],
	)
}

# Warning only (does not block): SSH open to the whole internet.
warn contains msg if {
	some rc in input.resource_changes
	rc.type == "azurerm_network_security_group"
	some rule in rc.change.after.security_rule
	rule.destination_port_range == "22"
	rule.source_address_prefix == "*"
	rule.access == "Allow"
	msg := sprintf("NETWORK: %s allows SSH (22) from any address. Restrict allowed_ssh_cidr to your IP.", [rc.address])
}
