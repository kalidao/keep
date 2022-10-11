// theme.config.js
export default {
    projectLink: 'https://github.com/kalidao/keep', // GitHub link in the navbar
    docsRepositoryBase: 'https://github.com/kalidao/keep/tree/main/docs', // base URL for the docs repository
    titleSuffix: ' – Keep',
    nextLinks: true,
    prevLinks: true,
    search: true,
    customSearch: null, // customizable, you can use algolia for example
    darkMode: true,
    footer: true,
    footerText: `MIT ${new Date().getFullYear()} © Kali Co, Inc.`,
    footerEditLink: ` Edit this page on GitHub`,
    logo: (
        <>
            <svg>...</svg>
            <span>Keep</span>
        </>
    ),
    head: (
        <>
            <meta name="viewport" content="width=device-width, initial-scale=1.0" />
            <meta name="description" content="Keep: " />
            <meta name="og:title" content="Keep: " />
        </>
    ),
}