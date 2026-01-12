---
id: partitioning
title: Stratégie de Partitionnement
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 0.1.0
status: draft
priority: medium
tags: [partitionnement, postgresql, performance, optimisation]
sidebar_label: Partitionnement
sidebar_position: 7
---

# Stratégie de Partitionnement

⚠️ **Documentation en cours de rédaction**

## Contexte

Le partitionnement est essentiel pour gérer efficacement les 250M d'articles OpenAlex sur PostgreSQL. Sans partitionnement, les requêtes sur la table `works` (800GB) seraient extrêmement lentes.

## Objectifs

- [ ] Partitionner la table `works` par année de publication
- [ ] Partitionner les tables de jointure (`works_authors`, `works_concepts`)
- [ ] Optimiser les requêtes avec partition pruning
- [ ] Faciliter l'archivage des données anciennes
- [ ] Améliorer les performances de maintenance (VACUUM, ANALYZE)

## Stratégie de Partitionnement

### Table `works` - Partitionnement par Année

```sql
-- Table parent
CREATE TABLE works (
    id TEXT PRIMARY KEY,
    doi TEXT,
    title TEXT,
    publication_year INTEGER NOT NULL,
    publication_date DATE,
    type TEXT,
    cited_by_count INTEGER,
    -- ... autres colonnes
) PARTITION BY RANGE (publication_year);

-- Partitions par année (exemple 2020-2024)
CREATE TABLE works_2020 PARTITION OF works
    FOR VALUES FROM (2020) TO (2021);

CREATE TABLE works_2021 PARTITION OF works
    FOR VALUES FROM (2021) TO (2022);

CREATE TABLE works_2022 PARTITION OF works
    FOR VALUES FROM (2022) TO (2023);

-- ... jusqu'à 2024

-- Partition pour données historiques (< 1900)
CREATE TABLE works_historical PARTITION OF works
    FOR VALUES FROM (MINVALUE) TO (1900);

-- Partition par défaut (données futures)
CREATE TABLE works_default PARTITION OF works DEFAULT;
```

### Répartition des Données

| Période | Nombre d'Articles | Taille Estimée | Partition |
|---------|------------------|----------------|-----------|
| < 1900 | ~500K | ~2 GB | works_historical |
| 1900-1950 | ~5M | ~20 GB | works_1900_1950 |
| 1950-2000 | ~30M | ~120 GB | Par décennie (5 partitions) |
| 2000-2010 | ~40M | ~160 GB | Par 5 ans (2 partitions) |
| 2010-2024 | ~170M | ~500 GB | Par année (14 partitions) |
| **Total** | **250M** | **~800 GB** | **~25 partitions** |

### Tables de Jointure

```sql
-- works_authors partitionnée par année de publication
CREATE TABLE works_authors (
    work_id TEXT NOT NULL,
    author_id TEXT NOT NULL,
    author_position INTEGER,
    publication_year INTEGER NOT NULL,
    PRIMARY KEY (work_id, author_id)
) PARTITION BY RANGE (publication_year);

-- works_concepts partitionnée par année de publication
CREATE TABLE works_concepts (
    work_id TEXT NOT NULL,
    concept_id TEXT NOT NULL,
    score FLOAT,
    publication_year INTEGER NOT NULL,
    PRIMARY KEY (work_id, concept_id)
) PARTITION BY RANGE (publication_year);
```

## Avantages du Partitionnement

### Performance des Requêtes

**Sans partitionnement** :
```sql
-- Scan complet de 250M lignes
SELECT COUNT(*) FROM works
WHERE publication_year BETWEEN 2020 AND 2024;
-- Temps: ~30-60 secondes
```

**Avec partitionnement** :
```sql
-- Scan uniquement de 5 partitions (~70M lignes)
SELECT COUNT(*) FROM works
WHERE publication_year BETWEEN 2020 AND 2024;
-- Temps: ~5-10 secondes (partition pruning automatique)
```

### Maintenance Optimisée

```sql
-- VACUUM/ANALYZE uniquement sur la partition de l'année en cours
VACUUM ANALYZE works_2024;

-- Création d'index en parallèle par partition
CREATE INDEX CONCURRENTLY idx_works_2024_cited_by_count
    ON works_2024 (cited_by_count DESC);
```

### Archivage Facilité

```sql
-- Détacher une partition ancienne pour archivage
ALTER TABLE works DETACH PARTITION works_historical;

-- Déplacer vers stockage HDD (Ceph pool HDD)
-- puis réattacher en READ ONLY
ALTER TABLE works ATTACH PARTITION works_historical_archived
    FOR VALUES FROM (MINVALUE) TO (1900);
```

## Index par Partition

```sql
-- Index sur chaque partition (création automatique)
CREATE INDEX idx_works_doi ON works (doi);
-- Crée automatiquement:
--   idx_works_2020_doi, idx_works_2021_doi, ...

-- Index conditionnel sur partitions récentes uniquement
CREATE INDEX idx_works_2024_title_trgm
    ON works_2024 USING gin (title gin_trgm_ops);
```

## Migration des Données Existantes

```sql
-- 1. Créer la nouvelle table partitionnée
CREATE TABLE works_partitioned (...) PARTITION BY RANGE (publication_year);

-- 2. Créer toutes les partitions

-- 3. Migrer les données par batch
INSERT INTO works_partitioned
SELECT * FROM works_old
WHERE publication_year = 2024;

-- 4. Vérifier l'intégrité
SELECT publication_year, COUNT(*)
FROM works_partitioned
GROUP BY publication_year;

-- 5. Renommer les tables
ALTER TABLE works RENAME TO works_old_backup;
ALTER TABLE works_partitioned RENAME TO works;
```

## Prochaines Étapes

1. Définir les bornes exactes des partitions selon distribution réelle
2. Créer un script de génération automatique des partitions
3. Tester la migration avec un sous-ensemble de données
4. Documenter la procédure de création de nouvelles partitions annuelles
5. Automatiser la maintenance par partition

## Références

- [Configuration PostgreSQL](./postgresql.md)
- [Stratégie de stockage globale](./strategy.md)
- [PostgreSQL Partitioning Documentation](https://www.postgresql.org/docs/current/ddl-partitioning.html)

---

**Statut** : 📝 Brouillon - À compléter avec scripts SQL et procédures de migration
