# Setup Guide

Complete step-by-step instructions for deploying this home SOC lab from scratch.

---

## Requirements

### Hardware
- Windows 11 laptop (host machine)
- Secondary machine running Kali Linux (attacker)
- Both machines on the same network

### Software
- Docker Desktop for Windows
- Git for Windows
- PowerShell (run as Administrator for agent and Sysmon steps)

### Network
- Note your Windows IP: run `ipconfig` and look for the WiFi adapter IPv4 address
- Note your Kali IP: run `ip a` and look for the wlan0 inet address

---

## Step 1 — Install Docker Desktop

Download and install Docker Desktop from https://www.docker.com/products/docker-desktop

After installing, open Docker Desktop and wait for the engine to fully start (the whale icon in the system tray stops animating) before proceeding.

---

## Step 2 — Deploy Wazuh in Docker

Open PowerShell and run:

```powershell
git clone https://github.com/wazuh/wazuh-docker.git
cd wazuh-docker
git checkout v4.12.0
cd single-node
```

Generate TLS certificates. This step is required before the first run:

```powershell
docker compose -f generate-indexer-certs.yml run --rm generator
```

Start the Wazuh stack:

```powershell
docker compose up -d
```

Verify all three containers are running:

```powershell
docker compose ps
```

You should see `wazuh-manager`, `wazuh-indexer`, and `wazuh-dashboard` all with a status of `Up`.

Access the dashboard at `https://localhost`. Accept the self-signed certificate warning.
Default credentials: `admin` / `<YOUR_WAZUH_PASSWORD>`

---

## Step 3 — Install Sysmon

Open PowerShell as Administrator and run:

```powershell
Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "$env:TEMP\Sysmon.zip"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" -OutFile "$env:TEMP\sysmonconfig.xml"

Expand-Archive "$env:TEMP\Sysmon.zip" -DestinationPath "$env:TEMP\Sysmon"
cd "$env:TEMP\Sysmon"
.\Sysmon64.exe -accepteula -i "$env:TEMP\sysmonconfig.xml"
```

Verify Sysmon is running and generating events:

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 5 | Format-List TimeCreated, Message
```

You should see recent process and network events in the output.

---

## Step 4 — Install Wazuh Agent

Open PowerShell as Administrator and run:

```powershell
Invoke-WebRequest -Uri "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.12.0-1.msi" -OutFile "$env:TEMP\wazuh-agent.msi"

msiexec /i "$env:TEMP\wazuh-agent.msi" /q WAZUH_MANAGER="127.0.0.1" WAZUH_AGENT_NAME="windows11-host"

NET START WazuhSvc
```

Verify the agent is enrolled by going to the Wazuh dashboard and navigating to:
`Server Management > Endpoints Summary`

The agent `windows11-host` should appear with a green Active status.

---

## Step 5 — Configure the Wazuh Agent

Open the agent config file as Administrator:

```powershell
Start-Process notepad "C:\Program Files (x86)\ossec-agent\ossec.conf" -Verb RunAs
```

Add the following block before the closing `</ossec_config>` tag:

```xml
<!-- Sysmon event channel -->
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>

<!-- Windows Firewall log file -->
<localfile>
  <location>C:\Windows\System32\LogFiles\Firewall\pfirewall.log</location>
  <log_format>syslog</log_format>
</localfile>

<!-- Windows Firewall Advanced Security event channel -->
<localfile>
  <log_format>eventlog</log_format>
  <location>Microsoft-Windows-Windows Firewall With Advanced Security/Firewall</location>
</localfile>
```

Save and close the file.

---

## Step 6 — Enable Firewall and Audit Logging

Open PowerShell as Administrator and run:

```powershell
# Enable Windows Firewall drop logging
netsh advfirewall set allprofiles logging droppedconnections enable
netsh advfirewall set allprofiles logging filename "C:\Windows\System32\LogFiles\Firewall\pfirewall.log"
netsh advfirewall set allprofiles logging maxfilesize 4096

# Enable failed logon auditing for RDP brute force detection
auditpol /set /subcategory:"Logon" /failure:enable
auditpol /set /subcategory:"Credential Validation" /failure:enable

# Enable RDP
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
```

Restart the Wazuh agent to apply the config changes:

```powershell
NET STOP WazuhSvc
NET START WazuhSvc
```

---

## Step 7 — Prepare Kali for Attack Simulations

On the Kali machine, install the required tools:

```bash
sudo apt update && sudo apt install -y nmap enum4linux hydra nikto dnsutils curl
```

Extract the rockyou wordlist if not already done:

```bash
sudo gunzip /usr/share/wordlists/rockyou.txt.gz
```

---

## Step 8 — Verify the Pipeline

Run a test Nmap scan from Kali targeting the Windows host IP:

```bash
sudo nmap -sS -sV <WINDOWS_HOST_IP>
```

In the Wazuh dashboard go to `Threat Intelligence > Threat Hunting`, set the time range to Last 15 minutes, and filter by agent `windows11-host`. You should see events appear within a minute of the scan completing.

If events are appearing, the full pipeline is working:

```
Sysmon > Windows Event Log > Wazuh Agent > Wazuh Manager > Dashboard
```

---

## Starting and Stopping the Lab

Two PowerShell scripts are included in the repo root for convenience.

To start everything:
```powershell
# Right-click SOC-Start.ps1 and select Run with PowerShell
# Or from an admin PowerShell terminal:
powershell.exe -ExecutionPolicy Bypass -File "SOC-Start.ps1"
```

To stop everything:
```powershell
powershell.exe -ExecutionPolicy Bypass -File "SOC-Stop.ps1"
```

---

## Troubleshooting

**Wazuh images not found on Docker Hub**
The main branch of wazuh-docker points to unreleased versions. Always checkout a stable tag such as `v4.12.0` before running docker compose.

**Agent not appearing in dashboard**
Check the agent service is running with `NET START WazuhSvc` and confirm the manager address in `ossec.conf` matches where the Wazuh manager is reachable. For a local single-node setup this should be `127.0.0.1`.

**Nmap scan not detected**
Confirm firewall logging is enabled and the firewall log localfile entry is present in `ossec.conf`. Restart the agent after any config changes.

**RDP brute force not detected**
Confirm audit policy is enabled by running `auditpol /get /subcategory:"Logon"` and verifying Failure shows as Enabled.

**Dashboard search returning Bad Request error**
Switch the query language from DQL to Lucene using the toggle on the right side of the search bar.
