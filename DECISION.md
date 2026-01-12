# Guide de Décision Architecturale - API OpenAlex

## 🎯 Objectif

Ce document vous aide à choisir l'architecture adaptée à vos besoins pour déployer l'API OpenAlex sur votre cluster Kubernetes de 4 serveurs.

**Nous sommes en phase d'exploration** - Pas de code pour l'instant, nous définissons les options.

---

## 📊 Votre Infrastructure

### Cluster dirqual1-4 (4 serveurs identiques)

| Ressource | Par Serveur | Total Cluster | Besoin OpenAlex | Surplus |
|-----------|-------------|---------------|-----------------|---------|
| **CPU Cores** | 40 | 160 | 32+ | **5×** |
| **CPU Threads** | 80 | 320 | 64+ | **5×** |
| **RAM** | 252 GB | 1 TB | 256 GB | **4×** |
| **NVMe SSD** | 3.4 TB | 13.6 TB | 4-6 TB | **2-3×** |
| **HDD SAS** | 67 TB | 270 TB | Backups metadata | **Énorme** |

**Verdict** : Infrastructure largement suffisante pour architecture avancée.

---

## 📁 Données OpenAlex

| Entité | Records | Taille Estimée |
|--------|---------|----------------|
| Works (Articles) | 250M | 1.2 TB |
| Authors | 90M | 300 GB |
| Authorship | 600M | 400 GB |
| Citations | 2B | 350 GB |
| Sources | 250K | 5 GB |
| Institutions | 100K | 10 GB |
| Concepts | 65K | 10 GB |
| **TOTAL** | **~3.5B rows** | **~3 TB** |

**Note importante** : Les données OpenAlex sont toujours disponibles en ligne, donc **pas besoin de backups complets** des données sources (seulement métadonnées de traitement et index personnalisés).

---

## 🏗️ Options Architecturales

### Option 1 : Architecture Hybride (Simple) 🟢

**Composants** : PostgreSQL + Elasticsearch + Redis

```text
FastAPI
  ↓
┌──────────┬──────────┐
│    PG    │    ES    │
└──────────┴──────────┘
```

**Stockage requis** : 4.3 TB NVMe (32% de votre capacité)

#### Avantages ✅
- **Simplicité** - 2 systèmes principaux à gérer
- **Maturité** - Technologies bien connues
- **Déploiement rapide** - Production en 2-3 mois
- **Équipe réduite** - 1-2 personnes suffisent
- **Documentation abondante** - Stack classique

#### Inconvénients ❌
- **Requêtes de graphes lentes** - Citations 3 niveaux = 2-5 secondes
- **Analyses temporelles lourdes** - Tendances sur 10 ans = 1-3 secondes
- **Scalabilité verticale** - Difficile d'ajouter capacité

#### Idéal pour 👍
- Besoin de production rapide
- API REST standard (filtres, recherche basique)
- Équipe IT limitée
- Budget développement serré
- Pas de requêtes analytiques complexes prévues

---

### Option 2 : Architecture Polyglotte (Optimale) 🚀

**Composants** : PostgreSQL + Neo4j + InfluxDB + Elasticsearch + Redis

```text
     FastAPI Router
          ↓
┌─────┬──────┬──────┬─────┐
│Neo4j│TScale│  PG  │ ES  │
└─────┴──────┴──────┴─────┘
```

**Stockage requis** : 3.6 TB NVMe (26% de votre capacité)

#### Avantages ✅
- **Performance exceptionnelle**
  - Citations (Neo4j) : **100-1500× plus rapide** (5-20ms vs 2-5s)
  - Tendances (InfluxDB) : **100-250× plus rapide** (10-50ms vs 1-3s)

- **Scalabilité horizontale** - Ajout de nœuds facile
- **Séparation des préoccupations** - Chaque DB fait ce qu'elle fait de mieux
- **Utilisation optimale des ressources** - Moins de CPU/RAM gaspillés
- **Cas d'usage avancés** - Analyses de réseaux, graphes, tendances

#### Inconvénients ❌
- **Complexité opérationnelle** - 5 systèmes à gérer
- **Déploiement plus long** - Production en 4-6 mois
- **Courbe d'apprentissage** - Formation équipe nécessaire
- **Synchronisation** - Cohérence éventuelle entre systèmes

