class ShareLinkService {
  static const String _host = '5nmg.l.time4vps.cloud';

  static Uri shop(int shopId) => Uri(
    scheme: 'https',
    host: _host,
    path: '/fopcam/',
    fragment: '/shop?shopId=$shopId',
  );

  static Uri product(int productId) => Uri(
    scheme: 'https',
    host: _host,
    path: '/fopcam/',
    fragment: '/product?productId=$productId',
  );

  static String get installHint =>
      'Ouvrez le lien dans FopCam. Si l’application n’est pas installée, '
      'utilisez l’option « Installer l’application » ou « Ajouter à l’écran '
      'd’accueil » de votre navigateur.';
}
