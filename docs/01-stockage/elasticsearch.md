---
id: elasticsearch
title: Configuration Elasticsearch
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 0.1.0
status: draft
priority: high
tags: [elasticsearch, recherche, full-text, indexation]
sidebar_label: Elasticsearch
sidebar_position: 6
---

# Configuration Elasticsearch

⚠️ **Documentation en cours de rédaction**

## Contexte

Elasticsearch est le moteur de recherche plein texte pour interroger les métadonnées OpenAlex :
- **Recherche d'articles** : Par titre, résumé, mots-clés
- **Recherche d'auteurs** : Par nom, affiliation
- **Recherche d'institutions** : Par nom, type, pays
- **Autocomplete** : Suggestions en temps réel
- **Filtres facettés** : Par année, type, concept, open access

## Objectifs

- [ ] Configuration cluster Elasticsearch 3 nœuds
- [ ] Mapping optimisé pour chaque type d'entité
- [ ] Stratégie de sharding (par année ou par type)
- [ ] Index sur titre, résumé, auteurs, institutions
- [ ] Analyseurs personnalisés (multilangue, stemming)
- [ ] Requêtes complexes avec scoring personnalisé

## Spécifications Prévues

### Stockage
- **Volume** : 2.1 TB (1.3TB données + 800GB marge)
- **Type** : NVMe via Rook/Ceph (rook-ceph-nvme)
- **Shards** : 3× 700GB par nœud
- **Réplication** : Factor 1 (3 nœuds → haute disponibilité)

### Ressources
- **CPU** : 8 cores par nœud (24 total)
- **RAM** : 32 GB par nœud (96 GB total)
- **Heap** : 16 GB par nœud (50% de RAM)

### Index Principaux

```yaml
Index: works
  Shards: 10
  Replicas: 1
  Documents: 250M
  Size: ~800GB
  Fields:
    - title (text, analyzed)
    - abstract (text, analyzed)
    - doi (keyword)
    - publication_year (integer)
    - cited_by_count (integer)
    - open_access.is_oa (boolean)
    - authorships.author.display_name (text)
    - concepts.display_name (text)

Index: authors
  Shards: 5
  Replicas: 1
  Documents: 90M
  Size: ~300GB
  Fields:
    - display_name (text + keyword)
    - last_known_institution (text)
    - works_count (integer)
    - cited_by_count (integer)

Index: institutions
  Shards: 1
  Replicas: 1
  Documents: 100K
  Size: ~50MB
  Fields:
    - display_name (text + keyword)
    - country_code (keyword)
    - type (keyword)
```

## Cas d'Usage

### Recherche Plein Texte
```json
GET /works/_search
{
  "query": {
    "multi_match": {
      "query": "machine learning neural networks",
      "fields": ["title^3", "abstract^2", "concepts.display_name"],
      "type": "best_fields",
      "fuzziness": "AUTO"
    }
  },
  "size": 20,
  "sort": [
    { "_score": "desc" },
    { "cited_by_count": "desc" }
  ]
}
```

### Autocomplete
```json
GET /authors/_search
{
  "suggest": {
    "author-suggest": {
      "prefix": "Geoff Hin",
      "completion": {
        "field": "display_name.suggest",
        "size": 10,
        "fuzzy": { "fuzziness": 2 }
      }
    }
  }
}
```

### Filtres Facettés
```json
GET /works/_search
{
  "query": {
    "bool": {
      "must": { "match": { "title": "climate change" }},
      "filter": [
        { "range": { "publication_year": { "gte": 2020 }}},
        { "term": { "open_access.is_oa": true }},
        { "terms": { "type": ["article", "review"] }}
      ]
    }
  },
  "aggs": {
    "by_year": { "terms": { "field": "publication_year" }},
    "by_concept": { "terms": { "field": "concepts.display_name.keyword", "size": 20 }}
  }
}
```

## Prochaines Étapes

1. Définir les mappings complets pour chaque index
2. Configurer les analyseurs personnalisés
3. Implémenter la stratégie de sharding
4. Créer le pipeline d'indexation depuis PostgreSQL
5. Tester les performances de recherche

## Références

- [Stratégie de stockage globale](./strategy.md)
- [Configuration Rook/Ceph](./rook-ceph.md)
- [Architecture polyglotte](../00-introduction/polyglot-architecture.md)
- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/)

---

**Statut** : 📝 Brouillon - À compléter avec mappings, analyseurs, et StatefulSet
