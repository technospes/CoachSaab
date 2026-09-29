import 'package:flutter/material.dart';
import '../main.dart'; // Import Design System
import 'preflight_screen.dart';
import '../services/session_service.dart';
import '../domain/exercise_repository.dart';
import '../widgets/goal_picker_sheet.dart';

class TrainHubScreen extends StatefulWidget {
  const TrainHubScreen({super.key});

  @override
  State<TrainHubScreen> createState() => _TrainHubScreenState();
}

class _TrainHubScreenState extends State<TrainHubScreen> {
  int _selectedTabIndex = 0; // 0: Fitness, 1: Yoga, 2: Sports
  String? _selectedActivityName;
  String? _selectedActivityKey;

  final Map<int, List<Map<String, dynamic>>> _activities = {
    0: [
      {'name': 'Treadmill Run', 'key': 'running', 'icon': Icons.directions_run_rounded},
      {'name': 'Bicep Curls', 'key': 'bicep_curl', 'image': 'assets/images/flat/bicep-curl-start.webp', 'icon' : Icons.fitness_center_rounded}, 
      {'name': 'Squats', 'key': 'squat', 'image': 'assets/images/flat/bodyweight-squat-start.webp', 'icon': Icons.accessibility_new_rounded},
      {'name': 'Reverse curl', 'key': 'reverse_curl', 'image': 'assets/images/flat/db-reverse-curl-start.webp', 'icon': Icons.directions_walk_rounded},
      {'name': 'Push-ups', 'key': 'pushup', 'image': 'assets/images/flat/push-up-start.webp', 'icon': Icons.fitness_center_rounded},
      {'name': 'Pull-ups', 'key': 'pullup', 'image': 'assets/images/flat/pull-up-start.webp', 'icon': Icons.sports_gymnastics_rounded},
      {'name': 'Plank', 'key': 'plank', 'image': 'assets/images/flat/plank-main.webp', 'icon': Icons.airline_seat_flat_rounded},
      {'name': 'Crunches', 'key': 'crunch', 'image': 'assets/images/flat/crunches-start.webp', 'icon': Icons.fitness_center_rounded},
      {'name': 'Lunges', 'key': 'lunge', 'image': 'assets/images/flat/lunge-start.webp', 'icon': Icons.directions_walk_rounded},
      {'name': 'Sit Ups', 'key': 'sit_ups', 'image': 'assets/images/flat/sit-ups-start.webp', 'icon': Icons.terrain_rounded},
      {'name': 'Jumping jacks', 'key': 'jumping_jack', 'image': 'assets/images/flat/jumping-jacks-peak.webp', 'icon': Icons.accessibility_rounded},
    ],
    // Add dummy keys for Yoga and Sports for now
    1: [
      // {'name': 'Surya Namaskar', 'key': 'surya_namaskar', 'icon': Icons.self_improvement_rounded},
      {'name': 'Warrior II', 'key': 'warrior_2', 'icon': Icons.sports_martial_arts_rounded},
      {'name': 'Downward Dog', 'key': 'downward_dog', 'icon': Icons.accessibility_rounded},
      {'name': 'Tree Pose', 'key': 'tree_pose', 'icon': Icons.nature_people_rounded},
      {'name': 'Cobra Pose', 'key': 'cobra_pose', 'icon': Icons.boy_rounded},
      {'name': 'Bridge Pose', 'key': 'bridge_pose', 'icon': Icons.airline_seat_flat_rounded},
    ],
    2: [
      {'name': 'Cricket', 'key': 'cricket', 'icon': Icons.sports_cricket_rounded},
      {'name': 'Football', 'key': 'football', 'icon': Icons.sports_soccer_rounded},
      {'name': 'Basketball', 'key': 'basketball', 'icon': Icons.sports_basketball_rounded},
      {'name': 'Badminton', 'key': 'badminton', 'icon': Icons.sports_tennis_rounded},
      {'name': 'Athletics', 'key': 'athletics', 'icon': Icons.directions_run_rounded},
      {'name': 'Others', 'key': 'others', 'icon': Icons.more_horiz_rounded},
    ]
  };

