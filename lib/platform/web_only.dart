// lib/platform/web_only.dart
import 'package:latlong2/latlong.dart';
import 'dart:html' as html;

Future<LatLng?> getWebPosition() async {
  try {
    final result = await html.window.navigator.geolocation.getCurrentPosition();
    return LatLng(result.coords?.latitude ?? 45.06288, result.coords?.longitude ?? 7.66277);
  } catch (e) {
    print("Web geolocation error: $e");
    return null;
  }
}

