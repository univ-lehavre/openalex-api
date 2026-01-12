---
id: fastapi-router
title: Router FastAPI Multi-Database
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 0.1.0
status: draft
priority: high
tags: [fastapi, router, python, architecture]
sidebar_label: FastAPI Router
sidebar_position: 2
---

# Router FastAPI Multi-Database

⚠️ **Documentation en cours de rédaction**

## Contexte

Le router FastAPI orchestre les requêtes vers les 4 bases de données (PostgreSQL, Neo4j, InfluxDB, Elasticsearch) en fonction du type de requête et optimise les performances avec Redis cache.

## Objectifs

- [ ] Architecture modulaire avec repositories pattern
- [ ] Connexions asynchrones à toutes les bases
- [ ] Pool de connexions optimisé
- [ ] Circuit breaker pour résilience
- [ ] Observabilité (traces, métriques, logs)
- [ ] Tests unitaires et d'intégration

## Architecture du Router

```python
# Structure du projet
openalex-api/
├── app/
│   ├── main.py                 # FastAPI app
│   ├── api/
│   │   ├── v1/
│   │   │   ├── works.py        # Endpoints works
│   │   │   ├── authors.py      # Endpoints authors
│   │   │   └── ...
│   ├── repositories/
│   │   ├── postgres.py         # PostgreSQL queries
│   │   ├── neo4j.py            # Neo4j Cypher queries
│   │   ├── influxdb.py         # InfluxDB Flux queries
│   │   └── elasticsearch.py    # ES queries
│   ├── services/
│   │   ├── works_service.py    # Business logic
│   │   └── cache_service.py    # Redis cache
│   ├── models/
│   │   ├── works.py            # Pydantic models
│   │   └── ...
│   └── core/
│       ├── config.py           # Configuration
│       ├── database.py         # DB connections
│       └── dependencies.py     # FastAPI dependencies
```

## Exemple d'Implémentation

### 1. Configuration des Connexions

```python
# core/database.py
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from neo4j import AsyncGraphDatabase
from influxdb_client_3 import InfluxDBClient3
from elasticsearch import AsyncElasticsearch
import redis.asyncio as redis

class DatabaseManager:
    def __init__(self):
        # PostgreSQL
        self.pg_engine = create_async_engine(
            "postgresql+asyncpg://user:pass@postgres:5432/openalex",
            pool_size=20,
            max_overflow=10
        )

        # Neo4j
        self.neo4j_driver = AsyncGraphDatabase.driver(
            "bolt://neo4j:7687",
            auth=("neo4j", "password"),
            max_connection_pool_size=50
        )

        # InfluxDB
        self.influx_client = InfluxDBClient3(
            host="http://influxdb:8086",
            token="my-token",
            org="openalex"
        )

        # Elasticsearch
        self.es_client = AsyncElasticsearch(
            ["http://elasticsearch:9200"],
            max_retries=3,
            retry_on_timeout=True
        )

        # Redis
        self.redis_client = redis.Redis(
            host="redis", port=6379,
            decode_responses=True
        )

db = DatabaseManager()
```

### 2. Repository Pattern

```python
# repositories/works_repository.py
from sqlalchemy import select
from typing import List, Optional

class WorksRepository:
    def __init__(self, db: DatabaseManager):
        self.db = db

    async def get_by_id(self, work_id: str) -> Optional[dict]:
        """Récupérer un work depuis PostgreSQL"""
        async with AsyncSession(self.db.pg_engine) as session:
            query = select(Work).where(Work.id == work_id)
            result = await session.execute(query)
            return result.scalar_one_or_none()

    async def search(self, query: str, filters: dict) -> List[dict]:
        """Recherche full-text via Elasticsearch"""
        body = {
            "query": {
                "bool": {
                    "must": {"multi_match": {
                        "query": query,
                        "fields": ["title^3", "abstract"]
                    }},
                    "filter": self._build_filters(filters)
                }
            }
        }
        response = await self.db.es_client.search(
            index="works",
            body=body
        )
        return response["hits"]["hits"]

    async def get_citations(self, work_id: str, depth: int = 1) -> List[dict]:
        """Récupérer citations via Neo4j"""
        async with self.db.neo4j_driver.session() as session:
            query = f"""
            MATCH (w:Work {{id: $work_id}})<-[:CITES*1..{depth}]-(citing:Work)
            RETURN citing.id, citing.title, citing.cited_by_count
            ORDER BY citing.cited_by_count DESC
            LIMIT 100
            """
            result = await session.run(query, work_id=work_id)
            return [record.data() async for record in result]

    async def get_trends(self, concept_id: str, start: str, end: str) -> List[dict]:
        """Récupérer tendances via InfluxDB"""
        query = f'''
        from(bucket: "openalex")
          |> range(start: {start}, stop: {end})
          |> filter(fn: (r) => r.concept_id == "{concept_id}")
          |> aggregateWindow(every: 1mo, fn: sum)
        '''
        result = self.db.influx_client.query(query)
        return result.to_dict('records')
```

### 3. Service Layer avec Cache

