# Write-up – Installation et configuration d'un serveur ELK 8.17 sous Ubuntu Server 22.04

## Objectif

Mettre en place une plateforme ELK (Elasticsearch, Kibana, Fleet Server et Elastic Agent) sur une machine virtuelle Ubuntu Server afin de centraliser des journaux et réaliser des tests de détection de sécurité.

---

# 1. Choix de l'environnement

## Ubuntu Server vs Ubuntu Desktop

Ubuntu Server a été retenu car :

* Consommation mémoire plus faible.
* Moins de processus inutiles.
* Plus de ressources disponibles pour Elasticsearch.
* Administration principalement réalisée via SSH.

## Ressources recommandées

Pour un laboratoire :

* 4 vCPU
* 8 Go RAM minimum
* 50 Go disque

Pour davantage de confort :

* 8 vCPU
* 16 Go RAM

## Version Ubuntu

Ubuntu Server 22.04 LTS est parfaitement adaptée à ELK 8.x.

Les versions suivantes sont compatibles :

* Ubuntu 22.04.5
* Ubuntu 22.04.6

Les deux conviennent.

---

# 2. Vérifications préalables

## Vérification de Java

Elasticsearch nécessite OpenJDK.

Afficher les versions installées :

```bash
java -version
update-alternatives --config java
```

---

# 3. Installation d'Elasticsearch

Installation du dépôt Elastic :

```bash
sudo apt install apt-transport-https
```

Ajout du dépôt :

```bash
deb https://artifacts.elastic.co/packages/8.x/apt stable main
```

---

# 4. Gestion des clés GPG

Si problème 

```text
NO_PUBKEY D27D666CD88E42B4
```

La clé est présente dans :

```text
/etc/apt/trusted.gpg
```

et

```text
/etc/apt/trusted.gpg.d/
```

La configuration moderne utilise :

```text
/usr/share/keyrings/elasticsearch-archive-keyring.gpg
```

La ligne de dépôt retenue :

```bash
deb [signed-by=/usr/share/keyrings/elasticsearch-archive-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main
```

---

## 5. Configuration réseau

## Mode VirtualBox retenu

Carte 1 :

```text
NAT
```

Permet :

* Accès Internet.
* Mise à jour Ubuntu.
* Installation des paquets.

Carte 2 :

```text
Pont (Bridged)
```

Permet :

* Communication avec les autres VM.
* Déploiement d'agents.
* Tests réseau.

### Pourquoi ne pas utiliser uniquement NAT + redirection de ports ?

La redirection suffit pour accéder à Kibana depuis l'hôte.

En revanche :

* Les autres VM ne peuvent pas communiquer directement avec ELK.
* Les agents Wazuh ou Elastic Agent deviennent plus difficiles à déployer.

Le mode pont est donc préférable dans un laboratoire SOC.

---

## 6. Elasticsearch : HTTPS ou HTTP

La version 8.x active la sécurité par défaut.

Configuration observée :

```yaml
xpack.security.enabled: true

xpack.security.http.ssl:
  enabled: true

xpack.security.transport.ssl:
  enabled: true
```

Cela provoque :

```text
received plaintext http traffic on an https channel
```

lors d'un :

```bash
curl http://localhost:9200
```

### Solution

Soit :

Utiliser HTTPS :

```bash
curl -k https://localhost:9200
```

Soit :

Désactiver TLS HTTP.

Finalement Elasticsearch a été configuré en HTTP.

---

## 7. Gestion du compte elastic

Le mot de passe du compte :

```text
elastic
```

avait déjà été défini.

si la commande :

```bash
elasticsearch-setup-passwords
```

échouait.

La solution consiste à utiliser :

```bash
elasticsearch-reset-password
```

ou le mot de passe déjà connu.

Validation :

```bash
curl -u elastic:motdepasse http://localhost:9200
```

---

## 8. Configuration de Kibana

Erreur :

```text
value of "elastic" is forbidden
```

Kibana ne peut plus utiliser le compte :

```text
elastic
```

dans la version 8.x.

Il faut utiliser :

```text
kibana_system
```

avec son mot de passe.

Après correction :

```text
Kibana démarre correctement.
```

---

## 9. Alertes liées aux clés de chiffrement

Messages observés :

```text
missing encryption key
```

Pour corriger :

```bash
/usr/share/kibana/bin/kibana-encryption-keys generate
```

Puis ajout dans :

```bash
/etc/kibana/kibana.yml
```

des clés :

```yaml
xpack.encryptedSavedObjects.encryptionKey:
xpack.reporting.encryptionKey:
xpack.security.encryptionKey:
```

---

## 10. Installation de Fleet Server

Elasticsearch fonctionnant en HTTP.

Création du Fleet Server avec :

```bash
sudo elastic-agent enroll \
--fleet-server-es=http://192.168.1.169:9200 \
--fleet-server-service-token=<TOKEN> \
--fleet-server-policy=fleet-server-policy \
--fleet-server-port=8220
```

Résultat :

```text
Fleet Server opérationnel.
```

---

## 11. Installation d'Elastic Agent

Deux méthodes :

## Via Fleet (recommandée)

Depuis Kibana :

```text
Fleet → Add Agent
```

Puis exécution de la commande générée.

## Via APT

```bash
sudo apt install elastic-agent
```

sous réserve que le dépôt Elastic fonctionne correctement.

---

## 12. Simulation d'une attaque SSH

Objectif :

Déclencher des événements de sécurité.

Exemple :

```bash
hydra -l root \
-P /usr/share/wordlists/rockyou.txt \
ssh://192.168.1.169
```

Logs générés :

```text
Failed password
```

dans :

```bash
/var/log/auth.log
```

---

## 13. Création d'une règle de détection

Requête KQL :

```text
event.outcome: "failure"
and process.name: "sshd"
and event.category: "authentication"
```

## Version Query DSL

```json
{
  "query": {
    "bool": {
      "must": [
        {"match":{"event.outcome":"failure"}},
        {"match":{"process.name":"sshd"}},
        {"match":{"event.category":"authentication"}}
      ]
    }
  }
}
```

## Version ES|QL

```sql
FROM logs-*
| WHERE event.outcome == "failure"
AND process.name == "sshd"
AND event.category == "authentication"
```

Une règle créée dans Kibana correspond directement à une alerte active.

---

## 14. Coexistence ELK, Wazuh et Splunk

Il est possible d'installer simultanément :

* Elastic Agent
* Wazuh Agent
* Splunk Universal Forwarder

sur une même VM.

Points d'attention :

* Consommation CPU.
* Consommation RAM.
* Multiplication des lectures de logs.
* Bande passante.

Cette approche est pertinente dans un laboratoire pédagogique comparant plusieurs SIEM.

---

## 15. Script de gestion des agents

Un script Bash a été conçu permettant :

* Démarrer Elastic Agent.
* Arrêter Elastic Agent.
* Démarrer Wazuh Agent.
* Arrêter Wazuh Agent.
* Démarrer Splunk Universal Forwarder.
* Arrêter Splunk Universal Forwarder.

Utilisation :

```bash
chmod +x manage_agents.sh
./manage_agents.sh
```

---

## Conclusion

À l'issue de ces travaux :

* Elasticsearch 8.17.2 fonctionne correctement.
* Kibana est opérationnel.
* Fleet Server est déployé.
* Elastic Agent peut être enrôlé.
* Une détection de brute-force SSH est disponible.
* L'architecture réseau (NAT + Pont) permet l'ajout futur d'agents sur d'autres machines virtuelles.
* La plateforme constitue une base solide pour des exercices SOC, SIEM et détection d'intrusion.
