import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../main.dart'; 
import 'plan_viewer_screen.dart';
import '../core/state/plan_progress_controller.dart';
import 'workout_history_screen.dart';
import '../widgets/coachsaab_avatar.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  final String userId; 
  final String accessToken; 
  final VoidCallback onNavigateToReports; 

  const HomeScreen({
    super.key, 
    required this.userName, 
    required this.userId,
    required this.accessToken, 
    required this.onNavigateToReports, 
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String get formattedName => widget.userName.isNotEmpty ? "${widget.userName[0].toUpperCase()}${widget.userName.substring(1)}" : "";

  final String coachAvatarUrl = 'https://api.dicebear.com/9.x/bottts-neutral/png?seed=CoachSaab&backgroundColor=1A2B33';
  String get userAvatarUrl => 'https://api.dicebear.com/9.x/micah/png?seed=${widget.userName}&backgroundColor=transparent';

  Map<String, dynamic>? _activePlan;
  bool _isLoadingPlan = true;

  Map<String, dynamic>? _recentSession;
  bool _isLoadingSession = true;
  String _gender = 'Male';
  
  //   FIX 1: Cache the formatted date so it doesn't recalculate on every scroll frame
  String _formattedSessionDate = 'Recently';

  @override
  void initState() {
    super.initState();
    _loadUserGender();
    _fetchActivePlan();
    _fetchRecentSession();
  }

  Future<void> _loadUserGender() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _gender = prefs.getString('user_gender') ?? 'Male';
      });
    }
  }

  Future<void> _fetchRecentSession() async {
    try {
      final url = Uri.parse('https://coachsaab-api.onrender.com/api/v1/users/${widget.userId}/sessions/recent');
      final response = await http.get(url, headers: {'Authorization': 'Bearer ${widget.accessToken}'});
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          if (mounted) {
            setState(() {
              _recentSession = data['session'];
              
              //   FIX 1 (cont): Parse the heavy date string exactly once here!
              String dateStr = _recentSession!['created_at'] ?? '';
              if (dateStr.isNotEmpty) {
                try {
                  DateTime dt = DateTime.parse(dateStr).toLocal();
                  _formattedSessionDate = DateFormat('MMM dd, yyyy • h:mm a').format(dt);
                } catch (e) {
                  debugPrint("Date parse error: $e");
                }
              }
              _isLoadingSession = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("Failed to load recent session: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingSession = false);
      }
    }
  }

  Future<void> _fetchActivePlan() async {
    try {
      final url = Uri.parse('https://coachsaab-api.onrender.com/api/v1/users/${widget.userId}/plan');
      final response = await http.get(url, headers: {'Authorization': 'Bearer ${widget.accessToken}'});
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] != 'no_active_plan') {
          if (mounted) {
            setState(() {
              _activePlan = data;
              _isLoadingPlan = false;
            });
            planProgressController.load(data['plan_id'], data['plan_json'] ?? {});
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("Failed to load plan: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingPlan = false);
      }
    }
  }

  void _showChatbotModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (context) => CoachSaabChatSheet(
        userId: widget.userId, 
        userName: formattedName, 
        coachAvatarUrl: coachAvatarUrl,
        accessToken: widget.accessToken,
      ),
    ).then((_) {
      _fetchActivePlan();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Stack(
          children: [
            //   FIX 2: Switched back to SingleChildScrollView. 
            // For a short screen, this paints once and stays in memory, preventing GC spikes.
            SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(),
                  const SizedBox(height: AppSpacing.xl),
                  
                  RepaintBoundary(
                    child: _buildHeroCard(),
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  _buildSectionHeader('Recent Activity', 'View All >', onActionTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkoutHistoryScreen(
                          userId: widget.userId,
                          accessToken: widget.accessToken,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.md),
                  
                  //   FIX 3: Isolated heavy shadow cards from scroll repainting
                  _isLoadingSession 
                    ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.accent)))
                    : _recentSession == null 
                      ? _buildEmptyActivityCard()
                      : RepaintBoundary(child: _buildRecentActivityCard()),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Your Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight)),
                      ElevatedButton(
                        onPressed: () => _showChatbotModal(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A2B33),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.smallControl)),
                        ),
                        child: Text(_activePlan != null ? 'Update Plan' : 'Create Plan', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  _isLoadingPlan 
                    ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.accent)))
                    : _activePlan == null 
                      ? _buildEmptyPlanCard()
                      : RepaintBoundary(child: _buildActivePlanCard()),

                  const SizedBox(height: AppSpacing.xl),

                  _buildSectionHeader('Your Reports', 'View All >', onActionTap: widget.onNavigateToReports),
                  const SizedBox(height: AppSpacing.md),
                  
                  RepaintBoundary(
                    child: GestureDetector(
                      onTap: widget.onNavigateToReports, 
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.accentPale, borderRadius: BorderRadius.circular(AppRadius.smallControl)),
                              child: const Icon(Icons.analytics_rounded, color: AppColors.accent),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('Weekly Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimaryLight)),
                                  Text('Form Analysis • View Trends', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondaryLight),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 100), 
                ],
              ),
            ),
            
            Positioned(
              bottom: AppSpacing.lg,
              right: AppSpacing.lg,
              child: RepaintBoundary(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => _showChatbotModal(context),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6, right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16).copyWith(bottomRight: const Radius.circular(4)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Ask CoachSaab', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A2B33))),
                            SizedBox(width: 4),
                            Icon(Icons.auto_awesome, size: 14, color: AppColors.accent), 
                          ],
                        ),
                      ),
                    ),
                    CoachSaabAvatar(onTap: () => _showChatbotModal(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 38, height: 38, // 🚀 CHANGED: Reduced from 44 to 38
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: CircleAvatar(
              radius: 17,
              backgroundImage: AssetImage(
                _gender.toLowerCase() == 'female' 
                    ? 'assets/images/female_profile.png' 
                    : 'assets/images/male_profile.png'
              ),
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
        Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Hi $formattedName ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimaryLight)),
                const Text('👋', style: TextStyle(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 2),
            const Text('Small steps today. Stronger you tomorrow.', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Stack(
            children: [
              const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimaryLight, size: 28),
              Positioned(
                right: 2, top: 2,
                child: Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surfaceLight, width: 2),
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      height: 180, 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.heroCard),
        color: Colors.black87,
      ),
      //   FIX 4: Changed from antiAlias to hardEdge (massively reduces GPU strain)
      clipBehavior: Clip.hardEdge, 
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.7,
              child: Image.network(
                'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?q=80&w=400&auto=format&fit=crop',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.95), 
                  Colors.black.withValues(alpha: 0.85), 
                  Colors.black.withValues(alpha: 0.20), 
                ],
                stops: const [0.3, 0.55, 1.0],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text("Today's Focus", style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold)),
                SizedBox(height: AppSpacing.xs),
                Text("Move Better.\nLive Healthier.", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.2, color: Colors.white)),
                SizedBox(height: AppSpacing.sm),
                Text(
                  "Discipline today creates\nresults for life.", 
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis, 
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlanCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          const Icon(Icons.assignment_add, color: AppColors.textSecondaryLight, size: 32),
          const SizedBox(height: AppSpacing.sm),
          const Text('No Active Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimaryLight)),
          const SizedBox(height: 4),
          const Text("Ask CoachSaab to generate a custom routine.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEmptyActivityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: const Text(
        "No recent activity found. Start training!", 
        textAlign: TextAlign.center, 
        style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 14, fontWeight: FontWeight.w500)
      ),
    );
  }

  //   ADDED: Robust string formatter to guarantee clean UI titles
  String _formatActivityName(String rawKey) {
    if (rawKey.isEmpty || rawKey == 'null') return "Workout";
    
    // 1. Auto-correct known database typos from early testing
    if (rawKey.toLowerCase() == 'quat') rawKey = 'squat';
    
    // 2. Convert snake_case or kebab-case to readable spaces
    String spaced = rawKey.replaceAll(RegExp(r'[_\-]'), ' ');
    
    // 3. Capitalize the first letter of EVERY word (e.g., "tree pose" -> "Tree Pose")
    return spaced.split(' ').map((word) {
      if (word.isEmpty) return '';
      return "${word[0].toUpperCase()}${word.substring(1).toLowerCase()}";
    }).join(' ');
  }

  // ADD THIS RIGHT BELOW _formatActivityName
  String _getAssetForActivity(String activityKey) {
    final key = activityKey.toLowerCase();
    if (key.contains('run')) return 'assets/icons/running_session_icon.png';
    if (key.contains('squat') || key.contains('quat')) return 'assets/icons/Squat_Session_icon.png';
    if (key.contains('tree') || key.contains('pose') || key.contains('yoga')) return 'assets/icons/Tree_Pose_Image.png';
    if (key.contains('bicep') || key.contains('curl')) return 'assets/icons/bicep_curls_session_Icon.jpg';
    
    // Fallback to the splash icon if an unknown exercise is logged
    return 'assets/icons/Splash_Screen_Icon.png'; 
  }

  Widget _buildRecentActivityCard() {
    String rawKey = (_recentSession!['activity_key'] ?? 'Workout').toString();
    String displayTitle = "${_formatActivityName(rawKey)} Session";
    
    // 🚀 Detect continuous mode by key (mirrors the logic in Reports & History)
    final isRun = rawKey.toLowerCase().contains('run');
    
    int reps = _recentSession!['reps'] ?? 0;
    int formScore = _recentSession!['form_score'] ?? 0;
    int durationSecs = _recentSession!['duration_seconds'] ?? 0;
    int durationMins = (durationSecs / 60).round();
    String deviation = _recentSession!['dominant_deviation'] ?? '';
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(AppRadius.smallControl),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.smallControl),
                  child: Image.asset(
                    _getAssetForActivity(rawKey),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimaryLight)),
                    //   The UI now simply reads the cached string!
                    Text(_formattedSessionDate, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(formScore > 80 ? 'Great!' : 'Good', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              )
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.md), child: Divider(height: 1, color: Color(0xFFEEEEEE))),
          
          // 🚀 Mode-aware stat metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: isRun
              ? [
                  _buildStatMetric('$reps', 'Steps'),
                  _buildStatMetric('$formScore', 'Avg SPM'),
                  _buildStatMetric(durationMins > 0 ? '$durationMins min' : '${durationSecs}s', 'Duration'),
                ]
              : [
                  _buildStatMetric('$reps', 'Reps'),
                  _buildStatMetric('$formScore%', 'Accuracy'),
                  _buildStatMetric(durationMins > 0 ? '$durationMins min' : '${durationSecs}s', 'Duration'),
                ],
          ),
          
          if (deviation.isNotEmpty && deviation != 'null' && !isRun) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.warningBg.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.smallControl),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Main issue: ${deviation.replaceAll('_', ' ')}', 
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimaryLight)
                    ),
                  ),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildActivePlanCard() {
    final planJson = _activePlan!['plan_json'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlanViewerScreen(
              planData: _activePlan!,
              accessToken: widget.accessToken,
            ),
          ),
        ).then((_) => _fetchActivePlan());
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(AppRadius.smallControl)),
                  child: const Icon(Icons.calendar_month_rounded, color: AppColors.success),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_activePlan!['plan_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimaryLight), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${planJson['duration_weeks']} Weeks • ${planJson['goal']}', style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            
            ValueListenableBuilder<PlanProgress>(
              valueListenable: planProgressController,
              builder: (context, progress, child) {
                return Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.fraction, 
                          backgroundColor: AppColors.backgroundLight, 
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success), 
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      progress.percentage > 0 ? '${progress.percentage}% Done' : 'Just Started', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimaryLight),
                    ),
                  ],
                );
              }
            )
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, String action, {VoidCallback? onActionTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight)),
        GestureDetector(
          onTap: onActionTap, 
          child: Text(
            action, 
            style: const TextStyle(fontSize: 14, color: AppColors.accent, fontWeight: FontWeight.bold)
          ),
        ),
      ],
    );
  }

  Widget _buildStatMetric(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimaryLight)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
      ],
    );
  }
}

