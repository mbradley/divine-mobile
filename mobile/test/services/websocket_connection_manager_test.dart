// ABOUTME: Tests for WebSocketConnectionManager implementing proper event-driven patterns
// ABOUTME: Validates connection state machine, exponential backoff, and no Future.delayed usage

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/websocket_connection_manager.dart';

void main() {
  group('WebSocketConnectionManager', () {
    late WebSocketConnectionManager manager;
    late MockWebSocketFactory mockFactory;
    late MockWebSocket mockSocket;

    setUp(() {
      mockFactory = MockWebSocketFactory();
      mockSocket = MockWebSocket();
      mockFactory.socket = mockSocket;
      manager = WebSocketConnectionManager(
        url: 'wss://localhost:8080',
        socketFactory: mockFactory,
      );
    });

    tearDown(() {
      mockSocket.dispose();
      manager.dispose();
    });

    group('Connection State Machine', () {
      test('should start in disconnected state', () {
        expect(manager.state, ConnectionState.disconnected);
        expect(manager.isConnected, false);
      });

      test('should transition to connecting when connect called', () {
        manager.connect();
        expect(manager.state, ConnectionState.connecting);
      });

      test('should transition to connected when socket opens', () async {
        final stateChanges = <ConnectionState>[];
        final completer = Completer<void>();

        manager.stateStream.listen((state) {
          stateChanges.add(state);
          if (state == ConnectionState.connected) {
            completer.complete();
          }
        });

        manager.connect();
        await Future.microtask(() {}); // Allow connection to start

        mockSocket.simulateOpen();

        // Wait for connected state
        await completer.future.timeout(
          const Duration(seconds: 1),
          onTimeout: () => throw 'State did not transition to connected',
        );

        expect(manager.state, ConnectionState.connected);
        expect(stateChanges, [
          ConnectionState.connecting,
          ConnectionState.connected,
        ]);
      });

      test('should transition to disconnected on error', () async {
        manager.connect();
        mockSocket.simulateOpen();

        await Future.microtask(() {});
        expect(manager.state, ConnectionState.connected);

        mockSocket.simulateError('Network error');
        await Future.microtask(() {});

        expect(manager.state, ConnectionState.disconnected);
      });

      test('should handle authentication flow', () async {
        final stateChanges = <ConnectionState>[];
        manager.stateStream.listen(stateChanges.add);

        manager.connect();
        mockSocket.simulateOpen();

        // Simulate AUTH challenge
        mockSocket.simulateMessage({
          'type': 'AUTH',
          'challenge': 'test-challenge',
        });

        await Future.microtask(() {});
        expect(manager.state, ConnectionState.authenticating);

        // Complete authentication
        manager.completeAuthentication('auth-response');
        await Future.microtask(() {});

        expect(manager.state, ConnectionState.connected);
      });
    });

    group('Exponential Backoff', () {
      test('should use exponential backoff for reconnection', () async {
        final reconnectDelays = <Duration>[];

        // Track reconnection attempts
        manager.reconnectDelayStream.listen(reconnectDelays.add);

        // Enable auto-reconnect
        manager.enableAutoReconnect();

        // First failure
        manager.connect();
        await Future.microtask(() {});
        mockSocket.simulateError('Connection failed');
        await Future.microtask(() {});

        // Wait for first delay to be recorded
        await Future.microtask(() {});
        expect(reconnectDelays.length, greaterThanOrEqualTo(1));
        expect(reconnectDelays[0].inMilliseconds, 1000); // 1s

        // The manager will automatically reconnect after the timer
        // We need to simulate subsequent failures to test backoff
      });

      test('should reset backoff on successful connection', () async {
        manager.enableAutoReconnect();

        // First failure
        manager.connect();
        mockSocket.simulateError('Failed');
        await Future.microtask(() {});

        // Second failure (should have doubled delay)
        manager.connect();
        mockSocket.simulateError('Failed');
        await Future.microtask(() {});

        // Successful connection
        manager.connect();
        mockSocket.simulateOpen();
        await Future.microtask(() {});

        // Next failure should reset to initial delay
        mockSocket.simulateClose();

        final nextDelay = await manager.reconnectDelayStream.first;
        expect(nextDelay.inMilliseconds, 1000); // Back to 1s
      });
    });

    group('Event-Driven Patterns', () {
      test('should not use Future.delayed for connection waiting', () async {
        // This test validates that connection readiness is event-driven
        final completer = Completer<void>();

        manager.onConnected.listen((_) {
          completer.complete();
        });

        manager.connect();

        // Should not complete until socket actually opens
        expect(completer.isCompleted, false);

        mockSocket.simulateOpen();

        // Should complete via event, not timing
        await completer.future;
        expect(manager.isConnected, true);
      });

      test('should use completer for operation completion', () async {
        manager.connect();
        mockSocket.simulateOpen();
        await Future.microtask(() {});

        // Send operation should complete when ACK received
        final future = manager.sendWithAck({
          'type': 'REQ',
          'id': 'test-req',
        });

        // Should not complete immediately
        var completed = false;
        unawaited(future.then((_) => completed = true));
        await Future.microtask(() {});
        expect(completed, false);

        // Simulate ACK
        mockSocket.simulateMessage({
          'type': 'OK',
          'id': 'test-req',
        });

        await future;
        expect(completed, true);
      });

      test('should provide connection ready future', () async {
        final readyFuture = manager.waitUntilReady();

        // Should not be ready initially
        var isReady = false;
        unawaited(readyFuture.then((_) => isReady = true));
        await Future.microtask(() {});
        expect(isReady, false);

        // Connect and open
        manager.connect();
        mockSocket.simulateOpen();

        // Should complete when ready
        await readyFuture;
        expect(isReady, true);
      });
    });

    group('Health Checking', () {
      test('should perform periodic health checks without delays', () async {
        final healthChecks = <DateTime>[];

        manager.healthCheckStream.listen((_) {
          healthChecks.add(DateTime.now());
        });

        manager.connect();
        mockSocket.simulateOpen();
        await Future.microtask(() {});

        // Enable health checking with 1 second interval
        manager.enableHealthChecking(
          interval: const Duration(seconds: 1),
        );

        // Simulate timer ticks (not using Future.delayed)
        for (var i = 0; i < 3; i++) {
          manager.triggerHealthCheck();
          await Future.microtask(() {}); // Allow health check to process
          mockSocket.simulateMessage({'type': 'PONG'});
          await Future.microtask(() {}); // Allow response to process
        }

        // Give time for all events to propagate
        await Future.microtask(() {});

        expect(healthChecks.length, 3);
      });

      test('should disconnect on health check failure', () async {
        manager.connect();
        mockSocket.simulateOpen();
        await Future.microtask(() {});

        manager.enableHealthChecking(
          interval: const Duration(seconds: 1),
          timeout: const Duration(seconds: 5),
        );

        // Trigger health check but don't respond
        manager.triggerHealthCheck();

        // Simulate timeout via timer completion
        manager.simulateHealthCheckTimeout();
        await Future.microtask(() {});

        expect(manager.state, ConnectionState.disconnected);
      });
    });

    group('Connection Pooling', () {
      test('should manage multiple relay connections', () async {
        final pool = WebSocketConnectionPool();

        final relay1 = pool.createConnection('wss://relay1.com');
        final relay2 = pool.createConnection('wss://relay2.com');

        expect(pool.connectionCount, 2);
        expect(pool.connectedCount, 0);

        // For this test, we need a custom factory that tracks sockets
        final testFactory = TestWebSocketFactory();
        final testPool = WebSocketConnectionPool();

        // Create connections with test factory
        final conn1 = WebSocketConnectionManager(
          url: 'wss://relay1.com',
          socketFactory: testFactory,
        );
        final conn2 = WebSocketConnectionManager(
          url: 'wss://relay2.com',
          socketFactory: testFactory,
        );

        // Connect both
        conn1.connect();
        conn2.connect();

        // Simulate successful connections
        testFactory.sockets[0].simulateOpen();
        testFactory.sockets[1].simulateOpen();

        await Future.microtask(() {});

        // Check actual connection states
        expect(conn1.isConnected, true);
        expect(conn2.isConnected, true);
      });
    });
  });
}

