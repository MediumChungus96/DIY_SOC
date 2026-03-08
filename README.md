# Home SOC Lab — Wazuh + Sysmon on Windows 11

A home Security Operations Center (SOC) lab built on a Windows 11 laptop using Wazuh (Docker), Sysmon, and a Kali Linux attacker machine. Designed to simulate real-world attack scenarios and practice threat detection, log analysis, and MITRE ATT&CK mapping.

---

## Architecture

```
[Kali Linux Laptop]
  └── WiFi (<KALI_IP>)
        │
        │  attack traffic (Nmap, SMB, RDP, DNS, HTTP)
        ▼
[Windows 11 Laptop — <WINDOWS_HOST_IP>]
  ├── Sysmon (kernel-level telemetry)
  ├── Wazuh Agent (log forwarder)
  └── Wazuh Stack (Docker)
        ├── wazuh-manager
        ├── wazuh-indexer (OpenSearch)
        └── wazuh-dashboard (https://localhost)
```

Both machines on the same home network. Future improvement: isolate lab traffic on a dedicated router with a USB-to-Ethernet adapter.

---

## Components

| Component | Version | Role |
|-----------|---------|------|
| Wazuh Manager | 4.12.0 | SIEM / alert engine |
| Wazuh Indexer | 4.12.0 | OpenSearch data store |
| Wazuh Dashboard | 4.12.0 | Web UI |
| Wazuh Agent | 4.12.0 | Windows log forwarder |
| Sysmon | v15.15 | Kernel telemetry (process, network, file) |
| SwiftOnSecurity Config | latest | Sysmon ruleset |
| Docker Desktop | 29.x | Container runtime |
| Kali Linux | Rolling | Attacker machine |

---

## Setup Guide

### Prerequisites
- Windows 11 laptop
- Docker Desktop installed and running
- Git installed
- Kali Linux machine on the same network
- PowerShell (run as Administrator for agent/Sysmon steps)

---

### 1. Deploy Wazuh in Docker

```powershell
git clone https://github.com/wazuh/wazuh-docker.git
cd wazuh-docker
git checkout v4.12.0
cd single-node

# Generate TLS certificates (required before first run)
docker compose -f generate-indexer-certs.yml run --rm generator

# Start the stack
docker compose up -d
```

Access the dashboard at `https://localhost`
Default credentials: `admin` / `SecretPassword`

---

### 2. Install Sysmon

```powershell
# Download Sysmon and SwiftOnSecurity config
Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "$env:TEMP\Sysmon.zip"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" -OutFile "$env:TEMP\sysmonconfig.xml"

# Extract and install
Expand-Archive "$env:TEMP\Sysmon.zip" -DestinationPath "$env:TEMP\Sysmon"
cd "$env:TEMP\Sysmon"
.\Sysmon64.exe -accepteula -i "$env:TEMP\sysmonconfig.xml"
```

Verify Sysmon is running:
```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 5 | Format-List TimeCreated, Message
```

---

### 3. Install Wazuh Agent

```powershell
Invoke-WebRequest -Uri "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.12.0-1.msi" -OutFile "$env:TEMP\wazuh-agent.msi"

msiexec /i "$env:TEMP\wazuh-agent.msi" /q WAZUH_MANAGER="127.0.0.1" WAZUH_AGENT_NAME="windows11-host"

NET START WazuhSvc
```

Verify the agent appears as **Active** in the dashboard under:
`Server Management > Endpoints Summary`

---

### 4. Configure Agent (ossec.conf)

Open `C:\Program Files (x86)\ossec-agent\ossec.conf` as Administrator and add the following before the closing `</ossec_config>` tag:

```xml
<!-- Sysmon event channel -->
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>

<!-- Windows Firewall log -->
<localfile>
  <location>C:\Windows\System32\LogFiles\Firewall\pfirewall.log</location>
  <log_format>syslog</log_format>
</localfile>
```

Enable firewall logging:
```powershell
netsh advfirewall set allprofiles logging droppedconnections enable
netsh advfirewall set allprofiles logging filename "C:\Windows\System32\LogFiles\Firewall\pfirewall.log"
netsh advfirewall set allprofiles logging maxfilesize 4096
```

