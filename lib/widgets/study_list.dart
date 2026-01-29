import 'package:flutter/material.dart';

import '../models/wms_models.dart';

class StudyList extends StatefulWidget {
  const StudyList({
    super.key,
    required this.studies,
    required this.enabledLayerNames,
    required this.onLayerToggled,
    required this.onZoomTo,
  });

  final List<WmsLayer> studies;
  final Set<String> enabledLayerNames;
  final void Function(String layerName, bool enabled) onLayerToggled;
  final void Function(WmsLayer layer) onZoomTo;

  @override
  State<StudyList> createState() => _StudyListState();
}

class _StudyListState extends State<StudyList> {
  final Set<String> _expandedStudies = {};

  @override
  void initState() {
    super.initState();
    for (final study in widget.studies) {
      if (study.name != null) {
        _expandedStudies.add(study.name!);
      }
    }
  }

  bool _isStudyPartiallySelected(WmsLayer study) {
    final childNames = study.children
        .where((c) => c.isRequestable)
        .map((c) => c.name!)
        .toSet();
    final selected = childNames.intersection(widget.enabledLayerNames);
    return selected.isNotEmpty && selected.length < childNames.length;
  }

  bool _isStudyFullySelected(WmsLayer study) {
    final childNames = study.children
        .where((c) => c.isRequestable)
        .map((c) => c.name!)
        .toSet();
    if (childNames.isEmpty) return false;
    return childNames.difference(widget.enabledLayerNames).isEmpty;
  }

  void _toggleStudy(WmsLayer study, bool select) {
    for (final child in study.children) {
      if (child.isRequestable) {
        widget.onLayerToggled(child.name!, select);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.studies.length,
      itemBuilder: (context, index) {
        final study = widget.studies[index];
        final isExpanded = _expandedStudies.contains(study.name);
        final isFullySelected = _isStudyFullySelected(study);
        final isPartiallySelected = _isStudyPartiallySelected(study);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Checkbox(
                value: isFullySelected,
                tristate: true,
                onChanged: (value) {
                  _toggleStudy(study, value == true || !isPartiallySelected && !isFullySelected);
                },
              ),
              title: Text(
                study.title,
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
                          _expandedStudies.remove(study.name);
                        } else {
                          _expandedStudies.add(study.name!);
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
                            isSelected: widget.enabledLayerNames.contains(layer.name),
                            onToggle: (v) => widget.onLayerToggled(layer.name!, v),
                            onZoomTo: () => widget.onZoomTo(layer),
                          ))
                      .toList(),
                ),
              ),
            const Divider(height: 1),
          ],
        );
      },
    );
  }
}

class _LayerTile extends StatelessWidget {
  const _LayerTile({
    required this.layer,
    required this.isSelected,
    required this.onToggle,
    required this.onZoomTo,
  });

  final WmsLayer layer;
  final bool isSelected;
  final void Function(bool) onToggle;
  final VoidCallback onZoomTo;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Checkbox(
        value: isSelected,
        onChanged: (v) => onToggle(v ?? false),
      ),
      title: Text(layer.title),
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
