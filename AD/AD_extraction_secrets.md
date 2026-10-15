
# Extraction des identifiants Windows

* **Contexte général** — Windows et Active Directory stockent des identifiants à plusieurs endroits (mémoire, registre, fichiers, coffres utilisateur) selon si la machine est autonome ou jointe à un domaine et selon l’usage (connexion interactive, réauthentification, accès hors-ligne, intégration d’applications). Pour les pentesteurs, chaque emplacement offre des opportunités d’extraction avec des exigences et des privilèges différents.

* **Mémoire LSASS** — Le processus `lsass.exe` conserve en mémoire des secrets très sensibles : hachages NTLM/LM, tickets Kerberos (TGT, tickets de service) et parfois des mots de passe en clair. Utile pour SSO. Extraction possible avec accès **SYSTÈME** (ex. dump de LSASS). Outil : *mimikatz* (`sekurlsa::logonpasswords`, `sekurlsa::minidump`).

* **Ruches SAM + SYSTEM** — La ruche SAM contient les hachages des comptes locaux (y compris l’administrateur local). Ces hachages sont chiffrés avec la BootKey dérivée de la ruche SYSTEM. Extraction hors-ligne possible (export des ruches, VSS, accès aux fichiers) et décodage ensuite. Outils/commandes cités : *mimikatz (lsadump::sam)*, export VSS, etc.

* **Secrets LSA** — Stockés sous `HKLM\SECURITY\Policy\Secrets`. Contiennent par exemple les identifiants de domaine mis en cache, mots de passe de tâches/services, parfois mots de passe RDP. Souvent en clair ou facilement déchiffrables. Accès via LSARPC ou outils spécialisés (ex. *secretsdump.py*).

* **DPAPI (coffre-fort utilisateur)** — Service cryptographique pour protéger les secrets applicatifs par utilisateur (mots de passe Wi-Fi, identifiants de navigateurs, clés RDP). Une clé principale utilisateur (stockée sous `%APPDATA%\Microsoft\Protect`) est chiffrée à partir du mot de passe Windows ; si l’attaquant a cette clé + le mot de passe de l’utilisateur, il peut déchiffrer les secrets. Outils : *mimikatz* (`vault::list`, `vault::cred /export`), etc.

* **NTDS.dit (contrôleur de domaine)** — Base de données AD sur les DC : utilisateurs, comptes machines, hachages NTLM, clés Kerberos. C’est le dépôt le plus précieux en environnement de domaine : possession permet d’usurper n’importe quel compte. Accès via réplication (MS-DRSR / DCSync) ou extraction hors-ligne. Outils : *secretsdump.py -just-dc*, `lsadump::dcsync`.

* **Table récapitulative** — Le texte fournit un tableau indiquant pour chaque magasin : contenu, pourquoi il existe, méthode d’accès et outils/commandes typiques (ex. mimikatz, secretsdump.py, vssadmin, lsadump, etc.).

* **Conclusion / suite** — On a maintenant une vue d’ensemble des cibles d’extraction (mémoire, ruches, secrets LSA, DPAPI, NTDS.dit). Les tâches suivantes montrent comment utiliser les outils et techniques pour extraire ces identifiants.

* **Note opérationnelle** — Le texte inclut des identifiants d’accès à la machine WRK pour la tâche suivante (compte Administrateur local + adresse IP + connexion RDP).

---

## Checklist pratique

### Privilèges requis

* Accès `SYSTEM` local : dump LSASS, export des ruches.
* Compte Administrateur local : export des ruches SAM/SYSTEM localement, LSARPC via RPC nommé.
* Compte de domaine avec `Replicating Directory Changes` (DCSync) ou Administrateur de domaine : lecture NTDS.
* Jeton utilisateur (ou mot de passe) du compte cible : DPAPI unlock.

### Outils & commandes essentiels (rapide)

