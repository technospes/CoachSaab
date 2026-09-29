import 'package:flutter/material.dart';
import '../../main.dart'; // Ensure this points to where AppColors is defined

class GoalPickerSheet extends StatefulWidget {
  final String exerciseName;
  final String trackingMode;

  const GoalPickerSheet({
    super.key,
    required this.exerciseName,
    required this.trackingMode,
  });

  @override
  State<GoalPickerSheet> createState() => _GoalPickerSheetState();
}

class _GoalPickerSheetState extends State<GoalPickerSheet> {
  int _reps = 10;
  int _durationSeconds = 30;

  static const List<int> _repPresets = [6, 8, 10, 12, 15];
  static const List<int> _durationPresets = [15, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.exerciseName,
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.trackingMode == 'hold' ? 'Set your hold target' : 'Set your rep target',
            style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          // Adaptive Presets
          if (widget.trackingMode == 'hold')
            _buildDurationPresets()
          else if (widget.trackingMode == 'repetition')
            _buildRepPresets(),
            
          const SizedBox(height: 20),
          
          // Adaptive Stepper
          if (widget.trackingMode == 'hold')
            _buildDurationStepper()
          else if (widget.trackingMode == 'repetition')
            _buildRepStepper(),
            
          const SizedBox(height: 28),
          
          // Start Button
          SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textPrimaryLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              onPressed: () {
                if (widget.trackingMode == 'hold') {
                  Navigator.pop(context, GoalResult(durationSeconds: _durationSeconds));
                } else if (widget.trackingMode == 'repetition') {
                  Navigator.pop(context, GoalResult(reps: _reps));
                } else {
                  // Continuous Mode: Open-ended for now
                  Navigator.pop(context, const GoalResult());
                }
              },
              child: const Text('Start', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // --- REPS UI ---
  Widget _buildRepPresets() {
    return Wrap(
      spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
      children: _repPresets.map((r) => _chip(
        label: '$r',
        selected: _reps == r,
        onTap: () => setState(() => _reps = r),
      )).toList(),
    );
  }

  Widget _buildRepStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepperButton(Icons.remove, () {
          if (_reps > 1) setState(() => _reps--);
        }),
        const SizedBox(width: 24),
        Text(
          '$_reps',
          style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 44, fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 24),
        _stepperButton(Icons.add, () {
          if (_reps < 50) setState(() => _reps++);
        }),
      ],
    );
  }

  // --- DURATION UI ---
  Widget _buildDurationPresets() {
    return Wrap(
      spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
      children: _durationPresets.map((d) => _chip(
        label: '${d}s',
        selected: _durationSeconds == d,
        onTap: () => setState(() => _durationSeconds = d),
      )).toList(),
    );
  }

  Widget _buildDurationStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepperButton(Icons.remove, () {
          if (_durationSeconds > 5) setState(() => _durationSeconds -= 5);
        }),
        const SizedBox(width: 24),
        Text(
          '${_durationSeconds}s',
          style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 44, fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 24),
        _stepperButton(Icons.add, () {
          if (_durationSeconds < 300) setState(() => _durationSeconds += 5);
        }),
      ],
    );
  }

  // --- SHARED COMPONENTS ---
  Widget _chip({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52, height: 52,
        decoration: const BoxDecoration(
          color: Colors.white10,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.textPrimaryDark, size: 26),
      ),
    );
  }
}

class GoalResult {
  final int? reps;
  final int? durationSeconds;
  const GoalResult({this.reps, this.durationSeconds});
}