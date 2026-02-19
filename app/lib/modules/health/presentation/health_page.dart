import 'package:flutter/material.dart';
import 'package:thrive_app/core/result/app_result.dart';
import 'package:thrive_app/modules/health/application/health_controller.dart';
import 'package:thrive_app/modules/health/domain/health_repository.dart';

class HealthPage extends StatelessWidget {
  const HealthPage({required this.controller, super.key});

  final HealthController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Module')),
      body: FutureBuilder<AppResult<HealthStatus>>(
        future: controller.loadStatus(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return snapshot.data!.when(
            success: (status) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    status.healthy ? Icons.check_circle : Icons.warning,
                    color: status.healthy ? Colors.green : Colors.orange,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  Text(status.details, textAlign: TextAlign.center),
                ],
              ),
            ),
            failure: (failure) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  failure.userMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
