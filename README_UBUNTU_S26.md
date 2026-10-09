# Labatab — UbuntuS26 Template + VM Deploy Playbooks

Two Ansible playbooks that run **on the Ansible server** (`192.168.68.36`,
account `ansible`, project at `/home/ansible/Labatab`) to build an
Ubuntu Server 26.04 cloud-init template on Proxmox (`192.168.68.8`) and
then deploy fully-configured VMs from it.

## Files

| File | Purpose |
|---|---|
| `make_ubuntu_s26_template.yml` | Builds Proxmox template **VMID 500 "UbuntuS26"** from the official Ubuntu 26.04 cloud image |
| `deploy_vm_from_template.yml` | Prompts for a VM name, clones template 500, configures, boots, patches, and installs ClamAV + Wazuh |
| `snippets/labatab-ubuntuS26-userdata.yaml` | First-boot cloud-init snippet applied to every clone (SSH password auth, guest agent, datasource pinning) |
| `scripts/labatab-template-firstboot-cleanup.sh` | Resets cloud-init/host-keys/machine-id inside the template before templating |
| `scripts/labatab-wazuh-agent-install.sh` | Installs + starts the Wazuh agent on a new VM |
| `scripts/labatab-get-vm-ip.sh` | Discovers a VM's DHCP IP via the QEMU guest agent |

## 1. Build the template (run once)

```bash
ssh ansible@192.168.68.36
cd /home/ansible/Labatab
ansible-playbook make_ubuntu_s26_template.yml
```

It will ask for confirmation, then:

1. Downloads `resolute-server-cloudimg-amd64.img` (Ubuntu Server 26.04 LTS
   "Resolute Raccoon") **onto the PVE host** and verifies the SHA256 against
   Ubuntu's published `SHA256SUMS`. It also checks the qcow2 magic bytes so a
   raw misread can't corrupt the template.
2. Creates VM **500 "UbuntuS26"**, imports the image as `scsi0`
   (`virtio-scsi-single`, `ssd=1,discard=on`), resizes to 32G.
3. Attaches a **cloud-init drive** (`ide2`), enables the **QEMU guest agent**,
   sets **DHCP** (`ipconfig0 ip=dhcp`), and sets the cloud-init user
   **`ansible`** with password **`Th1s1s1t@ns1bl3`**.
4. Uploads the first-boot snippet and attaches it via
   `--cicustom user=local:snippets/labatab-ubuntuS26-userdata.yaml`.
5. Boots VM 500 once, discovers its DHCP IP via the guest agent, verifies SSH
   login as `ansible`, confirms the guest agent answers, then cleans
   cloud-init state + host keys + machine-id inside the guest and shuts down.
6. Converts VM 500 into the **UbuntuS26** template.

## 2. Deploy a new VM (run per VM)

```bash
ssh ansible@192.168.68.36
cd /home/ansible/Labatab
ansible-playbook deploy_vm_from_template.yml
# → prompts: "Enter the NAME for the new VM (e.g. Neo, Trinity, Ripley)"
```

After you type a name it:

1. Picks the next free VMID (`max + 1`) and **full-clones** template 500.
2. Sets the VM name, **DHCP**, and cloud-init user `ansible` /
   `Th1s1s1t@ns1bl3`.
3. Starts the VM and **waits 45 seconds** (as requested).
4. **Discovers the DHCP IP via the QEMU guest agent**
   (`qm guest cmd <vmid> network-get-interfaces`) — never guesses the IP.
5. **Accepts the SSH fingerprint** (`ssh-keyscan` + `StrictHostKeyChecking=accept-new`)
   and retries login until cloud-init has actually created the user.
6. Runs **apt update + apt dist-upgrade**.
7. **Reboots if needed** (checks `/var/run/reboot-required`) and waits for return.
8. Re-runs **`add_qemu.yml`** and **`deploy_clamav_wazuh_v2.yml`** against only
   the new VM (`--limit`), then installs + starts the **Wazuh agent**.
9. Adds the new VM to the inventory under `[web_servers]`.

## Why this fixes "can't connect to the new VM after it's created"

The historic failure had several causes, all addressed here:

- **SSH password auth was off.** Ubuntu cloud images ship
  `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf` with
  `PasswordAuthentication no`. sshd uses the **first** value found, and
  `sshd_config.d/*.conf` is `Include`d at the **top** of `sshd_config`, so a
  drop-in numbered **lower than 60** wins. The snippet writes
  `/etc/ssh/sshd_config.d/00-labatab-password-auth.conf` → `PasswordAuthentication yes`.
  (Relying on cloud-init's own `ssh_pwauth` writes `50-cloud-init.conf`, which
  **loses** to `60-` — that was a real trap.)
- **No IP discovery.** The old playbook guessed `IP = VMID`. This playbook
  reads the real DHCP lease from the guest agent.
- **Guest agent not ready.** The snippet enables + starts `qemu-guest-agent`
  **before** cloud-init finishes, and restarts `ssh`, so by the time SSH
  accepts connections the agent is answering and password auth is live.
- **User didn't exist yet when port 22 opened.** A new cloud VM opens port 22
  before cloud-init finishes creating the user. We retry the SSH login (up to
  ~6.5 min) until it succeeds — this race is the classic "Permission denied"
  on a brand-new VM.
- **Host key prompt.** `ssh-keyscan` + `accept-new` accept the fingerprint
  automatically.

## Requirements on the Ansible server

- `ansible` user can SSH to `192.168.68.8` (PVE) as `ansible` with key
  `~/.ssh/id_ed25519` **and** has **passwordless sudo** for `qm`.
- Python3 + `pyyaml` available (Ansible target needs python3 — the snippet
  installs it on the guest).
- Network access from the PVE host to `cloud-images.ubuntu.com`.
