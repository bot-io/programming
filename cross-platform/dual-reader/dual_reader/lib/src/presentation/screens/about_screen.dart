import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          // App icon / logo area
          Icon(
            Icons.menu_book_rounded,
            size: 72,
            color: theme.primaryColor,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Dual Reader',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Version 1.0.0',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Description
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Description'),
            subtitle: const Text(
              'Bilingual ebook reader - read original and translated text side-by-side',
            ),
          ),
          const Divider(),
          // Credits
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Credits'),
            subtitle: const Text(
              'Built with Flutter, Riverpod, Hive, Transformers.js, ML Kit',
            ),
          ),
          const Divider(),
          // License
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('License'),
            subtitle: const Text('Open Source - MIT License'),
          ),
          const Divider(),
          // GitHub link
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('GitHub'),
            subtitle: const Text('github.com/bot-io/programming'),
            onTap: () {
              // In a real app this would launch the URL via url_launcher
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
