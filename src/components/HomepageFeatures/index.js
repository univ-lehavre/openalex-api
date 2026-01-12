import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

const FeatureList = [
  {
    title: 'Architecture Hybride',
    icon: '🏗️',
    description: (
      <>
        PostgreSQL pour les données structurées et relations, Elasticsearch pour
        la recherche plein texte. Le meilleur des deux mondes pour 3 To de données.
      </>
    ),
  },
  {
    title: 'Performance Optimale',
    icon: '⚡',
    description: (
      <>
        Latence P95 &lt; 500ms, support de 100-500 requêtes/seconde avec cache
        multi-niveaux (Redis) et optimisations d'index avancées.
      </>
    ),
  },
  {
    title: 'Haute Disponibilité',
    icon: '🛡️',
    description: (
      <>
        Déploiement Kubernetes avec réplication, sauvegardes automatisées,
        et stratégie zero-downtime pour 99,9% de disponibilité.
      </>
    ),
  },
];

function Feature({icon, title, description}) {
  return (
    <div className={clsx('col col--4')}>
      <div className="text--center">
        <div className={styles.featureIcon}>{icon}</div>
      </div>
      <div className="text--center padding-horiz--md">
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures() {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