#### Idéal pour 👍
- Infrastructure largement suffisante (✅ c'est votre cas)
- Cas d'usage avancés (graphes de citations, analyses bibliométriques)
- Horizon long terme (5-10 ans)
- Équipe prête à investir en compétences
- Performance critique pour expérience utilisateur

---

### Option 3 : Architecture Évolutive (Compromis) 🔄

**Principe** : Commencer simple, ajouter systèmes spécialisés selon besoins réels

**Phase 1** (Mois 1-3) : PostgreSQL + Elasticsearch
**Phase 2** (Mois 4-6) : + Neo4j si requêtes graphes nécessaires
**Phase 3** (Mois 7-9) : + InfluxDB si analyses temporelles nécessaires

#### Avantages ✅
- **Démarrage rapide** - Production en 2-3 mois
- **Apprentissage progressif** - Un système à la fois
- **Investissement adapté** - Payer selon besoins réels
- **Réduction des risques** - Pivot possible si besoins mal estimés

#### Inconvénients ❌
- **Migrations complexes** - Transfert de données entre systèmes
- **Dette technique** - Code temporaire à refactorer
- **Coût total potentiellement plus élevé** - Développement en plusieurs fois

#### Idéal pour 👍
- Besoins utilisateurs incertains
- Première itération d'un produit
- Équipe en apprentissage
- Budget phased release
- Tolérance au downtime pour évolutions

---

## 🎓 Recommandation pour Contexte Universitaire

### Architecture Polyglotte ⭐ (Recommandée)

**Pourquoi** :

1. **Ressources disponibles** ✅
   - Vous avez 5× les CPU nécessaires
   - Vous avez 4× la RAM nécessaire
   - Vous avez 3× le stockage nécessaire
   - → **Pas de contrainte de ressources**

2. **Cas d'usage académiques** ✅
   - Recherche = analyses de graphes de citations
   - Études bibliométriques = séries temporelles
   - APIs universitaires = performance pour chercheurs
   - → **Besoins dépassent l'API REST basique**

3. **Horizon long terme** ✅
   - Infrastructure universitaire stable (pas startup)
   - Investissement durable (5-10 ans)
   - Formation valorisée (compétences transférables)
   - → **ROI sur long terme justifié**

4. **Écosystème CNCF** ✅
   - Technologies cloud-native standards
   - Intégration Kubernetes native
   - Support communautaire large
   - → **Stack moderne et pérenne**

### Stratégie de Déploiement Progressif

Pour réduire les risques, déployer en 3 vagues :

**Vague 1** (Mois 1-2) : PostgreSQL + Elasticsearch + Monitoring
- Valider infrastructure Kubernetes + Rook/Ceph
- Charger données OpenAlex
- API REST basique fonctionnelle

**Vague 2** (Mois 3-4) : Ajout Neo4j
- Import graphe de citations (2B edges)
- Endpoints graphes dans API
- Benchmarks de performance vs PostgreSQL

**Vague 3** (Mois 5-6) : Ajout InfluxDB
- Migration données temporelles
- Endpoints analytics et tendances
- Dashboards de monitoring avancés

**Avantage** : Validation à chaque étape, possibilité de s'arrêter si besoins couverts.

---

## 🛠️ Stack Technologique CNCF

### Priorité aux Projets CNCF

Tous les composants infrastructure sont des projets **CNCF Graduated** (production-ready) :

| Composant | Projet CNCF | Statut | Rôle |
|-----------|-------------|--------|------|
| Orchestration | **Kubernetes** | Graduated | Orchestration conteneurs |
| Stockage | **Rook/Ceph** | Graduated | Stockage persistant (RBD, S3) |
| Monitoring | **Prometheus** | Graduated | Métriques et alerting |
| Logging | **Loki** | Graduated | Agrégation de logs |
| Ingress | **Contour (Envoy)** | Graduated | Reverse proxy + TLS |
| TLS | **cert-manager** | Graduated | Certificats auto |
| GitOps | **Flux** | Graduated | Déploiement déclaratif |
| Backup | **Velero** | Graduated | Backup/restore K8s |
| Registry | **Harbor** | Graduated | Registry Docker privé |

**Avantage** : Standards cloud-native, intégration native, support communautaire.

### Bases de Données (Hors CNCF)

Les systèmes de bases de données ne sont pas dans CNCF mais sont des standards :

- **PostgreSQL** - Standard OLTP open-source
- **Neo4j** - Leader des bases de données graphes
- **InfluxDB** - Base de données time-series native avec TSM engine
- **Elasticsearch** - Standard recherche plein texte
- **Redis** - Standard cache distribué

---

## 📝 Prochaines Étapes

### Si vous choisissez Architecture Polyglotte :

1. **Lire la documentation détaillée** :
   - [Architecture Polyglotte](docs/00-introduction/polyglot-architecture.md)
   - [Stack CNCF](docs/10-annexes/cncf-stack.md)
   - [Rook/Ceph Storage](docs/01-stockage/rook-ceph.md)

2. **Valider les choix techniques** :
   - Déploiement K8s : K3s vs kubeadm ?
   - Distribution Linux : Debian vs Ubuntu ?
   - Stratégie réseau : Calico vs Cilium ?

3. **Planifier la Phase 1** :
   - Timeline : 2 mois
   - Équipe : 2-3 personnes
   - Livrables : Cluster K8s + Rook + Monitoring

### Si vous choisissez Architecture Hybride :

1. **Lire la documentation détaillée** :
   - [Architecture Hybride](docs/00-introduction/architecture-decision.md)
   - [Stratégie Stockage](docs/01-stockage/strategy.md)

2. **Planifier la Phase 1** :
   - Timeline : 1 mois
   - Équipe : 1-2 personnes
   - Livrables : Cluster K8s + PostgreSQL + Elasticsearch

### Si vous choisissez Architecture Évolutive :

1. **Commencer par Hybride** (documentation ci-dessus)
2. **Définir les seuils de bascule** :
   - Ajouter Neo4j si latence citations > 1 seconde
   - Ajouter InfluxDB si latence tendances > 500ms
3. **Planifier budget pour Phases 2-3**

---

## 🤔 Questions Fréquentes

### Q1 : Pourquoi pas une seule base de données universelle ?

**R** : Aucune base de données n'excelle dans tous les domaines. PostgreSQL est excellent pour OLTP mais 100× plus lent que Neo4j pour les graphes. Elasticsearch est parfait pour le full-text mais médiocre pour les transactions.

### Q2 : La complexité de 5 bases de données n'est-elle pas excessive ?

**R** : Dans votre cas, non :
- Vous avez les ressources (5× surplus CPU/RAM)
- Vous avez l'horizon temps (5-10 ans)
- Les gains de performance justifient l'investissement

Pour une startup avec budget serré, oui c'est excessif. Pour une université avec infrastructure solide, c'est justifié.

### Q3 : Peut-on faire sans Neo4j et InfluxDB ?

**R** : Oui, avec PostgreSQL + Elasticsearch vous aurez une API fonctionnelle. Mais :
- Citations 3 niveaux : 2-5s vs 5-20ms (Neo4j)
- Tendances 10 ans : 1-3s vs 10-50ms (InfluxDB)

Si les chercheurs tolèrent ces latences, l'hybride suffit.

### Q4 : Pourquoi pas Cassandra ou MongoDB ?

**R** : Cassandra et MongoDB sont excellents mais :
- Cassandra : write-optimized, pas pour OLTP
- MongoDB : document store, pas optimal pour relations
- Neo4j + PostgreSQL couvrent mieux les besoins OpenAlex

### Q5 : Les données OpenAlex changent tous les mois, comment gérer ?

**R** : Pipeline ETL Airflow mensuel :
1. Télécharger nouveaux snapshots OpenAlex
2. Transformer et charger dans toutes les DB
3. Basculer en Blue-Green (zero downtime)
4. Valider et nettoyer ancien environnement

Stratégie Blue-Green évite les interruptions.

### Q6 : Pourquoi ne pas tout mettre dans Elasticsearch ?

**R** : Elasticsearch est un moteur de recherche, pas une base de données transactionnelle :
- Pas de transactions ACID
- Pas de contraintes d'intégrité référentielle
- Pas optimisé pour updates fréquents

Il complète PostgreSQL mais ne le remplace pas.

---

## 📚 Documentation Complète

Toute la documentation détaillée est organisée en modules dans `/docs/` :

- **Introduction** - Vue d'ensemble, décisions d'architecture
- **Stockage** - PostgreSQL, Neo4j, InfluxDB, Elasticsearch, Rook/Ceph
- **Indexation** - Index, mapping, vues matérialisées
- **Recherche** - Full-text, requêtes structurées, graphes, analytics
- **API** - Design REST, FastAPI, cache, rate limiting
- **Ingestion** - Pipeline ETL, Airflow, transformation, zero-downtime
- **Kubernetes** - Cluster, StatefulSets, Deployments, storage
- **Observabilité** - Prometheus, Grafana, Loki, alerting
- **Implémentation** - Roadmap 6 phases détaillées
- **Opérations** - Runbook, disaster recovery, troubleshooting
- **Annexes** - Stack CNCF, coûts, risques, tests

---

## 💬 Besoin d'Aide pour Décider ?

Posez-vous ces questions :

1. **Performance** : Les requêtes de graphes (citations) et tendances temporelles sont-elles critiques ?
   - ✅ Oui → **Polyglotte**
   - ❌ Non → **Hybride**

2. **Équipe** : Avez-vous 2-3 personnes IT prêtes à investir 4-6 mois ?
   - ✅ Oui → **Polyglotte**
   - ❌ Non → **Hybride** ou **Évolutif**

3. **Incertitude** : Les besoins utilisateurs sont-ils bien définis ?
   - ✅ Oui → **Polyglotte** ou **Hybride**
   - ❌ Non → **Évolutif**

4. **Horizon** : L'infrastructure sera-t-elle utilisée 5+ ans ?
   - ✅ Oui → **Polyglotte** (ROI long terme)
   - ❌ Non → **Hybride** (simplicité)

---

**Prêt à choisir ?** Consultez la documentation détaillée dans `/docs/` pour approfondir l'option qui vous intéresse.
