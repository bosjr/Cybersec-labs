# Write-up — Intégration d’Auditd dans Splunk avec TA-linux_auditd

## 1. Objectif

Mettre en place une chaîne complète de collecte et d’analyse des logs **Linux Auditd** dans Splunk afin de :

* centraliser les événements système (`auditd`)
* normaliser les logs via un **Technology Add-on (TA)**
* exploiter les données dans des recherches et dashboards SOC

---

## 2. Architecture mise en place

* **Machine Linux (agent)** : Ubuntu avec `auditd` + Splunk Universal Forwarder
* **Splunk (indexer/search head)** : réception, indexation et parsing
* **Add-on utilisé** : `TA-linux_auditd` (archivé Splunkbase, v3.1.2)

---

## 3. Installation du TA-linux_auditd

### 3.1 Récupération

* Téléchargement de l’archive :

  ```bash
  linux-auditd-technology-add-on_312.tgz
  ```

* Vérification d’intégrité :

  ```bash
  sha256sum linux-auditd-technology-add-on_312.tgz
  ```

---

### 3.2 Déploiement Splunk

Décompression et installation dans Splunk :

```bash
tar -xvzf linux-auditd-technology-add-on_312.tgz
sudo mv TA-linux_auditd /opt/splunk/etc/apps/
sudo chown -R splunk:splunk /opt/splunk/etc/apps/TA-linux_auditd
sudo systemctl restart splunk
```

### 3.3 Résultat attendu

* Ajout du parsing `auditd`
* Définition du sourcetype : `linux:auditd`
* Extraction automatique des champs :

  * `type`, `exe`, `cmdline`
  * `uid`, `auid`
  * `success`, `syscall`

---

## 4. Configuration du Forwarder Splunk

### 4.1 Collecte des logs auditd

Fichier :

```bash
/opt/splunkforwarder/etc/system/local/inputs.conf
```

Configuration :

```ini
[monitor:///var/log/audit/audit.log]
disabled = false
sourcetype = linux:auditd
index = linux_file_integrity
```

---

### 4.2 Redémarrage agent

```bash
sudo /opt/splunkforwarder/bin/splunk restart
```

---

## 5. Configuration de l’index Splunk

Création de l’index :

* Nom : `linux_file_integrity`
* Type : index standard Splunk
* Utilisation : logs d’intégrité système (auditd)

---

## 6. Vérification de l’ingestion

### 6.1 Recherche Splunk

```spl
index=linux_file_integrity sourcetype=linux:auditd
```

### 6.2 Résultat attendu

Événements de type :

* `SYSCALL`
* `EXECVE`
* `PATH`
* `CWD`

Avec champs extraits :

* commande exécutée (`exe`, `cmdline`)
* utilisateur (`uid`, `auid`)
* résultat (`success`)

---

## 7. Tests fonctionnels

### 7.1 Génération d’événements auditd

```bash
sudo auditctl -w /etc/passwd -p wa -k test_integrity
sudo ls /etc/passwd
```

### 7.2 Vérification Splunk

```spl
index=linux_file_integrity key=test_integrity
```

---

## 8. Points de vigilance

* `sourcetype=linux:auditd` doit être défini côté forwarder (sinon parsing cassé)
* éviter les doublons dans `inputs.conf`
* vérifier que `/var/log/audit/audit.log` est bien utilisé (et non `/var/log/syslog`)
* l’index doit exister avant ingestion

---

## 9. Résultat final

✔ Logs `auditd` centralisés dans Splunk
✔ Parsing automatique via TA-linux_auditd
✔ Index dédié `linux_file_integrity`
✔ Données prêtes pour :

* détection d’élévation de privilèges
* monitoring d’intégrité système
* analyse SOC / forensic Linux

---

## 10. Extension possible

* création d’alertes (sudo suspect, exec dans `/tmp`)
* dashboard “file integrity monitoring”
* corrélation avec Suricata / Sysmon Linux
* mapping MITRE ATT&CK (Execution / Persistence)

---
