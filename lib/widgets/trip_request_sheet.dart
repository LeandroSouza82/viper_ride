import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/trip_request_service.dart';
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
    final Color sliderBg = Theme.of(context).brightness == Brightness.dark
        ? Colors.black
        : Colors.grey[200]!;

    final price = _formatPrice(trip['price'] ?? trip['fare'] ?? trip['valor']);
    final eta = trip['eta'] ?? trip['pickup_eta'] ?? '--';
    final distanceToPickup =
        trip['distance_to_pickup'] ?? trip['pickup_distance'] ?? '--';
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
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

              const SizedBox(height: 8),

              // Top row: preço à esquerda, X + rating/payment à direita
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Preço + métricas
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        double extrairNumero(dynamic valor) {
                          if (valor == null) return 0.0;
                          if (valor is num) return valor.toDouble();
                          final limpo = valor
                              .toString()
                              .replaceAll(RegExp(r'[^0-9.,]'), '')
                              .replaceAll(',', '.');
                          return double.tryParse(limpo) ?? 0.0;
                        }

                        final double valorTotal = extrairNumero(
                          trip['price'] ?? trip['fare'] ?? trip['valor'],
                        );
                        final double distColeta = extrairNumero(
                          trip['distance_to_pickup'] ?? trip['pickup_distance'],
                        );
                        final double distViagem = extrairNumero(
                          trip['distance'] ?? trip['trip_distance'],
                        );
                        final double totalKm = distColeta + distViagem;
                        final double valorPorKm = totalKm > 0
                            ? (valorTotal / totalKm)
                            : 0.0;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              price,
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  '$eta • $distanceToPickup',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (valorPorKm > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.yellow,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'R\$ ${valorPorKm.toStringAsFixed(2).replaceAll('.', ',')}/km',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // X, rating e pagamento
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () {
                          TripRequestService.instance.requestNotifier.value =
                              null;
                          AudioService.instance.stopSound();
                        },
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.orangeAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating.toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.credit_card,
                            size: 18,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            payment.toString(),
                            style: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Embarque (antes: Coleta)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Icon(Icons.circle, color: Colors.green, size: 12),
                      Container(
                        width: 1,
                        height: 36,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[700]
                            : Colors.grey[300],
                      ),
                      Icon(Icons.location_on, color: Colors.red, size: 20),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Embarque',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pickup,
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Destination (alinha pino vermelho com texto)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 36),
                      Icon(Icons.location_on, color: Colors.red, size: 20),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Destino',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          destination,
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Real slider — usa slide_to_act
              SlideAction(
                text: 'Deslize para aceitar',
                textStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
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

              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Arraste para a direita para aceitar a corrida',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
