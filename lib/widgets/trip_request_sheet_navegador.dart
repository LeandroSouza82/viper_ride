import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> abrirNavegadorExterno(
  BuildContext context,
  double lat,
  double lng,
) async {
  String navPref = 'Google Maps';
  try {
    final prefs = await SharedPreferences.getInstance();
    navPref = prefs.getString('navigation_app') ?? 'Google Maps';
  } catch (_) {}

  String url = '';
  if (navPref == 'Waze') {
    url = 'https://waze.com/ul?ll=$lat,$lng&navigate=yes';
    if (!await canLaunchUrl(Uri.parse(url))) {
      // Fallback para Google Maps
      url = 'google.navigation:q=$lat,$lng&mode=d';
      if (!await canLaunchUrl(Uri.parse(url))) {
        // Fallback para busca web
        url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      }
    }
  } else {
    url = 'google.navigation:q=$lat,$lng&mode=d';
    if (!await canLaunchUrl(Uri.parse(url))) {
      // Fallback para busca web
      url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    }
  }
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    // Mostra erro amigável se tudo falhar
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir o app de navegação.')),
      );
    }
  }
}
