import 'package:flutter/material.dart';
import '../services/trip_request_service.dart';
import '../services/audio_service.dart';
import 'package:slide_to_act/slide_to_act.dart';

class TripRequestSheet extends StatelessWidget {
  final Map<String, dynamic> trip;

  const TripRequestSheet({super.key, required this.trip});

  String _formatPrice(dynamic p) {
    if (p == null) return 'R\$ 0,00';
    try {
      final n = p is num ? p : num.parse(p.toString());
      return 'R\$ ${n.toStringAsFixed(2)}';
    } catch (_) {
      return p.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDayTime = DateTime.now().hour >= 6 && DateTime.now().hour < 18;
    // Tema dinâmico: fundo escuro durante o dia, claro à noite (conforme solicitado)
    final Color bgColor = isDayTime ? Colors.grey[900]! : Colors.white;
    final Color primaryText = isDayTime ? Colors.white : Colors.black87;
    final Color secondaryText = isDayTime
        ? Colors.grey.shade300
        : Colors.grey[700]!;
    final Color iconColor = isDayTime ? Colors.white : Colors.grey[700]!;
    final Color sliderBg = isDayTime ? Colors.grey[800]! : Colors.grey[200]!;

    final price = _formatPrice(trip['price'] ?? trip['fare'] ?? trip['valor']);
    final eta = trip['eta'] ?? trip['pickup_eta'] ?? '--';
    final distanceToPickup =
        trip['distance_to_pickup'] ?? trip['pickup_distance'] ?? '--';
    final tripDistance = trip['distance'] ?? trip['trip_distance'] ?? '--';
    final pickup =
        trip['pickup_address'] ?? trip['origin'] ?? 'Local de coleta';
    final destination =
        trip['destination_address'] ?? trip['destination'] ?? 'Destino';
    final rating = trip['rating'] ?? trip['passenger_rating'] ?? '—';
    final payment = trip['payment_method'] ?? trip['payment'] ?? '—';

    return SafeArea(
      top: false,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de tempo (12s) — Tween animando de 1.0 -> 0.0
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: 0.0),
                duration: Duration(seconds: 12),
                onEnd: () {
                  TripRequestService.instance.requestNotifier.value = null;
                  AudioService.instance.stopSound();
                },
                builder: (context, value, child) {
                  return SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(
                      value: value,
                      backgroundColor: sliderBg.withAlpha((0.4 * 255).round()),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.greenAccent.shade400,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 8),
              // Top row: close button
              Row(
                children: [
                  Expanded(child: SizedBox()),
                  IconButton(
                    onPressed: () {
                      TripRequestService.instance.requestNotifier.value = null;
                      AudioService.instance.stopSound();
                    },
                    icon: Icon(Icons.close, color: iconColor),
                  ),
                ],
              ),

              // Price + ETA/Distance (com badge R$/km)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          price,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                        SizedBox(height: 6),
                        // Badge de R$/km — cálculo seguro e exibido em destaque
                        Builder(
                          builder: (ctx) {
                            double toDoubleSafe(dynamic v) {
                              if (v == null) return 0.0;
                              if (v is num) return v.toDouble();
                              try {
                                return double.parse(v.toString());
                              } catch (_) {
                                return 0.0;
                              }
                            }

                            final double priceNum = toDoubleSafe(
                              trip['price'] ??
                                  trip['fare'] ??
                                  trip['valor'] ??
                                  0,
                            );
                            final double dPickup = toDoubleSafe(
                              trip['distance_to_pickup'] ??
                                  trip['pickup_distance'] ??
                                  trip['pickup_distance_km'],
                            );
                            final double dTrip = toDoubleSafe(
                              trip['distance'] ??
                                  trip['trip_distance'] ??
                                  trip['distance_km'],
                            );
                            final double totalKm = (dPickup + dTrip);
                            final String rateText =
                                (totalKm > 0 && priceNum > 0)
                                ? 'R\$ ${(priceNum / totalKm).toStringAsFixed(2)} / km'
                                : '—';

                            return Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green[800],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    rateText,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                              ],
                            );
                          },
                        ),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.timer, size: 16, color: secondaryText),
                            SizedBox(width: 6),
                            Text(
                              '$eta • $distanceToPickup',
                              style: TextStyle(color: secondaryText),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '• $tripDistance',
                              style: TextStyle(color: secondaryText),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Rating / Payment
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.orangeAccent,
                            size: 18,
                          ),
                          SizedBox(width: 4),
                          Text(
                            rating.toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: primaryText,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.credit_card,
                            size: 18,
                            color: secondaryText,
                          ),
                          SizedBox(width: 6),
                          Text(
                            payment.toString(),
                            style: TextStyle(color: secondaryText),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Pickup
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Icon(
                        Icons.circle,
                        color: isDayTime ? Colors.green : Colors.white,
                        size: 12,
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: isDayTime ? Colors.grey[300] : Colors.grey[700],
                      ),
                      Icon(
                        Icons.location_on,
                        color: isDayTime ? Colors.red : Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coleta',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: primaryText,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(pickup, style: TextStyle(color: primaryText)),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Destination
              Row(
                children: [
                  SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Destino',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: primaryText,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(destination, style: TextStyle(color: primaryText)),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Real slider — usa slide_to_act
              SlideAction(
                text: 'Deslize para aceitar',
                textStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
                innerColor: Colors.green,
                outerColor: sliderBg,
                elevation: 0,
                onSubmit: () async {
                  TripRequestService.instance.requestNotifier.value = null;
                  try {
                    await AudioService.instance.stopSound();
                  } catch (_) {}
                },
              ),

              SizedBox(height: 8),
              Center(
                child: Text(
                  'Arraste para a direita para aceitar a corrida',
                  style: TextStyle(fontSize: 12, color: secondaryText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
