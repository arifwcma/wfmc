import 'package:flutter/material.dart';

import '../models/wms_models.dart';
import '../utils/debouncer.dart';

typedef OnLayerToggle = void Function(String layerName, bool enabled);
typedef OnZoomTo = void Function(WmsLayer layer);

class LayerTree extends StatefulWidget {
  const LayerTree({
    super.key,
    required this.root,
    required this.enabledLayerNames,
    required this.onLayerToggled,
    required this.onZoomTo,
  });

  final WmsLayer root;
  final Set<String> enabledLayerNames;
  final OnLayerToggle onLayerToggled;
  final OnZoomTo onZoomTo;

  @override
  State<LayerTree> createState() => _LayerTreeState();
}

class _LayerTreeState extends State<LayerTree> {
  final _debouncer = Debouncer();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debouncer.call(() {
      if (mounted) {
        setState(() => _searchQuery = value.trim().toLowerCase());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search layers',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              _LayerNode(
                layer: widget.root,
                enabledLayerNames: widget.enabledLayerNames,
                onLayerToggled: widget.onLayerToggled,
                onZoomTo: widget.onZoomTo,
                searchQuery: _searchQuery,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LayerNode extends StatelessWidget {
  const _LayerNode({
    required this.layer,
    required this.enabledLayerNames,
    required this.onLayerToggled,
    required this.onZoomTo,
    required this.searchQuery,
  });

  final WmsLayer layer;
  final Set<String> enabledLayerNames;
  final OnLayerToggle onLayerToggled;
  final OnZoomTo onZoomTo;
  final String searchQuery;

  bool _matches(WmsLayer l) {
    if (searchQuery.isEmpty) return true;
    final hay = ('${l.title} ${l.name ?? ''}').toLowerCase();
    return hay.contains(searchQuery);
  }

  bool _subtreeMatches(WmsLayer l) {
    if (_matches(l)) return true;
    for (final c in l.children) {
      if (_subtreeMatches(c)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_subtreeMatches(layer)) {
      return const SizedBox.shrink();
    }

    final requestable = layer.isRequestable;
    final enabled = requestable && enabledLayerNames.contains(layer.name);

    final title = Text(
      layer.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    final subtitle = layer.name != null
        ? Text(
            layer.name!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        : null;

    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (layer.bbox3857 != null)
          IconButton(
            tooltip: 'Zoom to',
            onPressed: () => onZoomTo(layer),
            icon: const Icon(Icons.center_focus_strong),
          ),
        if (requestable)
          Switch(
            value: enabled,
            onChanged: (v) => onLayerToggled(layer.name!, v),
          ),
      ],
    );

    if (layer.children.isEmpty) {
      return ListTile(
        dense: true,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
      );
    }

    return ExpansionTile(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      children: layer.children
          .map(
            (c) => _LayerNode(
              layer: c,
              enabledLayerNames: enabledLayerNames,
              onLayerToggled: onLayerToggled,
              onZoomTo: onZoomTo,
              searchQuery: searchQuery,
            ),
          )
          .toList(),
    );
  }
}

