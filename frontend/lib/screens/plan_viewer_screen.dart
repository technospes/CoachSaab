import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/state/plan_progress_controller.dart';

class PlanViewerScreen extends StatefulWidget {
  final Map<String, dynamic> planData;
  final String accessToken;

  const PlanViewerScreen({super.key, required this.planData, required this.accessToken,});

  @override
  State<PlanViewerScreen> createState() => _PlanViewerScreenState();
}

class _PlanViewerScreenState extends State<PlanViewerScreen> {
  static const Color primaryBlue = Color(0xFF1577E3);
  static const Color successGreen = Color(0xFF22C55E);
  static const Color lightBlueBg = Color(0xFFE8F4FF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color borderStroke = Color(0xFFE2E8F0);
  static const Color background = Color(0xFFF7F9FC);
  static const Color darkCard = Color(0xFF0F172A);

  int _selectedWeek = 1;
  int _totalWeeks = 4;
  late DateTime _startDate;

  String? _planId;
  String? _userId;
  String _planName = '';
  String _goal = '';
  String _notes = '';
  List<dynamic> _schedule = [];

  @override
  void initState() {
    super.initState();
    _parsePlanData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_userId != null) {
      _refreshPlanData();
    }
  }

  void _parsePlanData() {
    _planId = widget.planData['plan_id'];
    _userId = widget.planData['user_id'];
    _planName = widget.planData['plan_name'] ?? 'My Plan';

    if (widget.planData['created_at'] != null) {
      _startDate = DateTime.parse(widget.planData['created_at']);
    } else {
      _startDate = DateTime.now();
    }

    final planJson = widget.planData['plan_json'] ?? {};
    _totalWeeks = planJson['duration_weeks'] ?? 4;
    _goal = planJson['goal'] ?? 'General Fitness';
    _notes = planJson['notes'] ?? 'Stay consistent and listen to your body.';

    if (planJson['schedule'] != null) {
      _schedule = planJson['schedule'];
    } else {
      _schedule = List.generate(7, (index) {
        bool isRest = index >= 5;
        return {
          'day_number': index + 1,
          'focus': isRest ? 'REST DAY' : 'FULL BODY',
          'exercises': isRest
              ? []
              : ['Push Up (3 sets x 12 reps)', 'Squat (3 sets x 10 reps)'],
          'is_rest': isRest,
        };
      });
    }

    // Reset selected week to 1 if it's out of bounds
    if (_selectedWeek > _totalWeeks) {
      _selectedWeek = 1;
    }
  }

