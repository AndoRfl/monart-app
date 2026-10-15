import 'package:flutter/material.dart';
import 'api_service.dart';

void main() {
  runApp(const MonArtApp());
}

class MonArtApp extends StatelessWidget {
  const MonArtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MonArt Monitoring',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blue,
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String _errorMessage = '';

  // Métriques système
  double _cpuPercent = 0.0;
  double _ramPercent = 0.0;
  double _diskPercent = 0.0;
  String _hostname = 'Debian';
  String _os = 'Linux';
  int _uptimeHours = 0;

  // Statut des services
  Map<String, bool> _services = {};

  // Blocages
  int _totalBlocked = 0;
  List<dynamic> _recentBlocks = [];

  // Controllers pour le blocage / déblocage
  final TextEditingController _blockController = TextEditingController();
  final TextEditingController _unblockController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final data = await ApiService.fetchProxyStats();

      // Extraction sécurisée des données système
      final sys = data['system'] as Map<String, dynamic>? ?? {};

      final cpu = data['cpu'] ?? data['cpu_percent'] ?? sys['cpu'] ?? sys['cpu_percent'];
      final ram = data['ram_percent'] ?? data['memory_percent'] ?? sys['ram_percent'] ?? sys['memory_percent'];
      final disk = data['disk_percent'] ?? sys['disk_percent'];

      final servicesData = data['services'] as Map<String, dynamic>? ?? {};
      Map<String, bool> parsedServices = {};
      servicesData.forEach((key, value) {
        parsedServices[key] = value == true;
      });

      final filtering = data['filtering'] as Map<String, dynamic>? ?? {};
      final blockedCount = data['total_blocked'] ?? filtering['total_blocked'] ?? 0;
      final blocksList = data['recent_blocks'] ?? filtering['recent_blocks'] ?? [];

      setState(() {
        _cpuPercent = _parseDouble(cpu);
        _ramPercent = _parseDouble(ram);
        _diskPercent = _parseDouble(disk);

        _hostname = sys['hostname']?.toString() ?? 'Debian';
        _os = sys['os']?.toString() ?? 'Linux';
        _uptimeHours = ((sys['uptime_seconds'] ?? 0) as num).toInt() ~/ 3600;

        _services = parsedServices;
        _totalBlocked = (blockedCount as num).toInt();
        _recentBlocks = List.from(blocksList);

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de connexion au serveur API';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleBlockDomain() async {
    final domain = _blockController.text.trim();
    if (domain.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Blocage de $domain en cours...')),
    );

    final success = await ApiService.blockDomain(domain);
    _blockController.clear();

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Domaine $domain bloqué !'), backgroundColor: Colors.green),
      );
      _loadDashboardData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec du blocage'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleUnblockDomain() async {
    final domain = _unblockController.text.trim();
    if (domain.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Déblocage de $domain en cours...')),
    );

    final success = await ApiService.unblockDomain(domain);
    _unblockController.clear();

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exception appliquée pour $domain !'), backgroundColor: Colors.green),
      );
      _loadDashboardData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec du déblocage'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MonArt Control Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAlignment.start,
                  children: [
                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)),
                      ),

                    Text(
                      '$_hostname | $_os | Uptime: ${_uptimeHours}h',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    // Jauges Système CPU, RAM, DISK
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('CPU', _cpuPercent, Colors.blue)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildStatCard('RAM', _ramPercent, Colors.orange)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildStatCard('DISQUE', _diskPercent, Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Actions de blocage
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            TextField(
                              controller: _blockController,
                              decoration: InputDecoration(
                                labelText: 'Bloquer un domaine',
                                hintText: 'ex: tiktok.com',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.block, color: Colors.red),
                                  onPressed: _handleBlockDomain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _unblockController,
                              decoration: InputDecoration(
                                labelText: 'Débloquer un domaine',
                                hintText: 'ex: facebook.com',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.check_circle, color: Colors.green),
                                  onPressed: _handleUnblockDomain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Liste des services
                    const Text('Statut des Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Card(
                      child: _services.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('Aucun service détecté', style: TextStyle(color: Colors.grey)),
                            )
                          : Column(
                              children: _services.entries.map((e) {
                                return ListTile(
                                  title: Text(e.key.toUpperCase()),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: e.value ? Colors.green : Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      e.value ? 'Actif' : 'Inactif',
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Blocages récents
                    Row(
                      mainAxisAlignment: MainAlignment.spaceBetween,
                      children: [
                        const Text('Derniers Blocages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Chip(
                          label: Text('Total: $_totalBlocked'),
                          backgroundColor: Colors.red.withOpacity(0.3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: _recentBlocks.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('Aucun blocage récent', style: TextStyle(color: Colors.grey)),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _recentBlocks.length > 10 ? 10 : _recentBlocks.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final block = _recentBlocks[_recentBlocks.length - 1 - index];
                                return ListTile(
                                  title: Text(
                                    block['target']?.toString() ?? 'Domaine inconnu',
                                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text('Client: ${block['client'] ?? 'Inconnu'}'),
                                  trailing: Text(
                                    block['timestamp']?.toString() ?? '',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, double percent, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              color: color,
              backgroundColor: Colors.grey.shade800,
            ),
          ],
        ),
      ),
    );
  }
}
