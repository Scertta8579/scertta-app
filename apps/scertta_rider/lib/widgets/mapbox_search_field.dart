import 'package:flutter/material.dart';

import '../services/mapbox_geocoding_service.dart';

/// Campo de búsqueda con autocompletado Mapbox
class MapboxSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final Color prefixColor;
  final bool isDestino;
  final double? proximityLng;
  final double? proximityLat;
  final ValueChanged<MapboxPlaceResult> onPlaceSelected;
  final VoidCallback? onClear;
  final bool autofocus;

  const MapboxSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.prefixColor,
    required this.onPlaceSelected,
    this.isDestino = false,
    this.proximityLng,
    this.proximityLat,
    this.onClear,
    this.autofocus = false,
  });

  @override
  State<MapboxSearchField> createState() => _MapboxSearchFieldState();
}

class _MapboxSearchFieldState extends State<MapboxSearchField> {
  List<MapboxPlaceResult> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;

  void _onTextChanged(String value) async {
    if (value.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    final results = await MapboxGeocodingService.search(
      query: value,
      limit: 5,
      proximityLng: widget.proximityLng,
      proximityLat: widget.proximityLat,
    );
    if (mounted) {
      setState(() {
        _suggestions = results;
        _showSuggestions = results.isNotEmpty;
        _isLoading = false;
      });
    }
  }

  void _selectSuggestion(MapboxPlaceResult place) {
    widget.controller.text = place.placeName;
    widget.onPlaceSelected(place);
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          autofocus: widget.autofocus,
          onChanged: _onTextChanged,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            prefixIcon: Icon(widget.prefixIcon, color: widget.prefixColor, size: widget.isDestino ? 12 : 14),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                IconButton(
                  icon: Icon(Icons.clear, size: 16, color: Colors.grey[700]),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onClear?.call();
                    setState(() {
                      _suggestions = [];
                      _showSuggestions = false;
                    });
                  },
                ),
              ],
            ),
            border: InputBorder.none,
            hintText: widget.hintText,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          style: TextStyle(
            color: Colors.black87,
            fontSize: 15,
            fontWeight: widget.isDestino ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              itemBuilder: (context, i) {
                final p = _suggestions[i];
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.location_on_outlined, size: 20, color: Colors.grey[700]),
                  title: Text(p.text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(p.placeName, style: TextStyle(fontSize: 11, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _selectSuggestion(p),
                );
              },
            ),
          ),
      ],
    );
  }
}
