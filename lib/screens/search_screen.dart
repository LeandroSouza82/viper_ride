import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/viper_theme.dart';

class ViperSearchScreen extends StatefulWidget {
  const ViperSearchScreen({super.key});

  @override
  State<ViperSearchScreen> createState() => _ViperSearchScreenState();
}

class _ViperSearchScreenState extends State<ViperSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_ViperSuggestion> _suggestions = const [
    _ViperSuggestion(
      label: 'Casa',
      sublabel: 'Rua das AcÃ¡cias, 123 â€” Vila Madalena, SP',
      icon: Icons.home_outlined,
    ),
    _ViperSuggestion(
      label: 'Trabalho',
      sublabel: 'Av. Paulista, 1000 â€” Bela Vista, SP',
      icon: Icons.work_outline,
    ),
    _ViperSuggestion(
      label: 'Aeroporto de Congonhas',
      sublabel: 'Av. Washington LuÃ­s, s/n â€” Campo Belo, SP',
      icon: Icons.flight_outlined,
    ),
    _ViperSuggestion(
      label: 'Shopping Ibirapuera',
      sublabel: 'Av. Ibirapuera, 3103 â€” Moema, SP',
      icon: Icons.shopping_bag_outlined,
    ),
    _ViperSuggestion(
      label: 'Parque Ibirapuera',
      sublabel: 'Av. Pedro Ãlvares Cabral â€” Vila Mariana, SP',
      icon: Icons.park_outlined,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: ViperColors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: SafeArea(
            child: Container(
              color: ViperColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: ViperColors.black,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F6F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            color: ViperColors.black,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              autofocus: true,
                              style: const TextStyle(
                                color: ViperColors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                              cursorColor: ViperColors.black,
                              decoration: const InputDecoration(
                                hintText: 'Para onde?',
                                hintStyle: TextStyle(
                                  color: Color(0xFF9E9E9E),
                                  fontWeight: FontWeight.w400,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: const Text(
                'SUGESTÃ•ES',
                style: TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: _suggestions.length,
                separatorBuilder: (context, index) => const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 76,
                  color: Color(0xFFF0F0F0),
                ),
                itemBuilder: (context, index) {
                  final s = _suggestions[index];
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF0F0F0),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              s.icon,
                              color: ViperColors.black,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.label,
                                  style: const TextStyle(
                                    color: ViperColors.black,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  s.sublabel,
                                  style: const TextStyle(
                                    color: Color(0xFF9E9E9E),
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViperSuggestion {
  final String label;
  final String sublabel;
  final IconData icon;

  const _ViperSuggestion({
    required this.label,
    required this.sublabel,
    required this.icon,
  });
}
