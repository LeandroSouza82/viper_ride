import 'dart:async';

import 'package:flutter/material.dart';

/// Formas de pagamento aceitas pelo Viper Ride.
enum ViperPaymentMethod { card, cash }

/// Dados de uma solicitação de corrida recebida pelo motorista.
class RideRequest {
  const RideRequest({
    required this.id,
    required this.fare,
    required this.minutesToPassenger,
    required this.kmToPassenger,
    required this.minutesToDestination,
    required this.kmToDestination,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationAddress,
    required this.destLat,
    required this.destLng,
    required this.passengerRating,
    required this.paymentMethod,
  });

  final String id;
  final double fare; // ex: 27.50
  final int minutesToPassenger; // ex: 3
  final double kmToPassenger; // ex: 1.2
  final int minutesToDestination;
  final double kmToDestination;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String destinationAddress;
  final double destLat;
  final double destLng;
  final double passengerRating; // ex: 4.9
  final ViperPaymentMethod paymentMethod;
}

/// Card flutuante de solicitação de corrida para o motorista.
///
/// Flutua sobre o mapa com fundo dark premium e cantos arredondados.
///
/// Comportamento do timer:
///   Barra de 15s no topo: verde → vermelho. Ao esgotar, [onDeclined] é
///   chamado automaticamente. O motorista pode rejeitar a qualquer momento
///   tocando no ícone "X" (canto superior direito).
///
/// Swipe-to-accept:
///   Implementação nativa com [GestureDetector] + [LayoutBuilder].
///   Thumb deslizável: arrastar ≥70% da trilha confirma a corrida via
///   [onAccepted]. Soltar antes: thumb retorna com animação snap-back.
class RideRequestAlert extends StatefulWidget {
  const RideRequestAlert({
    super.key,
    required this.request,
    required this.onAccepted,
    required this.onDeclined,
  });

  final RideRequest request;
  final VoidCallback onAccepted;
  final VoidCallback onDeclined;

  @override
  State<RideRequestAlert> createState() => _RideRequestAlertState();
}

class _RideRequestAlertState extends State<RideRequestAlert> {
  static const _totalSeconds = 15;
  static const _green = Color(0xFF2ECC71);
  static const _red = Color(0xFFE74C3C);
  static const _cardBg = Color(0xFF0E0E0E);
  static const _surfaceBg = Color(0xFF1A1A1A);

  // Timer a 1Hz: 60× menos frames que AnimationController — sem Vsync,
  // sem interação com o engine de animação, sem invalidações ao PlatformView.
  final _timeLeft = ValueNotifier<int>(_totalSeconds);
  Timer? _ticker;

  double _swipeOffset = 0.0;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    // Timer.periodic a 1Hz — sem Vsync, sem frames contínuos ao compositor.
    // Substitui AnimationController (60fps) que causava QueueBuffer timeout
    // ao propagar invalidações de repaint ao canvas OpenGL do Mapbox.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _timeLeft.value - 1;
      _timeLeft.value = next;
      if (next <= 0) {
        _ticker?.cancel();
        widget.onDeclined();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _timeLeft.dispose();
    super.dispose();
  }

  // ── Swipe handlers ──────────────────────────────────────────────────────────

  void _onSwipeUpdate(DragUpdateDetails details, double trackWidth) {
    if (_accepted) return;
    setState(() {
      _swipeOffset = (_swipeOffset + details.delta.dx).clamp(0.0, trackWidth);
    });
  }

  void _onSwipeEnd(double trackWidth) {
    if (_accepted) return;
    if (_swipeOffset >= trackWidth * 0.70) {
      // Aceito: cancela o ticker e notifica o pai
      setState(() => _accepted = true);
      _ticker?.cancel();
      widget.onAccepted();
    } else {
      // Snap-back: AnimatedPositioned cuida da animação
      setState(() => _swipeOffset = 0.0);
    }
  }

  // ── Formatação ──────────────────────────────────────────────────────────────

  String get _fareLabel =>
      'R\$ ${widget.request.fare.toStringAsFixed(2).replaceAll('.', ',')}';

  String get _toPassengerLabel {
    final km = widget.request.kmToPassenger.toStringAsFixed(1);
    return '${widget.request.minutesToPassenger} min • $km km';
  }

  String get _toDestinationLabel {
    final km = widget.request.kmToDestination.toStringAsFixed(1);
    return '${widget.request.minutesToDestination} min • $km km';
  }

  String get _ratingLabel =>
      '⭐ ${widget.request.passengerRating.toStringAsFixed(1)}';

  String get _paymentLabel =>
      widget.request.paymentMethod == ViperPaymentMethod.card
      ? '💳 Cartão'
      : '💵 Dinheiro';

