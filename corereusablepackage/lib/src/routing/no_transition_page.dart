import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// GoRouter page builder with no transition animation (instant swap).
Page<void> noTransitionPage({required Widget child, LocalKey? key}) {
  return NoTransitionPage<void>(key: key, child: child);
}
