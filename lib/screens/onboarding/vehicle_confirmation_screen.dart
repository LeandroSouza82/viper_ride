import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import 'otp_verification_screen.dart';

class VehicleConfirmationScreen extends StatefulWidget {
  final String placaInicial;
  final bool isMotoInicial;
  const VehicleConfirmationScreen({
    super.key,
    required this.placaInicial,
    required this.isMotoInicial,
  });

  @override
  State<VehicleConfirmationScreen> createState() =>
      _VehicleConfirmationScreenState();
}

class _VehicleConfirmationScreenState extends State<VehicleConfirmationScreen> {
  late TextEditingController _placaController;
  late bool _isMoto;
  String? _marcaSelecionada;
  String? _modeloSelecionado;
  String? _corSelecionada;

  // BANCO DE CARROS
  // BANCO DE CARROS (COMPLETO)
  final List<String> _marcasCarro = [
    'Chevrolet',
    'Fiat',
    'Ford',
    'Honda',
    'Hyundai',
    'Jeep',
    'Nissan',
    'Renault',
    'Toyota',
    'Volkswagen',
    'Peugeot',
    'Citroën',
    'CAOA Chery',
    'Kia',
    'Mitsubishi',
    'BYD',
    'GWM',
    'Outra Marca',
  ];

  final Map<String, List<String>> _modelosCarro = {
    'Chevrolet': [
      'Onix',
      'Onix Plus',
      'Tracker',
      'Cruze',
      'Spin',
      'Prisma',
      'Cobalt',
      'Classic',
      'Celta',
      'Corsa',
      'Vectra',
      'Astra',
      'Agile',
      'Montana',
      'Outro Modelo',
    ],
    'Fiat': [
      'Argo',
      'Cronos',
      'Fastback',
      'Mobi',
      'Pulse',
      'Toro',
      'Uno',
      'Palio',
      'Siena',
      'Grand Siena',
      'Punto',
      'Linea',
      'Idea',
      'Strada',
      'Fiorino',
      'Outro Modelo',
    ],
    'Ford': [
      'Ka',
      'Ka Sedan',
      'EcoSport',
      'Fiesta',
      'Focus',
      'Fusion',
      'Outro Modelo',
    ],
    'Honda': ['City', 'Civic', 'Fit', 'HR-V', 'WR-V', 'CR-V', 'Outro Modelo'],
    'Hyundai': [
      'HB20',
      'HB20S',
      'Creta',
      'Tucson',
      'i30',
      'Elantra',
      'Azera',
      'Outro Modelo',
    ],
    'Jeep': ['Renegade', 'Compass', 'Commander', 'Outro Modelo'],
    'Nissan': [
      'Kicks',
      'Versa',
      'March',
      'Sentra',
      'Frontier',
      'Tiida',
      'Livina',
      'Outro Modelo',
    ],
    'Renault': [
      'Kwid',
      'Sandero',
      'Logan',
      'Duster',
      'Captur',
      'Clio',
      'Symbol',
      'Fluence',
      'Outro Modelo',
    ],
    'Toyota': [
      'Corolla',
      'Yaris',
      'Etios',
      'Corolla Cross',
      'Hilux',
      'SW4',
      'Outro Modelo',
    ],
    'Volkswagen': [
      'Polo',
      'Virtus',
      'T-Cross',
      'Nivus',
      'Gol',
      'Voyage',
      'Fox',
      'Jetta',
      'Up!',
      'Saveiro',
      'Golf',
      'SpaceFox',
      'Outro Modelo',
    ],
    'Peugeot': ['208', '2008', '207', '308', '3008', '206', 'Outro Modelo'],
    'Citroën': ['C3', 'C4 Cactus', 'C4 Lounge', 'Aircross', 'Outro Modelo'],
    'CAOA Chery': [
      'Tiggo 2',
      'Tiggo 3x',
      'Tiggo 5x',
      'Tiggo 7',
      'Tiggo 8',
      'Arrizo 5',
      'Arrizo 6',
      'QQ',
      'Outro Modelo',
    ],
    'Kia': ['Cerato', 'Sportage', 'Picanto', 'Soul', 'Outro Modelo'],
    'Mitsubishi': [
      'Lancer',
      'ASX',
      'Outlander',
      'Pajero',
      'Triton',
      'Outro Modelo',
    ],
    'BYD': [
      'Dolphin',
      'Dolphin Mini',
      'Seal',
      'Song Plus',
      'Yuan Plus',
      'Outro Modelo',
    ],
    'GWM': ['Haval H6', 'Ora 03', 'Outro Modelo'],
    'Outra Marca': ['Outro Modelo'],
  };

