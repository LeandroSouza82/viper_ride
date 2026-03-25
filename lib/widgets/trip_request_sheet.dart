import 'package:flutter/material.dart';
import '../services/trip_request_service.dart';

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
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: close button
              Row(
                children: [
                  Expanded(child: SizedBox()),
                  IconButton(
                    onPressed: () {
                      TripRequestService.instance.requestNotifier.value = null;
                    },
                    icon: Icon(Icons.close),
                  ),
                ],
              ),

              // Price + ETA/Distance
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
                          ),
                        ),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.timer,
                              size: 16,
                              color: Colors.grey[700],
                            ),
                            SizedBox(width: 6),
                            Text(
                              '$eta • $distanceToPickup',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '• $tripDistance',
                              style: TextStyle(color: Colors.grey[700]),
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
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.credit_card,
                            size: 18,
                            color: Colors.grey[700],
                          ),
                          SizedBox(width: 6),
                          Text(
                            payment.toString(),
                            style: TextStyle(color: Colors.grey[700]),
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
                      Icon(Icons.circle, color: Colors.green, size: 12),
                      Container(width: 1, height: 36, color: Colors.grey[300]),
                      Icon(Icons.location_on, color: Colors.red, size: 20),
                    ],
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coleta',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(pickup, style: TextStyle(color: Colors.black87)),
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
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          destination,
                          style: TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Slider placeholder (visual) — full width
              GestureDetector(
                onHorizontalDragEnd: (_) {
                  // TODO: Implementar aceite
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.chevron_right, color: Colors.green),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Deslize para aceitar',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 8),
              // Small hint text
              Center(
                child: Text(
                  'Arraste para a direita para aceitar a corrida',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
