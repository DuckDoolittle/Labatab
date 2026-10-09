#!/bin/bash
# =============================================================================
# labatab-template-firstboot-cleanup.sh
# =============================================================================
# Run INSIDE the UbuntuS26 template guest (as root) AFTER first boot and
# BEFORE `qm template`. Resets cloud-init + host keys + machine-id + netplan
# + DHCP leases so every clone is a clean first boot with fresh host keys.
#
# Usage (from the ansible server):
#   ssh -i ~/.ssh/id_ed25519 ansible@<TEMPLATE_IP> 'sudo bash -s' < labatab-template-firstboot-cleanup.sh
# =============================================================================
set -e

# Reset cloud-init so the next boot (first clone boot) is a true first boot.
cloud-init clean --logs || true

# Remove SSH host keys - regenerated on next boot so clones don't share keys.
rm -f /etc/ssh/ssh_host_*

# Reset machine-id so systemd/dbus regenerate it per-clone.
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id

# Remove netplan files so clones get a fresh netplan on boot.
rm -f /etc/netplan/50-cloud-init.yaml /etc/netplan/90-*.yaml 2>/dev/null || true

# Clear DHCP leases so the clone requests a fresh lease.
rm -f /var/lib/dhcp/*.leases /var/lib/dhcpcd/*.lease* 2>/dev/null || true

# Clear apt cache to keep the template small.
apt-get clean || true
rm -rf /var/lib/apt/lists/* || true

sync
echo "Template cleanup complete."
