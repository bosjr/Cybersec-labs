# Write-up — Installation de Sysmon for Linux et intégration dans Splunk

Sysmon constitue une excellente suite logique. Contrairement à `auditd`, **Sysmon for Linux** produit des journaux structurés qui sont généralement envoyés dans **Syslog**, puis collectés par le Splunk Universal Forwarder.

## 1. Objectif

Déployer **Sysmon for Linux** afin de compléter `auditd` en collectant des événements comportementaux :

* création de processus
* connexions réseau
* chargement de bibliothèques
* création de fichiers
* activité DNS (selon la configuration)

Les événements seront ensuite centralisés dans Splunk.

---

## 2. Architecture

```text
Ubuntu
│
├── Sysmon for Linux
├── syslog (rsyslog)
├── Splunk Universal Forwarder
│
└────────────► Splunk Enterprise
```

---

## 3. Installation de Sysmon

## Installation des dépendances

```bash
sudo apt update
sudo apt install wget curl unzip
```

---

## Télécharger Sysmon

```bash
wget https://github.com/microsoft/SysmonForLinux/releases/latest/download/sysmonforlinux
```

ou télécharger le paquet correspondant à la distribution.

---

## Installation

Selon le paquet téléchargé.

Exemple Debian :

```bash
sudo dpkg -i sysmon*.deb
```

Vérifier :

```bash
sysmon -?
```

---

## 4. Configuration

Télécharger une configuration.

La plus utilisée est celle de :

### SwiftOnSecurity

ou

### olafhartong

Exemple :

```bash
wget https://raw.githubusercontent.com/olafhartong/sysmon-modular/master/sysmonconfig.xml
```

---

Installation de la configuration

```bash
sudo sysmon -accepteula -i sysmonconfig.xml
```

Vérification

```bash
sudo sysmon -s
```

---

## 5. Vérification

Vérifier le service

```bash
systemctl status sysmon
```

ou

```bash
systemctl status sysmon.service
```

---

Lister la configuration

```bash
sudo sysmon -c
```

---

## 6. Vérifier les logs

Selon la distribution

```bash
journalctl -u sysmon
```

ou

```bash
journalctl | grep Sysmon
```

ou

```bash
tail -f /var/log/syslog
```

On doit voir des événements ressemblant à :

```text
Sysmon EventID 1
Process Create

Sysmon EventID 3
Network Connection

Sysmon EventID 11
File Create
```

---

## 7. Configuration du Splunk Universal Forwarder

Modifier :

```text
/opt/splunkforwarder/etc/system/local/inputs.conf
```

Exemple :

```ini
[monitor:///var/log/syslog]
disabled = false
index = linux_sysmon
sourcetype = syslog
```

Si Sysmon écrit directement dans un autre fichier, adapter le chemin.

---

Redémarrer le Forwarder

```bash
sudo /opt/splunkforwarder/bin/splunk restart
```

---

## 8. Création de l'index

Créer :

```text
linux_sysmon
```

dans

```text
Settings
→ Indexes
```

---

## 9. Vérification dans Splunk

Recherche :

```spl
index=linux_sysmon
```

Puis

```spl
index=linux_sysmon Sysmon
```

ou

```spl
index=linux_sysmon EventID=1
```

---

## 10. Recherches utiles

### Création de processus

```spl
index=linux_sysmon EventID=1
```

---

### Connexions réseau

```spl
index=linux_sysmon EventID=3
```

---

### Création de fichiers

```spl
index=linux_sysmon EventID=11
```

---

### Activité d'un utilisateur

```spl
index=linux_sysmon
| stats count by User
```

---

## 11. Auditd vs Sysmon

| Auditd                         | Sysmon                             |
| ------------------------------ | ---------------------------------- |
| Audit noyau Linux              | Audit comportemental               |
| Appels système                 | Création de processus              |
| Surveillance de fichiers       | Connexions réseau                  |
| Contrôle d'intégrité           | Arbre des processus                |
| Conforme Linux Audit Framework | Équivalent Linux de Sysmon Windows |

---

## 12. Architecture finale

```text
Ubuntu

        +----------------------+
        |      auditd          |
        +----------+-----------+
                   |
                   |
        +----------v-----------+
        |      Sysmon          |
        +----------+-----------+
                   |
                   |
        +----------v-----------+
        |      rsyslog         |
        +----------+-----------+
                   |
                   |
        +----------v-----------+
        | Splunk Forwarder     |
        +----------+-----------+
                   |
                   |
             Splunk Enterprise
                   |
      +------------+------------+
      |                         |
 linux_file_integrity     linux_sysmon
```

Cette architecture est celle que l'on retrouve fréquemment dans les laboratoires SOC : **`auditd`** est utilisé pour l'audit et l'intégrité des systèmes Linux, tandis que **Sysmon for Linux** apporte une télémétrie comportementale plus riche, permettant des corrélations avancées avec d'autres sources comme Suricata ou Wazuh.
