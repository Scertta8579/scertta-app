import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color kScerttaTealInbox = Color(0xFF00838F);

/// Bandeja solo para notificaciones persistidas (marketing / sistema), no chats de viaje.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _loading = false;
        _error = 'Sesión no disponible';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _supabase
          .from('notificaciones_app')
          .select('id,titulo,cuerpo,tipo,leida_at,created_at')
          .eq('perfil_id', uid)
          .order('created_at', ascending: false)
          .limit(80);
      final list = (res as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _items = [];
          _loading = false;
          _error =
              'No se pudieron cargar las notificaciones. Ejecutá la migración SQL `notificaciones_app` en Supabase o revisá políticas RLS.';
        });
      }
    }
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    try {
      final dt = DateTime.parse(s).toLocal();
      final now = DateTime.now();
      final d = DateTime(now.year, now.month, now.day).difference(DateTime(dt.year, dt.month, dt.day)).inDays;
      if (d == 0) return 'Hoy ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (d == 1) return 'Ayer';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return s;
    }
  }

  Future<void> _marcarLeida(String id) async {
    try {
      await _supabase.from('notificaciones_app').update({'leida_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
      await _load();
    } catch (_) {
      /* ignorar: UI ya mostró lista */
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Bandeja de Entrada',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: kScerttaTealInbox,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kScerttaTealInbox))
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[800], height: 1.4),
                      ),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        children: const [
                          SizedBox(height: 48),
                          Icon(Icons.notifications_none, size: 56, color: Colors.black26),
                          SizedBox(height: 16),
                          Text(
                            'No hay notificaciones de marketing ni del sistema.\nCuando lleguen avisos push guardados, aparecerán aquí.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black54, height: 1.35),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final row = _items[i];
                          final titulo = row['titulo']?.toString() ?? 'Aviso';
                          final cuerpo = row['cuerpo']?.toString() ?? '';
                          final tipo = row['tipo']?.toString() ?? 'sistema';
                          final leida = row['leida_at'] != null;
                          final id = row['id']?.toString();
                          return _NotificacionTile(
                            title: titulo,
                            subtitle: cuerpo,
                            time: _formatTime(row['created_at']),
                            tipo: tipo,
                            isNew: !leida,
                            onTap: id != null && !leida ? () => _marcarLeida(id) : null,
                          );
                        },
                      ),
      ),
    );
  }
}

class _NotificacionTile extends StatelessWidget {
  const _NotificacionTile({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.tipo,
    required this.isNew,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String time;
  final String tipo;
  final bool isNew;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final esMarketing = tipo.toLowerCase() == 'marketing';
    return Card(
      elevation: 0,
      color: isNew ? kScerttaTealInbox.withValues(alpha: 0.06) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: esMarketing ? Colors.deepPurple.shade100 : kScerttaTealInbox,
          child: Icon(
            esMarketing ? Icons.campaign_outlined : Icons.notifications_active_outlined,
            color: esMarketing ? Colors.deepPurple : Colors.white,
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isNew ? FontWeight.bold : FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            if (isNew)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: kScerttaTealInbox,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Nuevo',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(subtitle, maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(
              '$time · ${esMarketing ? 'Marketing' : 'Sistema'}',
              style: TextStyle(fontSize: 12, color: Colors.grey[800]),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
