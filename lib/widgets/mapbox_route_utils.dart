import 'dart:convert';
import 'package:http/http.dart' as http;

Future<List<List<double>>> fetchMapboxRoute({
  required String accessToken,
  required List<double> origin, // [lng, lat]
  required List<double> destination, // [lng, lat]
}) async {
  final url =
      'https://api.mapbox.com/directions/v5/mapbox/driving-traffic/${origin[0]},${origin[1]};${destination[0]},${destination[1]}?geometries=polyline6&overview=full&access_token=$accessToken';
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) throw Exception('Erro Directions: ${response.body}');
  final data = json.decode(response.body);
  final polyline = data['routes'][0]['geometry'] as String;
  return decodePolyline6(polyline);
}

// Decodifica polyline6 para lista de [lng, lat]
List<List<double>> decodePolyline6(String encoded) {
  List<List<double>> coordinates = [];
  int index = 0, len = encoded.length;
  int lat = 0, lng = 0;
  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;
    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;
    coordinates.add([
      lng / 1e6,
      lat / 1e6,
    ]);
  }
  return coordinates;
}
