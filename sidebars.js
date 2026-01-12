/**
 * Creating a sidebar enables you to:
 - create an ordered group of docs
 - render a sidebar for each doc of that group
 - provide next/previous navigation

 The sidebars can be generated from the filesystem, or explicitly defined here.

 Create as many sidebars as you want.
 */

// @ts-check

/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docsSidebar: [
    {
      type: 'category',
      label: '📋 Introduction',
      collapsed: false,
      items: [
        'introduction/overview',
        'introduction/architecture-decision',
        'introduction/architecture-options',
        'introduction/polyglot-architecture',
        'introduction/success-metrics',
      ],
    },
    {
      type: 'category',
      label: '💾 Stockage',
      collapsed: true,
      items: [
        'stockage/strategy',
        'stockage/rook-ceph',
        // Modules à créer - décommenter quand prêts
        // 'stockage/postgresql',
        // 'stockage/neo4j',
        // 'stockage/influxdb',
        // 'stockage/elasticsearch',
        // 'stockage/partitioning',
        // 'stockage/backup-recovery',
      ],
    },
    // Décommenter les catégories suivantes au fur et à mesure de la création des modules
    /*
    {
      type: 'category',
      label: '🔍 Indexation',
      collapsed: true,
      items: [
        'indexation/overview',
        'indexation/postgresql-indexes',
        'indexation/elasticsearch-mapping',
        'indexation/materialized-views',
      ],
    },
    {
      type: 'category',
      label: '🔎 Recherche',
      collapsed: true,
      items: [
        'recherche/search-architecture',
        'recherche/full-text-search',
        'recherche/structured-queries',
        'recherche/graph-queries',
        'recherche/analytics',
      ],
    },
    {
      type: 'category',
      label: '🚀 API',
      collapsed: true,
      items: [
        'api/api-design',
        'api/fastapi-implementation',
        'api/caching-strategy',
        'api/rate-limiting',
        'api/authentication',
      ],
    },
    {
      type: 'category',
      label: '📥 Ingestion de Données',
      collapsed: true,
      items: [
        'ingestion/etl-pipeline',
        'ingestion/airflow-dag',
        'ingestion/transformation',
        'ingestion/loading',
        'ingestion/zero-downtime',
      ],
    },
    {
      type: 'category',
      label: '☸️ Kubernetes',
      collapsed: true,
      items: [
        'kubernetes/cluster-architecture',
        'kubernetes/resource-planning',
        'kubernetes/statefulsets',
        'kubernetes/deployments',
        'kubernetes/storage-provisioning',
      ],
    },
    {
      type: 'category',
      label: '📊 Observabilité',
      collapsed: true,
      items: [
        'observabilite/monitoring-stack',
        'observabilite/key-metrics',
        'observabilite/dashboards',
        'observabilite/alerting',
        'observabilite/logging',
      ],
    },
    {
      type: 'category',
      label: '🏗️ Implémentation',
      collapsed: true,
      items: [
        'implementation/roadmap',
        'implementation/phase-1-foundations',
        'implementation/phase-2-database',
        'implementation/phase-3-api',
        'implementation/phase-4-etl',
        'implementation/phase-5-production',
        'implementation/phase-6-launch',
      ],
    },
    {
      type: 'category',
      label: '⚙️ Opérations',
      collapsed: true,
      items: [
        'operations/runbook',
        'operations/disaster-recovery',
        'operations/troubleshooting',
        'operations/maintenance',
      ],
    },
    {
      type: 'category',
      label: '📚 Annexes',
      collapsed: true,
      items: [
        'annexes/cncf-stack',
        'annexes/technology-stack',
        'annexes/cost-estimation',
        'annexes/risk-mitigation',
        'annexes/critical-files',
        'annexes/verification-tests',
      ],
    },
    */
  ],
};

module.exports = sidebars;
