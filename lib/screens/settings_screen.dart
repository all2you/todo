import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/openai_service.dart';
import '../services/notification_service.dart';
import '../services/weather_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // OpenAI
  final _keyCtrl = TextEditingController();
  bool _obscure = true;
  String _selectedModel = 'gpt-4o-mini';

  // OpenWeather
  final _weatherKeyCtrl = TextEditingController();
  bool _weatherObscure = true;

  // 알림
  bool _notifEnabled = false;
  TimeOfDay _notifTime = const TimeOfDay(hour: 21, minute: 0);
  bool _notifLoading = false;

  // 앱 잠금
  bool _lockEnabled = false;
  bool _hasPin = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  static const _models = [
    ('gpt-4o-mini', 'GPT-4o Mini', '빠르고 경제적'),
    ('gpt-4o', 'GPT-4o', '가장 똑똑한 모델'),
    ('gpt-3.5-turbo', 'GPT-3.5 Turbo', '빠른 응답'),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _weatherKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final key = await OpenAiService.getApiKey();
    final model = await OpenAiService.getModel();
    final weatherKey = await WeatherService.getApiKey();
    final notif = await NotificationService.loadSettings();
    final lockEnabled = await AuthService.isLockEnabled();
    final hasPin = await AuthService.hasPin();
    final biometricEnabled = await AuthService.isBiometricEnabled();
    final biometricAvailable = await AuthService.canUseBiometrics();
    setState(() {
      _keyCtrl.text = key ?? '';
      _selectedModel = model;
      _weatherKeyCtrl.text = weatherKey ?? '';
      _notifEnabled = notif.enabled;
      _notifTime = TimeOfDay(hour: notif.hour, minute: notif.minute);
      _lockEnabled = lockEnabled;
      _hasPin = hasPin;
      _biometricEnabled = biometricEnabled;
      _biometricAvailable = biometricAvailable;
    });
  }

  Future<void> _save() async {
    await OpenAiService.saveApiKey(_keyCtrl.text);
    await OpenAiService.saveModel(_selectedModel);
    await WeatherService.saveApiKey(_weatherKeyCtrl.text);
    await _applyNotificationSetting(_notifEnabled);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('설정이 저장되었습니다'),
          backgroundColor: Color(0xFF6B9B7A),
        ),
      );
    }
  }

  Future<void> _applyNotificationSetting(bool enabled) async {
    await NotificationService.saveSettings(
      enabled: enabled,
      hour: _notifTime.hour,
      minute: _notifTime.minute,
    );
    if (enabled) {
      await NotificationService.scheduleDailyReminder(_notifTime);
    } else {
      await NotificationService.cancelReminder();
    }
  }

  Future<void> _toggleNotification(bool value) async {
    if (value) {
      setState(() => _notifLoading = true);
      final granted = await NotificationService.requestPermission();
      setState(() => _notifLoading = false);
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('알림 권한이 거부되었습니다. 설정에서 허용해주세요.')),
          );
        }
        return;
      }
    }
    setState(() => _notifEnabled = value);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notifTime,
      helpText: '알림 받을 시간 선택',
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _notifTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '설정',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 앱 잠금 섹션 ───────────────────────────────
          _buildSection(
            icon: Icons.lock_outline,
            title: '앱 잠금',
            children: [_buildLockSettings()],
          ),
          const SizedBox(height: 16),
          // ── 알림 섹션 ───────────────────────────────────
          _buildSection(
            icon: Icons.notifications_outlined,
            title: '매일 일기 알림',
            children: [_buildNotifSettings()],
          ),
          const SizedBox(height: 16),
          // ── OpenWeather 섹션 ──────────────────────────────
          _buildSection(
            icon: Icons.cloud_outlined,
            title: '날씨 자동 감지 (OpenWeather)',
            children: [
              _buildWeatherApiKeyField(),
              const SizedBox(height: 8),
              _buildWeatherHelpText(),
            ],
          ),
          const SizedBox(height: 16),
          // ── OpenAI 섹션 ─────────────────────────────────
          _buildSection(
            icon: Icons.auto_awesome,
            title: 'AI 글 다듬기 (OpenAI)',
            children: [
              _buildApiKeyField(),
              const SizedBox(height: 16),
              _buildModelSelector(),
              const SizedBox(height: 8),
              _buildHelpText(),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('저장'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B9B7A),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6B9B7A), size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLockSettings() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('앱 잠금 사용',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text('PIN과 생체 인증으로 일기를 보호해요',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Switch(
              value: _lockEnabled,
              activeColor: const Color(0xFF6B9B7A),
              onChanged: _toggleLock,
            ),
          ],
        ),
        if (_lockEnabled) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _changePin,
            icon: const Icon(Icons.pin_outlined),
            label: Text(_hasPin ? 'PIN 변경' : 'PIN 설정'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B9B7A),
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: Color(0xFF6B9B7A)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_biometricAvailable && _hasPin) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('생체 인증 사용',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text('지문 · Face ID로도 잠금을 해제해요',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Switch(
                  value: _biometricEnabled,
                  activeColor: const Color(0xFF6B9B7A),
                  onChanged: _toggleBiometric,
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _toggleLock(bool value) async {
    if (value) {
      final pin = await _promptNewPin();
      if (pin == null) return;
      await AuthService.setPin(pin);
      await AuthService.setLockEnabled(true);
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('앱 잠금 해제'),
          content: const Text('잠금을 끄면 PIN과 생체 인증 설정이 삭제됩니다. 계속하시겠습니까?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('해제'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      await AuthService.setLockEnabled(false);
    }
    await _loadSettings();
  }

  Future<void> _changePin() async {
    if (_hasPin) {
      final current = await _promptPin(title: '현재 PIN 입력');
      if (current == null) return;
      final ok = await AuthService.verifyPin(current);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('현재 PIN이 일치하지 않습니다')),
          );
        }
        return;
      }
    }
    final next = await _promptNewPin();
    if (next == null) return;
    await AuthService.setPin(next);
    await _loadSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN이 저장되었습니다')),
      );
    }
  }

  Future<String?> _promptNewPin() async {
    while (true) {
      final first = await _promptPin(title: '새 PIN 입력 (4~6자리 숫자)');
      if (first == null) return null;
      if (first.length < 4 ||
          first.length > 6 ||
          !RegExp(r'^\d+$').hasMatch(first)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN은 4~6자리 숫자여야 합니다')),
          );
        }
        continue;
      }
      final second = await _promptPin(title: 'PIN 다시 입력');
      if (second == null) return null;
      if (first != second) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN이 일치하지 않습니다. 다시 시도해주세요')),
          );
        }
        continue;
      }
      return first;
    }
  }

  Future<String?> _promptPin({required String title}) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _PinPromptDialog(title: title),
    );
    if (result == null || result.isEmpty) return null;
    return result;
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final result = await AuthService.authenticateWithBiometrics(
        reason: '생체 인증을 등록합니다',
      );
      if (result != BiometricResult.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('생체 인증에 실패했습니다')),
          );
        }
        return;
      }
    }
    await AuthService.setBiometricEnabled(value);
    await _loadSettings();
  }

  Widget _buildNotifSettings() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('알림 켜기', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text('매일 지정한 시간에 일기 쓰기를 알려드려요',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            _notifLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Switch(
                    value: _notifEnabled,
                    activeColor: const Color(0xFF6B9B7A),
                    onChanged: _toggleNotification,
                  ),
          ],
        ),
        if (_notifEnabled) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF6B9B7A).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFF6B9B7A).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time,
                      color: Color(0xFF6B9B7A), size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _notifTime.format(context),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B9B7A)),
                  ),
                  const Spacer(),
                  const Text('시간 변경',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B9B7A))),
                  const Icon(Icons.chevron_right,
                      size: 16, color: Color(0xFF6B9B7A)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '저장 버튼을 눌러야 알림이 설정됩니다.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          ),
        ],
      ],
    );
  }

  Widget _buildApiKeyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('API 키', style: TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 6),
        TextField(
          controller: _keyCtrl,
          obscureText: _obscure,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            hintText: 'sk-...',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('모델 선택', style: TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 8),
        ..._models.map((m) {
          final (id, name, desc) = m;
          final selected = _selectedModel == id;
          return GestureDetector(
            onTap: () => setState(() => _selectedModel = id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF6B9B7A).withOpacity(0.1)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      selected ? const Color(0xFF6B9B7A) : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected
                        ? const Color(0xFF6B9B7A)
                        : Colors.grey.shade400,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? const Color(0xFF6B9B7A)
                                  : const Color(0xFF2C2C2C))),
                      Text(desc,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHelpText() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.amber.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'API 키는 platform.openai.com에서 발급받을 수 있습니다.\n키는 기기에만 저장되며 외부로 전송되지 않습니다.',
              style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherApiKeyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('API 키', style: TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 6),
        TextField(
          controller: _weatherKeyCtrl,
          obscureText: _weatherObscure,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            hintText: 'OpenWeatherMap API 키 입력',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            suffixIcon: IconButton(
              icon: Icon(
                  _weatherObscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () =>
                  setState(() => _weatherObscure = !_weatherObscure),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherHelpText() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'openweathermap.org에서 무료 API 키를 발급받을 수 있습니다.\n일기 작성 시 현재 위치의 날씨를 자동으로 선택합니다.',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinPromptDialog extends StatefulWidget {
  final String title;
  const _PinPromptDialog({required this.title});

  @override
  State<_PinPromptDialog> createState() => _PinPromptDialogState();
}

class _PinPromptDialogState extends State<_PinPromptDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 6,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'PIN',
          counterText: '',
        ),
        onSubmitted: (_) => Navigator.pop(context, _ctrl.text.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('확인'),
        ),
      ],
    );
  }
}
