// @ts-check
// Note: type annotations allow type checking and IDEs autocompletion

const {themes} = require('prism-react-renderer');
const lightCodeTheme = themes.github;
const darkCodeTheme = themes.dracula;

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'API OpenAlex',
  tagline: 'Documentation technique - Infrastructure 3To de données JSON sur Kubernetes',
  favicon: 'img/favicon.ico',

  // Set the production url of your site here
  url: 'https://openalex-api.univ-lehavre.fr',
  // Set the /<baseUrl>/ pathname under which your site is served
  baseUrl: '/',

  // GitHub pages deployment config
  organizationName: 'univ-lehavre',
  projectName: 'openalex-api',

  onBrokenLinks: 'warn',
  onBrokenMarkdownLinks: 'warn',

  // Internationalisation
  i18n: {
    defaultLocale: 'fr',
    locales: ['fr'],
    localeConfigs: {
      fr: {
        label: 'Français',
        direction: 'ltr',
        htmlLang: 'fr-FR',
        calendar: 'gregory',
      },
    },
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          // Remove this to remove the "edit this page" links.
          editUrl: 'https://github.com/univ-lehavre/openalex-api/tree/main/',
          showLastUpdateTime: true,
          showLastUpdateAuthor: true,
        },
        blog: false, // Désactiver le blog
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      // Replace with your project's social card
      image: 'img/openalex-social-card.png',
      navbar: {
        title: 'API OpenAlex',
        logo: {
          alt: 'Logo Université Le Havre Normandie',
          src: 'img/logo.svg',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'docsSidebar',
            position: 'left',
            label: 'Documentation',
          },
          {
            href: 'https://github.com/univ-lehavre/openalex-api',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Documentation',
            items: [
              {
                label: 'Introduction',
                to: '/docs/00-introduction/overview',
              },
              {
                label: 'Architecture',
                to: '/docs/01-stockage/strategy',
              },
              {
                label: 'Implémentation',
                to: '/docs/08-implementation/roadmap',
              },
            ],
          },
          {
            title: 'Ressources',
            items: [
              {
                label: 'OpenAlex',
                href: 'https://openalex.org',
              },
              {
                label: 'OpenAlex API',
                href: 'https://docs.openalex.org',
              },
              {
                label: 'Université Le Havre Normandie',
                href: 'https://www.univ-lehavre.fr',
              },
            ],
          },
          {
            title: 'Plus',
            items: [
              {
                label: 'GitHub',
                href: 'https://github.com/univ-lehavre/openalex-api',
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Université Le Havre Normandie. Documentation générée avec Docusaurus.`,
      },
      prism: {
        theme: lightCodeTheme,
        darkTheme: darkCodeTheme,
        additionalLanguages: ['bash', 'yaml', 'json', 'python', 'javascript', 'sql'],
      },
      docs: {
        sidebar: {
          hideable: true,
          autoCollapseCategories: true,
        },
      },
      colorMode: {
        defaultMode: 'light',
        disableSwitch: false,
        respectPrefersColorScheme: true,
      },
    }),
};

module.exports = config;
