/// A teamreg.vzsfoto.hu mobil kliense.
///
/// A [googleServerClientId] a webes OAuth-kliens. A telefon erről kér
/// azonosító tokent, ezt ellenőrzi az API a GOOGLE_CLIENT_ID alapján.
class ApiConfig {
  /// CakePHP ApiV1, kötőjeles előtag: /api-v1/*.json
  static const baseUrl = 'https://teamreg.vzsfoto.hu/api-v1';

  /// Nyilvános webes OAuth-kliens. A titkos kulcs nem kerül az alkalmazásba.
  static const googleServerClientId =
      '663330869081-v8if05jn3sgsvmacgd0m3u2drlvm5s3q.apps.googleusercontent.com';

  /// Sötét klubháttér, a splash és a sötét téma alapja.
  static const brandColor = 0xFF100E0C;
}
