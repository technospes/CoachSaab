import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SessionReportScreen extends StatelessWidget {
  final Map<String, dynamic> sessionData;

  const SessionReportScreen({super.key, required this.sessionData});

  // Utility to format names
  String _displayExerciseName(String key) {
    final lowerKey = key.toLowerCase();
    if (lowerKey == 'running' || lowerKey == 'run') return 'Treadmill Run'; // 🚀 Custom override
    if (lowerKey == 'squat' || lowerKey == 'quat') return 'Squat';
    if (lowerKey == 'push_up') return 'Push-Up';
    if (lowerKey == 'bicep_curl') return 'Bicep Curl';
    
    return key.replaceAll('_', ' ').split(' ')
        .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
        .join(' ');
  }

  // Utility to format duration
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    if (minutes == 0) return '${remaining}s';
    if (remaining == 0) return '${minutes}m';
    return '${minutes}m ${remaining}s';
  }

  @override
  Widget build(BuildContext context) {
    final activityName = _displayExerciseName(sessionData['activity_key'] ?? '');
    
    // 🚀 Clean single-check condition
    final activityKey = (sessionData['activity_key'] ?? '').toString().toLowerCase();
    final isRun = activityKey.contains('run');

    final formScore = sessionData['form_score'] ?? 0;
    final reps = sessionData['reps'] ?? 0;
    final duration = _formatDuration(sessionData['duration_seconds'] ?? 0);
    final deviation = sessionData['dominant_deviation'] ?? '';
    
    String formattedDate = 'Unknown Date';
    if (sessionData['created_at'] != null) {
      try {
        DateTime dt = DateTime.parse(sessionData['created_at']).toLocal();
        formattedDate = DateFormat('MMMM dd, yyyy • h:mm a').format(dt);
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE0E5EC),
      appBar: AppBar(
        title: const Text('Session Report', style: TextStyle(color: Color(0xFF2D3748), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D3748)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Header (with conditional icon)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRun ? Icons.directions_run_rounded : Icons.fitness_center_rounded, 
                  color: Colors.white, 
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              activityName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF2D3748)),
            ),
            const SizedBox(height: 8),
            Text(
              formattedDate,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF718096), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 40),

            // 2. Main Stats Row (Conditional layout)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: isRun ? [
                  _buildStatMetric('$reps', 'Total Steps', color: const Color(0xFF22C55E)),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  _buildStatMetric('$formScore', 'Avg SPM'),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  _buildStatMetric(duration, 'Duration'),
                ] : [
                  _buildStatMetric('$formScore%', 'Form Score', color: const Color(0xFF22C55E)),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  _buildStatMetric('$reps', 'Total Reps'),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  _buildStatMetric(duration, 'Duration'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. AI Feedback Card (Safely wrapped in if (!isRun))
            if (!isRun) ...[
              const Text('AI Form Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
              const SizedBox(height: 12),
              if (deviation.isNotEmpty && deviation != 'null' && deviation != 'None')
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Dominant Issue', style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              deviation.replaceAll('_', ' ').split(' ').map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}').join(' '),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2D3748)),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "CoachSaab noticed this deviation repeatedly during your set. Focus on correcting this specific movement pattern next time.",
                              style: TextStyle(fontSize: 13, color: Color(0xFF718096), height: 1.4),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle_outline, color: Color(0xFF22C55E), size: 28),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "Clean set! No major deviations detected by the AI.",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3748)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatMetric(String value, String label, {Color color = const Color(0xFF2D3748)}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF718096), fontWeight: FontWeight.w600)),
      ],
    );
  }
}