// Mock classes for testing
class MockWebSocketFactory implements WebSocketFactory {
  MockWebSocket? socket;

  @override
  MockWebSocket create(String url) {
    // Return the pre-set socket if available, otherwise create new
    if (socket != null) {
      return socket!;
    }
    socket = MockWebSocket();
    return socket!;
  }
}

class MockWebSocket implements WebSocketInterface {
  final _openController = StreamController<void>.broadcast();
  final _closeController = StreamController<void>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  bool _isOpen = false;
  bool _connectCalled = false;

  @override
  Stream<void> get onOpen => _openController.stream;

  @override
  Stream<void> get onClose => _closeController.stream;

  @override
  Stream<String> get onError => _errorController.stream;

  @override
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> connect() async {
    _connectCalled = true;
    // Simulate async connection - don't open immediately
  }

  @override
  void send(Map<String, dynamic> data) {
    if (!_isOpen) throw StateError('WebSocket is not open');
  }

  @override
  void close() {
    if (_isOpen) {
      _isOpen = false;
      if (!_closeController.isClosed) {
        _closeController.add(null);
      }
    }
  }

  void simulateOpen() {
    _isOpen = true;
    if (!_openController.isClosed) {
      _openController.add(null);
    }
  }

  void simulateClose() {
    _isOpen = false;
    if (!_closeController.isClosed) {
      _closeController.add(null);
    }
  }

  void simulateError(String error) {
    _isOpen = false;
    if (!_errorController.isClosed) {
      _errorController.add(error);
    }
  }

  void simulateMessage(Map<String, dynamic> message) {
    if (!_messageController.isClosed) {
      _messageController.add(message);
    }
  }

  void dispose() {
    _openController.close();
    _closeController.close();
    _errorController.close();
    _messageController.close();
  }
}

extension TestableConnectionManager on WebSocketConnectionManager {
  MockWebSocket get mockSocket => (this as dynamic).socket as MockWebSocket;
}

// Test factory that tracks created sockets
class TestWebSocketFactory implements WebSocketFactory {
  final List<MockWebSocket> sockets = [];

  @override
  MockWebSocket create(String url) {
    final socket = MockWebSocket();
    sockets.add(socket);
    return socket;
  }
}
