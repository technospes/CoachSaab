import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'session_report_screen.dart'; // ✅ Added the import here at the top

class WorkoutHistoryScreen extends StatefulWidget {
  final String userId;
  final String accessToken;

  const WorkoutHistoryScreen({
    super.key,
    required this.userId,
    required this.accessToken,
  });

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _sessions = [];

  @override
  void initState() {
    super.initState();
    _fetchSessionHistory();
  }

  Future<void> _fetchSessionHistory() async {
    try {
      final url = Uri.parse('https://coachsaab-api.onrender.com/api/v1/users/${widget.userId}/sessions?limit=20');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _sessions = data['sessions'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        debugPrint("History API Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Failed to load sessions: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Utility to format names (e.g., 'bicep_curl' -> 'Bicep Curl')
  String _displayExerciseName(String key) {
    if (key.toLowerCase() == 'squat' || key.toLowerCase() == 'quat') return 'Squat';
    if (key.toLowerCase() == 'push_up') return 'Push-Up';
    if (key.toLowerCase() == 'bicep_curl') return 'Bicep Curl';
    
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

  // Helper to map the raw activity key to a specific Image Asset
  String _getAssetForActivity(String activityKey) {
    final key = activityKey.toLowerCase();
    if (key.contains('run')) return 'assets/icons/running_session_icon.png';
    if (key.contains('squat') || key.contains('quat')) return 'assets/icons/Squat_Session_icon.png';
    if (key.contains('tree') || key.contains('pose') || key.contains('yoga')) return 'assets/icons/Tree_Pose_Image.png';
    if (key.contains('bicep') || key.contains('curl')) return 'assets/icons/bicep_curls_session_Icon.jpg';
    
    // Fallback for anything else
    return 'assets/icons/Splash_Screen_Icon.png';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0E5EC), // Neu background matching your app
      appBar: AppBar(
        title: const Text('Workout History', style: TextStyle(color: Color(0xFF2D3748), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D3748)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E)))
          : _sessions.isEmpty
              ? const Center(child: Text("No workouts logged yet.", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    // ✅ Here is where 'session' and 'context' actually exist!
                    final session = _sessions[index];
                    
                    String formattedDate = 'Unknown Date';
                    if (session['created_at'] != null) {
                      try {
                        DateTime dt = DateTime.parse(session['created_at']).toLocal();
                        formattedDate = DateFormat('MMM dd, yyyy • h:mm a').format(dt);
                      } catch (_) {}
                    }

                    // ✅ Your cleanly wired Card goes right here
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              _getAssetForActivity(session['activity_key'] ?? ''),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        title: Text(
                          _displayExerciseName(session['activity_key'] ?? ''),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D3748)),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Builder(
                            builder: (context) {
                              final activityKey = (session['activity_key'] ?? '').toString().toLowerCase();
                              final isRun = activityKey.contains('run');

                              if (isRun) {
                                return Text(
                                  '$formattedDate\n${session['reps']} Steps • ${_formatDuration(session['duration_seconds'] ?? 0)} • ${session['form_score']} SPM',
                                  style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                                );
                              }
                              return Text(
                                '$formattedDate\n${session['reps']} Reps • ${_formatDuration(session['duration_seconds'] ?? 0)} • ${session['form_score']}% Form',
                                style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                              );
                            },
                          ),
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // ✅ Routes to the detailed report and passes the session data!
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SessionReportScreen(sessionData: session),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}