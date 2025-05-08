// lib/platform/web_only.dart
import 'package:latlong2/latlong.dart';
import 'dart:html' as html;

Future<LatLng?> getWebPosition() async {
  try {
    final result = await html.window.navigator.geolocation.getCurrentPosition();
    final lat = result.coords?.latitude?.toDouble() ?? 45.06288;
    final lon = result.coords?.longitude?.toDouble() ?? 7.66277;
    return LatLng(lat, lon);
  } catch (e) {
    print("Web geolocation error: $e");
    return null;
  }
}

