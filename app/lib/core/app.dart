import 'package:flutter/material.dart';
import 'package:thrive_app/core/architecture/module_registry.dart';

class ThriveApp extends StatelessWidget {
  const ThriveApp({required this.registry, super.key});

  final ModuleRegistry registry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thrive',
      routes: registry.buildRoutes(),
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thrive')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pushNamed('/health'),
          child: const Text('Open Health Module'),
        ),
      ),
    );
  }
}
