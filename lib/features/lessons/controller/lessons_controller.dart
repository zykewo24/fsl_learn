import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedLevelProvider = StateProvider<int>(
  (ref) => 1,
);

final searchQueryProvider = StateProvider<String>(
  (ref) => '',
);

// Kept alive for the app lifetime (not autoDispose) so the text field and
// [searchQueryProvider] stay in sync when the Lessons tab is unmounted and
// remounted by the home shell.
final searchControllerProvider = Provider<TextEditingController>((ref) {
  final controller = TextEditingController();

  ref.onDispose(() {
    controller.dispose();
  });

  return controller;
});