* `mimikatz` — `sekurlsa::logonpasswords`, `lsadump::sam`, `lsadump::dcsync`, `vault::list`, `dpapi::masterkey`.
* `secretsdump.py` (Impacket) — `-just-dc`, `-sam`, remote NTDS extraction, DCSync via `-dcsync`.
* `psexec.py` (Impacket) — exécution distante avec authentification (utilisateur/NTLM).
* `PsExec` (Sysinternals) — exécution distante (Windows native).
* `vssadmin` / `ntdsutil` / copie hors-ligne — extraire `NTDS.dit` + fichiers LOG.
* `procdump` / mini-dump` — dump LSASS sans triggering AV (parfois).
* `secretsdump.py` ou `rpcclient`/`reg`/`smbclient` pour récupérer ruches via partage administratifs.

### Étapes typiques (ordre conseillé)

1. Obtenir un shell (user).
2. Élever au minimum à administrateur local si possible.
3. Si possible, obtenir `SYSTEM` (p. ex. via `psexec`, token impersonation) pour LSASS dump.
4. Dump LSASS -> rechercher cleartext, tickets Kerberos, NTLM.
5. Exporter ruches SAM + SYSTEM si requises (hors-ligne ou via snapshot).
6. Tenter `secretsdump.py` / `dcsync` si accès DC disponible.
7. Récupérer DPAPI masterkeys du profil utilisateur si on vise les coffres.

## Précautions / détection

* Beaucoup d’outils déclenchent EDR/AV (mimikatz, psexec, procdump). Favoriser techniques stealth (proc dump via signed binaries, usage de token stealing).
* Actions bruyantes : VSS snapshot creation, remote service creation (PsExec), DCSync (solicitations LDAP/DRSUAPI) — générer des événements audités (EventID 4662, 4624, 4648, etc.).
* Nettoyage : laisser des preuves est risqué — planifier réponse/compétence légale.

---

## Diagramme (vue d’ensemble — ASCII)

```
                           +----------------------+
                           |    Active Directory  |
                           |    (NTDS.dit on DCs) |
                           +---------+------------+
                                     |
                Replication / DCSync | (secretsdump.py -just-dc, lsadump::dcsync)
                                     |
+----------------+        +----------v-----------+        +-----------------------+
| Workstation /  |        |  Local machine       |        |  User profile folder  |
| Member server  |<------>|  (Windows OS)        |<------>|  %APPDATA%\Microsoft\ |
|                | SMB/RPC|                      | Token  |  Protect  (DPAPI)     |
+----------------+        +----------+-----------+        +-----------------------+
                                     |
         +---------------------------+--------------------------+
         |                           |                          |
         |                           |                          |
  LSASS memory                 Registry hives               LSA Secrets
 (lsass.exe: NTLM hashes,      (C:\Windows\System32\       HKLM\SECURITY\Policy\Secrets
  Kerberos tickets, clear)     config\SAM & SYSTEM)        (cached creds, RDP pw)
  (mimikatz sekurlsa::*)       (mimikatz lsadump::sam)     (secretsdump.py via LSARPC)
```

---

## Détail : `secretsdump.py` (Impacket) — utilité et usage

### Qu’est-ce que c’est ?
`secretsdump.py` fait partie de la suite Impacket. Il permet d’extraire les hachages/sécrets depuis une cible Windows via plusieurs méthodes : accès local aux fichiers SAM/SYSTEM/NTDS, extraction via services (SMB) ou via réplication DRSUAPI (DCSync). Peut aussi utiliser l’interface LSARPC pour récupérer secrets LSA

### Modes courants

* `secretsdump.py user:pass@TARGET` — exfiltre SAM/SECURITY/NTDS via SMB (si credentials admin).
* `secretsdump.py -just-dc DOMAIN/USER:PASS@DC` — ciblé sur DC pour récupérer NTDS-like info via RPC.
* `secretsdump.py -sam SAMfile -system SYSTEMfile` — extraire hachages depuis fichiers locaux exportés.
* `secretsdump.py -outputfile <file>` — stocke résultats.
* `secretsdump.py -hashes lmhash:nthash ...` — pass NTLM hashes to authenticate.

### Prérequis

* Compte avec privilèges suffisants (Administrateur local pour SAM/LSA via SMB ; pour DCSync il faut `Replicating Directory Changes` ou privilèges de domaine).
* Ou accès aux fichiers locaux (SAM/ SYSTEM/NTDS.dit) hors-ligne.

### Exemple

```bash
# Extrait hachages via SMB en tant qu'administrateur local
secretsdump.py DOMAIN/admin:Passw0rd@10.220.10.20

