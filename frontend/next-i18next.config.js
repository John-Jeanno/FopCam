module.exports = {
  i18n: {
    defaultLocale: 'fr',
    locales: ['fr', 'en', 'es'],
  },
  localePath: typeof window === 'undefined'
    ? require('path').resolve('./public/locales')
    : `${process.env.NEXT_PUBLIC_BASE_PATH || ''}/locales`,
}