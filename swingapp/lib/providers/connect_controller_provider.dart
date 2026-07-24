import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;
import '../models/song.dart';

class AskariaDevice {
  final nsd.Service nsdService;
  final String name;
  final String host;
  final int port;

  AskariaDevice({
    required this.nsdService,
    required this.name,
    required this.host,
    required this.port,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AskariaDevice &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port;

  @override
  int get hashCode => host.hashCode ^ port.hashCode;
}

class ConnectControllerProvider extends ChangeNotifier {
  nsd.Discovery? _discovery;
  final List<AskariaDevice> _devices = [];
  bool _isScanning = false;

  AskariaDevice? _connectedDevice;
  WebSocket? _socket;

  // State from the connected device
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Song? _currentSong;

  // Getters
  List<AskariaDevice> get devices => _devices;
  bool get isScanning => _isScanning;
  AskariaDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _socket != null && _socket!.readyState == WebSocket.open;
  
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  Song? get currentSong => _currentSong;

  Future<void> startDiscovery() async {
    if (_isScanning) return;
    _isScanning = true;
    _devices.clear();
    notifyListeners();

    try {
      _discovery = await nsd.startDiscovery('_askaria._tcp');
      _discovery!.addListener(() {
        _devices.clear();
        for (final service in _discovery!.services) {
          if (service.host != null && service.port != null) {
            _devices.add(AskariaDevice(
              nsdService: service,
              name: service.name ?? 'Unknown Device',
              host: service.host!,
              port: service.port!,
            ));
          }
        }
        notifyListeners();
      });
    } catch (e) {
      debugPrint('[ConnectController] Discovery error: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopDiscovery() async {
    if (_discovery != null) {
      await nsd.stopDiscovery(_discovery!);
      _discovery = null;
    }
    _isScanning = false;
    notifyListeners();
  }

  Future<void> connectTo(AskariaDevice device) async {
    await disconnect(); // Disconnect existing

    try {
      final wsUrl = 'ws://${device.host}:${device.port}/connect';
      debugPrint('[ConnectController] Connecting to $wsUrl');
      _socket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 5));
      _connectedDevice = device;
      
      _socket!.listen(
        _handleMessage,
        onDone: () => disconnect(),
        onError: (e) => disconnect(),
      );
      
      notifyListeners();
    } catch (e) {
      debugPrint('[ConnectController] Connection failed: $e');
      await disconnect();
    }
  }

  Future<void> disconnect() async {
    if (_socket != null) {
      await _socket!.close();
      _socket = null;
    }
    _connectedDevice = null;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _currentSong = null;
    notifyListeners();
  }

  void _handleMessage(dynamic message) {
    if (message is String) {
      try {
        final data = json.decode(message);
        if (data['type'] == 'state_update') {
          _isPlaying = data['is_playing'] ?? false;
          _position = Duration(milliseconds: data['position_ms'] ?? 0);
          _duration = Duration(milliseconds: data['duration_ms'] ?? 0);
          
          final songData = data['song'];
          if (songData != null) {
            _currentSong = Song.fromJson(songData);
          } else {
            _currentSong = null;
          }
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[ConnectController] Parse error: $e');
      }
    }
  }

  void _sendCommand(String action, [Map<String, dynamic>? extraParams]) {
    if (!isConnected) return;
    
    final payload = {'action': action};
    if (extraParams != null) {
      payload.addAll(extraParams);
    }
    
    _socket!.add(json.encode(payload));
  }

  // --- Remote Control Commands ---
  
  void playSong(Song song) {
    // Send full song metadata so the receiver can play it
    _sendCommand('play', {
      'song': {
        'hash': song.hash,
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'image': song.image,
        'filepath': song.filepath,
      }
    });
  }

  void playPause() {
    _sendCommand('play_pause');
  }

  void next() {
    _sendCommand('next');
  }

  void previous() {
    _sendCommand('previous');
  }

  void seek(Duration pos) {
    _sendCommand('seek', {'position_ms': pos.inMilliseconds});
  }

  @override
  void dispose() {
    stopDiscovery();
    disconnect();
    super.dispose();
  }
}
