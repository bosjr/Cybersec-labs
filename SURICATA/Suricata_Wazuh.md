# Intégration Suricata avec Wazuh et détection Nmap

## Objectif

Faire remonter dans Wazuh les alertes générées par Suricata, notamment les détections de scans Nmap.

---

# Architecture

## Agent

VM Ubuntu :

* Suricata 7
* Agent Wazuh
* IP : `10.0.2.12`

## Manager

VM Wazuh :

* Manager Wazuh
* Dashboard OpenSearch
* IP : `10.0.2.18`

---

# Vérification de Suricata

## Vérification du fichier eve.json

Sur l'agent :

```bash
sudo ls -l /var/log/suricata/eve.json
```

Résultat :

```text
-rw-r--r-- 1 root root ...
```

Le fichier est bien généré.

---

## Vérification de la configuration eve-log

Dans :

```bash
sudo nano /etc/suricata/suricata.yaml
```

Configuration :

```yaml
- eve-log:
    enabled: yes
    filetype: regular
    filename: /var/log/suricata/eve.json
```

Types activés :

```yaml
types:
  - alert
  - dns
  - http
```

---

## Validation de la configuration

Sur l'agent :

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml
```

Résultat :

```text
Configuration provided was successfully loaded.
```

---

## Vérification de Wazuh Agent

## Ajout du monitoring du fichier Suricata

Sur l'agent :

```xml
<localfile>
  <log_format>json</log_format>
  <location>/var/log/suricata/eve.json</location>
</localfile>
```

Puis :

```bash
sudo systemctl restart wazuh-agent
```

---

## Contrôle dans ossec.log

Sur l'agent :

```bash
sudo grep suricata /var/ossec/logs/ossec.log
```

Résultat :

```text
Analyzing file: '/var/log/suricata/eve.json'
```

Conclusion :

Le logcollector surveille correctement le fichier.

---

## Problème 1

## Aucune alerte Suricata visible

Dans Wazuh :

```kql
rule.groups:suricata
```

Aucun résultat.

---

## Analyse

Les logs Suricata arrivaient bien au manager.

Exemple :

```json
"location":"/var/log/suricata/eve.json"
```

Mais :

```json
"decoder":{
   "name":"json"
}
```

Aucune règle Suricata n'était appliquée.

---

## Vérification des règles Suricata

Sur le manager :

```bash
sudo ls /var/ossec/ruleset/rules/ | grep -i suricata
```

Résultat :

Aucun fichier Suricata.

---

## Création d'une règle locale

Sur le manager :

Fichier :

```bash
sudo nano /var/ossec/etc/rules/local_rules.xml
```

Ajout :

```xml
<group name="local,suricata">

  <rule id="100010" level="10">
    <decoded_as>json</decoded_as>
    <field name="event_type">alert</field>
    <description>Suricata Alert detected</description>
    <group>suricata</group>
  </rule>

</group>
```

Puis :

```bash
sudo systemctl restart wazuh-manager
```

---

## Vérification

Recherche :

```kql
rule.groups:suricata
```

Résultat :

```json
"groups": [
  "ids",
  "suricata"
]
```

Conclusion :

Les alertes Suricata remontent correctement dans Wazuh.

---

## Exemple d'alerte détectée

```text
ET INFO GNU/Linux APT User-Agent Outbound likely related to package management
```

Groupe :

```json
"groups": [
  "ids",
  "suricata"
]
```

---

## Problème 2 Nmap

## Règles Nmap présentes

Sur l'agent :

```bash
grep -i nmap /var/lib/suricata/rules/local.rules
```

Présence de règles :

```text
POSSBL PORT SCAN (NMAP -sS)
POSSBL PORT SCAN (NMAP -sT)
POSSBL PORT SCAN (NMAP -sA)
POSSBL PORT SCAN (NMAP -sX)
POSSBL PORT SCAN (NMAP -sU)
```

---

## Erreur détectée

Suricata signalait :

```text
No rule files match the pattern /var/lib/suricata/rules/local.rules
```

Le fichier était placé dans :

```text
/etc/suricata/rules/
```

Au lieu de :

```text
/var/lib/suricata/rules/
```

Correction :

```bash
sudo mv /etc/suricata/rules/local.rules /var/lib/suricata/rules/
```

Puis :

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml
```

Validation réussie.

---

## Test Nmap

Depuis le manager :

```bash
sudo nmap -sS -T4 -p- 10.0.2.12
```

Résultat :

```text
22/tcp open ssh
```

---

## Observation Suricata

Dans eve.json :

```json
"event_type":"flow"
```

et

```json
"alerted":false
```

Conclusion :

Le trafic est vu par Suricata mais aucune règle Nmap ne se déclenche.

---

## Saturation du buffer Wazuh

Sur l'agent :

```text
Agent buffer is full: Events may be lost.
```

Puis :

```text
Agent buffer is under 70 %. Working properly again.
```

---

## Cause probable

Le scan :

```bash
nmap -sS -T4 -p-
```

génère plusieurs dizaines de milliers d'événements.

L'agent Wazuh sature avant de tout transmettre.

---

## Vérifications restantes

## Sur l'agent

Vérifier les alertes Suricata directement :

```bash
sudo tail -f /var/log/suricata/eve.json | grep alert
```

ou

```bash
grep "340000" /var/log/suricata/eve.json
```

Les SID Nmap vont de :

```text
3400001
à
3400008
```

---

## Si aucune alerte

Le problème est côté Suricata :

* règle non adaptée au trafic
* seuil trop élevé
* scan trop rapide
* trafic local mal vu par l'interface

---

## Si alertes présentes dans eve.json

Le problème est côté Wazuh :

* décodage
* règles
* buffer saturé

---

# État actuel

| Élément                          | État        |
| -------------------------------- | ----------- |
| Suricata installé                | OK          |
| eve.json généré                  | OK          |
| Wazuh lit eve.json               | OK          |
| Alertes Suricata remontent       | OK          |
| Filtre `rule.groups:suricata`    | OK          |
| Règles Nmap chargées             | OK          |
| Trafic Nmap vu par Suricata      | OK          |
| Alertes Nmap déclenchées         | À confirmer |
| Saturation buffer agent observée | OUI         |

## Prochaine étape

Sur l'agent Ubuntu :

```bash
sudo grep "340000" /var/log/suricata/eve.json
```

C'est le test le plus important pour savoir si Suricata déclenche réellement les règles Nmap avant d'investiguer davantage côté Wazuh.
