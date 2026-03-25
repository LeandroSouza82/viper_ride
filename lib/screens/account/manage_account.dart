import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageAccountScreen extends StatefulWidget {
  const ManageAccountScreen({super.key});

  @override
  State<ManageAccountScreen> createState() => _ManageAccountScreenState();
}

class _ManageAccountScreenState extends State<ManageAccountScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  // Equipamentos locais
  bool _hasBau = false;
  bool _hasTwoHelmets = false;
  bool _doesFoodDelivery = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final res = await Supabase.instance.client
          .from('profiles')
          .select(
            'id, full_name, avatar_url, rating, cpf, phone, vehicle_plate, vehicle_model, equipment',
          )
          .eq('id', userId)
          .maybeSingle();

      if (res == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final profile = Map<String, dynamic>.from(res);
      final equipment = profile['equipment'];
      if (equipment is List) {
        _hasBau = equipment.contains('bau');
        _hasTwoHelmets = equipment.contains('two_helmets');
        _doesFoodDelivery = equipment.contains('food_delivery');
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _maskCpf(String? cpf) {
    if (cpf == null || cpf.isEmpty) return '-';
    final only = cpf.replaceAll(RegExp(r'[^0-9]'), '');
    if (only.length < 5) return '***.***.$only';
    final last3 = only.substring(only.length - 3);
    return '***.***.$last3';
  }

  Future<void> _saveEquipment() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final equipment = <String>[];
    if (_hasBau) equipment.add('bau');
    if (_hasTwoHelmets) equipment.add('two_helmets');
    if (_doesFoodDelivery) equipment.add('food_delivery');

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'equipment': equipment})
          .eq('id', userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Equipamentos salvos')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao salvar equipamentos')),
      );
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir conta'),
        content: const Text(
          'Tem certeza que deseja excluir permanentemente sua conta? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Ação sensível: normalmente precisaria de backend para excluir dados.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitação de exclusão enviada.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar conta da Viper'),
        backgroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Perfil
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage:
                            _profile != null &&
                                (_profile!['avatar_url'] as String?) != null
                            ? NetworkImage(_profile!['avatar_url'] as String)
                            : null,
                        child:
                            _profile == null ||
                                (_profile!['avatar_url'] as String?) == null
                            ? const Icon(
                                Icons.person,
                                size: 36,
                                color: Colors.black54,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _profile?['full_name'] as String? ?? '-',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  (_profile?['rating'] as num?)
                                          ?.toStringAsFixed(1) ??
                                      '-',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Informações
                  const Text(
                    'Informações',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('CPF'),
                          subtitle: Text(_maskCpf(_profile?['cpf'] as String?)),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text('Telefone'),
                          subtitle: Text(_profile?['phone'] as String? ?? '-'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text('Veículo'),
                          subtitle: Text(
                            '${_profile?['vehicle_plate'] ?? '-'} • ${_profile?['vehicle_model'] ?? '-'}',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Ações rápidas
                  const Text(
                    'Ações rápidas',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Navegar para alterar e-mail (placeholder)
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Alterar E-mail'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Segurança'),
                                content: const Text(
                                  'Dispositivos e sessões ativas (placeholder).',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text('Fechar'),
                                  ),
                                ],
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Segurança'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Equipamentos
                  const Text(
                    'Equipamentos',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        CheckboxListTile(
                          title: const Text('Baú'),
                          value: _hasBau,
                          onChanged: (v) =>
                              setState(() => _hasBau = v ?? false),
                        ),
                        CheckboxListTile(
                          title: const Text('Dois capacetes'),
                          value: _hasTwoHelmets,
                          onChanged: (v) =>
                              setState(() => _hasTwoHelmets = v ?? false),
                        ),
                        CheckboxListTile(
                          title: const Text('Faço entregas de comida'),
                          value: _doesFoodDelivery,
                          onChanged: (v) =>
                              setState(() => _doesFoodDelivery = v ?? false),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              ElevatedButton(
                                onPressed: _saveEquipment,
                                child: const Text('Salvar'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Zona de perigo
                  const Text(
                    'Zona de perigo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: Colors.red.shade50,
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('Desativar conta temporariamente'),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                            ),
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Desativar conta'),
                                  content: const Text(
                                    'Deseja desativar sua conta temporariamente?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Conta desativada temporariamente',
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text('Desativar'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Text('Desativar'),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text('Excluir conta permanentemente'),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                            ),
                            onPressed: _confirmDeleteAccount,
                            child: const Text('Excluir'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
