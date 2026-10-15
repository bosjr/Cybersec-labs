# SOAR Light Layer — Réponse automatique SOC (Splunk + Linux)

Objectif : ajouter une **couche de réponse automatisée** au lab pour compléter détection + corrélation + scoring.

---

## 1. Objectif global

Automatiser des actions après détection :

* enrichissement d’événements
* notification SOC
* blocage réseau (optionnel lab)
* collecte de preuves
* création d’incident

---

## 2. Architecture

```text id="s1"
Detection Splunk
      │#
      ▼
Alert Trigger
      │
      ▼
Webhook / Script
      │
      ├── Enrichment
      ├── Notification
      ├── Response action
      └── Logging incident
```

---

## 3. Types de réponse (SOAR light)

## 3.1 Niveau 1 — Notification

* email
* syslog centralisé
* Discord / Slack webhook

---

## 3.2 Niveau 2 — Enrichissement

* GeoIP
* WHOIS
* réputation IP
* contexte host/user

---

## 3.3 Niveau 3 — Action (lab uniquement)

* blocage IP (iptables)
* kill process
* isolation VM

---

## 4. Exemple d’alerte Splunk avec webhook

## 4.1 Détection (Sysmon exec suspect)

```spl id="s2"
index=linux_sysmon EventID=1
| search Image="*/bash" OR Image="*/sh"
```

---

## 4.2 Action Splunk

Dans l’alerte :

* Trigger Action → Webhook

Payload JSON :

```json id="s3"
{
  "host": "$result.host$",
  "image": "$result.Image$",
  "command": "$result.CommandLine$",
  "severity": "medium"
}
```

---

## 5. Script de réponse (Linux)

## 5.1 Exemple script d’enrichissement

```bash id="s4"
#!/bin/bash

HOST=$1
IP=$2

echo "[ALERT] Host: $HOST IP: $IP" >> /var/log/soc_incidents.log
```

---

## 5.2 Blocage IP (lab only)

```bash id="s5"
iptables -A INPUT -s $IP -j DROP
```

---

## 6. Création incident local

## 6.1 Log SOC structuré

```bash id="s6"
echo "$(date) | ALERT | HOST=$HOST | EVENT=$EVENT" >> /var/log/soc_incidents.log
```

---

## 7. Corrélation avec Splunk

## 7.1 Vue incidents

```spl id="s7"
index=linux_os_logs soc_incidents.log
| table _time host event severity
```

---

## 7.2 Corrélation attaque + réponse

```spl id="s8"
(index=linux_sysmon OR index=linux_file_integrity OR index=network_security_logs)
| transaction host maxspan=10m
```

---

## 8. Enrichissement Threat Intel (simple)

## 8.1 GeoIP

```spl id="s9"
| iplocation dest_ip
```

---

## 8.2 IP suspectes (baseline simple)

```spl id="s10"
| stats count by dest_ip
| sort count
```

---

## 9. SOC workflow complet

```text id="s11"
1. Attack detected (Splunk)
2. Alert triggered
3. Webhook sent
4. Script executed
5. Incident logged
6. Dashboard updated
```

---

## 10. Niveaux de maturité

| Niveau | Capacité        |
| ------ | --------------- |
| 1      | logs uniquement |
| 2      | dashboards      |
| 3      | alerting        |
| 4      | corrélation     |
| 5      | hunting         |
| 6      | automation      |
| 7      | SOAR light      |

---

## 11. Bonnes pratiques

* ne jamais bloquer en production sans validation
* logguer toutes les actions SOAR
* séparer détection et réponse
* versionner scripts
* limiter actions automatiques agressives

---