  Future<void> _refreshPlanData() async {
    if (_userId == null) return;
    try {
      final url = Uri.parse(
        'https://coachsaab-api.onrender.com/api/v1/users/$_userId/plan',
      );
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${widget.accessToken}'}, // ✅ Added token here
      );
      if (response.statusCode == 200) {
        final newData = jsonDecode(response.body);
        // Check if there's an actual plan (not "no_active_plan")
        if (mounted && !newData.containsKey('status')) {
          setState(() {
            // Update ALL plan data fields
            widget.planData['plan_id'] = newData['plan_id'];
            widget.planData['user_id'] = newData['user_id'];
            widget.planData['plan_name'] = newData['plan_name'] ?? widget.planData['plan_name'];
            widget.planData['plan_json'] = newData['plan_json'];
            widget.planData['created_at'] = newData['created_at'];
            
            // Re-parse the data to update all variables
            _planId = newData['plan_id'];
            _planName = newData['plan_name'] ?? 'My Plan';
            
            // Parse the updated plan_json
            final planJson = newData['plan_json'] ?? {};
            _totalWeeks = planJson['duration_weeks'] ?? 4;
            _goal = planJson['goal'] ?? 'General Fitness';
            _notes = planJson['notes'] ?? 'Stay consistent and listen to your body.';
            
            if (planJson['schedule'] != null) {
              _schedule = planJson['schedule'];
            }
            
            // Reset selected week if needed
            if (_selectedWeek > _totalWeeks) {
              _selectedWeek = 1;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to refresh plan: $e');
    }
  }

  Future<void> _toggleDayCompletion(int dayNumber) async {
    if (_planId == null) return;
    try {
      await planProgressController.toggleDay(_planId!, _selectedWeek, dayNumber);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sync progress. Check your connection.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate the day range for the selected week
    int startDayNum = ((_selectedWeek - 1) * 7) + 1;
    int endDayNum = _selectedWeek * 7;

    List<dynamic> currentWeekDays = [];
    if (_schedule.length == 7) {
      for (int i = 0; i < 7; i++) {
        int dayOffset = startDayNum + i;
        var templateDay = _schedule[i % 7];
        currentWeekDays.add({
          'day_number': dayOffset,
          'focus': templateDay['focus'],
          'exercises': templateDay['exercises'],
          'is_rest': templateDay['is_rest'],
        });
      }
    } else {
      currentWeekDays = _schedule.where((d) {
        int dn = d['day_number'] ?? 1;
        return dn >= startDayNum && dn <= endDayNum;
      }).toList();
    }

    if (currentWeekDays.isEmpty) {
      currentWeekDays = List.generate(7, (index) {
        int absDay = startDayNum + index;
        bool isRest = index >= 5;
        return {
          'day_number': absDay,
          'focus': isRest ? 'REST DAY' : 'FULL BODY',
          'exercises': isRest ? [] : ['Full Body Circuit (3 sets x 12 reps)'],
          'is_rest': isRest,
        };
      });
    }

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Your Plan', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: textPrimary), onPressed: _refreshPlanData),
          IconButton(icon: const Icon(Icons.calendar_month_outlined, color: textPrimary), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert_rounded, color: textPrimary), onPressed: () {}),
        ],
      ),
      body: ValueListenableBuilder<PlanProgress>(
        valueListenable: planProgressController,
        builder: (context, progress, child) {
          int totalDays = progress.totalTrainingDays;
          int completedCount = progress.completedDays;
          double progressPercent = progress.fraction;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Plan Summary Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: darkCard, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildPill('$_totalWeeks WEEKS', primaryBlue, Colors.white),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildPill(_goal.toUpperCase(), Colors.white24, Colors.white)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(_planName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.2)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 14),
                                  const SizedBox(width: 6),
                                  Text('Started on ${DateFormat('dd MMM yyyy').format(_startDate)}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          children: [
                            SizedBox(
                              width: 64, height: 64,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CircularProgressIndicator(
                                    value: progressPercent, strokeWidth: 6, backgroundColor: Colors.white12,
                                    valueColor: const AlwaysStoppedAnimation<Color>(primaryBlue), strokeCap: StrokeCap.round,
                                  ),
                                  Center(child: Text('${progress.percentage}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('$completedCount / $totalDays days', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Week Selector (Unchanged)
                SizedBox(
                  height: 64,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _totalWeeks,
                    itemBuilder: (context, index) {
                      int weekNum = index + 1;
                      bool isSelected = _selectedWeek == weekNum;
                      DateTime weekStart = _startDate.add(Duration(days: (weekNum - 1) * 7));
                      DateTime weekEnd = weekStart.add(const Duration(days: 6));
                      String dateRange = '${DateFormat('dd').format(weekStart)}–${DateFormat('dd MMM').format(weekEnd)}';

                      return GestureDetector(
                        onTap: () => setState(() => _selectedWeek = weekNum),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? primaryBlue : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? primaryBlue : borderStroke),
                            boxShadow: isSelected ? [BoxShadow(color: primaryBlue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('W$weekNum', style: TextStyle(color: isSelected ? Colors.white : textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 2),
                              Text(dateRange, style: TextStyle(color: isSelected ? Colors.white70 : textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Coach Notes
                if (_notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: lightBlueBg, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded, color: primaryBlue, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Coach Notes', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 6),
                                Text(_notes, style: const TextStyle(color: textSecondary, height: 1.5, fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
                _buildWeekHeader(startDayNum, endDayNum, progress), // Passed progress here
                const SizedBox(height: 16),

                // 4. Daily Checklists
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: currentWeekDays.length,
                  itemBuilder: (context, index) {
                    return _buildDayCard(currentWeekDays[index], progress); // Passed progress here
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

    Widget _buildWeekHeader(int startDayNum, int endDayNum, PlanProgress progress) {
    int daysInWeek = 7;
    int completedThisWeek = 0;
    for (int i = startDayNum; i <= endDayNum; i++) {
      if (progress.completedKeys.contains('w${_selectedWeek}_d$i')) completedThisWeek++;
    }

    DateTime currentWeekStart =
        _startDate.add(Duration(days: (_selectedWeek - 1) * 7));
    DateTime currentWeekEnd = currentWeekStart.add(const Duration(days: 6));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Week $_selectedWeek',
                  style: const TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '•  ${DateFormat('dd MMM').format(currentWeekStart)} – ${DateFormat('dd MMM').format(currentWeekEnd)}',
                    style: const TextStyle(color: textSecondary, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12, color: textSecondary),
                  children: [
                    TextSpan(
                      text: '$completedThisWeek ',
                      style: TextStyle(
                        color: completedThisWeek == daysInWeek
                            ? successGreen
                            : textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: '/ 7 days done'),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 80,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completedThisWeek / 7,
                    backgroundColor: borderStroke,
                    valueColor: const AlwaysStoppedAnimation<Color>(successGreen),
                    minHeight: 4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

    Widget _buildDayCard(Map<String, dynamic> dayData, PlanProgress progress) {
    int dayNumber = dayData['day_number'];
    bool isRest = dayData['is_rest'] == true;
    String focus = dayData['focus'] ?? '';
    List<dynamic> rawExercises = dayData['exercises'] ?? [];

    // SAFE EXERCISE PARSER: Handles both string lists and object maps
    List<String> exerciseNames = [];
    for (var ex in rawExercises) {
      if (ex is String) {
        exerciseNames.add(ex);
      } else if (ex is Map && ex.containsKey('name')) {
        exerciseNames.add(ex['name'].toString());
      }
    }

    bool isCompleted = progress.completedKeys.contains('w${_selectedWeek}_d$dayNumber');
    DateTime dateForDay = _startDate.add(Duration(days: dayNumber - 1));

    Color cardColor = isCompleted ? const Color(0xFFF8FAFC) : Colors.white;
    Color titleColor = isCompleted ? textSecondary : textPrimary;

    return GestureDetector(
      onTap: () => _toggleDayCompletion(dayNumber),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted
                ? successGreen.withValues(alpha: 0.3)
                : borderStroke,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildStatusIcon(isCompleted, isRest),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Day $dayNumber',
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // WRAPPED IN EXPANDED TO PREVENT OVERFLOW
                      Expanded(
                        child: Text(
                          '•  ${DateFormat('E, dd MMM').format(dateForDay)}',
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (focus.isNotEmpty)
                        // 🚀 NEW: Wrapped in Flexible to prevent long text from overflowing the screen
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isRest ? borderStroke : lightBlueBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              focus.toUpperCase(),
                              style: TextStyle(
                                color: isRest ? textSecondary : primaryBlue,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isRest
                        ? 'Complete Rest / Active Recovery'
                        : exerciseNames.join(', '),
                    style: TextStyle(
                      color: isCompleted ? textSecondary : textPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: borderStroke,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(bool isCompleted, bool isRest) {
    if (isCompleted) {
      return Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: successGreen,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
      );
    } else if (isRest) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: borderStroke, width: 2),
        ),
        child: const Icon(Icons.bedtime_outlined, color: textSecondary, size: 18),
      );
    } else {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: primaryBlue, width: 2),
        ),
      );
    }
  }

  Widget _buildPill(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}