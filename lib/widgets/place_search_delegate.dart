import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/geocoding_service.dart';

/// Search delegate for address / place-name search (Nominatim).
class PlaceSearchDelegate extends SearchDelegate<LatLng?> {
  PlaceSearchDelegate({required this.geocodingService});

  final GeocodingService geocodingService;

  @override
  String get searchFieldLabel => 'Search address or place';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildBody(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildBody(context);

  Widget _buildBody(BuildContext context) {
    if (query.length < 3) {
      return const Center(child: Text('Type at least 3 characters'));
    }
    return _SuggestionList(
      query: query,
      geocodingService: geocodingService,
      onSelected: (location) => close(context, location),
    );
  }
}

// ---------------------------------------------------------------------------
// Stateful widget that debounces Nominatim requests internally
// ---------------------------------------------------------------------------

class _SuggestionList extends StatefulWidget {
  const _SuggestionList({
    required this.query,
    required this.geocodingService,
    required this.onSelected,
  });

  final String query;
  final GeocodingService geocodingService;
  final void Function(LatLng) onSelected;

  @override
  State<_SuggestionList> createState() => _SuggestionListState();
}

class _SuggestionListState extends State<_SuggestionList> {
  Timer? _debounce;
  List<GeocodingResult> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void didUpdateWidget(covariant _SuggestionList old) {
    super.didUpdateWidget(old);
    if (widget.query != old.query) _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search() {
    _debounce?.cancel();
    if (widget.query.length < 3) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () {
      widget.geocodingService.search(widget.query).then((results) {
        if (mounted) {
          setState(() {
            _results = results;
            _loading = false;
          });
        }
      }).catchError((_) {
        if (mounted) setState(() => _loading = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return const Center(child: Text('No results'));
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (ctx, i) {
        final r = _results[i];
        return ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: Text(
            r.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => widget.onSelected(r.location),
        );
      },
    );
  }
}