```python
# services/works_service.py
from typing import Optional
import json
import hashlib

class WorksService:
    def __init__(self, repo: WorksRepository, cache: redis.Redis):
        self.repo = repo
        self.cache = cache

    async def get_work(self, work_id: str) -> Optional[dict]:
        """Récupérer un work avec cache"""
        # Check cache
        cache_key = f"work:{work_id}"
        cached = await self.cache.get(cache_key)
        if cached:
            return json.loads(cached)

        # Query database
        work = await self.repo.get_by_id(work_id)
        if not work:
            return None

        # Store in cache (24h)
        await self.cache.setex(
            cache_key,
            86400,  # 24 hours
            json.dumps(work)
        )
        return work

    async def search_works(self, query: str, filters: dict, page: int = 1):
        """Recherche avec cache"""
        # Generate cache key from parameters
        cache_key = self._generate_cache_key("search", query, filters, page)
        cached = await self.cache.get(cache_key)
        if cached:
            return json.loads(cached)

        # Query Elasticsearch
        results = await self.repo.search(query, filters)

        # Cache for 1 hour
        await self.cache.setex(cache_key, 3600, json.dumps(results))
        return results

    def _generate_cache_key(self, *args) -> str:
        """Générer une clé de cache unique"""
        key_str = ":".join(str(arg) for arg in args)
        return f"cache:{hashlib.md5(key_str.encode()).hexdigest()}"
```

### 4. API Router

```python
# api/v1/works.py
from fastapi import APIRouter, Depends, Query
from typing import List, Optional

router = APIRouter(prefix="/works", tags=["works"])

@router.get("/")
async def list_works(
    search: Optional[str] = None,
    filter: Optional[str] = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(25, ge=1, le=200),
    service: WorksService = Depends(get_works_service)
):
    """Liste paginée de works avec recherche et filtres"""
    if search:
        results = await service.search_works(search, filter, page)
    else:
        results = await service.list_works(filter, page, per_page)

    return {
        "meta": {
            "count": results["total"],
            "page": page,
            "per_page": per_page
        },
        "results": results["items"]
    }

@router.get("/{work_id}")
async def get_work(
    work_id: str,
    service: WorksService = Depends(get_works_service)
):
    """Détails d'un work"""
    work = await service.get_work(work_id)
    if not work:
        raise HTTPException(status_code=404, detail="Work not found")
    return work

@router.get("/{work_id}/citations")
async def get_citations(
    work_id: str,
    depth: int = Query(1, ge=1, le=3),
    page: int = Query(1, ge=1),
    service: WorksService = Depends(get_works_service)
):
    """Citations d'un work (via Neo4j)"""
    citations = await service.get_citations(work_id, depth, page)
    return {"results": citations}

@router.get("/trends")
async def get_trends(
    concept_id: Optional[str] = None,
    author_id: Optional[str] = None,
    start_date: str = Query(...),
    end_date: str = Query(...),
    service: WorksService = Depends(get_works_service)
):
    """Tendances temporelles (via InfluxDB)"""
    trends = await service.get_trends(
        concept_id=concept_id,
        author_id=author_id,
        start=start_date,
        end=end_date
    )
    return {"results": trends}
```

### 5. Main Application

```python
# main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI(
    title="OpenAlex API",
    version="1.0.0",
    description="API pour interroger les données OpenAlex"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Prometheus metrics
Instrumentator().instrument(app).expose(app)

# Routers
app.include_router(works_router, prefix="/api/v1")
app.include_router(authors_router, prefix="/api/v1")

@app.on_event("startup")
async def startup():
    """Initialize database connections"""
    await db.connect()

@app.on_event("shutdown")
async def shutdown():
    """Close database connections"""
    await db.disconnect()

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "databases": {
            "postgres": await db.check_postgres(),
            "neo4j": await db.check_neo4j(),
            "influxdb": await db.check_influxdb(),
            "elasticsearch": await db.check_elasticsearch()
        }
    }
```

## Circuit Breaker Pattern

```python
# core/circuit_breaker.py
from datetime import datetime, timedelta

class CircuitBreaker:
    """Circuit breaker pour éviter surcharge des bases"""
    def __init__(self, failure_threshold=5, timeout=60):
        self.failure_threshold = failure_threshold
        self.timeout = timeout
        self.failures = 0
        self.last_failure_time = None
        self.state = "CLOSED"  # CLOSED, OPEN, HALF_OPEN

    async def call(self, func, *args, **kwargs):
        if self.state == "OPEN":
            if datetime.now() - self.last_failure_time > timedelta(seconds=self.timeout):
                self.state = "HALF_OPEN"
            else:
                raise Exception("Circuit breaker is OPEN")

        try:
            result = await func(*args, **kwargs)
            if self.state == "HALF_OPEN":
                self.state = "CLOSED"
                self.failures = 0
            return result
        except Exception as e:
            self.failures += 1
            self.last_failure_time = datetime.now()
            if self.failures >= self.failure_threshold:
                self.state = "OPEN"
            raise e
```

## Prochaines Étapes

1. Implémenter tous les repositories (PostgreSQL, Neo4j, InfluxDB, Elasticsearch)
2. Créer les services avec logique métier
3. Écrire les tests unitaires et d'intégration
4. Configurer le déploiement Kubernetes
5. Ajouter observabilité (traces OpenTelemetry)

## Références

- [API Design](./api-design.md)
- [Configuration PostgreSQL](../01-stockage/postgresql.md)
- [Configuration Neo4j](../01-stockage/neo4j.md)
- [Architecture polyglotte](../00-introduction/polyglot-architecture.md)

---

**Statut** : 📝 Brouillon - À compléter avec implémentation complète et tests
