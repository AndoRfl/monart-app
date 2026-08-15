import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MonitoringApp());
}

class MonitoringApp extends StatelessWidget {
  const MonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MonArt Supervision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
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
  // Adresse IP de votre serveur Debian
  final String serverIp = "192.168.56.10";
  Timer? _timer;
  
  Map<String, dynamic>? metricsData;
  bool isLoading = true;
  String errorMessage = "";
  double selectedQosLimit = 0; // 0 = Unlimited

  @override
  void initState() {
    super.initState();
    fetchMetrics();
    // Rafraîchissement automatique toutes les 3 secondes
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      fetchMetrics();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchMetrics() async {
    try {
      final response = await http
          .get(Uri.parse('http://$serverIp:8000/api/metrics'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        setState(() {
          metricsData = json.decode(response.body);
          isLoading = false;
          errorMessage = "";
        });
      } else {
        setState(() {
          errorMessage = "Erreur serveur : ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Impossible de joindre l'API ($serverIp)";
        isLoading = false;
      });
    }
  }

  Future<void> applyQos(int limitMbit) async {
    try {
      final response = await http.post(
        Uri.parse('http://$serverIp:8000/api/qos/limit?rate_mbit=$limitMbit'),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Limitation QoS appliquée : ${limitMbit == 0 ? 'Illimité' : '$limitMbit Mbit/s'}"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Échec de l'action QoS : $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Supervision MonArt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchMetrics,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage, style: const TextStyle(color: Colors.red, fontSize: 16)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAlignment.start,
                    children: [
                      // SECTION 1 : METRIQUES SYSTEME
                      const Text("Ressources Serveur", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildGaugeCard("CPU", "${metricsData!['system']['cpu_percent']}%", metricsData!['system']['cpu_percent'] / 100),
                          _buildGaugeCard("RAM", "${metricsData!['system']['ram_percent']}%", metricsData!['system']['ram_percent'] / 100),
                          _buildGaugeCard("Disque", "${metricsData!['system']['disk_percent']}%", metricsData!['system']['disk_percent'] / 100),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECTION 2 : RESEAU & BANDE PASSANTE
                      const Text("Bande Passante & Trafic", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Icon(Icons.arrow_downward, color: Colors.green, size: 30),
                                  const SizedBox(height: 5),
                                  Text("RX (Download)", style: TextStyle(color: Colors.grey[400])),
                                  Text("${metricsData!['network']['rx_kbps']} Kbps", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                children: [
                                  const Icon(Icons.arrow_upward, color: Colors.blue, size: 30),
                                  const SizedBox(height: 5),
                                  Text("TX (Upload)", style: TextStyle(color: Colors.grey[400])),
                                  Text("${metricsData!['network']['tx_kbps']} Kbps", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // SECTION 3 : CONTRÔLE DE TRAFIC (QoS)
                      const Text("Actionneur QoS (Bande Passante)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Text("Appliquer une restriction de débit sur le réseau :"),
                              const SizedBox(height: 15),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => applyQos(2),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                    child: const Text("2 Mbps"),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => applyQos(5),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                                    child: const Text("5 Mbps"),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => applyQos(0),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    child: const Text("Illimité"),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // SECTION 4 : STATUT DES SERVICES
                      const Text("Services Réseau", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      _buildServiceTile("DNS (BIND9)", metricsData!['services']['dns_bind9']),
                      _buildServiceTile("Serveur Web Apache2", metricsData!['services']['apache2']),
                      _buildServiceTile("VPN OpenVPN", metricsData!['services']['openvpn']),
                    ],
                  ),
                ),
    );
  }

  Widget _buildGaugeCard(String title, String value, double percent) {
    Color progressColor = percent > 0.85 ? Colors.red : (percent > 0.7 ? Colors.orange : Colors.blue);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: percent,
                    color: progressColor,
                    backgroundColor: Colors.grey[800],
                  ),
                  Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTile(String name, bool isOnline) {
    return Card(
      child: ListTile(
        leading: Icon(
          isOnline ? Icons.check_circle : Icons.error,
          color: isOnline ? Colors.green : Colors.red,
        ),
        title: Text(name),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isOnline ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            isOnline ? "ONLINE" : "OFFLINE",
            style: TextStyle(
              color: isOnline ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