  // BANCO DE MOTOS
  final List<String> _marcasMoto = [
    'Honda',
    'Yamaha',
    'Suzuki',
    'Kawasaki',
    'BMW',
    'Triumph',
    'Dafra',
    'Haojue',
    'Shineray',
    'Royal Enfield',
    'Bajaj',
    'Voltz',
    'Outra Marca',
  ];

  final Map<String, List<String>> _modelosMoto = {
    'Honda': [
      'CG 160 Titan',
      'CG 160 Fan',
      'CG 160 Start',
      'CG 150',
      'CG 125',
      'Biz 125',
      'Biz 110i',
      'Pop 110i',
      'Bros 160',
      'CB 300F',
      'CB 250F Twister',
      'XRE 300',
      'XRE 190',
      'PCX',
      'Elite 125',
      'ADV',
      'Outro Modelo',
    ],
    'Yamaha': [
      'Crosser 150',
      'Fazer 250',
      'Fazer 150',
      'Factor 150',
      'Factor 125',
      'MT-03',
      'NMAX 160',
      'XMAX',
      'Lander 250',
      'Neo 125',
      'Fluo 125',
      'YBR 125',
      'Outro Modelo',
    ],
    'Suzuki': [
      'GSX-S750',
      'V-Strom',
      'Burgman',
      'Intruder 125',
      'Yes 125',
      'GSX 150',
      'Outro Modelo',
    ],
    'Kawasaki': [
      'Ninja 400',
      'Z400',
      'Versys 300',
      'Ninja 300',
      'Outro Modelo',
    ],
    'BMW': ['G 310 R', 'G 310 GS', 'F 850 GS', 'Outro Modelo'],
    'Triumph': [
      'Tiger 900',
      'Tiger 800',
      'Street Triple',
      'Scrambler',
      'Outro Modelo',
    ],
    'Dafra': [
      'Citycom 300i',
      'Cruisym 150',
      'Apache RTR 200',
      'Horizon 150',
      'Outro Modelo',
    ],
    'Haojue': [
      'DR 160',
      'Chopper Road 150',
      'Master Ride 150',
      'DK 150',
      'Lind 125',
      'Outro Modelo',
    ],
    'Shineray': [
      'Jet 125',
      'Worker 125',
      'Phoenix 50',
      'Jef 150',
      'SH 125',
      'Outro Modelo',
    ],
    'Royal Enfield': [
      'Meteor 350',
      'Classic 350',
      'Hunter 350',
      'Himalayan',
      'Outro Modelo',
    ],
    'Bajaj': ['Dominar 400', 'Dominar 200', 'Dominar 160', 'Outro Modelo'],
    'Voltz': ['EVS', 'EV1 Sport', 'Outro Modelo'],
    'Outra Marca': ['Outro Modelo'],
  };

  final List<String> _cores = [
    'Branco',
    'Preto',
    'Prata',
    'Cinza',
    'Vermelho',
    'Azul',
    'Outra',
  ];

  @override
  void initState() {
    super.initState();
    _placaController = TextEditingController(
      text: widget.placaInicial == "Não encontrada" ? "" : widget.placaInicial,
    );
    _isMoto = widget.isMotoInicial; // Inicia com a detecção do robô
  }

