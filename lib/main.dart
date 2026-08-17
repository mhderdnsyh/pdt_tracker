import 'package:flutter/material.dart';
import 'services/alarm_service.dart';
import 'services/mqtt_service.dart';

void main() {
  runApp(const PdtTrackerApp());
}

class PdtTrackerApp extends StatelessWidget {
  const PdtTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDT Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const TestingInterface(),
    );
  }
}

class TestingInterface extends StatefulWidget {
  const TestingInterface({super.key});

  @override
  State<TestingInterface> createState() => _TestingInterfaceState();
}

class _TestingInterfaceState extends State<TestingInterface> {
  late final AlarmService _alarmService;
  MqttService? _mqttService;

  final TextEditingController _serverController =
      TextEditingController(text: 'broker.emqx.io');

  final TextEditingController _topicController =
      TextEditingController(text: 'pdt_tracker/alerts');
  final TextEditingController _messageController =
      TextEditingController(text: 'EMERGENCY_ALARM');

  bool _isMqttConnected = false;
  bool _isAlarmPlaying = false;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _alarmService = AlarmService();
    _addLog('System initialized.');
  }

  void _addLog(String msg) {
    setState(() {
      _logs.insert(0, '[${DateTime.now().toString().split('.').first}] $msg');
    });
  }

  Future<void> _toggleMqttConnection() async {
    if (_isMqttConnected) {
      _mqttService?.disconnect();
      setState(() {
        _isMqttConnected = false;
      });
      _addLog('MQTT Disconnected.');
    } else {
      final server = _serverController.text.trim();
      if (server.isEmpty) return;

      _addLog('Connecting to MQTT broker: $server...');
      _mqttService = MqttService(
        server: server,
        clientId: 'pdt_client_${DateTime.now().millisecondsSinceEpoch}',
      );

      final errorMsg = await _mqttService!.connect();
      final isConnected = (errorMsg == null);
      setState(() {
        _isMqttConnected = isConnected;
      });

      if (isConnected) {
        _addLog('Connected to MQTT successfully!');
        final topic = _topicController.text.trim();
        if (topic.isNotEmpty) {
          _mqttService!.subscribe(topic);
          _addLog('Subscribed to topic: $topic');
        }

        _mqttService!.messageStream.listen((msg) {
          _addLog('Received MQTT Message: $msg');
          final upper = msg.toUpperCase();
          if (upper.contains('STOP') || upper.contains('OFF')) {
            _stopAlarm();
          } else if (upper.contains('ALARM') || upper.contains('TRIGGER')) {
            _triggerAlarm();
          }
        });

      } else {
        _addLog('MQTT Error: $errorMsg');
      }

    }
  }

  Future<void> _triggerAlarm() async {
    _addLog('Triggering high-pitch alarm & max volume...');
    await _alarmService.triggerAlarm();
    setState(() {
      _isAlarmPlaying = true;
    });
  }

  Future<void> _stopAlarm() async {
    _addLog('Stopping alarm...');
    await _alarmService.stopAlarm();
    setState(() {
      _isAlarmPlaying = false;
    });
  }

  void _sendMqttMessage() {
    if (_mqttService != null && _isMqttConnected) {
      final topic = _topicController.text.trim();
      final msg = _messageController.text.trim();
      if (topic.isNotEmpty && msg.isNotEmpty) {
        _mqttService!.publish(topic, msg);
        _addLog('Sent MQTT message to [$topic]: $msg');
      }
    } else {
      _addLog('Cannot send message: MQTT not connected.');
    }
  }

  @override
  void dispose() {
    _alarmService.dispose();
    _mqttService?.dispose();
    _serverController.dispose();
    _topicController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.indigoAccent),
            SizedBox(width: 10),
            Text(
              'PDT Tracker Tester',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Dashboard
            Row(
              children: [
                Expanded(
                  child: _buildStatusCard(
                    title: 'Alarm Status',
                    status: _isAlarmPlaying ? 'RINGING' : 'IDLE',
                    color: _isAlarmPlaying ? Colors.redAccent : const Color(0xFF10B981),
                    icon: _isAlarmPlaying
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatusCard(
                    title: 'MQTT Status',
                    status: _isMqttConnected ? 'CONNECTED' : 'DISCONNECTED',
                    color: _isMqttConnected ? Colors.indigoAccent : Colors.grey,
                    icon: _isMqttConnected ? Icons.wifi : Icons.wifi_off,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Audio & Alarm Test Card
            _buildSectionCard(
              title: 'Audio Alarm Control',
              icon: Icons.volume_up,
              child: Column(
                children: [
                  const Text(
                    'Pemicu alarm frekuensi tinggi dengan otomatis menyetel volume perangkat ke maksimum.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _triggerAlarm,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('PLAY ALARM'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _stopAlarm,
                          icon: const Icon(Icons.stop),
                          label: const Text('STOP ALARM'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Colors.white30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // MQTT Connection Test Card
            _buildSectionCard(
              title: 'MQTT Broker Control',
              icon: Icons.cloud_sync,
              child: Column(
                children: [
                  TextField(
                    controller: _serverController,
                    decoration: const InputDecoration(
                      labelText: 'MQTT Server Host',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.dns),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _topicController,
                    decoration: const InputDecoration(
                      labelText: 'Topic',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.topic),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _toggleMqttConnection,
                      icon: Icon(_isMqttConnected ? Icons.link_off : Icons.link),
                      label: Text(_isMqttConnected ? 'DISCONNECT MQTT' : 'CONNECT MQTT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isMqttConnected ? Colors.deepOrange : Colors.indigoAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  if (_isMqttConnected) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              labelText: 'Payload',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.message),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sendMqttMessage,
                          icon: const Icon(Icons.send),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Logs Section
            _buildSectionCard(
              title: 'System Activity Logs',
              icon: Icons.list_alt,
              child: Container(
                height: 180,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: _logs.isEmpty
                    ? const Center(
                        child: Text(
                          'No activity logs yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              _logs[index],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: Colors.greenAccent,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String status,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.indigoAccent),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Colors.white10),
          child,
        ],
      ),
    );
  }
}
