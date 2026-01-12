---
id: neo4j
title: Configuration Neo4j
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 0.1.0
status: draft
priority: high
tags: [neo4j, graphe, citations, base-de-données]
sidebar_label: Neo4j
sidebar_position: 4
---

# Configuration Neo4j

⚠️ **Documentation en cours de rédaction**

## Contexte

Neo4j est la base de données graphe pour stocker et interroger les relations de citations et collaborations :
- **Nœuds Works** : 250M articles
- **Relations CITES** : 2B citations
- **Relations AUTHORED_BY** : 500M relations auteur-article
- **Relations COLLABORATES_WITH** : Dérivées des co-auteurs

## Objectifs

- [ ] Configuration StatefulSet Kubernetes avec Rook/Ceph
- [ ] Modèle de graphe optimisé pour requêtes de citations
- [ ] Import des 2B relations depuis données OpenAlex
- [ ] Index sur propriétés clés (DOI, OpenAlex ID)
- [ ] Requêtes Cypher pour analyses bibliométriques
- [ ] Algorithmes de graphe (PageRank, Louvain, centralité)

## Spécifications Prévues

### Stockage
- **Volume** : 650 GB (610GB données + 40GB marge)
- **Type** : NVMe via Rook/Ceph (rook-ceph-nvme)
- **Ratio** : ~300 bytes/relation en moyenne

### Ressources
- **CPU** : 8-12 cores
- **RAM** : 48 GB (dbms.memory.pagecache.size: 32GB, dbms.memory.heap.max_size: 16GB)

### Modèle de Graphe

```cypher
// Nœuds
(:Work {id, doi, title, publication_year, cited_by_count})
(:Author {id, display_name, works_count, cited_by_count})

// Relations
(:Work)-[:CITES]->(:Work)
(:Author)-[:AUTHORED]->(:Work)
(:Author)-[:COLLABORATES_WITH]->(:Author)
```

## Cas d'Usage

### Citations Multi-Niveaux
```cypher
// Trouver tous les articles qui citent un article (niveau 3)
MATCH (w:Work {doi: '10.1234/example'})<-[:CITES*1..3]-(citing:Work)
RETURN citing.title, citing.publication_year
ORDER BY citing.cited_by_count DESC
LIMIT 100
```

**Performance attendue** : 5-50ms vs 2-5s avec PostgreSQL

### Réseau de Collaboration
```cypher
// Trouver les co-auteurs d'un auteur (distance 2)
MATCH (a:Author {id: 'A1234567890'})-[:AUTHORED]->(w:Work)<-[:AUTHORED]-(coauthor:Author)
RETURN coauthor.display_name, COUNT(w) as shared_papers
ORDER BY shared_papers DESC
LIMIT 20
```

### Algorithmes de Graphe
```cypher
// PageRank pour identifier les articles les plus influents
CALL gds.pageRank.stream('citation-graph')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).title AS article, score
ORDER BY score DESC LIMIT 100
```

## Prochaines Étapes

1. Concevoir le modèle de graphe complet
2. Définir la stratégie d'import des 2B relations
3. Identifier les index Neo4j nécessaires
4. Implémenter les requêtes Cypher pour l'API
5. Benchmarker les performances vs PostgreSQL

## Références

- [Stratégie de stockage globale](./strategy.md)
- [Configuration Rook/Ceph](./rook-ceph.md)
- [Architecture polyglotte](../00-introduction/polyglot-architecture.md)
- [Neo4j Graph Data Science Library](https://neo4j.com/docs/graph-data-science/)

---

**Statut** : 📝 Brouillon - À compléter avec modèle Cypher, StatefulSet, et stratégie d'import
