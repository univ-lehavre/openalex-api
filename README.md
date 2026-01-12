# API OpenAlex - Documentation Technique

[![DOI](https://zenodo.org/badge/1132817023.svg)](https://doi.org/10.5281/zenodo.18223656)
[![Documentation](https://img.shields.io/badge/docs-Docusaurus-blue)](https://docusaurus.io)
[![Licence](https://img.shields.io/badge/licence-MIT-green)](LICENSE)
[![Status](https://img.shields.io/badge/status-en%20développement-yellow)]()

Documentation technique du projet d'API OpenAlex de l'Université Le Havre Normandie - Infrastructure pour servir 3 To de données JSON sur Kubernetes.

## 📋 Vue d'Ensemble

Ce dépôt contient la documentation complète du projet d'infrastructure pour l'API OpenAlex :

- **Architecture hybride** : PostgreSQL + Elasticsearch
- **Infrastructure** : Cluster Kubernetes de 4 serveurs (dirqual1-4)
  - 160 cœurs physiques, 320 threads
  - 1 To RAM
  - 284 To stockage (13,6 To NVMe SSD + 270 To HDD)
- **Volume de données** : 3 To de données bibliographiques OpenAlex
- **Performance cible** : < 500ms P95, 100-500 req/s
- **Implémentation** : 20 semaines (6 phases)

## 📚 Structure de la Documentation

La documentation est organisée en **11 domaines fonctionnels** avec Docusaurus.

Voir la [documentation complète](docs/) pour tous les modules disponibles.

## 🚀 Démarrage Rapide

### Prérequis

- **Node.js** 18+ ([Télécharger](https://nodejs.org))
- **npm** ou **yarn**

### Installation

```bash
# Installer les dépendances
npm install

# Lancer le serveur de développement
npm start
```

📖 **Documentation accessible à** : http://localhost:3000

> 💡 Ouvrez cette URL dans votre navigateur pour explorer la documentation interactive

### Build pour Production

```bash
# Construire le site statique
npm run build

# Prévisualiser le build
npm run serve
```

## 📖 Modules de Documentation

**Disponibles** :
- ✅ Introduction : Vue d'ensemble, architecture, métriques
- ✅ Stockage : Stratégie globale, PostgreSQL, Elasticsearch

**À créer** (structure existante) :
- 📝 Indexation, Recherche, API, Ingestion
- 📝 Kubernetes, Observabilité, Implémentation
- 📝 Opérations, Annexes

## 🏗️ Architecture

### Stack Technologique

| Composant | Technologie | Rôle |
|-----------|-------------|------|
| **Base de données** | PostgreSQL 16 | Stockage principal |
| **Recherche** | Elasticsearch 8.11 | Recherche plein texte |
| **API** | FastAPI | Framework API async |
| **Cache** | Redis 7 | Cache distribué |
| **ETL** | Apache Airflow 2.8 | Orchestration |
| **Monitoring** | Prometheus/Grafana | Observabilité |
| **Orchestration** | Kubernetes 1.28+ | Infrastructure |

## 📊 Métriques de Succès

| Métrique | Objectif |
|----------|----------|
| **Latence P95** | < 500ms |
| **Throughput** | 100-500 req/s |
| **Disponibilité** | 99,9% |
| **Pipeline ETL** | < 48h |

## 🎯 Roadmap

- **Phase 1** : Fondations (3 sem) - Cluster K8s + monitoring
- **Phase 2** : Base de données (4 sem) - PostgreSQL + Elasticsearch
- **Phase 3** : API (4 sem) - FastAPI avec cache
- **Phase 4** : Pipeline ETL (4 sem) - Airflow + chargement 3 To
- **Phase 5-6** : Production & Lancement (5 sem)

## 🤝 Contribution

1. Fork le dépôt
2. Créer une branche : `git checkout -b feature/nouvelle-doc`
3. Commiter : `git commit -m 'Ajout documentation X'`
4. Ouvrir une Pull Request

## 📄 Licence

Projet sous licence MIT - Université Le Havre Normandie

## 🔗 Ressources

- [OpenAlex Documentation](https://docs.openalex.org)
- [Plan d'action détaillé](.claude/plans/swirling-growing-zebra.md)
- [Docusaurus](https://docusaurus.io/docs)

---

**Équipe Infrastructure - Université Le Havre Normandie** | Version 1.0.0 | 2026-01-12
