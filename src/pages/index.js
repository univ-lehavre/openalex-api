import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import HomepageFeatures from '@site/src/components/HomepageFeatures';

import styles from './index.module.css';

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className={clsx('hero hero--primary', styles.heroBanner)}>
      <div className="container">
        <h1 className="hero__title">{siteConfig.title}</h1>
        <p className="hero__subtitle">{siteConfig.tagline}</p>
        <div className={styles.buttons}>
          <Link
            className="button button--secondary button--lg"
            to="/docs/00-introduction/overview">
            Découvrir la Documentation 📚
          </Link>
        </div>
      </div>
    </header>
  );
}

export default function Home() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={`Accueil`}
      description="Documentation technique de l'API OpenAlex - 3 To de données bibliographiques sur Kubernetes">
      <HomepageHeader />
      <main>
        <HomepageFeatures />
        <section className={styles.stats}>
          <div className="container">
            <div className="row">
              <div className="col col--3">
                <div className={styles.stat}>
                  <div className={styles.statNumber}>3 To</div>
                  <div className={styles.statLabel}>Données OpenAlex</div>
                </div>
              </div>
              <div className="col col--3">
                <div className={styles.stat}>
                  <div className={styles.statNumber}>&lt; 500ms</div>
                  <div className={styles.statLabel}>Latence P95</div>
                </div>
              </div>
              <div className="col col--3">
                <div className={styles.stat}>
                  <div className={styles.statNumber}>99,9%</div>
                  <div className={styles.statLabel}>Disponibilité</div>
                </div>
              </div>
              <div className="col col--3">
                <div className={styles.stat}>
                  <div className={styles.statNumber}>250M+</div>
                  <div className={styles.statLabel}>Articles</div>
                </div>
              </div>
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
