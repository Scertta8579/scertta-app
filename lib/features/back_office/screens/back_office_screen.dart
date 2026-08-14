// lib/features/back_office/screens/back_office_screen.dart
// Back-Office — Pantalla principal del Panel Admin
//
// Estructura:
//   DefaultTabController (3 tabs)
//     AppBar
//       TabBar
//         Tab: Soporte y Reclamos   (ícono + badge de tickets abiertos)
//         Tab: Validación de Docs   (ícono + badge de documentos pendientes)
//         Tab: Piloto Automático IA (ícono)
//     TabBarView
//       SupportTicketsTab
//       DocumentValidationTab
//       AiAutomationTab

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/document_validation_provider.dart';
import '../providers/support_tickets_provider.dart';
import '../widgets/ai_automation_tab.dart';
import '../widgets/document_validation_tab.dart';
import '../widgets/support_tickets_tab.dart';

class BackOfficeScreen extends ConsumerWidget {
  const BackOfficeScreen({super.key});

  static const routeName = '/back-office';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Panel Admin',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            isScrollable: false,
            tabs: [
              _TabWithBadge(
                icon: Icons.support_agent_outlined,
                label: 'Soporte',
                badgeAsync: ref.watch(openTicketsProvider).whenData(
                      (tickets) => tickets.length,
                    ),
              ),
              _TabWithBadge(
                icon: Icons.document_scanner_outlined,
                label: 'Documentos',
                badgeAsync: ref.watch(pendingDocumentsProvider).whenData(
                      (docs) => docs.length,
                    ),
              ),
              const Tab(
                icon: Icon(Icons.auto_awesome_outlined),
                text: 'IA Automática',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SupportTicketsTab(),
            DocumentValidationTab(),
            AiAutomationTab(),
          ],
        ),
      ),
    );
  }
}

/// Tab con badge numérico cuando hay ítems pendientes.
class _TabWithBadge extends StatelessWidget {
  const _TabWithBadge({
    required this.icon,
    required this.label,
    required this.badgeAsync,
  });

  final IconData icon;
  final String label;
  final AsyncValue<int> badgeAsync;

  @override
  Widget build(BuildContext context) {
    final count = badgeAsync.valueOrNull ?? 0;

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