  void _handleActivitySelect(String name, String key) {
    if (_selectedTabIndex == 2 && name == 'Cricket') {
      _showSportsDeepDive();
    } else {
      setState(() {
        _selectedActivityName = name;
        _selectedActivityKey = key;
      });
    }
  }

  // ==========================================
  // SPORTS DEEP DIVE (Nested Bottom Sheet Flow)
  // ==========================================
  void _showSportsDeepDive() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (BuildContext context) {
        String? activeCategory;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.5, maxChildSize: 0.9, expand: false,
              builder: (context, scrollController) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          if (activeCategory != null)
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimaryDark),
                              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                              onPressed: () => setSheetState(() => activeCategory = null),
                            ),
                          if (activeCategory != null) const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              activeCategory ?? 'Cricket', 
                              style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 22, fontWeight: FontWeight.bold)
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.textSecondaryDark), 
                            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(context)
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        children: activeCategory == null
                            ? [
                                _buildNestedCard('Batting', Icons.sports_cricket_rounded, () {
                                  Navigator.pop(context);
                                  setState(() {
                                    _selectedActivityName = 'Batting Practice';
                                    _selectedActivityKey = 'batting'; // Backend key
                                  });
                                }),
                                _buildNestedCard('Bowling', Icons.sports_baseball_rounded, () {
                                  setSheetState(() => activeCategory = 'Bowling');
                                }),
                                _buildNestedCard('Fielding', Icons.pan_tool_rounded, () {
                                  Navigator.pop(context);
                                  setState(() {
                                    _selectedActivityName = 'Fielding Drills';
                                    _selectedActivityKey = 'fielding'; // Backend key
                                  });
                                }),
                              ]
                            : [
                                _buildNestedCard('Right Arm Fast Bowler', null, () {
                                  Navigator.pop(context);
                                  setState(() {
                                    _selectedActivityName = 'Right Arm Fast Bowling';
                                    _selectedActivityKey = 'cricket_bowling_right_arm_fast'; // Backend key
                                  });
                                }),
                                _buildNestedCard('Left Arm Fast Bowler', null, () {}),
                                _buildNestedCard('Right Arm Offbreak', null, () {}),
                                _buildNestedCard('Leg Spinner', null, () {}),
                              ],
                      ),
                    )
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildNestedCard(String title, IconData? icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
        leading: icon != null ? Icon(icon, color: AppColors.accent) : null,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimaryDark, fontWeight: FontWeight.w600, fontSize: 16)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondaryDark),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark, 
      appBar: AppBar(
        title: const Text('Train', style: TextStyle(color: AppColors.textPrimaryDark, fontWeight: FontWeight.bold, fontSize: 26)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimaryDark), onPressed: () {})
        ],
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark, 
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        top: 0, bottom: 0,
                        left: _selectedTabIndex * ((MediaQuery.of(context).size.width - (AppSpacing.lg * 2) - 8) / 3),
                        width: (MediaQuery.of(context).size.width - (AppSpacing.lg * 2) - 8) / 3,
                        child: Container(decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(21))),
                      ),
                      Row(
                        children: [
                          _buildTabLabel(0, 'Fitness'),
                          _buildTabLabel(1, 'Yoga'),
                          _buildTabLabel(2, 'Sports'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  _selectedTabIndex == 1 ? 'Choose a Pose / Flow' : 'Choose an Activity', 
                  style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 18, fontWeight: FontWeight.bold)
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85, 
                  ),
                  itemCount: _activities[_selectedTabIndex]!.length,
                  itemBuilder: (context, index) {
                    final item = _activities[_selectedTabIndex]![index];
                    final isSelected = _selectedActivityName == item['name'];
                    final double cardRadius = 16.0;
                    final double borderWidth = isSelected ? 4.0 : 1.5;
                    
                    return GestureDetector(
                      onTap: () => _handleActivitySelect(item['name'], item['key']),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        transform: Matrix4.diagonal3Values(isSelected ? 1.02 : 1.0, isSelected ? 1.02 : 1.0, 1.0),
                        transformAlignment: Alignment.center,
                        // The "border" is a solid filled rounded rect behind a padded, clipped inner
                        // card — this renders perfectly smooth at any thickness. (A stroked
                        // Border.all + BorderRadius combo chips/breaks at the corners once it
                        // gets thick, which is what you were seeing at width 4.0.)
                        padding: EdgeInsets.all(borderWidth),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.accent : Colors.white10,
                          borderRadius: BorderRadius.circular(cardRadius),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular((cardRadius - borderWidth).clamp(0.0, cardRadius)),
                          child: Container(
                            color: AppColors.surfaceDark,
                            child: Stack(
                          fit: StackFit.expand,
                          children: [
                            item.containsKey('image')
                              ? Image.asset(
                                  item['image'],
                                  fit: BoxFit.cover,
                                  // If the local file is missing, fallback to the generic icon on a solid backdrop!
                                  errorBuilder: (context, error, stackTrace) => Center(
                                    child: Icon(item['icon'] ?? Icons.fitness_center_rounded, color: AppColors.textSecondaryDark, size: 42),
                                  ),
                                )
                              : Center(
                                  child: Icon(item['icon'], color: isSelected ? AppColors.accent : AppColors.textSecondaryDark, size: 42),
                                ),

                            // Bottom scrim so the exercise name stays legible over any image
                            if (item.containsKey('image'))
                              Positioned(
                                left: 0, right: 0, bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.only(top: 20, bottom: 8, left: 6, right: 6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.75)],
                                    ),
                                  ),
                                  child: Text(
                                    item['name'], textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textPrimaryDark,
                                      fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),

                            // Icon-only cards (Yoga/Sports) keep the label underneath, not overlaid
                            if (!item.containsKey('image'))
                              Positioned(
                                left: 4, right: 4, bottom: 10,
                                child: Text(
                                  item['name'], textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textPrimaryDark,
                                    fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              ),

                            if (isSelected)
                              const Positioned(top: 8, right: 8, child: Icon(Icons.check_circle, color: AppColors.accent, size: 16)),
                          ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Soft dark fade so grid content never visually collides with the CTA button below,
          // even as more exercises are added and the grid extends further down.
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 130,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.backgroundDark.withValues(alpha: 0.0),
                      AppColors.backgroundDark.withValues(alpha: 0.55),
                      AppColors.backgroundDark.withValues(alpha: 0.92),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          
          Positioned(
            bottom: AppSpacing.lg, left: AppSpacing.lg, right: AppSpacing.lg,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _selectedActivityName != null ? 1.0 : 0.4, 
              child: IgnorePointer(
                ignoring: _selectedActivityName == null,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.textPrimaryLight,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      elevation: _selectedActivityName != null ? 4 : 0, // ✅ Fixed variable name here
                      shadowColor: AppColors.accent.withValues(alpha: 0.4),
                    ),
                    onPressed: () async {
                      if (_selectedActivityKey == null) return;

                      try {
                        // 1. Load definition first to understand its capabilities
                        final exercise = await ExerciseRepository().loadExercise(_selectedActivityKey!);

                        // 2. Launch the Adaptive Picker
                        if (!context.mounted) return;
                        final result = await showModalBottomSheet<GoalResult>(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => GoalPickerSheet(
                            exerciseName: _selectedActivityName!,
                            trackingMode: exercise.trackingMode,
                          ),
                        );

                        if (result == null) return; // User swiped away

                        // 3. Request SessionConfig WITH the user's explicit overrides
                        final sessionService = SessionService();
                        final config = await sessionService.startSession(
                          _selectedActivityKey!,
                          overrideReps: result.reps,
                          overrideDuration: result.durationSeconds,
                        );

                        if (!context.mounted) return;
                        
                        // 4. Launch Workout
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => PreFlightScreen(
                              activityName: _selectedActivityName!,
                              sessionConfig: config,
                            ),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        );
                      } catch (e) {
                        debugPrint("Session Start Error: $e");
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_selectedActivityName != null ? 'Start $_selectedActivityName' : 'Start Tracking', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(width: AppSpacing.sm),
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTabLabel(int index, String title) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          _selectedTabIndex = index;
          _selectedActivityName = null; 
          _selectedActivityKey = null;
        }),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              color: isSelected ? AppColors.textPrimaryLight : AppColors.textSecondaryDark,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
            child: Text(title),
          ),
        ),
      ),
    );
  }
}