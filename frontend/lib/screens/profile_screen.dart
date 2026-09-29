import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/api_client.dart';
import 'auth_screen.dart';
import '../core/state/plan_progress_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color primaryBlue = Color(0xFF1577E3);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color cardBg = Colors.white;
  static const Color dividerColor = Color(0xFFF1F5F9);

  late ApiClient _apiClient;
  bool _isLoading = true;
  String? _errorMessage;
  String? _userId;
  
  String _name = 'User';
  int? _age;
  double? _weight;
  double? _height;
  String _goals = '';
  String _preferences = '';
  String _aboutMe = '';
  String _gender = 'Male';
  String _planName = 'No Active Plan';
  String _currentWeekText = '';

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(onUnauthorized: _handleLogout);
    _loadProfileData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('user_id');
      
      String? savedName = prefs.getString('user_name');
      if (savedName != null && savedName.isNotEmpty) {
        _name = savedName;
      }

      if (_userId == null) {
        throw ApiException("Local user state is missing. Please log in again.");
      }

      final profileData = await _apiClient.get('/users/$_userId');
      
      if (profileData['name'] != null && profileData['name'].toString().isNotEmpty && profileData['name'] != 'User') {
        _name = profileData['name'];
      }
      _age = profileData['age'];
      _weight = profileData['weight_kg'] != null ? (profileData['weight_kg'] as num).toDouble() : null;
      _height = profileData['height_cm'] != null ? (profileData['height_cm'] as num).toDouble() : null;
      _goals = (profileData['goals'] as List?)?.join(', ') ?? '';
      _preferences = (profileData['preferred_categories'] as List?)?.join(', ') ?? '';
      _aboutMe = profileData['about_me'] ?? '';
      _gender = profileData['gender']?.toString() ?? 'Male';
      await prefs.setString('user_gender', _gender);

      // 2. Fetch Active Plan
      try {
        final planData = await _apiClient.get('/users/$_userId/plan');
        
        if (planData['plan_id'] != null) {
          _planName = planData['plan_name'] ?? 'My Plan';
          final String planId = planData['plan_id'];
          final planJson = planData['plan_json'] as Map<String, dynamic>?;
          
          final int totalWeeks = planJson?['duration_weeks'] ?? 2;
          
          // Delegate completion tracking entirely to the controller!
          planProgressController.load(planId, planJson ?? {});
          
          DateTime startDate = planData['created_at'] != null ? DateTime.parse(planData['created_at']) : DateTime.now();
          int daysSinceStart = DateTime.now().difference(startDate).inDays;
          int currentWeek = (daysSinceStart / 7).floor() + 1;
          if (currentWeek > totalWeeks) currentWeek = totalWeeks;
          if (currentWeek < 1) currentWeek = 1;
          
          _currentWeekText = 'Week $currentWeek of $totalWeeks';
        }
      } catch (planError) {
        debugPrint("Plan loading error: $planError");
      }

    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = "An unexpected error occurred.";
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditProfileSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: EditProfileForm(
          userId: _userId!,
          apiClient: _apiClient,
          initialName: _name, initialAge: _age, initialWeight: _weight, initialHeight: _height,
          initialGoals: _goals, initialPreferences: _preferences, initialAboutMe: _aboutMe,
          onSaveComplete: () {
            Navigator.pop(context);
            _loadProfileData(); 
          },
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: primaryBlue)),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      const storage = FlutterSecureStorage();
      await storage.deleteAll();

      if (!mounted) return;
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error logging out.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: backgroundLight, body: Center(child: CircularProgressIndicator(color: primaryBlue)));
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: backgroundLight,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: textPrimary, fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadProfileData,
                style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
                child: const Text('Try Again', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        backgroundColor: backgroundLight, elevation: 0, scrolledUnderElevation: 0, centerTitle: true,
        leading: Navigator.canPop(context) 
            ? IconButton(icon: const Icon(Icons.arrow_back, color: textPrimary), onPressed: () => Navigator.pop(context))
            : null,
        title: const Text('Profile', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton.icon(
              onPressed: _showEditProfileSheet,
              icon: const Icon(Icons.edit_outlined, size: 16, color: primaryBlue),
              label: const Text('Edit', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 14)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: primaryBlue.withValues(alpha: 0.3))),
                backgroundColor: primaryBlue.withValues(alpha: 0.05),
              ),
            ),
          )
        ],
      ),
      body: RefreshIndicator(
        color: primaryBlue,
        onRefresh: () async {
          await _loadProfileData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 80, 
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryBlue.withValues(alpha: 0.2), 
                            blurRadius: 12, 
                            offset: const Offset(0, 4)
                          )
                        ]
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          _gender.toLowerCase() == 'female' 
                              ? 'assets/images/female_profile.png' 
                              : 'assets/images/male_profile.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // 👇 This spacing and text column was accidentally deleted
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary)),
                          const SizedBox(height: 4),
                          const Text('Keep showing up, one rep at a time. 💪', style: TextStyle(fontSize: 14, color: textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  // 👇 REPLACE THE ENTIRE ROW WITH THIS:
                  child: Row(
                    children: [
                      ValueListenableBuilder<PlanProgress>(
                        valueListenable: planProgressController,
                        builder: (context, progress, child) {
                          return SizedBox(
                            width: 86, height: 86,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CircularProgressIndicator(
                                  value: progress.fraction, 
                                  strokeWidth: 8, backgroundColor: dividerColor,
                                  valueColor: const AlwaysStoppedAnimation<Color>(primaryBlue), strokeCap: StrokeCap.round,
                                ),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('${progress.percentage}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textPrimary)),
                                      const Text('Completed', style: TextStyle(fontSize: 10, color: textSecondary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Current Plan', style: TextStyle(color: textSecondary, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(_planName, style: const TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            if (_currentWeekText.isNotEmpty)
                              Text(_currentWeekText, style: const TextStyle(color: primaryBlue, fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                const Text('My Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                const SizedBox(height: 16),
                
                Container(
                  decoration: BoxDecoration(
                    color: cardBg, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.person_outline_rounded, 'Name', _name), _buildDivider(),
                      _buildInfoRow(Icons.calendar_today_outlined, 'Age', _age != null ? '$_age' : '-'), _buildDivider(),
                      _buildInfoRow(Icons.shopping_bag_outlined, 'Weight', _weight != null ? '${_weight!.toStringAsFixed(0)} kg' : '-'), _buildDivider(),
                      _buildInfoRow(Icons.straighten_outlined, 'Height', _height != null ? '${_height!.toStringAsFixed(0)} cm' : '-'), _buildDivider(),
                      _buildInfoRow(Icons.track_changes_outlined, 'Goal', _goals.isNotEmpty ? _goals : '-'), _buildDivider(),
                      _buildInfoRow(Icons.fitness_center_outlined, 'Preferred Exercise', _preferences.isNotEmpty ? _preferences : '-'), _buildDivider(),
                      _buildInfoRow(Icons.info_outline_rounded, 'About Me', _aboutMe.isNotEmpty ? _aboutMe : '-', isLast: true),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 14, color: textSecondary),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text('Your information is private and used to personalize your experience.', style: TextStyle(color: textSecondary, fontSize: 11), textAlign: TextAlign.center),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    label: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),

                const SizedBox(height: 80), 
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value, {bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryBlue, size: 22),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: Text(title, style: const TextStyle(color: textPrimary, fontSize: 15))),
          Expanded(flex: 3, child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: textSecondary, fontSize: 15))),
        ],
      ),
    );
  }

  Widget _buildDivider() => const Divider(height: 1, color: dividerColor, indent: 56, endIndent: 20);
}

class EditProfileForm extends StatefulWidget {
  final String userId;
  final ApiClient apiClient; 
  final String initialName;
  final int? initialAge;
  final double? initialWeight;
  final double? initialHeight;
  final String initialGoals;
  final String initialPreferences;
  final String initialAboutMe;
  final VoidCallback onSaveComplete;

  const EditProfileForm({
    super.key,
    required this.userId, required this.apiClient, required this.initialName,
    this.initialAge, this.initialWeight, this.initialHeight,
    required this.initialGoals, required this.initialPreferences,
    required this.initialAboutMe, required this.onSaveComplete,
  });

  @override
  State<EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends State<EditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late TextEditingController _nameCtrl, _ageCtrl, _weightCtrl, _heightCtrl, _goalsCtrl, _prefsCtrl, _aboutCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _ageCtrl = TextEditingController(text: widget.initialAge?.toString() ?? '');
    _weightCtrl = TextEditingController(text: widget.initialWeight?.toString() ?? '');
    _heightCtrl = TextEditingController(text: widget.initialHeight?.toString() ?? '');
    _goalsCtrl = TextEditingController(text: widget.initialGoals);
    _prefsCtrl = TextEditingController(text: widget.initialPreferences);
    _aboutCtrl = TextEditingController(text: widget.initialAboutMe);
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _ageCtrl.dispose(); _weightCtrl.dispose(); _heightCtrl.dispose();
    _goalsCtrl.dispose(); _prefsCtrl.dispose(); _aboutCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      List<String> goalsList = _goalsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      List<String> prefsList = _prefsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      final payload = {
        'name': _nameCtrl.text.trim(),
        'age': int.tryParse(_ageCtrl.text),
        'weight_kg': double.tryParse(_weightCtrl.text),
        'height_cm': double.tryParse(_heightCtrl.text),
        'goals': goalsList,
        'preferred_categories': prefsList,
        'about_me': _aboutCtrl.text.trim(),
      };

      await widget.apiClient.put('/users/${widget.userId}', body: payload);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', _nameCtrl.text.trim());
      widget.onSaveComplete();
      
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save profile updates.')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildTextField('Name', _nameCtrl, icon: Icons.person_outline),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Age', _ageCtrl, icon: Icons.calendar_today_outlined, isNumber: true)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Weight (kg)', _weightCtrl, icon: Icons.monitor_weight_outlined, isNumber: true)),
                    ],
                  ),
                  _buildTextField('Height (cm)', _heightCtrl, icon: Icons.straighten_outlined, isNumber: true),
                  _buildTextField('Fitness Goals (comma separated)', _goalsCtrl, icon: Icons.track_changes_outlined),
                  _buildTextField('Preferred Exercises (comma separated)', _prefsCtrl, icon: Icons.fitness_center_outlined),
                  _buildTextField('About Me', _aboutCtrl, icon: Icons.info_outline, maxLines: 3),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1577E3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {required IconData icon, bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF64748B)),
          prefixIcon: maxLines == 1 ? Icon(icon, color: Color(0xFF64748B), size: 20) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1577E3), width: 2)),
          filled: true, fillColor: const Color(0xFFF8FAFC),
        ),
      ),
    );
  }
}