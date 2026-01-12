# Guide de Démarrage Rapide

## 🎉 Félicitations !

Votre documentation modulaire Docusaurus pour l'API OpenAlex est maintenant configurée et prête à l'emploi.

## ✅ Ce qui a été créé

### Configuration de Base
- ✅ **package.json** - Dépendances Docusaurus 3.x
- ✅ **docusaurus.config.js** - Configuration complète en français
- ✅ **sidebars.js** - Navigation par 11 domaines fonctionnels
- ✅ **src/** - Composants React et styles personnalisés
- ✅ **static/** - Assets statiques (logo, favicon)
- ✅ **.gitignore** - Exclusions Git

### Documentation Créée (4 modules complets)

#### 00-introduction/
- ✅ **overview.md** - Vue d'ensemble du projet, contexte, objectifs
- ✅ **architecture-decision.md** - Justification architecture hybride
- ✅ **success-metrics.md** - KPIs, SLA, métriques de performance

#### 01-stockage/
- ✅ **strategy.md** - Distribution 3 To, blue-green, récapitulatif

### Structure Préparée (30+ modules à documenter)

Les dossiers et navigation sont créés pour :
- **02-indexation/** (4 modules)
- **03-recherche/** (5 modules)
- **04-api/** (5 modules)
- **05-ingestion/** (5 modules)
- **06-kubernetes/** (5 modules)
- **07-observabilite/** (5 modules)
- **08-implementation/** (7 modules)
- **09-operations/** (4 modules)
- **10-annexes/** (5 modules)

## 🚀 Lancer la Documentation

```bash
# Installer les dépendances (si pas déjà fait)
npm install

# Démarrer le serveur de développement
npm start
```

Accéder à : **http://localhost:3000**

## 📝 Créer un Nouveau Module

### 1. Créer le fichier Markdown

```bash
# Exemple : créer le module PostgreSQL
touch docs/01-stockage/postgresql.md
```

### 2. Ajouter les métadonnées YAML

```yaml
---
id: postgresql
title: Configuration PostgreSQL
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 1.0.0
status: draft
priority: high
tags: [postgresql, base-de-données, configuration]
categories: [stockage, technique]
dependencies: [01-stockage/strategy.md]
sidebar_label: PostgreSQL
sidebar_position: 2
---

# Configuration PostgreSQL

Votre contenu ici...
```

### 3. Le module apparaît automatiquement dans la navigation !

## 📊 Statut des Métadonnées

Chaque module utilise ces métadonnées :

| Champ | Valeurs | Usage |
|-------|---------|-------|
| **status** | draft / review / approved | État de validation |
| **priority** | high / medium / low | Criticité |
| **tags** | Array de strings | Taxonomie, recherche |
| **categories** | Array de strings | Organisation |
| **dependencies** | Array de paths | Liens entre modules |

## 🎨 Personnalisation

### Modifier les Couleurs

Éditer `src/css/custom.css` :

```css
:root {
  --ifm-color-primary: #0066cc; /* Couleur principale */
}
```

### Modifier le Logo

Remplacer `static/img/logo.svg` par votre logo

### Modifier le Titre

Éditer `docusaurus.config.js` :

```javascript
title: 'Votre Titre',
tagline: 'Votre sous-titre',
```

## 📦 Build pour Production

```bash
# Construire le site statique
npm run build

# Tester le build localement
npm run serve
```

Les fichiers statiques seront dans `build/`

## 🚀 Déploiement

### GitHub Pages

1. Configurer GitHub Pages dans les settings du repo
2. Créer `.github/workflows/deploy.yml` :

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
      - run: npm install
      - run: npm run build
      - uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./build
```

### Netlify

1. Connecter votre repo GitHub à Netlify
2. Configuration :
   - **Build command**: `npm run build`
   - **Publish directory**: `build`

## 📚 Compléter la Documentation

### Ordre de Priorité Recommandé

1. **Domaine Stockage (01)** - Fondamental
   - postgresql.md
   - elasticsearch.md
   - partitioning.md
   - backup-recovery.md

2. **Domaine API (04)** - Interface principale
   - api-design.md
   - fastapi-implementation.md
   - caching-strategy.md

3. **Domaine Kubernetes (06)** - Infrastructure
   - cluster-architecture.md
   - statefulsets.md
   - deployments.md

4. **Domaine Implémentation (08)** - Roadmap
   - roadmap.md
   - phase-1 à phase-6

5. **Autres domaines** - Compléter selon besoins

## 🔗 Ressources Utiles

- [Docusaurus Documentation](https://docusaurus.io/docs)
- [Markdown Guide](https://www.markdownguide.org/)
- [OpenAlex Documentation](https://docs.openalex.org)
- [Plan d'action détaillé](.claude/plans/swirling-growing-zebra.md)

## 💡 Conseils

### Pour les Diagrammes

Utilisez des blocs de code avec ` ```text ` pour les diagrammes ASCII :

````markdown
```text
┌──────────────┐
│  PostgreSQL  │
└──────┬───────┘
       │
┌──────▼───────┐
│     API      │
└──────────────┘
```
````

### Pour les Exemples de Code

Spécifiez le langage pour la coloration syntaxique :

````markdown
```sql
SELECT * FROM works WHERE publication_year = 2020;
```

```python
from fastapi import FastAPI
app = FastAPI()
```

```yaml
apiVersion: v1
kind: Service
```
````

### Pour les Tableaux

Utilisez la syntaxe Markdown :

```markdown
| Colonne 1 | Colonne 2 |
|-----------|-----------|
| Valeur 1  | Valeur 2  |
```

## 🎯 Prochaines Étapes

1. ✅ Démarrer le serveur : `npm start`
2. 📝 Compléter les modules de documentation
3. 🎨 Personnaliser le thème si nécessaire
4. 🚀 Déployer sur GitHub Pages ou Netlify
5. 📢 Partager avec l'équipe !

## 🤝 Support

Des questions ? Consultez :
- La [documentation Docusaurus](https://docusaurus.io/docs)
- Le [plan d'action complet](.claude/plans/swirling-growing-zebra.md)
- Les modules d'exemple dans `docs/00-introduction/`

---

**Bonne documentation ! 📚✨**
