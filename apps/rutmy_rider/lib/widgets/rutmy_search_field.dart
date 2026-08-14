import 'package:flutter/material.dart';
import 'package:flutter_shared/services/rutmy_geocoding_service.dart';

/// Campo de búsqueda de lugares con autocompletado usando el geocodificador
/// self-hosted (RutmyGeocodingService). Reemplaza a RutmySearchField.
class RutmySearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final Color prefixColor;
  final bool autofocus;
  final bool isDestino;
  final double? proximityLng;
  final double? proximityLat;
  final void Function(RutmyPlaceResult place) onPlaceSelected;
  final VoidCallback? onClear;

  const RutmySearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.prefixColor,
    required this.onPlaceSelected,
    this.autofocus = false,
    this.isDestino = false,
    this.proximityLng,
    this.proximityLat,
    this.onClear,
  });

  @override
  State<RutmySearchField> createState() => _RutmySearchFieldState();
}

class _RutmySearchFieldState extends State<RutmySearchField> {
  List<RutmyPlaceResult> _suggestions = [];
  bool _loading = false;

  Future<void> _onChanged(String query) async {
    if (query.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _loading = true);
    final results = await RutmyGeocodingService.search(
      query: query,
      proximityLng: widget.proximityLng,
      proximityLat: widget.proximityLat,
    );
    if (!mounted) return;
    setState(() {
      _suggestions = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          autofocus: widget.autofocus,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: Icon(widget.prefixIcon, color: widget.prefixColor),
            border: InputBorder.none,
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      widget.controller.clear();
                      setState(() => _suggestions = []);
                      widget.onClear?.call();
                    },
                  )
                : (_loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null),
          ),
        ),
        if (_suggestions.isNotEmpty)
          ..._suggestions.map((p) => ListTile(
                dense: true,
                leading: const Icon(Icons.location_on_outlined, size: 20),
                title: Text(p.text, style: const TextStyle(fontSize: 14)),
                subtitle: p.placeName.isNotEmpty
                    ? Text(p.placeName,
                        style: const TextStyle(fontSize: 12), maxLines: 1)
                    : null,
                onTap: () {
                  widget.controller.text = p.placeName.isNotEmpty
                      ? p.placeName
                      : p.text;
                  setState(() => _suggestions = []);
                  widget.onPlaceSelected(p);
                },
              )),
      ],
    );
  }
}
