import 'package:flutter/material.dart';

import '../config/study_metadata.dart';
import '../models/wms_models.dart';

class StudyList extends StatefulWidget {
  const StudyList({
    super.key,
    required this.studies,
    required this.enabledStudies,
    required this.enabledLayers,
    required this.onStudyToggled,
    required this.onLayerToggled,
    required this.onZoomTo,
    this.scrollController,
  });

  final List<WmsLayer> studies;
  final Set<String> enabledStudies;
  final Set<String> enabledLayers;
  final void Function(String studyName, bool enabled) onStudyToggled;
  final void Function(String layerName, bool enabled) onLayerToggled;
  final void Function(WmsLayer layer) onZoomTo;
  final ScrollController? scrollController;

  @override
  State<StudyList> createState() => _StudyListState();
}

class _StudyListState extends State<StudyList> {
  final Set<String> _expandedStudies = {};

  @override
  void initState() {
    super.initState();
    // Start collapsed for fast drawer rendering.
  }

  String _studyDisplayName(String studyName) {
    final info = StudyMetadata.studies[studyName];
    if (info != null) {
      return '${info.displayName} ${info.completionYear}';
    }
    return studyName;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.scrollController,
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
                _studyDisplayName(studyName),
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
                            isSelected: widget.enabledLayers.contains(layer.name),
                            isParentEnabled: isStudyEnabled,
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
