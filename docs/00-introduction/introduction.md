---
slug: /
id: intro
title: Bienvenue
sidebar_label: Accueil
sidebar_position: 0
---

# Documentation API OpenAlex

Bienvenue dans la documentation technique du projet **API OpenAlex** de l'Université Le Havre Normandie.

## 🎯 Objectif du Projet

Construire une infrastructure API performante pour servir **3 To de données bibliographiques OpenAlex** sur un cluster Kubernetes auto-géré.

## 📊 Chiffres Clés

- **250M+** articles scientifiques
- **90M+** auteurs
- **3 To** de données JSON
- **< 500ms** latence P95
- **99,9%** disponibilité cible

## 🏗️ Architecture

Notre approche hybride combine :
- **PostgreSQL 16** pour le stockage structuré et les relations
- **Elasticsearch 8.11** pour la recherche plein texte
- **FastAPI** pour une API REST performante
- **Kubernetes** pour l'orchestration

## 📚 Navigation

### Pour Commencer
- [Vue d'Ensemble](overview) - Contexte et objectifs
- [Décision d'Architecture](architecture-decision) - Pourquoi cette architecture ?
- [Métriques de Succès](success-metrics) - Comment mesurer la réussite

### Documentation Technique
- [**Stockage**](/docs/stockage/strategy) - Stratégie de stockage des 3 To
- **Indexation** - Optimisation des index (à venir)
- **Recherche** - 4 patterns de requêtes (à venir)
- **API** - Design et implémentation FastAPI (à venir)
- **Kubernetes** - Déploiement et opérations (à venir)

### Implémentation
- **Roadmap** - Plan d'implémentation en 6 phases (à venir)
- **Opérations** - Runbook et procédures (à venir)

## 🚀 État du Projet

**Statut actuel** : Phase de planification (Phase 0)

**Prochaine étape** : Phase 1 - Fondations (Semaines 1-3)

---

**Version** : 1.0.0
**Dernière mise à jour** : 2026-01-12
**Équipe** : Infrastructure - Université Le Havre Normandie
