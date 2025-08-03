// ABOUTME: WebSocket service for real-time profile updates and notifications
// ABOUTME: Handles profile-specific event subscriptions and live data streams

import 'dart:async';

import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/services/nostr_service_interface.dart';

/// Manages WebSocket connections for profile-specific real-time updates
class ProfileWebSocketService {
  ProfileWebSocketService(this._nostrService);
  
  final INostrService _nostrService;
  final Map<String, StreamSubscription<Event>> _profileSubscriptions = {};
  final Map<String, StreamController<Event>> _profileControllers = {};
  
  bool _isDisposed = false;

  /// Subscribes to profile updates for a specific user
  Stream<Event> subscribeToProfile(String pubkey) {
    if (_isDisposed) throw StateError('ProfileWebSocketService is disposed');
    
    final subscriptionId = 'profile_$pubkey';
    
    // Return existing stream if already subscribed
    if (_profileControllers.containsKey(subscriptionId)) {
      return _profileControllers[subscriptionId]!.stream;
    }
    
    final controller = StreamController<Event>.broadcast();
    _profileControllers[subscriptionId] = controller;
    
    // TODO: Set up actual profile subscription using NostrService
    // For now, return empty stream
    
    return controller.stream;
  }

  /// Unsubscribes from profile updates
  Future<void> unsubscribeFromProfile(String pubkey) async {
    final subscriptionId = 'profile_$pubkey';
    
    final subscription = _profileSubscriptions.remove(subscriptionId);
    await subscription?.cancel();
    
    final controller = _profileControllers.remove(subscriptionId);
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }

  /// Gets the list of currently subscribed profile pubkeys
  List<String> get subscribedProfiles {
    return _profileControllers.keys
        .where((key) => key.startsWith('profile_'))
        .map((key) => key.substring('profile_'.length))
        .toList();
  }

  /// Gets a single profile (stub implementation)
  Future<UserProfile?> getProfile(String pubkey) async {
    // TODO: Implement real profile fetching
    return null;
  }

  /// Gets multiple profiles (stub implementation)
  Future<Map<String, UserProfile>> getMultipleProfiles(List<String> pubkeys) async {
    // TODO: Implement real profile fetching
    return {};
  }

  /// Disposes the service and all active subscriptions
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    final subscriptions = List.from(_profileSubscriptions.values);
    _profileSubscriptions.clear();
    
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    
    final controllers = List.from(_profileControllers.values);
    _profileControllers.clear();
    
    for (final controller in controllers) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
    
    _isDisposed = true;
  }
}