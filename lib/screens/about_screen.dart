import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Wimmera CMA')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Wimmera Catchment Management Authority',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          const Text(
            'The Wimmera CMA works with the community to protect and improve '
            'the land and water resources of the Wimmera region in western '
            'Victoria, Australia.\n\n'
            'This app provides access to flood investigation mapping across '
            'the Wimmera catchment, helping communities understand flood risk '
            'in their area.',
          ),
          const SizedBox(height: 24),
          const Text(
            'Flood Studies',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'The flood depth maps shown in this app are based on detailed '
            'flood investigations carried out across the Wimmera region. Each '
            'study models flood behaviour for a range of event probabilities '
            '(from 1-in-5 year to 1-in-200 year events).',
          ),
          const SizedBox(height: 24),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Visit Wimmera CMA Website'),
            subtitle: const Text('wcma.vic.gov.au'),
            onTap: () => launchUrl(Uri.parse('https://wcma.vic.gov.au')),
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Contact Us'),
            subtitle: const Text('wcma@wcma.vic.gov.au'),
            onTap: () =>
                launchUrl(Uri.parse('mailto:wcma@wcma.vic.gov.au')),
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('Phone'),
            subtitle: const Text('(03) 5382 1544'),
            onTap: () => launchUrl(Uri.parse('tel:+61353821544')),
          ),
        ],
      ),
    );
  }
}
