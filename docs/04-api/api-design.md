---
id: api-design
title: Design de l'API REST
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 0.1.0
status: draft
priority: high
tags: [api, rest, fastapi, design]
sidebar_label: API Design
sidebar_position: 1
---

# Design de l'API REST

⚠️ **Documentation en cours de rédaction**

## Contexte

L'API REST OpenAlex doit fournir un accès unifié aux données stockées dans les 4 bases de données (PostgreSQL, Neo4j, InfluxDB, Elasticsearch) avec des performances optimales et une expérience développeur exceptionnelle.

## Objectifs

- [ ] Design RESTful conforme aux standards OpenAPI 3.0
- [ ] Endpoints pour Works, Authors, Institutions, Concepts, Sources
- [ ] Pagination, filtres, tri, recherche sur tous les endpoints
- [ ] Authentification et rate limiting
- [ ] Cache Redis pour performances
- [ ] Documentation interactive (Swagger/ReDoc)

## Architecture API

```text
┌─────────────────────┐
│   FastAPI Router    │
│   (API Gateway)     │
└──────────┬──────────┘
           │
    ┌──────┴──────┬──────────┬──────────┐
    ↓             ↓          ↓          ↓
┌─────────┐  ┌────────┐ ┌────────┐ ┌────────┐
│   PG    │  │ Neo4j  │ │InfluxDB│ │   ES   │
│(Metadata│  │(Graph) │ │(Time)  │ │(Search)│
└─────────┘  └────────┘ └────────┘ └────────┘
```

## Endpoints Principaux

### Works (Articles)

```yaml
GET /works
  Description: Liste paginée d'articles
  Query params:
    - filter: publication_year:2024, type:article, is_oa:true
    - search: machine learning
    - sort: cited_by_count:desc, publication_date:desc
    - page: 1, per_page: 25 (max 200)
  Source: PostgreSQL + Elasticsearch (si search)
  Cache: 1h

GET /works/\{id\}
  Description: Détails d'un article
  Path params: id (OpenAlex ID ou DOI)
  Source: PostgreSQL
  Cache: 24h

GET /works/\{id\}/citations
  Description: Articles qui citent cet article
  Query params: depth (1-3), page, per_page
  Source: Neo4j
  Cache: 6h

GET /works/\{id\}/referenced-works
  Description: Articles cités par cet article
  Source: Neo4j
  Cache: 24h

GET /works/trends
  Description: Tendances de publications au fil du temps
  Query params: concept_id, author_id, granularity (day/month/year)
  Source: InfluxDB
  Cache: 1h
```

### Authors

```yaml
GET /authors
  Description: Liste paginée d'auteurs
  Query params: filter, search, sort, page
  Source: PostgreSQL + Elasticsearch
  Cache: 1h

GET /authors/\{id\}
  Description: Détails d'un auteur
  Source: PostgreSQL
  Cache: 24h

GET /authors/\{id\}/works
  Description: Publications d'un auteur
  Query params: page, per_page, sort
  Source: PostgreSQL
  Cache: 6h

GET /authors/\{id\}/coauthors
  Description: Réseau de collaboration
  Query params: depth (1-2), min_shared_works
  Source: Neo4j
  Cache: 12h

GET /authors/\{id\}/impact
  Description: Évolution de l'impact (h-index, citations)
  Query params: start_date, end_date, granularity
  Source: InfluxDB
  Cache: 6h
```

### Institutions

```yaml
GET /institutions
GET /institutions/\{id\}
GET /institutions/\{id\}/works
GET /institutions/\{id\}/authors
GET /institutions/\{id\}/trends
```

### Concepts

```yaml
GET /concepts
GET /concepts/\{id\}
GET /concepts/\{id\}/works
GET /concepts/\{id\}/related-concepts
GET /concepts/\{id\}/trends
```

### Sources

```yaml
GET /sources
GET /sources/\{id\}
GET /sources/\{id\}/works
```

## Format de Réponse Standard

```json
{
  "meta": {
    "count": 250000000,
    "page": 1,
    "per_page": 25,
    "pages": 10000000
  },
  "results": [
    {
      "id": "https://openalex.org/W2741809807",
      "doi": "https://doi.org/10.7717/peerj.4375",
      "title": "BERT: Pre-training of Deep Bidirectional Transformers",
      "publication_year": 2019,
      "publication_date": "2019-10-11",
      "type": "article",
      "cited_by_count": 15234,
      "open_access": {
        "is_oa": true,
        "oa_status": "gold",
        "oa_url": "https://..."
      },
      "authorships": [...],
      "concepts": [...],
      "primary_location": {...},
      "updated_date": "2024-01-15T10:30:00Z"
    }
  ]
}
```

## Filtres et Recherche

### Syntaxe de Filtres

```text
/works?filter=publication_year:>2020,type:article|review,is_oa:true

Opérateurs:
  : (égal)
  :> (supérieur)
  :< (inférieur)
  :>= :<=
  | (OR)
  , (AND)
```

### Recherche

```text
/works?search=machine learning&search_fields=title,abstract

Options:
  - search_fields: title, abstract, fulltext
  - fuzzy: true (autocorrection)
  - highlight: true (mots surlig nés)
```

## Performance et Cache

### Stratégie de Cache

| Endpoint | TTL | Invalidation |
|----------|-----|--------------|
| /works (liste) | 1h | Update quotidien |
| /works/\{id\} | 24h | Update sur changement |
| /works/\{id\}/citations | 6h | Recalculé nuit |
| /authors/\{id\}/coauthors | 12h | Recalculé semaine |
| /trends | 1h | Update temps réel |

### Rate Limiting

```yaml
Anonymous: 10 req/s, 1000 req/jour
Authenticated: 50 req/s, 100K req/jour
Premium: 200 req/s, illimité
```

## Prochaines Étapes

1. Définir le schéma OpenAPI 3.0 complet
2. Implémenter les routers FastAPI
3. Intégrer Redis pour le cache
4. Ajouter l'authentification JWT
5. Configurer rate limiting avec SlowAPI
6. Déployer sur Kubernetes avec Ingress

## Références

- [Router FastAPI Multi-DB](./fastapi-router.md)
- [Stratégie de cache](./caching-strategy.md)
- [Architecture polyglotte](../00-introduction/polyglot-architecture.md)

---

**Statut** : 📝 Brouillon - À compléter avec schéma OpenAPI et exemples de code FastAPI
