import 'package:flutter/material.dart';

class TripNavigationSheet extends StatelessWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onNavigate;
  final VoidCallback onArrived;

  const TripNavigationSheet({
    super.key,
    required this.trip,
    required this.onNavigate,
    required this.onArrived,
  });

  String _getPassengerName() {
    final name =
        trip['passenger_name'] ??
        trip['passenger'] ??
        trip['user_name'] ??
        trip['name'];
    if (name is String && name.isNotEmpty) return name;
    return 'Passageiro';
  }

  @override
  Widget build(BuildContext context) {
    final int horaAtual = DateTime.now().hour;
    final bool isNoite = horaAtual >= 18 || horaAtual < 6;
    final passengerName = _getPassengerName();

    return SafeArea(
      top: false,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isNoite ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(16.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                spreadRadius: 2.0,
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho: Nome do Passageiro
              Text(
                'Viagem com $passengerName',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isNoite ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),

              // Botão Primário: Navegar
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    debugPrint('VUP_LOG: Abrir Waze/Maps');
                    onNavigate();
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.navigation, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Navegar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Botão Secundário: Cheguei no Local
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isNoite ? Colors.white : Colors.black,
                    side: BorderSide(
                      color: isNoite ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    debugPrint('VUP_LOG: Motorista Chegou');
                    onArrived();
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Cheguei no Local',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
