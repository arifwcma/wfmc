import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

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
            title: const Text('Visit ${AppConfig.orgShortName} Website'),
            subtitle: Text(Uri.parse(AppConfig.orgWebsite).host),
            onTap: () => launchUrl(Uri.parse(AppConfig.orgWebsite)),
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Contact Us'),
            subtitle: const Text(AppConfig.contactEmail),
            onTap: () =>
                launchUrl(Uri.parse('mailto:${AppConfig.contactEmail}')),
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('Phone'),
            subtitle: const Text(AppConfig.orgPhone),
            onTap: () => launchUrl(Uri.parse(AppConfig.orgPhoneUri)),
          ),
        ],
      ),
    );
  }
}
