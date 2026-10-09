#!/bin/bash
# =============================================================================
# labatab-wazuh-agent-install.sh
# =============================================================================
# Installs + starts the Wazuh agent on a freshly deployed lab VM.
# Mirrors the exact steps from provision_new_vm.yml / deploy_clamav_wazuh_v2.yml.
#
# Usage (from the ansible server, via SSH):
#   ssh -i ~/.ssh/id_ed25519 ansible@<NEW_VM_IP> 'sudo bash -s' \
#       < labatab-wazuh-agent-install.sh
#
# Env vars (export before calling, or edit the defaults below):
#   WAZUH_MANAGER   Wazuh manager IP   (default 192.168.68.167)
#   WAZUH_AGENT_GROUP  Agent group     (default Servers)
#   WAZUH_PKG_URL   Wazuh agent .deb  (default 4.14.8-1 amd64)
# =============================================================================
set -e

WAZUH_MANAGER="${WAZUH_MANAGER:-192.168.68.167}"
WAZUH_AGENT_GROUP="${WAZUH_AGENT_GROUP:-Servers}"
WAZUH_PKG_URL="${WAZUH_PKG_URL:-https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.14.8-1_amd64.deb}"

if [ -x /var/ossec/bin/wazuh-agent ]; then
    echo "Wazuh agent already installed - ensuring it is enabled and running."
else
    echo "Downloading Wazuh agent package..."
    wget -q "${WAZUH_PKG_URL}" -O /tmp/wazuh-agent.deb
    echo "Installing Wazuh agent (manager=${WAZUH_MANAGER}, group=${WAZUH_AGENT_GROUP})..."
    WAZUH_MANAGER="${WAZUH_MANAGER}" WAZUH_AGENT_GROUP="${WAZUH_AGENT_GROUP}" dpkg -i /tmp/wazuh-agent.deb
    rm -f /tmp/wazuh-agent.deb
fi

systemctl daemon-reload
systemctl enable wazuh-agent
systemctl start wazuh-agent

echo "Wazuh agent install complete."
/var/ossec/bin/wazuh-control status || true
