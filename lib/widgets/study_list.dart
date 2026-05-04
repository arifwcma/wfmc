import 'package:flutter/material.dart';

import '../config/pmtiles_base_layers.dart';
import '../config/study_metadata.dart';
import '../models/wms_models.dart';

class StudyList extends StatefulWidget {
  const StudyList({
    super.key,
    required this.studies,
    required this.baseLayers,
    required this.pmtilesBaseLayers,
    required this.enabledStudies,
    required this.enabledLayers,
    required this.enabledBaseLayers,
    required this.enabledPmtilesBaseLayers,
    required this.onStudyToggled,
    required this.onLayerToggled,
    required this.onBaseLayerToggled,
    required this.onPmtilesBaseLayerToggled,
    required this.onZoomTo,
    this.scrollController,
  });

  final List<WmsLayer> studies;
  final List<WmsLayer> baseLayers;
  final List<PmTilesBaseLayer> pmtilesBaseLayers;
  final Set<String> enabledStudies;
  final Set<String> enabledLayers;
  final Set<String> enabledBaseLayers;
  final Set<String> enabledPmtilesBaseLayers;
  final void Function(String studyName, bool enabled) onStudyToggled;
  final void Function(String layerName, bool enabled) onLayerToggled;
  final void Function(String baseLayerName, bool enabled) onBaseLayerToggled;
  final void Function(String pmtilesLayerId, bool enabled)
      onPmtilesBaseLayerToggled;
  final void Function(WmsLayer layer) onZoomTo;
  final ScrollController? scrollController;

  @override
  State<StudyList> createState() => _StudyListState();
}

class _StudyListState extends State<StudyList> {
  final Set<String> _expandedStudies = {};
  bool _baseLayersExpanded = false;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: widget.scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        SliverList.builder(
          itemCount: widget.studies.length,
          itemBuilder: (context, index) {
            final study = widget.studies[index];
            final studyName = study.name;
            if (studyName == null) return const SizedBox.shrink();

            final isExpanded = _expandedStudies.contains(studyName);
            final isStudyEnabled = widget.enabledStudies.contains(studyName);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: Checkbox(
                    value: isStudyEnabled,
                    onChanged: (value) {
                      widget.onStudyToggled(studyName, value ?? false);
                    },
                  ),
                  title: Text(
                    StudyReports.displayNameFor(studyName),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (study.bbox3857 != null)
                        IconButton(
                          icon: const Icon(Icons.zoom_in_map, size: 20),
                          onPressed: () => widget.onZoomTo(study),
                          tooltip: 'Zoom to study',
                        ),
                      IconButton(
                        icon: Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                        ),
                        onPressed: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedStudies.remove(studyName);
                            } else {
                              _expandedStudies.add(studyName);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Column(
                      children: study.children
                          .where((c) => c.isRequestable)
                          .map((layer) => _LayerTile(
                                layer: layer,
                                isSelected:
                                    widget.enabledLayers.contains(layer.name),
                                isParentEnabled: isStudyEnabled,
                                onToggle: (v) =>
                                    widget.onLayerToggled(layer.name!, v),
                                onZoomTo: () => widget.onZoomTo(layer),
                              ))
                          .toList(),
                    ),
                  ),
                const Divider(height: 1),
              ],
            );
          },
        ),
        if (widget.baseLayers.isNotEmpty ||
            widget.pmtilesBaseLayers.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildBaseLayersSection(context),
          ),
      ],
    );
  }

  Widget _buildBaseLayersSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.layers_outlined),
          title: const Text(
            'Base Layers',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: IconButton(
            icon: Icon(
              _baseLayersExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            onPressed: () {
              setState(() => _baseLayersExpanded = !_baseLayersExpanded);
            },
          ),
          onTap: () {
            setState(() => _baseLayersExpanded = !_baseLayersExpanded);
          },
        ),
        if (_baseLayersExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              children: [
                for (final layer
                    in widget.baseLayers.where((l) => l.isRequestable))
                  _LayerTile(
                    layer: layer,
                    isSelected: widget.enabledBaseLayers.contains(layer.name),
                    isParentEnabled: true,
                    onToggle: (v) =>
                        widget.onBaseLayerToggled(layer.name!, v),
                    onZoomTo: () => widget.onZoomTo(layer),
                  ),
                for (final pm in widget.pmtilesBaseLayers)
                  _PmTilesLayerTile(
                    layer: pm,
                    isSelected:
                        widget.enabledPmtilesBaseLayers.contains(pm.id),
                    onToggle: (v) =>
                        widget.onPmtilesBaseLayerToggled(pm.id, v),
                  ),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

class _PmTilesLayerTile extends StatelessWidget {
  const _PmTilesLayerTile({
    required this.layer,
    required this.isSelected,
    required this.onToggle,
  });

  final PmTilesBaseLayer layer;
  final bool isSelected;
  final void Function(bool) onToggle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Checkbox(
        value: isSelected,
        onChanged: (v) => onToggle(v ?? false),
      ),
      title: Text(
        layer.title,
        style: TextStyle(
          color: isSelected ? null : Theme.of(context).disabledColor,
        ),
      ),
    );
  }
}

class _LayerTile extends StatelessWidget {
  const _LayerTile({
    required this.layer,
    required this.isSelected,
    required this.isParentEnabled,
    required this.onToggle,
    required this.onZoomTo,
  });

  final WmsLayer layer;
  final bool isSelected;
  final bool isParentEnabled;
  final void Function(bool) onToggle;
  final VoidCallback onZoomTo;

  @override
  Widget build(BuildContext context) {
    final effectivelyEnabled = isSelected && isParentEnabled;

    return ListTile(
      dense: true,
      leading: Checkbox(
        value: isSelected,
        onChanged: (v) => onToggle(v ?? false),
      ),
      title: Text(
        layer.title,
        style: TextStyle(
          color: effectivelyEnabled ? null : Theme.of(context).disabledColor,
        ),
      ),
      subtitle: !isParentEnabled && isSelected
          ? Text(
              'Parent study disabled',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.error,
              ),
            )
          : null,
      trailing: layer.bbox3857 != null
          ? IconButton(
              icon: const Icon(Icons.zoom_in_map, size: 18),
              onPressed: onZoomTo,
              tooltip: 'Zoom to layer',
            )
          : null,
    );
  }
}