Enable failed logon auditing (for RDP brute force detection):
```powershell
auditpol /set /subcategory:"Logon" /failure:enable
auditpol /set /subcategory:"Credential Validation" /failure:enable
```

Restart the agent:
```powershell
NET STOP WazuhSvc
NET START WazuhSvc
```

---

## ⚔️ Attack Simulations

All attacks run from the Kali machine targeting the Windows host at `<WINDOWS_HOST_IP>`.

### Install Tools on Kali

```bash
sudo apt update && sudo apt install -y nmap enum4linux hydra nikto dnsutils curl
```

---

### Attack 1 — Nmap Reconnaissance

```bash
sudo nmap -sS -sV -O <WINDOWS_HOST_IP>
```

**What it simulates:** T1046 - Network Service Discovery  
**Wazuh detection:** MITRE ATT&CK > Account Discovery spike  
**Open ports found:** 443 (Wazuh), 902/912 (VMware), 3306 (MySQL), 9200 (OpenSearch)

---

### Attack 2 — SMB Enumeration

```bash
enum4linux -a <WINDOWS_HOST_IP>
```

**What it simulates:** T1135 - Network Share Discovery  
**Wazuh detection:** Multiple Firewall Drop events from same source IP

---

### Attack 3 — RDP Brute Force

```bash
# Extract wordlist if needed
sudo gunzip /usr/share/wordlists/rockyou.txt.gz

hydra -l administrator -P /usr/share/wordlists/rockyou.txt rdp://<WINDOWS_HOST_IP> -t 4 -W 3
```

**What it simulates:** T1110 - Brute Force  
**Wazuh detection:** Event ID 4625 (Failed Logon) alerts  
**Prerequisite:** Enable RDP and audit logging (see Setup step 4)

---

### Attack 4 — DNS Beacon Simulation

```bash
for i in $(seq 1 20); do dig @<WINDOWS_HOST_IP> malware-c2-$i.evil.com; sleep 1; done
```

**What it simulates:** T1071.004 - DNS C2 beaconing  
**Wazuh detection:** Repeated DNS query events in Sysmon network logs

---

### Attack 5 — HTTP Exploit Scanning

```bash
nikto -h http://<WINDOWS_HOST_IP>
```

**What it simulates:** T1190 - Exploit Public-Facing Application  
**Wazuh detection:** Web attack rules, HTTP scan pattern alerts

---

## Viewing Results in Wazuh

1. Open `https://localhost`
2. Go to **Threat Intelligence > Threat Hunting**
3. Set time range to **Last 15 minutes**
4. Filter by agent: `windows11-host`
5. Check **Threat Intelligence > MITRE ATT&CK** for technique mapping

---

## MITRE ATT&CK Coverage

| Technique | ID | Attack Simulation |
|-----------|-----|------------------|
| Network Service Discovery | T1046 | Nmap scan |
| Network Share Discovery | T1135 | SMB enumeration |
| Brute Force | T1110 | Hydra RDP |
| DNS C2 | T1071.004 | DNS beacon simulation |
| Exploit Public App | T1190 | Nikto HTTP scan |
| Account Discovery | T1087 | Nmap / enumeration |

---

## Planned Improvements

-  Add dedicated isolated router for lab network segmentation
-  Add USB-to-Ethernet adapter for dual-NIC Windows setup
-  Integrate Shuffle SOAR for automated alert response
-  Add TheHive for case management
-  Deploy a vulnerable VM (Metasploitable) as a dedicated target
-  Build custom Wazuh detection rules
-  Add Elastic SIEM integration

---

## Repo Structure

```
home-soc-lab/
├── README.md               # This file
├── docs/
│   ├── setup.md            # Detailed setup walkthrough
│   └── attack-playbook.md  # Attack simulation reference
├── configs/
│   └── ossec.conf          # Wazuh agent config
└── rules/
    └── custom_rules.xml    # Custom Wazuh detection rules (WIP)
```

---

## ⚠️ Disclaimer

This lab is for educational purposes only. All attack simulations are performed against systems I own on a private network. Never use these techniques against systems you don't own or have explicit permission to test.
