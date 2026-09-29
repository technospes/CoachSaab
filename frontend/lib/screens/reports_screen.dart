import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;

class ReportsScreen extends StatefulWidget {
  final String userId;
  final String accessToken;
  final String? initialActivityKey;

  const ReportsScreen({
    super.key,
    required this.userId,
    required this.accessToken,
    this.initialActivityKey,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const Color neuBackground = Color(0xFFE0E5EC);
  static const Color neuDarkShadow = Color(0xFFA3B1C6);
  static const Color neuLightShadow = Color(0xFFFFFFFF);

  static const Color textDark = Color(0xFF2D3748);
  static const Color textLight = Color(0xFF718096);
  static const Color accentGreen = Color(0xFF22C55E);

  String _selectedTimeframe = 'This Week';
  final List<String> _timeframes = ['This Week', 'Last 4 Weeks', 'This Month', 'All Time'];

  late String _selectedActivity;

  // Canonical keys matching database and session_summary_screen
  final List<Map<String, String>> _activities = [
    {'name': 'All Exercises', 'key': 'all'},
    {'name': 'Squats', 'key': 'squat'},
    {'name': 'Push-Ups', 'key': 'push_up'},
    {'name': 'Bicep Curls', 'key': 'bicep_curl'},
    {'name': 'Tree Pose', 'key': 'tree_pose'},
    {'name': 'Treadmill Run', 'key': 'running'},
  ];

  bool _isLoading = true;
  int _totalWorkouts = 0;
  String _consistency = "0%";
  int _totalReps = 0;
  int _avgFormScore = 0;
  List<double> _trendData = [];

  List<dynamic> _commonIssues = [];
  List<dynamic> _exercisePerf = [];

  String _metricType = 'form_score';
  String _primaryMetricLabel = 'Avg Form';

  @override
  void initState() {
    super.initState();
    _selectedActivity = widget.initialActivityKey ?? 'all';
    _fetchReportsData();
  }

  Future<void> _fetchReportsData() async {
    setState(() => _isLoading = true);
    try {
      final queryParams = {
        'timeframe': _selectedTimeframe,
      };
      if (_selectedActivity != 'all') {
        queryParams['activity_key'] = _selectedActivity;
      }

      final url = Uri.https(
        'coachsaab-api.onrender.com',
        '/api/v1/users/${widget.userId}/dashboard',
        queryParams,
      );

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _totalWorkouts = data['total_workouts'] ?? 0;
            _consistency = data['consistency'] ?? '0%';
            _totalReps = data['total_reps'] ?? 0;
            _avgFormScore = data['avg_form_score'] ?? 0;
            _metricType = data['metric_type'] ?? 'form_score';
            _primaryMetricLabel = data['primary_metric_label'] ?? 'Avg Form';

            final rawTrend = data['trend_data'] ?? [];
            _trendData = rawTrend.map<double>((e) => (e as num).toDouble()).toList();

            _commonIssues = data['common_issues'] ?? [];
            _exercisePerf = data['exercise_performance'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching reports: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildNeuCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double? width,
    BoxShape shape = BoxShape.rectangle,
  }) {
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: neuBackground,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(20) : null,
        boxShadow: const [
          BoxShadow(color: neuDarkShadow, offset: Offset(6, 6), blurRadius: 12, spreadRadius: 1),
          BoxShadow(color: neuLightShadow, offset: Offset(-6, -6), blurRadius: 12, spreadRadius: 1),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: neuBackground,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: accentGreen))
            : RefreshIndicator(
                color: accentGreen,
                onRefresh: _fetchReportsData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reports',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: textDark, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 4),
                      const Text('Filter by exercise to see specific trends.', style: TextStyle(fontSize: 14, color: textLight)),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: _buildTimeframeFilter()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildActivityFilter()),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _buildKPIs(),
                      const SizedBox(height: 32),
                      _buildTrendChart(),
                      const SizedBox(height: 32),
                      _buildCommonIssues(),
                      const SizedBox(height: 32),
                      _buildExercisePerformance(),
                      const SizedBox(height: 32),
                      _buildCompletion(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTimeframeFilter() {
    return _buildNeuCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTimeframe,
          isExpanded: true,
          icon: const Icon(Icons.calendar_today_rounded, color: textDark, size: 16),
          dropdownColor: neuBackground,
          style: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w600),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _selectedTimeframe = newValue);
              _fetchReportsData();
            }
          },
          items: _timeframes.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value, overflow: TextOverflow.ellipsis));
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActivityFilter() {
    return _buildNeuCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedActivity,
          isExpanded: true,
          icon: const Icon(Icons.fitness_center_rounded, color: textDark, size: 16),
          dropdownColor: neuBackground,
          style: const TextStyle(color: textDark, fontSize: 13, fontWeight: FontWeight.w600),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _selectedActivity = newValue);
              _fetchReportsData();
            }
          },
          items: _activities.map<DropdownMenuItem<String>>((Map<String, String> item) {
            return DropdownMenuItem<String>(value: item['key'], child: Text(item['name']!, overflow: TextOverflow.ellipsis));
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildKPIs() {
    final bool isRun = _metricType == 'cadence' || _selectedActivity == 'running';
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      children: [
        _buildNeuKPICard(Icons.local_fire_department_rounded, '$_totalWorkouts', 'Workouts'),
        _buildNeuKPICard(Icons.monitor_heart_outlined, _consistency, 'Consistency'),
        _buildNeuKPICard(
          isRun ? Icons.directions_run_rounded : Icons.fitness_center_rounded,
          '$_totalReps',
          isRun ? 'Total Steps' : 'Total Reps',
        ),
        _buildNeuKPICard(Icons.star_rounded, isRun ? '$_avgFormScore SPM' : '$_avgFormScore%', _primaryMetricLabel),
      ],
    );
  }

  Widget _buildNeuKPICard(IconData icon, String value, String label) {
    return _buildNeuCard(
      width: (MediaQuery.of(context).size.width / 2) - 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: textLight, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textDark)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: textLight, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    final bool isRun = _metricType == 'cadence' || _selectedActivity == 'running';
    String title = _selectedActivity == 'all'
        ? 'Overall Form Trend'
        : isRun
            ? 'Cadence (SPM) Trend'
            : 'Form Score Trend';

    final bool hasData = _trendData.isNotEmpty;

    return _buildNeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textDark)),
              if (_trendData.isNotEmpty)
                Text(
                  '${_trendData.length} Session${_trendData.length > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accentGreen),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: hasData
                ? CustomPaint(painter: _NeuTrendPainter(data: _trendData, isRun: isRun))
                : const Center(
                    child: Text(
                      'No session data logged yet for this filter.',
                      style: TextStyle(fontSize: 13, color: textLight, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonIssues() {
    if (_commonIssues.isEmpty) return const SizedBox.shrink();
    return _buildNeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Common Form Issues', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textDark)),
          const SizedBox(height: 16),
          ..._commonIssues.map((issue) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(issue['issue'] ?? 'Unknown', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text('${issue['count']} occurrences', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                  )
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExercisePerformance() {
    if (_exercisePerf.isEmpty || _selectedActivity != 'all') return const SizedBox.shrink();
    return _buildNeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Exercise Performance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textDark)),
          const SizedBox(height: 16),
          ..._exercisePerf.map((perf) {
            final prev = perf['previous'] ?? 0;
            final curr = perf['current'] ?? 0;
            final isImproving = curr >= prev;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  const Icon(Icons.fitness_center_rounded, color: textLight, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(perf['name'] ?? 'Exercise', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark)),
                  ),
                  Row(
                    children: [
                      Text('$prev', style: const TextStyle(fontSize: 14, color: textLight, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, color: textLight.withValues(alpha: 0.5), size: 14),
                      const SizedBox(width: 6),
                      Text('$curr', style: TextStyle(fontSize: 16, color: isImproving ? accentGreen : Colors.red, fontWeight: FontWeight.w900)),
                      if (isImproving) const Icon(Icons.arrow_upward_rounded, color: accentGreen, size: 14),
                    ],
                  )
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompletion() {
    return _buildNeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Plan Consistency', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textDark)),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: double.tryParse(_consistency.replaceAll('%', '')) != null
                        ? double.parse(_consistency.replaceAll('%', '')) / 100
                        : 0,
                    strokeWidth: 12,
                    backgroundColor: neuBackground.withValues(alpha: 0.5),
                    valueColor: const AlwaysStoppedAnimation<Color>(accentGreen),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Text(_consistency, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textDark)),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeuTrendPainter extends CustomPainter {
  final List<double> data;
  final bool isRun;

  _NeuTrendPainter({required this.data, this.isRun = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final graphHeight = size.height;
    final graphWidth = size.width;

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, graphHeight), Offset(graphWidth, graphHeight), gridPaint);
    canvas.drawLine(Offset(0, graphHeight / 2), Offset(graphWidth, graphHeight / 2), gridPaint);
    canvas.drawLine(Offset(0, 0), Offset(graphWidth, 0), gridPaint);

    final double maxY = isRun ? 220.0 : 100.0;

    // Single-session baseline handling for demo readiness
    final List<double> plotData = data.length == 1 ? [data[0], data[0]] : data;

    final List<Offset> points = [];
    final double xStep = graphWidth / (plotData.length - 1);
    for (int i = 0; i < plotData.length; i++) {
      final double x = (i * xStep);
      final double safeValue = plotData[i] > maxY ? maxY : (plotData[i] < 0 ? 0 : plotData[i]);
      final double y = graphHeight - ((safeValue / maxY) * graphHeight);
      points.add(Offset(x, y));
    }

    final Path linePath = Path();
    linePath.moveTo(points[0].dx, points[0].dy);

    if (data.length == 1) {
      // Draw straight baseline with a highlighted center marker for single session
      linePath.lineTo(points[1].dx, points[1].dy);
    } else {
      for (int i = 0; i < points.length - 1; i++) {
        final double controlX = points[i].dx + (points[i + 1].dx - points[i].dx) / 2;
        linePath.cubicTo(controlX, points[i].dy, controlX, points[i + 1].dy, points[i + 1].dx, points[i + 1].dy);
      }
    }

    final Path fillPath = Path.from(linePath);
    fillPath.lineTo(points.last.dx, graphHeight);
    fillPath.lineTo(points.first.dx, graphHeight);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, graphHeight),
        [const Color(0xFF22C55E).withValues(alpha: 0.25), const Color(0xFF22C55E).withValues(alpha: 0.0)],
      );
    canvas.drawPath(fillPath, fillPaint);

    final lineStroke = Paint()
      ..color = const Color(0xFF22C55E)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, lineStroke);

    final dotPaintOuter = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final dotPaintInner = Paint()..color = const Color(0xFF22C55E)..style = PaintingStyle.fill;

    if (data.length == 1) {
      // Draw a single focal dot in the middle of the graph
      final centerPoint = Offset(graphWidth / 2, points[0].dy);
      canvas.drawCircle(centerPoint, 7, dotPaintInner);
      canvas.drawCircle(centerPoint, 4, dotPaintOuter);
    } else {
      for (final point in points) {
        canvas.drawCircle(point, 6, dotPaintInner);
        canvas.drawCircle(point, 4, dotPaintOuter);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NeuTrendPainter oldDelegate) {
    if (oldDelegate.isRun != isRun) return true;
    if (oldDelegate.data.length != data.length) return true;
    for (int i = 0; i < data.length; i++) {
      if (oldDelegate.data[i] != data[i]) return true;
    }
    return false;
  }
}