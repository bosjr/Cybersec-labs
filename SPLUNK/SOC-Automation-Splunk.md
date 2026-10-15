# SOC Automation Layer — Splunk (Detection + Scoring + Reporting)

Objectif : transformer ton lab en **cycle SOC automatisé** (type mini “Detection Engineering pipeline”).

---

## 1. Objectif global

Automatiser :

* exécution des scénarios (attack-runner)
* collecte des logs Splunk
* évaluation des détections
* scoring SOC
* génération de rapport

---

## 2. Architecture

```text id="s1"
Attack Runner
     │
     ▼
Auditd / Sysmon / Suricata
     │
     ▼
Splunk (indexes)
     │
     ▼
Detection Rules
     │
     ▼
Scoring Engine
     │
     ▼
SOC Report
```

---

## 3. Composant 1 — Score de détection

## 3.1 Principe

Chaque scénario reçoit un score :

```text id="s2"
0 = invisible
1 = logs présents
2 = visible dans Splunk
3 = dashboard OK
4 = alert déclenchée
5 = corrélé multi-source
```

---

## 3.2 SPL de base pour scoring

```spl id="s3"
(index=linux_sysmon OR index=linux_file_integrity OR index=network_security_logs)
| stats values(index) as sources by host
| eval score=mvcount(sources)
```

---

## 4. Composant 2 — Détection automatique

## 4.1 Alertes actives

Exemple :

```spl id="s4"
index=linux_sysmon EventID=1
| search Image="*/bash" OR Image="*/sh"
```

Trigger :

* > 0 results

---

## 4.2 Corrélation automatique

```spl id="s5"
(index=linux_sysmon OR index=linux_file_integrity OR index=network_security_logs)
| transaction host maxspan=10m
```

---

## 5. Composant 3 — Scoring par scénario

## 5.1 Mapping scénario → score

| Scénario             | Score attendu |
| -------------------- | ------------- |
| Initial Access       | 4             |
| Privilege Escalation | 5             |
| Persistence          | 3             |
| Lateral Movement     | 4             |
| Exfiltration         | 5             |

---

## 5.2 SPL scoring par attaque

```spl id="s6"
index=linux_sysmon OR index=linux_file_integrity OR index=network_security_logs
| stats values(index) as sources by host
| eval score=mvcount(sources)
| table host score sources
```

---

## 6. Composant 4 — Reporting SOC

## 6.1 Rapport global

```spl id="s7"
index=linux_sysmon OR index=linux_file_integrity OR index=network_security_logs
| stats count by index
```

---

## 6.2 Rapport sécurité

```spl id="s8"
index=linux_sysmon OR index=linux_file_integrity
| stats count by host, User
```

---

## 6.3 Rapport attaques

```spl id="s9"
(index=linux_sysmon EventID=1 OR index=linux_file_integrity OR index=network_security_logs)
| sort _time
| table _time host index Image file dest_ip CommandLine
```

---

## 7. Pipeline complet SOC

```text id="s10"
1. Attack Runner
2. Log generation
3. Splunk ingestion
4. Detection rules
5. Alerts
6. Scoring
7. Report
```

---

## 8. Extensions possibles

## 8.1 Automatisation complète

* cron job attack runner
* exécution nightly
* comparaison baseline

---

## 8.2 API Splunk

* extraction résultats via REST API
* génération rapport JSON/PDF

---

## 8.3 CI/CD detection engineering

* versioning règles SPL
* test automatique des détections
* validation avant déploiement

---

## 8.4 UEBA simple

* baseline utilisateurs
* déviation comportementale

---

## 9. Ce que tu as maintenant

Tu as construit :

✔ SIEM fonctionnel
✔ SOC dashboards
✔ alerting
✔ threat hunting
✔ attack simulation
✔ automation runner
✔ scoring engine

---
