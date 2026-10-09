#!/bin/bash
# =============================================================================
# labatab-get-vm-ip.sh
# =============================================================================
# Discover a Proxmox VM's IPv4 address via the QEMU guest agent.
# Reliable alternative to guessing IP from VMID. Requires:
#   - VM has --agent enabled=1
#   - qemu-guest-agent installed + running inside the guest
#
# Usage:
#   labatab-get-vm-ip.sh <VMID>           # run ON the PVE host (uses sudo qm)
#   labatab-get-vm-ip.sh <VMID> <PVE_IP>  # run remotely (SSHes to PVE as ansible)
#
# Prints the IPv4 address on stdout, or exits 1 if not found yet.
# =============================================================================
set -euo pipefail

VMID="${1:?Usage: $0 <VMID> [PVE_IP]}"
PVE_IP="${2:-}"
PVE_USER="${PVE_USER:-ansible}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"

QEMU_CMD='sudo qm guest cmd '"${VMID}"' '"'"'{"command": "network-get-interfaces"}'"'"''

if [ -n "${PVE_IP}" ]; then
    RAW="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
            -i "${SSH_KEY}" "${PVE_USER}@${PVE_IP}" \
            "sudo qm guest cmd ${VMID} '{\"command\": \"network-get-interfaces\"}'")"
else
    RAW="$(eval "sudo qm guest cmd ${VMID} '{\"command\": \"network-get-interfaces\"}'")"
fi

printf '%s' "${RAW}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
ifaces = data if isinstance(data, list) else data.get('result', [])
for i in ifaces:
    if i.get('name') == 'lo':
        continue
    for a in i.get('ip-addresses', []):
        if a.get('ip-address-type') == 'ipv4' and not a.get('ip-address','').startswith('127.'):
            print(a['ip-address']); sys.exit(0)
sys.exit(1)
"
