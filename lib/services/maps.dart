/*
 * A verseny helyszínét a telefon saját térképében nyitja, útvonaltervezéssel.
 * Először a natív térkép, utána a Google Maps webes útvonala, végül a mentett link.
 */
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';

/// A telefon saját térképprogramja, útvonaltervezéssel.
Future<bool> openDirections(String mapUrl) async {
  final destination = mapDestination(mapUrl);
  final encoded = Uri.encodeComponent(destination);
  final tries = <Uri>[];
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    tries.add(Uri.parse('https://maps.apple.com/?daddr=$encoded&dirflg=d'));
    tries.add(Uri.parse('comgooglemaps://?daddr=$encoded&directionsmode=driving'));
  } else {
    tries.add(Uri.parse('google.navigation:q=$encoded&mode=d'));
    tries.add(Uri.parse('geo:0,0?q=$encoded'));
  }
  tries.add(
    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$encoded&travelmode=driving'),
  );
  if (httpUrl(mapUrl)) {
    tries.add(Uri.parse(mapUrl));
  }
  for (final uri in tries) {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) {
        return true;
      }
    } catch (error) {
      debugPrint('A térkép nem nyílt meg: $uri ($error)');
    }
  }
  return false;
}
