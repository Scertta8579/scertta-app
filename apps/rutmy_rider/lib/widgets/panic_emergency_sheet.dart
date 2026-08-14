import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Claves locales alineadas con la app conductor.
class PanicEmergencyPrefs {
  PanicEmergencyPrefs._();

  static const contactsKey = 'scertta_emergency_contacts_json';
  static const grabarViajeKey = 'scertta_grabar_viajes';
}

Future<List<String>> loadEmergencyContactsLocal() async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString(PanicEmergencyPrefs.contactsKey);
  if (raw == null || raw.isEmpty) return [];
  try {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveEmergencyContactsLocal(List<String> phones) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(PanicEmergencyPrefs.contactsKey, jsonEncode(phones));
}

Future<void> syncEmergencyContactsToPerfil(List<String> phones) async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return;
  try {
    await client.from('perfiles').update({'contactos_emergencia': phones}).eq('id', uid);
  } catch (_) {}
}

Future<void> mergeContactsFromPerfilToPrefs() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return;
  try {
    final row = await client.from('perfiles').select('contactos_emergencia').eq('id', uid).maybeSingle();
    final raw = row?['contactos_emergencia'];
    if (raw is! List || raw.isEmpty) return;
    final fromDb = raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    if (fromDb.isEmpty) return;
    final local = await loadEmergencyContactsLocal();
    if (local.isNotEmpty) return;
    await saveEmergencyContactsLocal(fromDb);
  } catch (_) {}
}

Future<void> activarGrabacionViajeLocal() async {
  final p = await SharedPreferences.getInstance();
  await p.setBool(PanicEmergencyPrefs.grabarViajeKey, true);
}

String _soloDigitos(String s) {
  return s.replaceAll(RegExp(r'\D'), '');
}

Future<void> _enviarSmsUbicacion(String telefono, String cuerpo) async {
  final digits = _soloDigitos(telefono);
  if (digits.isEmpty) return;
  final uri = Uri(scheme: 'sms', path: digits, queryParameters: {'body': cuerpo});
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

Future<void> ejecutarEnvioUbicacionContactos(
  BuildContext context, {
  VoidCallback? onDespuesDeProtocolo,
}) async {
  final contacts = await loadEmergencyContactsLocal();
  if (contacts.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agendá al menos un contacto de emergencia antes de enviar la ubicación.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  await syncEmergencyContactsToPerfil(contacts);

  LocationPermission perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Necesitamos permiso de ubicación para compartir tu posición.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  final pos = await Geolocator.getCurrentPosition();
  final url = 'https://www.google.com/maps?q=${pos.latitude},${pos.longitude}';
  final cuerpo =
      'Emergencia Scertta: necesito ayuda. Mi ubicación: $url (actualizado ${DateTime.now().toIso8601String()})';

  await activarGrabacionViajeLocal();

  for (final t in contacts) {
    await _enviarSmsUbicacion(t, cuerpo);
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ubicación enviada por SMS. Grabación del viaje activada.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    onDespuesDeProtocolo?.call();
  }
}

Future<void> _abrir911() async {
  final uri = Uri(scheme: 'tel', path: '911');
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

void showPanicEmergencySheet(
  BuildContext context, {
  VoidCallback? onDespuesDeUbicacion,
}) {
  unawaited(mergeContactsFromPerfilToPrefs());
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PanicEmergencySheetBody(onDespuesDeUbicacion: onDespuesDeUbicacion),
  );
}

class _PanicEmergencySheetBody extends StatefulWidget {
  const _PanicEmergencySheetBody({this.onDespuesDeUbicacion});

  final VoidCallback? onDespuesDeUbicacion;

  @override
  State<_PanicEmergencySheetBody> createState() => _PanicEmergencySheetBodyState();
}

class _PanicEmergencySheetBodyState extends State<_PanicEmergencySheetBody> {
  List<String> _contacts = [];
  bool _cargando = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final c = await loadEmergencyContactsLocal();
    if (mounted) setState(() {
      _contacts = c;
      _cargando = false;
    });
  }

  Future<void> _editarContactos() async {
    final c1 = TextEditingController(text: _contacts.isNotEmpty ? _contacts[0] : '');
    final c2 = TextEditingController(text: _contacts.length > 1 ? _contacts[1] : '');
    final c3 = TextEditingController(text: _contacts.length > 2 ? _contacts[2] : '');
    bool? ok;
    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('Contactos de emergencia'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Hasta 3 números con código de área. Se usarán para SMS con tu ubicación.'),
                const SizedBox(height: 12),
                TextField(controller: c1, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono 1')),
                TextField(controller: c2, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono 2')),
                TextField(controller: c3, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono 3')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('Guardar')),
          ],
        ),
      );
    } finally {
      final list = [
        c1.text.trim(),
        c2.text.trim(),
        c3.text.trim(),
      ].where((s) => s.isNotEmpty).toList();
      c1.dispose();
      c2.dispose();
      c3.dispose();
      if (ok != true) return;
      await saveEmergencyContactsLocal(list);
      await syncEmergencyContactsToPerfil(list);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 32),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Pánico y emergencias',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Enviá tu ubicación por SMS a tus contactos agendados y activá la grabación del viaje.',
                style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.35),
              ),
              const SizedBox(height: 20),
              if (_cargando)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.group_outlined, color: Colors.teal.shade700),
                  title: const Text('Contactos de emergencia'),
                  subtitle: Text(
                    _contacts.isEmpty ? 'Sin contactos — tocá para agendar' : '${_contacts.length} contacto(s)',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _editarContactos,
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _enviando
                      ? null
                      : () async {
                          setState(() => _enviando = true);
                          try {
                            await ejecutarEnvioUbicacionContactos(
                              context,
                              onDespuesDeProtocolo: widget.onDespuesDeUbicacion,
                            );
                            if (mounted) Navigator.pop(context);
                          } finally {
                            if (mounted) setState(() => _enviando = false);
                          }
                        },
                  icon: _enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.share_location),
                  label: Text(_enviando ? 'Enviando…' : 'Enviar ubicación a contactos'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _abrir911,
                  icon: const Icon(Icons.phone_in_talk),
                  label: const Text('Llamar al 911'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade800,
                    side: BorderSide(color: Colors.red.shade200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
