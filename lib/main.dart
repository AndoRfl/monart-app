import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MonArtApp());
}

class MonArtApp extends StatelessWidget {
  const MonArtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MonArt Supervision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF1E1E2C),
        cardColor: const Color(0xFF2D2D44),
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
  // ADRESSE IP DU SERVEUR DEBIAN
  final String serverIp = "192.168.56.10";
  
  bool isLoading = true;
  bool isConnected = false;
  Map<String, dynamic> metrics = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchMetrics();
    // Rafraîchissement automatique toutes les 5 secondes
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      fetchMetrics();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchMetrics() async {
    final url = Uri.parse('http://$serverIp:8000/api/metrics');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        setState(() {
          metrics = json.decode(response.body);
          isConnected = true;
          isLoading = false;
        });
      } else {
        setState(() {
          isConnected = false;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isConnected = false;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervision MonArt'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => isLoading = true);
              fetchMetrics();
            },
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 20),
                  const Text(
                    "Métriques Système",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildMetricTile(
                    title: "Utilisation CPU",
                    value: isConnected ? "${metrics['cpu_usage'] ?? 'N/A'} %" : "N/A",
                    icon: Icons.memory,
                    color: Colors.orange,
                  ),
                  _buildMetricTile(
                    title: "Mémoire RAM",
                    value: isConnected ? "${metrics['ram_usage'] ?? 'N/A'} %" : "N/A",
                    icon: Icons.storage,
                    color: Colors.blue,
                  ),
                  _buildMetricTile(
                    title: "Espace Disque",
                    value: isConnected ? "${metrics['disk_usage'] ?? 'N/A'} %" : "N/A",
                    icon: Icons.disc_full,
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Services Réseau",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildServiceTile("PostgreSQL", metrics['services']?['postgresql']),
                  _buildServiceTile("Tomcat 10", metrics['services']?['tomcat']),
                  _buildServiceTile("Caddy Server", metrics['services']?['caddy']),
                  _buildServiceTile("OpenVPN", metrics['services']?['openvpn']),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              isConnected ? Icons.check_circle : Icons.error,
              color: isConnected ? Colors.green : Colors.red,
              size: 36,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? "Serveur En Ligne" : "Serveur Inaccessible",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  "IP: $serverIp",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildServiceTile(String name, dynamic status) {
    bool isOk = status == true || status == "active" || status == "running";
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(name),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isOk ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isOk ? "ACTIF" : "INACTIF",
            style: TextStyle(
              color: isOk ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
