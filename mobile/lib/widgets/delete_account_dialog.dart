// ABOUTME: Dialog widgets for account deletion flow
// ABOUTME: Warning dialog with confirmation and completion dialog with next steps

import 'package:flutter/material.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Show warning dialog before account deletion
Future<void> showDeleteAccountWarningDialog({
  required BuildContext context,
  required VoidCallback onConfirm,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text(
        '⚠️ Delete Account?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: const Text(
        'This action is PERMANENT and cannot be undone.\n\n'
        'This will:\n'
        '• Request deletion of ALL your content from Nostr relays\n'
        '• Remove your Nostr keys from this device\n'
        '• Sign you out immediately\n\n'
        'Your videos, profile, and all activity will be deleted from '
        'participating relays. Some relays may not honor deletion requests.\n\n'
        'Are you absolutely sure?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text(
            'Delete My Account',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

/// Show completion dialog after account deletion
Future<void> showDeleteAccountCompletionDialog({
  required BuildContext context,
  required VoidCallback onCreateNewAccount,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text(
        '✓ Account Deleted',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: const Text(
        'Your deletion request has been sent to Nostr relays.\n\n'
        'You\'ve been signed out and your keys have been removed from this device.',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Close',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCreateNewAccount();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.vineGreen,
            foregroundColor: Colors.white,
          ),
          child: const Text(
            'Create New Account',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}
