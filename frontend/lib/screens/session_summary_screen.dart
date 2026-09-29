import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../tracking/session_tracker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionSummaryScreen extends StatefulWidget {
  final SessionTracker tracker;
  final String activityName;

  const SessionSummaryScreen({
    super.key,
    required this.tracker,
    required this.activityName,
  });

  @override
  State<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  bool _isSubmitting = false;

  // Snapshot variables captured immediately on initState
  late final bool _isRun;
  late final String _activityKey;
  late final int _reps;
  late final int _durationSeconds;
  late final int _formScore;
  late final double _formAccuracy;
  late final int _goodReps;
  late final int _imperfectReps;
  late final String? _dominantDeviation;
  late final Map<String, dynamic> _deviationsJson;
  late final List<dynamic> _repResults;

  @override
  void initState() {
    super.initState();
    _snapshotTrackerData();
  }

  /// Maps display names reliably to the backend's singular snake_case schema.
  String _getCanonicalActivityKey(String activityName) {
    final normalized = activityName.toLowerCase().trim();

    const activityMap = {
      'squat': 'squat',
      'squats': 'squat',
      'push-up': 'push_up',
      'push-ups': 'push_up',
      'push up': 'push_up',
      'push ups': 'push_up',
      'push_up': 'push_up',
      'bicep curl': 'bicep_curl',
      'bicep curls': 'bicep_curl',
      'bicep_curl': 'bicep_curl',
      'tree pose': 'tree_pose',
      'tree_pose': 'tree_pose',
      'running': 'running',
      'run': 'running',
      'treadmill run': 'running',
    };

    if (activityMap.containsKey(normalized)) {
      return activityMap[normalized]!;
    }

    // Fallback: strip trailing singular 's' and replace spaces/hyphens with '_'
    String fallback = normalized;
    if (fallback.endsWith('s') && !fallback.endsWith('ss')) {
      fallback = fallback.substring(0, fallback.length - 1);
    }
    return fallback.replaceAll(RegExp(r'[\s\-]+'), '_');
  }

  void _snapshotTrackerData() {
    _activityKey = _getCanonicalActivityKey(widget.activityName);
    _isRun = _activityKey == 'running';

    if (_isRun) {
      _reps = widget.tracker.continuousTotalSteps;
      _durationSeconds = widget.tracker.continuousDurationSeconds;
      _formScore = widget.tracker.continuousAverageCadence;
      _formAccuracy = 100.0;
      _goodReps = 0;
      _imperfectReps = 0;
      _dominantDeviation = null;
      _deviationsJson = {};
      _repResults = [];
    } else {
      _goodReps = widget.tracker.goodReps;
      _imperfectReps = widget.tracker.imperfectReps;

      // Ensure reps represent total attempts (or good + imperfect if attempts is 0)
      final calculatedTotal = _goodReps + _imperfectReps;
      _reps = widget.tracker.totalAttempts > 0
          ? widget.tracker.totalAttempts
          : calculatedTotal;

      _durationSeconds = widget.tracker.durationSeconds > 0
          ? widget.tracker.durationSeconds
          : 0;

      // Form score fallback if tracker reports 0 despite recorded reps
      if (widget.tracker.formScore > 0) {
        _formScore = widget.tracker.formScore;
      } else if (_reps > 0 && _goodReps > 0) {
        _formScore = ((_goodReps / _reps) * 100).round();
      } else {
        _formScore = 0;
      }

      _formAccuracy = widget.tracker.formAccuracy;
      _dominantDeviation = widget.tracker.dominantDeviation;
      _deviationsJson = Map<String, dynamic>.from(widget.tracker.deviationTallies);
      _repResults = widget.tracker.repResults.map((r) => r.toJson()).toList();
    }

    debugPrint(
      "📊 SNAPSHOTTED WORKOUT DATA: activity=$_activityKey, reps=$_reps (good=$_goodReps, imperfect=$_imperfectReps), score=$_formScore, duration=$_durationSeconds",
    );
  }

  Future<void> _submitSessionToDatabase() async {
    setState(() => _isSubmitting = true);

    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token') 
               ?? await storage.read(key: 'jwt') 
               ?? await storage.read(key: 'token') 
               ?? '';

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) {
        debugPrint("❌ Error: User ID not found in local storage.");
        return;
      }

      final url = Uri.parse('https://coachsaab-api.onrender.com/api/v1/sessions');

      final payload = _isRun
          ? {
              "user_id": userId,
              "activity_key": "running",
              "reps": _reps,
              "duration_seconds": _durationSeconds,
              "form_score": _formScore,
              "dominant_deviation": null,
              "deviations_json": {},
              "rep_results": [],
            }
          : {
              "user_id": userId,
              "activity_key": _activityKey,
              "reps": _reps,
              "duration_seconds": _durationSeconds,
              "form_score": _formScore,
              "dominant_deviation": _dominantDeviation,
              "deviations_json": _deviationsJson,
              "rep_results": _repResults,
            };

      debugPrint("🚀 DISPATCHING SESSION PAYLOAD: ${jsonEncode(payload)}");

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint("✅ Session Saved Successfully: ${response.body}");
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        debugPrint("❌ Failed to save session: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Network Error: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 48),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Well Done!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Workout recorded successfully.',
                style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 16),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fitness_center_rounded, color: AppColors.accent, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          widget.activityName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Divider(color: Colors.white10, height: 1),
                    ),
                    Builder(
                      builder: (context) {
                        if (_isRun) {
                          final mins = (_durationSeconds ~/ 60).toString().padLeft(2, '0');
                          final secRem = (_durationSeconds % 60).toString().padLeft(2, '0');

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatMetric('$_reps', 'Total Steps'),
                              _buildStatMetric('$_formScore', 'Avg SPM'),
                              _buildStatMetric('$mins:$secRem', 'Duration'),
                            ],
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatMetric('$_reps', 'Reps'),
                            _buildStatMetric('$_formScore%', 'Quality'),
                            _buildStatMetric('${_formAccuracy.toStringAsFixed(0)}%', 'Accuracy'),
                          ],
                        );
                      },
                    ),
                    if (!_isRun) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Divider(color: Colors.white10, height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatMetric('$_goodReps', 'Good', color: AppColors.success),
                          _buildStatMetric('$_imperfectReps', 'Imperfect', color: AppColors.warning),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_dominantDeviation != null && !_isRun)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Main Area for Improvement:',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '"$_dominantDeviation"',
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: _isSubmitting ? null : _submitSessionToDatabase,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.black87,
                            strokeWidth: 3,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: Colors.black87),
                            SizedBox(width: 8),
                            Text(
                              'Generate AI Report',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatMetric(String value, String label, {Color color = Colors.white}) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
      ],
    );
  }
}