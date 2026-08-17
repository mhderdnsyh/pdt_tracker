import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  MqttServerClient? _client;
  final String server;
  final String clientId;
  final int port;
  
  final _messageStreamController = StreamController<String>.broadcast();
  Stream<String> get messageStream => _messageStreamController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  MqttService({
    required this.server,
    required this.clientId,
    this.port = 1883,
  });

  Future<String?> connect() async {
    _client = MqttServerClient.withPort(server, clientId, port);
    _client!.logging(on: false);
    _client!.setProtocolV311();
    _client!.autoReconnect = true;
    _client!.resubscribeOnAutoReconnect = true;
    _client!.keepAlivePeriod = 20;
    _client!.connectTimeoutPeriod = 10000;

    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;


    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean();

    _client!.connectionMessage = connMess;

    try {
      await _client!.connect();
    } catch (e) {
      debugPrint('MQTT Client exception: $e');
      _client!.disconnect();
      _isConnected = false;
      return 'Error: $e';
    }

    if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
      debugPrint('MQTT client connected');
      _isConnected = true;

      _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final recMess = c[0].payload as MqttPublishMessage;
        final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        _messageStreamController.add(pt);
      });

      return null; // Success
    } else {
      final status = _client!.connectionStatus?.state.toString() ?? 'Unknown';
      debugPrint('MQTT connection failed - status is $status');
      _client!.disconnect();
      _isConnected = false;
      return 'Failed (Status: $status)';
    }
  }


  void subscribe(String topic) {
    if (_isConnected && _client != null) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
    }
  }

  void publish(String topic, String message) {
    if (_isConnected && _client != null) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    }
  }

  void disconnect() {
    _client?.disconnect();
  }

  void _onConnected() {
    _isConnected = true;
    debugPrint('Connected to MQTT Broker');
  }

  void _onDisconnected() {
    _isConnected = false;
    debugPrint('Disconnected from MQTT Broker');
  }

  void _onSubscribed(String topic) {
    debugPrint('Subscribed to topic: $topic');
  }

  void dispose() {
    _messageStreamController.close();
    disconnect();
  }
}

