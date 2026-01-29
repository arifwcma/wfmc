import 'package:flutter/material.dart';

class LegendCard extends StatelessWidget {
  const LegendCard({
    super.key,
    required this.title,
    required this.layers,
    required this.legendUrlFor,
    required this.onClose,
  });

  final String title;
  final List<String> layers;
  final String Function(String layerName) legendUrlFor;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260, maxHeight: 360),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: layers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final layer = layers[idx];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          layer,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Image.network(
                          legendUrlFor(layer),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                              height: 40,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 40,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 20),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