  void _trocarTipo(bool paraMoto) {
    if (_isMoto != paraMoto) {
      setState(() {
        _isMoto = paraMoto;
        _marcaSelecionada = null; // Reseta ao trocar de tipo
        _modeloSelecionado = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canSubmit =
        _placaController.text.length >= 7 &&
        _marcaSelecionada != null &&
        _modeloSelecionado != null &&
        _corSelecionada != null;

    // Define qual lista usar com base no tipo
    List<String> marcasAtuais = _isMoto ? _marcasMoto : _marcasCarro;
    Map<String, List<String>> modelosAtuais = _isMoto
        ? _modelosMoto
        : _modelosCarro;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade100,
        elevation: 0,
        title: const Text(
          'Confirme seu Veículo',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quase lá!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Para facilitar a identificação pelos passageiros, preencha os detalhes do veículo.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 24),

            // SELETOR CARRO / MOTO
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _trocarTipo(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: !_isMoto ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !_isMoto ? Colors.black : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.directions_car,
                            color: !_isMoto ? Colors.white : Colors.black,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Carro',
                            style: TextStyle(
                              color: !_isMoto ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _trocarTipo(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _isMoto ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isMoto ? Colors.black : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.two_wheeler,
                            color: _isMoto ? Colors.white : Colors.black,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Moto',
                            style: TextStyle(
                              color: _isMoto ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            const Text(
              'Placa do Veículo',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _placaController,
              textCapitalization: TextCapitalization.characters,
              onChanged: (v) => setState(() {}),
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ), // CORREÇÃO DA COR AQUI
              decoration: InputDecoration(
                hintText: 'ABC1D23',
                hintStyle: const TextStyle(
                  color: Colors.black38,
                ), // Dica mais escura
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.pin, color: Colors.black),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Marca',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            DropdownMenu<String>(
              key: ValueKey('marca_\$_isMoto'),
              width: MediaQuery.of(context).size.width - 48,
              hintText: 'Selecione a marca',
              textStyle: const TextStyle(
                color: Colors.black,
              ), // CORREÇÃO DA COR AQUI
              enableFilter: true,
              enableSearch: true,
              dropdownMenuEntries: marcasAtuais
                  .map((e) => DropdownMenuEntry(value: e, label: e))
                  .toList(),
              onSelected: (val) {
                setState(() {
                  _marcaSelecionada = val;
                  _modeloSelecionado = null;
                });
              },
            ),
            const SizedBox(height: 24),

            const Text(
              'Modelo',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            DropdownMenu<String>(
              key: ValueKey('modelo_\$_marcaSelecionada'),
              width: MediaQuery.of(context).size.width - 48,
              hintText: _marcaSelecionada == null
                  ? 'Selecione a marca'
                  : 'Selecione o modelo',
              textStyle: const TextStyle(
                color: Colors.black,
              ), // CORREÇÃO DA COR AQUI
              enableFilter: true,
              enableSearch: true,
              enabled: _marcaSelecionada != null,
              dropdownMenuEntries:
                  (_marcaSelecionada != null
                          ? modelosAtuais[_marcaSelecionada]!
                          : <String>[])
                      .map((e) => DropdownMenuEntry(value: e, label: e))
                      .toList(),
              onSelected: (val) => setState(() => _modeloSelecionado = val),
            ),
            const SizedBox(height: 24),

            const Text(
              'Cor',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            DropdownMenu<String>(
              width: MediaQuery.of(context).size.width - 48,
              hintText: 'Ex: Prata',
              textStyle: const TextStyle(
                color: Colors.black,
              ), // CORREÇÃO DA COR AQUI
              dropdownMenuEntries: _cores
                  .map((e) => DropdownMenuEntry(value: e, label: e))
                  .toList(),
              onSelected: (val) => setState(() => _corSelecionada = val),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: canSubmit
                  ? () async {
                      HapticFeedback.heavyImpact();

                      final payloadVeiculo = {
                        'id': SupabaseService.getCurrentUserId(),
                        'vehicle_plate': _placaController.text,
                        'vehicle_model':
                            '$_marcaSelecionada $_modeloSelecionado',
                        'vehicle_color': _corSelecionada,
                      };

                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Enviando para a Viper...'),
                        ),
                      );

                      // Pega o erro (se houver)
                      final erro = await SupabaseService.saveMotoristaProgress(
                        payloadVeiculo,
                      );

                      if (!context.mounted) return;

                      if (erro == null) {
                        // SUCESSO: finaliza o cadastro, gera OTP e envia (simulado)
                        final userId = SupabaseService.getCurrentUserId();
                        String? phone;
                        if (userId != null) {
                          phone = await SupabaseService.getProfilePhone(userId);
                        }

                        await ViperAuthService.gerarEEnviarOTP(phone ?? '');
                        if (context.mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Solicitação de OTP enviada (verifique WhatsApp)',
                              ),
                            ),
                          );
                        }

                        if (!context.mounted) return;

                        // Navega para verificação OTP
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                OtpVerificationScreen(phoneNumber: phone ?? ''),
                          ),
                        );
                      } else {
                        // FALHA! Mostra o erro vermelho na tela
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Erro ao salvar: $erro'),
                            backgroundColor: Colors.red,
                            duration: const Duration(
                              seconds: 5,
                            ), // Fica 5 segundos na tela pra dar tempo de ler
                          ),
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirmar e Enviar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
