// lib/features/back_office/providers/support_tickets_provider.dart
// Back-Office — Providers de soporte y reclamos (Riverpod)

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/support_ticket.dart';
import '../data/repositories/support_tickets_repository.dart';

part 'support_tickets_provider.g.dart';

@Riverpod(keepAlive: true)
SupportTicketsRepository supportTicketsRepository(
        SupportTicketsRepositoryRef ref) =>
    SupportTicketsRepository();

/// Stream de tickets abiertos en tiempo real.
@riverpod
Stream<List<SupportTicket>> openTickets(OpenTicketsRef ref) {
  final repo = ref.watch(supportTicketsRepositoryProvider);
  return repo.watchOpen();
}

/// Todos los tickets (snapshot, no stream) — para la vista de historial.
@riverpod
Future<List<SupportTicket>> allTickets(AllTicketsRef ref) {
  final repo = ref.watch(supportTicketsRepositoryProvider);
  return repo.fetchAll();
}
