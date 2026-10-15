# Attack Simulation Runner — Automatisation des scénarios SOC (Linux)

Objectif : exécuter automatiquement les scénarios du framework **Attack Simulation** pour générer des logs Auditd / Sysmon / Suricata et valider Splunk.

---

## 1. Objectif

Créer un ensemble de scripts permettant :

* exécution reproductible des attaques
* génération contrôlée de logs
* tests rapides des détections SOC
* validation continue des dashboards / alertes

---

## 2. Structure

```text id="r1"
attack-runner/
│
├── run_all.sh
├── 01_initial_access.sh
├── 02_privilege_escalation.sh
├── 03_persistence.sh
├── 04_lateral_movement.sh
├── 05_exfiltration.sh
└── config.env
```

---

## 3. Fichier de configuration

## config.env

```bash id="r2"
TARGET_USER=user
TARGET_HOST=127.0.0.1
DELAY=2
LOG_LEVEL=info
```

---

## 4. Scénarios automatisés

---

## 4.1 Initial Access

```bash id="r3"
#!/bin/bash
source config.env

echo "[*] Initial Access Simulation"

ssh $TARGET_USER@$TARGET_HOST "whoami"
sleep $DELAY
ssh $TARGET_USER@$TARGET_HOST "id"
sleep $DELAY
ssh $TARGET_USER@$TARGET_HOST "bash -c 'echo test'"
```

---

## 4.2 Privilege Escalation

```bash id="r4"
#!/bin/bash
source config.env

echo "[*] Privilege Escalation"

ssh $TARGET_USER@$TARGET_HOST "sudo -l"
sleep $DELAY
ssh $TARGET_USER@$TARGET_HOST "sudo cat /etc/shadow"
```

---

## 4.3 Persistence

```bash id="r5"
#!/bin/bash
source config.env

echo "[*] Persistence Simulation"

ssh $TARGET_USER@$TARGET_HOST "echo '* * * * * /bin/bash' | sudo tee -a /etc/crontab"
```

---

## 4.4 Lateral Movement

```bash id="r6"
#!/bin/bash
source config.env

echo "[*] Lateral Movement"

ssh $TARGET_USER@$TARGET_HOST "ssh $TARGET_USER@localhost whoami"
```

---

## 4.5 Exfiltration

```bash id="r7"
#!/bin/bash
source config.env

echo "[*] Exfiltration Simulation"

ssh $TARGET_USER@$TARGET_HOST "curl http://example.com"
```

---

## 5. Runner global

## run_all.sh

```bash id="r8"
#!/bin/bash

echo "[*] Starting Attack Simulation Framework"

./01_initial_access.sh
sleep 2

./02_privilege_escalation.sh
sleep 2

./03_persistence.sh
sleep 2

./04_lateral_movement.sh
sleep 2

./05_exfiltration.sh

echo "[*] Simulation completed"
```

---

## 6. Vérification Splunk

## 6.1 Vue globale

```spl id="r9"
index=linux_sysmon OR index=linux_file_integrity OR index=network_security_logs
| stats count by host, index
```

---

## 6.2 Timeline attaque

```spl id="r10"
index=linux_sysmon OR index=linux_file_integrity OR index=network_security_logs
| sort _time
| table _time host index sourcetype Image file dest_ip CommandLine
```

---

## 6.3 Détection corrélée

```spl id="r11"
(index=linux_sysmon OR index=linux_file_integrity OR index=network_security_logs)
| stats values(index) as sources by host
| where mvcount(sources) >= 2
```

---

## 7. Intégration SOC

Ce runner permet :

* tests continus des règles Splunk
* validation dashboards
* simulation Purple Team automatisée
* entraînement SOC analyst

---

## 8. Sécurité (important)

⚠️ À utiliser uniquement :

* en lab isolé
* sur VM de test
* jamais en production

---

## 9. Améliorations possibles

* ajout randomisation (timestamps, commandes)
* injection d’I.O.C dynamiques
* génération payloads contrôlés
* intégration API Splunk (post-run reporting)
* scoring automatique SOC

---
