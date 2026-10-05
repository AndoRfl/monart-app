import 'dart:async';
import 'package:flutter/material.dart';
import 'services/api_service.dart';

void main() {
  runApp(const ServerMonitoringApp());
}

class ServerMonitoringApp extends StatelessWidget {
  const ServerMonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Debian 12 Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
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
  Timer? _timer;
  Map<String, dynamic>? _healthData;
  Map<String, dynamic>? _proxyData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _loadAllData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    try {
      final health = await ApiService.fetchHealth();
      final proxy = await ApiService.fetchProxyStats();
      setState(() {
        _healthData = health;
        _proxyData = proxy;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerProxyReload() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rechargement de Squid/SquidGuard...')),
    );
    bool success = await ApiService.reloadProxy();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Proxy rechargé avec succès !' : 'Erreur lors du rechargement',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debian 12 — Control Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
          ),
          IconButton(
            icon: const Icon(Icons.published_with_changes),
            tooltip: 'Recharger Squid',
            onPressed: _triggerProxyReload,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 60, color: Colors.red),
                        const SizedBox(height: 10),
                        Text('Erreur de connexion Tailscale :\n$_errorMessage',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 15),
                        ElevatedButton(
                          onPressed: _loadAllData,
                          child: const Text('Réessayer'),
                        )
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAllData,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      _buildSystemMetricsCard(),
                      const SizedBox(height: 16),
                      _buildServicesStatusCard(),
                      const SizedBox(height: 16),
                      _buildProxyClientsCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSystemMetricsCard() {
    final sys = _healthData?['system'] ?? {};
    final net = sys['network_bandwidth'] ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ressources Système',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildMetricBar('CPU', (sys['cpu_percent'] ?? 0.0) / 100,
                '${sys['cpu_percent']}%', Colors.blue),
            _buildMetricBar('RAM', (sys['ram_percent'] ?? 0.0) / 100,
                '${sys['ram_percent']}%', Colors.purple),
            _buildMetricBar('Disque', (sys['disk_percent'] ?? 0.0) / 100,
                '${sys['disk_percent']}%', Colors.orange),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  children: [
                    const Icon(Icons.arrow_downward, color: Colors.green),
                    Text(' Down: ${net['download_kbps'] ?? 0} Ko/s'),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.arrow_upward, color: Colors.blue),
                    Text(' Up: ${net['upload_kbps'] ?? 0} Ko/s'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBar(
      String label, double progress, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(label), Text(text)],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            color: color,
            backgroundColor: color.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesStatusCard() {
    final services = _healthData?['services'] ?? {};
    final docker = _healthData?['docker'] ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Statut des Services',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildServiceChip('Postfix', services['postfix']),
                _buildServiceChip('Dovecot', services['dovecot']),
                _buildServiceChip('Samba', services['samba']),
                _buildServiceChip('Nginx', services['nginx']),
                _buildServiceChip('Squid', services['squid']),
                _buildServiceChip('Nextcloud App', docker['nextcloud_app']),
                _buildServiceChip('Nextcloud DB', docker['nextcloud_db']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceChip(String name, String? status) {
    bool isActive = status == 'active' || status == 'running';
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: isActive ? Colors.green : Colors.red,
        radius: 6,
      ),
      label: Text('$name: ${status ?? "inconnu"}'),
    );
  }

  Widget _buildProxyClientsCard() {
    final List clients = _proxyData?['clients_usage'] ?? [];
    final filtering = _proxyData?['filtering'] ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('PC Clients & Filtrage',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Chip(
                  label: Text('Bloqués: ${filtering['total_blocked'] ?? 0}'),
                  backgroundColor: Colors.red.withOpacity(0.2),
                ),
              ],
            ),
            const Divider(),
            if (clients.isEmpty)
              const Text('Aucun trafic proxy enregistré récemment.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: clients.length,
                itemBuilder: (context, index) {
                  final client = clients[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.computer),
                    title: Text(client['client_ip']),
                    trailing: Text(
                      '${client['megabytes']} Mo',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
