// ABOUTME: Screen for managing Nostr relay connections and settings
// ABOUTME: Allows users to add, remove, and configure relay preferences

import 'package:flutter/material.dart';

/// Screen for managing Nostr relay settings
class RelaySettingsScreen extends StatefulWidget {
  const RelaySettingsScreen({super.key});

  @override
  State<RelaySettingsScreen> createState() => _RelaySettingsScreenState();
}

class _RelaySettingsScreenState extends State<RelaySettingsScreen> {
  final List<String> _relays = [
    'wss://localhost:8080', // Default embedded relay
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relay Settings'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: ListView.builder(
        itemCount: _relays.length,
        itemBuilder: (context, index) {
          final relay = _relays[index];
          return ListTile(
            title: Text(
              relay,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Connected',
              style: TextStyle(color: Colors.green[400]),
            ),
            trailing: relay != 'wss://localhost:8080' 
                ? IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeRelay(index),
                  )
                : null,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRelay,
        backgroundColor: Colors.purple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _addRelay() {
    // TODO: Implement add relay dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add relay functionality coming soon'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  void _removeRelay(int index) {
    setState(() {
      _relays.removeAt(index);
    });
  }
}