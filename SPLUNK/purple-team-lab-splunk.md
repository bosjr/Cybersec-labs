# Purple Team Lab — Scénarios d’attaque SOC (Auditd + Sysmon + Suricata + Splunk)

Objectif : simuler des chaînes d’attaque complètes et vérifier la capacité de détection dans Splunk.

---

## 1. Objectif du lab

Mettre en évidence :

* comportement attaquant (Linux)
* traces Sysmon
* traces Auditd
* détections Suricata
* corrélation Splunk

---

## 2. Scénario 1 — Accès initial + exécution

## 2.1 Simulation attaque

Sur machine Linux :

```bash id="p1"
ssh user@target
```

Puis :

```bash id="p2"
whoami
id
bash
```

---

## 2.2 Traces attendues

### Sysmon

* EventID 1 → bash, ssh

```spl id="p3"
index=linux_sysmon EventID=1
```

---

### Auditd

* login / session activity

```spl id="p4"
index=linux_file_integrity
```

---

## 2.3 Détection Splunk

```spl id="p5"
index=linux_sysmon EventID=1
| search Image="*/bash" OR Image="*/ssh"
```

---

## 3. Scénario 2 — Privilege escalation

## 3.1 Simulation

```bash id="p6"
sudo -i
```

ou

```bash id="p7"
sudo cat /etc/shadow
```

---

## 3.2 Traces attendues

### Auditd

* uid=0 / auid=0

```spl id="p8"
index=linux_file_integrity sourcetype=linux:auditd
| search uid=0 OR auid=0
```

---

## 3.3 Détection

```spl id="p9"
index=linux_file_integrity
| search sudo OR uid=0 OR auid=0
```

---

## 4. Scénario 3 — Modification système

## 4.1 Simulation

```bash id="p10"
sudo nano /etc/passwd
```

ou

```bash id="p11"
sudo useradd attacker
```

---

## 4.2 Traces attendues

* Auditd file integrity events

```spl id="p12"
index=linux_file_integrity
| search file="/etc/passwd" OR file="/etc/shadow"
```

---

## 5. Scénario 4 — Connexion réseau suspecte

## 5.1 Simulation

```bash id="p13"
curl http://example.com
```

ou reverse shell simulé

---

## 5.2 Traces attendues

### Sysmon

```spl id="p14"
index=linux_sysmon EventID=3
```

### Suricata

```spl id="p15"
index=network_security_logs
```

---

## 6. Scénario 5 — Chaîne complète d’attaque

## 6.1 Séquence

```text id="p16"
SSH access
→ bash execution
→ sudo privilege escalation
→ modification /etc/passwd
→ outbound network connection
```

---

## 6.2 Détection corrélée Splunk

```spl id="p17"
(index=linux_sysmon EventID=1)
OR (index=linux_file_integrity)
OR (index=network_security_logs)
| transaction host maxspan=10m
| table _time host index Image file dest_ip CommandLine
```

---

## 7. Validation SOC

## Critères de succès

✔ processus détecté
✔ élévation détectée
✔ modification système détectée
✔ trafic réseau détecté
✔ corrélation possible

---

## 8. Niveau d’analyse attendu

### Niveau 1

* logs isolés

### Niveau 2

* dashboard visible

### Niveau 3

* alertes déclenchées

### Niveau 4

* corrélation multi-source

### Niveau 5

* détection chaîne complète

---

## 9. Améliorations possibles

* ajout brute force SSH (fail2ban + logs auth)
* simulation exfiltration DNS
* simulation persistence cron
* ajout IOC (IP/domaines malveillants)

---

## 10. Conclusion

Ce lab valide la capacité SOC à :

* reconstruire une attaque complète
* corréler plusieurs sources
* identifier les étapes MITRE ATT&CK
* déclencher alertes Splunk

---
