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
    final int horaAtual = DateTime.now().hour;
    final bool isNoite = horaAtual >= 18 || horaAtual < 6;
    final Color sliderBg = isNoite ? Colors.black : Colors.grey[200]!;

    final price = _formatPrice(trip['price'] ?? trip['fare'] ?? trip['valor']);
    final pickup =
        trip['pickup_address'] ?? trip['origin'] ?? 'Local de coleta';
    final destination =
        trip['destination_address'] ?? trip['destination'] ?? 'Destino';
    final rating = trip['rating'] ?? trip['passenger_rating'] ?? '—';

    return SafeArea(
      top: false,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isNoite ? const Color(0xFF1E1E1E) : Colors.white,
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

              Builder(
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
                  final String tipoViagem = (trip['type'] == 'delivery')
                      ? 'ENTREGA'
                      : 'CORRIDA';
                  final IconData iconeViagem = (trip['type'] == 'delivery')
                      ? Icons.local_shipping
                      : Icons.directions_car;
                  final String formPagamento = trip['payment_method'] == 'pix'
                      ? 'Pix'
                      : (trip['payment_method'] == 'cash'
                            ? 'Dinheiro'
                            : 'Cartão');

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isNoite
                                ? Colors.grey[800]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                iconeViagem,
                                size: 16,
                                color: isNoite ? Colors.white : Colors.black,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tipoViagem,
                                style: TextStyle(
                                  color: isNoite ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          onPressed: () {
                            TripRequestService.instance.requestNotifier.value =
                                null;
                            AudioService.instance.stopSound();
                          },
                          icon: Icon(
                            Icons.close,
                            color: isNoite ? Colors.white : Colors.black,
                          ),
                        ),
                      ),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            price,
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              color: isNoite ? Colors.white : Colors.black,
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

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: isNoite ? Colors.white : Colors.black,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            rating.toString(),
                            style: TextStyle(
                              color: isNoite ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.credit_card,
                            size: 18,
                            color: isNoite ? Colors.white : Colors.black,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            formPagamento,
                            style: TextStyle(
                              color: isNoite ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Icon(Icons.circle, size: 12, color: Colors.green),
                      Container(width: 2, height: 40, color: Colors.grey),
                      Icon(Icons.stop, size: 12, color: Colors.red),
                    ],
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Embarque (${trip['distance_to_pickup'] ?? trip['pickup_distance'] ?? ''})",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isNoite ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pickup,
                          style: TextStyle(
                            color: isNoite ? Colors.white : Colors.black,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          "Destino (${trip['distance'] ?? trip['trip_distance'] ?? ''})",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isNoite ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          destination,
                          style: TextStyle(
                            color: isNoite ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              SlideAction(
                text: 'Deslize para aceitar',
                textStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isNoite ? Colors.white : Colors.black,
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
                    color: isNoite ? Colors.white : Colors.black,
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
