import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/spin_models.dart';
import '../providers/voucher_provider.dart';

/// Opens Spin & Win when a transaction unlocks a spin (or bulk verify returns
/// [SpinUnlock]).
Future<void> openSpinIfAvailable(
  BuildContext context, {
  String? transactionId,
  String? campaignId,
  SpinUnlock? spinUnlocked,
  WidgetRef? ref,
  bool probeStatus = false,
}) async {
  final unlocked = spinUnlocked;
  final txId = (unlocked?.transactionId ?? transactionId)?.trim();
  var hasSpin =
      unlocked?.hasSpinAvailable ?? (txId != null && txId.isNotEmpty);
  if (txId == null || txId.isEmpty) return;

  if (probeStatus && ref != null) {
    try {
      final status =
          await ref.read(voucherRepositoryProvider).spinStatus(txId);
      hasSpin = status.hasSpinAvailable;
      if (!hasSpin) return;
    } catch (_) {
      return;
    }
  } else if (unlocked != null && !unlocked.hasSpinAvailable) {
    return;
  }

  if (!hasSpin || !context.mounted) return;

  await Navigator.of(context).pushNamed(
    'spinWin',
    arguments: <String, dynamic>{
      'transactionId': txId,
      if (campaignId != null || unlocked?.campaignId != null)
        'campaignId': campaignId ?? unlocked?.campaignId,
    },
  );
}

/// Pulls a transaction id from common redemption / booking response shapes.
String? extractTransactionId(Map<String, dynamic>? data) {
  if (data == null) return null;
  final nested = data['redemption'] is Map
      ? Map<String, dynamic>.from(data['redemption'] as Map)
      : data;
  final candidates = [
    data['transactionId'],
    data['transaction_id'],
    nested['transactionId'],
    nested['transaction_id'],
    nested['_id'],
    nested['id'],
    data['_id'],
    data['id'],
    data['redemptionId'],
  ];
  for (final c in candidates) {
    final s = c?.toString().trim();
    if (s != null && s.isNotEmpty) return s;
  }
  return null;
}

SpinUnlock? extractSpinUnlock(Map<String, dynamic>? data) {
  if (data == null) return null;
  return SpinUnlock.tryParse(data['spinUnlocked']) ??
      SpinUnlock.tryParse(
        data['data'] is Map ? (data['data'] as Map)['spinUnlocked'] : null,
      );
}