# DCSync (extrait NTDS depuis un DC si le compte à les droits)
secretsdump.py -just-dc domain/daadmin:Passw0rd@dc.domain.local
```

### Forensics / défense

* DCSync est détectable (création de connexions LDAP/DRSUAPI inhabituelles, événements d’audit). Surveiller l’usage des privilèges de réplication.
* Les accès SMB/LSA depuis comptes non attendus sont suspects.

---

## Détail : `psexec.py` (Impacket) vs `PsExec` (Sysinternals)

### 1) `psexec.py` (Impacket)

### Qu’est-ce que c’est ?
Script Python de la collection Impacket imitant le comportement de PsExec : création d’un service distant pour exécuter une commande sur une machine cible via SMB/Service Control Manager. Très utilisé en pentest car intégré à Impacket (fonctionne avec hashes NTLM, etc.).

### Fonctionnalités

* Authentification avec nom/mot de passe ou NTLM hash (`-hashes`).
* Upload d’un binaire et création d’un service distant pour l’exécuter.
* Permet exécution interactive de commandes à distance.
* Peut utiliser `SMB` et `svcctl` RPC.

### Usage typique

```bash
# Exécution de cmd.exe sur la cible
psexec.py DOMAIN/user:Passw0rd@10.220.10.20

# Avec NTLM hash (pass-the-hash)
psexec.py DOMAIN/user@10.220.10.20 -hashes :aad3b435b51404eeaad3b435b51404ee:0123456789abcdef...
```

### Prérequis

* Compte avec droit d’administration sur la machine cible (Administrateur local/domain admin).
* Ports SMB accessibles (445).

### Avantages

* Permet passer-the-hash.
* Facilement scriptable et intégré avec reste d’Impacket.

### Inconvénients / Détection

* Création d’un service Windows distant laisse traces (EventID 7045 service created, 4697 service installed; event logs, file copies).
* Upload d’exécutables et exécution peut déclencher EDR.

## 2) `PsExec` (Sysinternals — Microsoft)

### Qu’est-ce que c’est ?
Outil Windows natif très connu qui permet exécution distante via création d’un service à distance. Moins furtif que certaines techniques mais largement utilisé administrativement — donc bruit peut se fondre si usage légitime.

### Usage typique

```cmd
psexec \\10.220.10.20 -u Administrator -p N3w34829DJdd?1 cmd.exe
```

### Particularités

* Interface Windows natif, exécutable signé (la signature peut réduire certains blocks d’AV).
* Nécessite droits administratifs distants.
* Lancement d’un service distant, traces similaires à psexec.py.

### Comparaison rapide

* `psexec.py` = flexible, pass-the-hash, scriptable (Python/Impacket).
* `PsExec` = outil officiel/Sysinternals, exécutable binaire signé, parfois moins "noisy" pour certains EDR mais toujours détectable.

---

## Commandes / snippets utiles (référence rapide)

### mimikatz (exemples)

```text
privilege::debug
sekurlsa::logonpasswords
lsadump::sam
lsadump::dcsync /domain:DOMAIN /user:krbtgt
vault::list
dpapi::masterkey /in:C:\Users\victim\AppData\Roaming\Microsoft\Protect\<GUID>\<file>
```

### secretsdump.py (exemples)

```bash
# Extract SAM/LSA via smb (admin)
secretsdump.py DOMAIN/admin:Pass@10.220.10.20

# From local SAM/SYSTEM files
secretsdump.py -sam SAM -system SYSTEM LOCAL

# DCSync-style extraction (requires privilèges de réplication)
secretsdump.py -just-dc domain/replicator:Pass@dc.domain.local
```

### psexec.py (exemples)

```bash
# Interactive shell
psexec.py DOMAIN/admin:Pass@10.220.10.20