class CoachSaabChatSheet extends StatefulWidget {
  final String userId;
  final String userName;
  final String coachAvatarUrl;
  final String accessToken;

  const CoachSaabChatSheet({
    super.key, 
    required this.userId, 
    required this.userName, 
    required this.coachAvatarUrl,
    required this.accessToken,
  });

  @override
  State<CoachSaabChatSheet> createState() => _CoachSaabChatSheetState();
}

class _CoachSaabChatSheetState extends State<CoachSaabChatSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isConnecting = true;
  bool _isSpeaking = false;
  String? _conversationId;
  final List<Map<String, dynamic>> _messages = [];

  final String _baseUrl = 'https://coachsaab-api.onrender.com/api/v1'; 

  @override
  void initState() {
    super.initState();
    _restoreConversationSession();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _restoreConversationSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final url = Uri.parse('$_baseUrl/chat/conversations');
      final response = await http.get(
        url, 
        headers: {'Authorization': 'Bearer ${widget.accessToken}'}
      );

      if (response.statusCode == 200) {
        final List<dynamic> conversations = jsonDecode(response.body);
        
        if (conversations.isNotEmpty) {
          conversations.sort((a, b) {
            final dateA = DateTime.tryParse(a['updated_at'] ?? a['created_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dateB = DateTime.tryParse(b['updated_at'] ?? b['created_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA); 
          });

          _conversationId = conversations.first['id'] ?? conversations.first['conversation_id'];
          await prefs.setString('conversation_id', _conversationId!);
          
          await _loadChatHistory(prefs);
          return;
        } else {
          await _startNewConversation(prefs);
          return;
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _messages.add({'role': 'assistant', 'content': 'Session expired. Please restart the app to log in again.'});
          });
        }
        return;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Network/Server error, attempting offline cache fallback: $e");
      
      final prefs = await SharedPreferences.getInstance();
      final savedConvId = prefs.getString('conversation_id');
      
      if (savedConvId != null) {
        _conversationId = savedConvId;
        await _loadChatHistory(prefs); 
      } else {
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _messages.add({'role': 'assistant', 'content': 'Network offline and no cached chat found. Please check your connection.'});
          });
        }
      }
    }
  }

  Future<void> _startNewConversation(SharedPreferences prefs) async {
    try {
      final url = Uri.parse('$_baseUrl/chat/conversations');
      final response = await http.post(url, headers: {'Authorization': 'Bearer ${widget.accessToken}'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _conversationId = data['conversation_id'];
        await prefs.setString('conversation_id', _conversationId!);
        
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _messages.add({
              'role': 'assistant',
              'content': 'Hello ${widget.userName}! I am CoachSaab, your AI fitness guide. What are we working on today?'
            });
          });
        }
      }
    } catch (e) {
      debugPrint("Failed to start conversation: $e");
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _messages.add({'role': 'assistant', 'content': 'Network Error: Check your connection.'});
        });
      }
    }
  }

  Future<void> _loadChatHistory(SharedPreferences prefs) async {
    try {
      final url = Uri.parse('$_baseUrl/chat/conversations/$_conversationId/messages');
      final response = await http.get(url, headers: {'Authorization': 'Bearer ${widget.accessToken}'});
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _messages.addAll(data.map((m) => Map<String, dynamic>.from(m)).toList());
            if (_messages.isEmpty) {
              _messages.add({'role': 'assistant', 'content': 'Welcome back ${widget.userName}! Ready to crush your goals?'});
            }
          });
          _scrollToBottom();
        }
      } else {
        await prefs.remove('conversation_id');
        await _startNewConversation(prefs);
      }
    } catch (e) {
      debugPrint("Failed to load history: $e");
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _messages.add({'role': 'assistant', 'content': 'Network Error: Could not load chat history.'});
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _conversationId == null) {
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isSpeaking = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final url = Uri.parse('$_baseUrl/chat/conversations/$_conversationId/messages');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.accessToken}'
        },
        body: jsonEncode({'role': 'user', 'content': text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String aiReply = data['content'] ?? "I have processed your request.";
        aiReply = aiReply.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '').trim();

        if (mounted) {
          setState(() {
            _messages.add({'role': 'assistant', 'content': aiReply});
            _isSpeaking = false;
          });
        }
        _scrollToBottom();
      } else {
        if (mounted) {
          setState(() {
            _messages.add({'role': 'assistant', 'content': 'Error: ${response.statusCode}'});
            _isSpeaking = false;
          });
        }
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Chat network error: $e");
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': 'Network error. Please check your connection.'});
          _isSpeaking = false;
        });
      }
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.bottomSheet)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.accentPale,
                      backgroundImage: AssetImage(
                        _isSpeaking
                            ? 'assets/images/coachsaab_talking.png'
                            : 'assets/images/coachsaab_static.png',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CoachSaab AI',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          _isSpeaking ? 'Thinking...' : 'Online',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isSpeaking ? AppColors.accent : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          
          Expanded(
            child: _isConnecting 
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg['role'] == 'user';
                    return _chatBubble(msg['content'], isUser);
                  },
                ),
          ),
          
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + AppSpacing.md, 
              left: AppSpacing.md, 
              right: AppSpacing.md
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Ask me anything...',
                      filled: true,
                      fillColor: AppColors.backgroundLight,
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                CircleAvatar(
                  backgroundColor: AppColors.accent,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18), 
                    onPressed: _sendMessage
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatBubble(String message, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82), 
        decoration: BoxDecoration(
          color: isUser ? AppColors.accent : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(AppRadius.card).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(AppRadius.card),
            bottomLeft: !isUser ? const Radius.circular(4) : const Radius.circular(AppRadius.card),
          ),
        ),
        child: MarkdownBody(
          data: message.replaceAll('<br>', '\n').replaceAll('<br/>', '\n'),
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(fontSize: 14, color: isUser ? Colors.white : AppColors.textPrimaryLight),
            strong: TextStyle(fontWeight: FontWeight.bold, color: isUser ? Colors.white : AppColors.textPrimaryLight),
            listBullet: TextStyle(color: isUser ? Colors.white : AppColors.textPrimaryLight),
            h1: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isUser ? Colors.white : AppColors.textPrimaryLight),
            h2: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isUser ? Colors.white : AppColors.textPrimaryLight),
            h3: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isUser ? Colors.white : AppColors.textPrimaryLight),
            tableBody: TextStyle(fontSize: 13, color: isUser ? Colors.white : AppColors.textPrimaryLight),
            tableHead: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isUser ? Colors.white : AppColors.textPrimaryLight),
          ),
        ),
      ),
    );
  }
}