  /// Interpola verde→vermelho conforme os segundos restantes decrescem.
  Color _barColorForTime(int t) =>
      Color.lerp(_red, _green, t / _totalSeconds.toDouble())!;

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Barra de progresso do timer ───────────────────────────────
                // ValueListenableBuilder a 1Hz: único ponto que muda no card.
                // Isola o rebuild à própria barra — corpo do card e mapa
                // nunca são tocados pelo timer.
                ValueListenableBuilder<int>(
                  valueListenable: _timeLeft,
                  builder: (context, t, _) => LinearProgressIndicator(
                    value: t / _totalSeconds.toDouble(),
                    minHeight: 4,
                    backgroundColor: const Color(0xFF222222),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _barColorForTime(t),
                    ),
                  ),
                ),

                // ── Corpo do card ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Valor da corrida + botão recusar
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _fareLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.5,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const SizedBox(height: 1),
                              RichText(
                                text: TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: 'At\u00e9 o passageiro: ',
                                      style: TextStyle(
                                        color: Color(0xFF8A8A8A),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    TextSpan(
                                      text: _toPassengerLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                              RichText(
                                text: TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: 'Viagem: ',
                                      style: TextStyle(
                                        color: Color(0xFF8A8A8A),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    TextSpan(
                                      text: _toDestinationLabel,
                                      style: const TextStyle(
                                        color: Color(0xFF2ECC71),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Botão X — rejeição imediata
                          GestureDetector(
                            onTap: widget.onDeclined,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF262626),
                                borderRadius: BorderRadius.circular(19),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFF888888),
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Endereços de coleta e destino
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _surfaceBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            _AddressRow(
                              iconColor: _green,
                              label: 'COLETA',
                              address: widget.request.pickupAddress,
                            ),
                            // Linha conectora entre os dois pontos
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                top: 3,
                                bottom: 3,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 2,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF333333),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _AddressRow(
                              iconColor: _red,
                              label: 'DESTINO',
                              address: widget.request.destinationAddress,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Nota do passageiro + forma de pagamento
                      Row(
                        children: [
                          _InfoChip(label: _ratingLabel),
                          const SizedBox(width: 8),
                          _InfoChip(label: _paymentLabel),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Botão deslizante de aceitar
                      _SwipeToAccept(
                        swipeOffset: _swipeOffset,
                        accepted: _accepted,
                        onUpdate: _onSwipeUpdate,
                        onEnd: _onSwipeEnd,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets internos ──────────────────────────────────────────────────────────

/// Linha de endereço com ícone colorido, label e texto completo.
class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.iconColor,
    required this.label,
    required this.address,
  });

  final Color iconColor;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Chip de informação (nota, pagamento).
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Botão deslizante nativo para aceitar a corrida.
///
/// Implementado com [GestureDetector] + [LayoutBuilder] — sem dependências
/// externas. O thumb verde pode ser arrastado da esquerda para a direita.
/// Ao atingir 70% da trilha e soltar, [onEnd] é chamado com sucesso.
/// Soltar antes: snap-back animado via [AnimatedPositioned].
class _SwipeToAccept extends StatelessWidget {
  const _SwipeToAccept({
    required this.swipeOffset,
    required this.accepted,
    required this.onUpdate,
    required this.onEnd,
  });

  final double swipeOffset;
  final bool accepted;
  final void Function(DragUpdateDetails, double trackWidth) onUpdate;
  final void Function(double trackWidth) onEnd;

  static const _green = Color(0xFF2ECC71);
  static const double _thumbSize = 52.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final trackWidth = totalWidth - _thumbSize;

        return GestureDetector(
          onHorizontalDragUpdate: (d) => onUpdate(d, trackWidth),
          onHorizontalDragEnd: (_) => onEnd(trackWidth),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFF171717),
              borderRadius: BorderRadius.circular(29),
              border: Border.all(color: const Color(0xFF2C2C2C)),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Preenchimento proporcional ao deslocamento do swipe
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: swipeOffset + _thumbSize,
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: accepted ? 0.20 : 0.12),
                        borderRadius: BorderRadius.circular(29),
                      ),
                    ),
                  ),
                ),

                // Texto central
                Center(
                  child: accepted
                      ? const Text(
                          'ACEITO  ✓',
                          style: TextStyle(
                            color: _green,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: _thumbSize * 0.5),
                            const Text(
                              'DESLIZE PARA ACEITAR',
                              style: TextStyle(
                                color: Color(0xFF555555),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF444444),
                              size: 16,
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF333333),
                              size: 16,
                            ),
                          ],
                        ),
                ),

                // Thumb deslizável
                // AnimatedPositioned só anima quando offset volta a 0 (snap-back)
                AnimatedPositioned(
                  duration: swipeOffset == 0.0
                      ? const Duration(milliseconds: 220)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  left: swipeOffset + 3,
                  top: 3,
                  child: Container(
                    width: _thumbSize - 6,
                    height: _thumbSize - 6,
                    decoration: BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _green.withValues(alpha: 0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.black,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