# Pass-the-hash
psexec.py DOMAIN/admin@10.220.10.20 -hashes :<nthash>
```

### PsExec (Windows)

```cmd
psexec \\10.220.10.20 -u Administrator -p "N3w34829DJdd?1" -i cmd.exe
```

---

## Détection & contremesures rapides (quelques points clés)

* **Activer l’audit** : auditer création de services (EventID 7045), création de snapshots VSS, accès inattendus aux clés SYSTEM/SECURITY, événements DRSUAPI/DCSync.
* **Limiter les droits** : restreindre qui a `Replicating Directory Changes`; limiter usage des comptes administrateurs.
* **Protection LSASS** : LSA Protection (Credential Guard, LSA Protected Process, Windows Defender Credential Guard) pour empêcher les dumps directs.
* **Surveiller SMB** : transferts de fichiers binaires inhabituels, usage de comptes admins sur postes utilisateurs.
* **Rotation des secrets** : rotation régulière des comptes de service, usage de Managed Service Accounts / gMSA.

---

## Mesures préventives (ajout)

### Prévention spécifique par magasin d’identifiants

### Mémoire LSASS

* **Activer LSA Protection (Protected Process Light, PPL)** : exiger que LSASS tourne en processus protégé pour empêcher le dumping par des processus non signés.
* **Déployer Windows Defender Credential Guard** (où possible) : isole et protège les secrets d'authentification (KERB/NTLM) hors de Windows « classique ».
* **Bloquer/alerter les dumps de processus** : détecter l’usage de `procdump`, `rundll32`, `taskmgr` lancé pour dumper LSASS ; bloquer les exécutables non signés qui tentent d’ouvrir lsass.exe.
* **Restreindre l’accès au droit SeDebugPrivilege** — n’accorder que sur des machines d’administration spécialisées.
* **Utiliser des Postes d’Administration Privés (PAW / Privileged Access Workstations)** pour toutes opérations d’administration et d’authentification.

### Ruches SAM + SYSTEM

* **Restreindre l’accès aux fichiers système** (`C:\Windows\System32\config\SAM` et `SYSTEM`) : droits NTFS très restreints ; sauvegardes chiffrées.
* **Limiter les comptes avec accès local administrateur** (just-in-time / juste-ce-qu’il-faut). Utiliser LAPS (Local Administrator Password Solution) pour rotation automatique des mots de passe locaux.
* **Désactiver comptes locaux inutilisés** et surveiller l’ajout de comptes locaux.
* **Sécuriser les sauvegardes & snapshots** : seuls des services autorisés peuvent créer VSS, accès chiffré aux sauvegardes hors-ligne.

### Secrets LSA (HKLM\SECURITY\Policy\Secrets)

* **Restreindre l’accès administratif** au service LSARPC ; limiter qui peut invoquer LSARPC.
* **Rotation & vaulting** des mots de passe de service (utiliser vaults centralisés / gestionnaires de secrets — HashiCorp Vault, Azure Key Vault, CyberArk).
* **Ne pas stocker de mots de passe en clair dans les tâches planifiées ou services** ; utiliser comptes gérés (gMSA) ou Managed Identities.
* **Détection** : surveiller appels LSARPC inhabituels, export de clé HKLM\SECURITY.

### DPAPI (coffre utilisateur)

* **Imposer MFA & mots de passe robustes** : la sécurité de DPAPI dépend de la force du mot de passe utilisateur.
* **Protéger les profils utilisateur** : chiffrement disque (BitLocker), empêcher exfiltration des dossiers `%APPDATA%\Microsoft\Protect`.
* **Gérer les masterkeys** : sauvegardes chiffrées et accès restreint.
* **Utiliser des solutions de gestion d’identités pour secrets applicatifs** plutôt que DPAPI quand possible.

### NTDS.dit (contrôleur de domaine)

* **Réduire l’exposition aux privilèges de réplication** :

  * Ne donner `Replicating Directory Changes` / `Replicating Directory Changes All` qu’aux comptes de sauvegarde/monitoring légitimes.
  * Mettre en place contrôle d’accès (ACL) sur objets sensibles (ex. `krbtgt`).
* **Séparer les rôles & restreindre l’accès aux DC** : seuls les admins de domaine et les comptes de service autorisés doivent se connecter/interagir avec DC.
* **Sécuriser les sauvegardes DC** (NTDS.dit + logs) : chiffrement des sauvegardes, accès restreint, vérification d’intégrité.
* **Monitoring DCSync** : détection des requêtes DRSUAPI/DCSync via logs, firewalling, IDS/EDR règles.

## Mesures transverses (processus, comptes, réseau, détection)

### Gestion des comptes & privilèges

* **Principe du moindre privilège** sur tous les comptes.
* **Séparation des comptes** : comptes administratifs locaux, administratifs de domaine, usage quotidien avec comptes non-privés.
* **Just-in-Time (JIT) & Just-Enough-Administration (JEA)** : délivrer privilèges temporaires et limités.
* **Rotation des mots de passe & usage de comptes gérés (gMSA)** pour services.
* **Interdire le Pass-the-Hash** via politiques, surveillance et réduction de stockage des hachages accessibles.

### Authentification & réseau

* **Exiger MFA** pour accès administratifs et services sensibles (RDP, consoles admin, VPN).
* **Séparer le réseau d’administration** (VLANs, ACLs). Restreindre SMB/RPC d’accès réseau (limiter ports 445/135 aux zones nécessaires).
* **Utiliser des bastions / jump hosts** pour accès RDP/PSExec/PSEXEC, avec journalisation détaillée.
* **Activer SMB signing** et où possible **NTLMv2 ou Kerberos strict**, limiter NTLM et monitorer l’emploi de NTLM.

### Endpoints & protection

* **EDR/AV configurés** pour bloquer/utiliser détection comportementale sur mimikatz, psexec, secdump, création de services distants, dumps de processus.
* **Application Whitelisting** (WDAC / AppLocker) pour empêcher outils non autorisés.
* **Harden LSASS** : bloquer accès non autorisé, empêcher chargement de modules non signés.
* **Patch management** rigoureux (OS, Sysinternals, Impacket usage monitoring).

### Surveillance & détection

* **Activer l’audit avancé** : Events pertinent (non-exhaustif) :

  * Création de services : EventID 7045 (service créé), 4697 (service installé).
  * Tentatives de dump / process access : EventID 10, 11 spécifiques EDR/AV.
  * Connexions administratives distantes : 4624 (logon success), 4648 (logon with explicit credentials), 4672 (special privileges assigned).
  * Modifications sur les clés SYSTEM/SECURITY et accès VSS.
  * DRSUAPI/DCSync-like operations (auditer réplicas et requêtes DRS).
* **Baselines & détection d’anomalies** : fréquence des DCSync, création de services, transferts SMB, utilisation de comptes administrateurs hors heures, etc.
* **Log centralisé & corrélation** (SIEM) pour détecter chaînes d’attaque (création service + upload binaire + dump LSASS).

### Gestion des Services & Processus distants (PsExec / psexec.py)

* **Restreindre la fonction de création de services à distance** (SCM) via GPO ou ACLs.
* **Bloquer les exécutables Sysinternals non autorisés** ou limiter leur usage avec AppLocker/WDAC.
* **Surveiller et alerter** sur :

  * Exécutions de PsExec/psexec.py (command lines, event logs).
  * Création de services distants (7045), transferts fichiers SMB inhabituels.
* **Contrôles réseau** : empêcher SMB interne entre segments non-administratifs ; filtrer trafic SMB depuis postes utilisateurs.

### Sauvegardes & récupération

* **Chiffrer sauvegardes** (NTDS.dit, SYSTEM, SAM), stocker hors ligne avec contrôle d’accès.
* **Tester restauration et procédures IR** : jeux de rôles & exercices de restauration pour s’assurer que le plan de reprise ne réintroduit pas une compromission.
* **Conserver journaux d’audit** hors ligne pour analyse post-incident.

### Formation & gouvernance

* **Former administrateurs** aux risques d’extraction d’identifiants et aux bonnes pratiques (usage de PAW, MFA, LAPS).
* **Politiques & procédures** explicites pour la gestion des comptes de service, accès aux DC, et création de services distants.
* **Processus de change** pour toute opération administrative sensible (audit trail, approbation).

## Check-list rapide de mise en œuvre (priorisation)

1. Activer MFA sur comptes admin et consoles sensibles.
2. Déployer LAPS pour mots de passe locaux.
3. Activer et vérifier LSA Protection et Credential Guard où applicable.
4. Restreindre `Replicating Directory Changes` et surveiller DCSync.
5. Configurer AppLocker/WDAC pour bloquer mimikatz/psexec.py non autorisés.
6. Chiffrer sauvegardes NTDS, SAM/SYSTEM, et restreindre accès aux sauvegardes.
7. Mettre en place SIEM + règles de détection pour création services distants, dumps LSASS, DCSync.
8. Déployer PAW + séparation des comptes et JIT/JEA.
9. Restreindre SMB/RPC via firewall/ACLs entre segments utilisateurs et serveurs.
10. Test de restauration + exercices IR.
