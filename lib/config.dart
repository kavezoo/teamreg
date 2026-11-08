/// A teamreg.vzsfoto.hu mobil kliense.
///
/// A [googleServerClientId] a webes OAuth-kliens. A telefon erről kér
/// azonosító tokent, ezt ellenőrzi az API a GOOGLE_CLIENT_ID alapján.
class ApiConfig {
  static const baseUrl = 'https://teamreg.vzsfoto.hu/api-v1';

  static const googleServerClientId =
      '663330869081-v8if05jn3sgsvmacgd0m3u2drlvm5s3q.apps.googleusercontent.com';

  static const brandColor = 0xFF100E0C;
}
