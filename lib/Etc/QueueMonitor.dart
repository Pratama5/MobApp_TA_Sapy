// QueueMonitor.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// NEW: Helper function to get a relevant icon based on the task title
IconData _getIconForTask(String title) {
  if (title.contains('Embedding')) {
    return Icons.layers_outlined;
  } else if (title.contains('Attack')) {
    return Icons.whatshot;
  } else if (title.contains('Extract')) {
    return Icons.find_in_page_outlined;
  }
  return Icons.hourglass_empty_outlined;
}

Future<Map<String, dynamic>?> showQueueDialog({
  required BuildContext context,
  required String taskId,
  required String serverIp,
  required String taskTitle, // NEW: Added to make the dialog context-aware
}) async {
  StateSetter? dialogStateSetter;
  String currentStatus = 'Queued...';
  int currentPosition = 0;

  Completer<Map<String, dynamic>?> resultCompleter = Completer();
  Timer? pollingTimer;

  void cleanUpAndClose([Map<String, dynamic>? result]) {
    if (pollingTimer?.isActive ?? false) {
      pollingTimer?.cancel();
    }
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (!resultCompleter.isCompleted) {
      resultCompleter.complete(result);
    }
  }

  pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
    try {
      final statusResponse = await http
          .get(Uri.parse('http://$serverIp:8000/queue_status/$taskId'));

      if (statusResponse.statusCode == 200) {
        final data = jsonDecode(statusResponse.body);
        final status = data['status'];

        if (dialogStateSetter != null) {
          dialogStateSetter!(() {
            if (status == 'processing') {
              currentStatus = 'Server is processing your task...';
            } else {
              currentPosition = data['position'] ?? 0;
              currentStatus = 'In queue...';
            }
          });
        }

        if (status == 'done' || status == 'done or unknown') {
          final resultResp =
              await http.get(Uri.parse('http://$serverIp:8000/result/$taskId'));
          if (resultResp.statusCode == 200) {
            final resultData = jsonDecode(resultResp.body);
            cleanUpAndClose(resultData);
          } else {
            cleanUpAndClose(null);
          }
        }
      } else {
        cleanUpAndClose(null);
      }
    } catch (e) {
      print("Queue polling error: $e");
      cleanUpAndClose(null);
    }
  });

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          dialogStateSetter = setState;
          // --- UI REDESIGN ---
          return AlertDialog(
            backgroundColor: const Color(0xFFF5E8E4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              taskTitle, // Use the dynamic title
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF411530)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Spinner layered around the icon
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          strokeWidth: 5,
                          valueColor:
                              const AlwaysStoppedAnimation(Color(0xFF5E2A4D)),
                          backgroundColor:
                              const Color(0xFF5E2A4D).withOpacity(0.2),
                        ),
                      ),
                      Icon(
                        _getIconForTask(taskTitle), // Use the dynamic icon
                        size: 45,
                        color: const Color(0xFF411530).withOpacity(0.8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Dynamic status text
                Text(
                  currentStatus,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
                if (currentStatus == 'In queue...')
                  Text(
                    'Waiting in Line: Position $currentPosition',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF411530)),
                  ),
                const SizedBox(height: 10),
                const Text(
                  'Please dont close until the task is completed.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF411530)),
                ),
              ],
            ),
          );
          // --- END OF UI REDESIGN ---
        },
      );
    },
  );

  return resultCompleter.future;
}
