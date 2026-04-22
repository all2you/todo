import 'package:flutter/material.dart';
import '../services/openai_service.dart';
import '../services/notification_service.dart';

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

  // 알림
  bool _notifEnabled = false;
  TimeOfDay _notifTime = const TimeOfDay(hour: 21, minute: 0);
  bool _notifLoading = false;

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
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final key = await OpenAiService.getApiKey();
    final model = await OpenAiService.getModel();
    final notif = await NotificationService.loadSettings();
    setState(() {
      _keyCtrl.text = key ?? '';
      _selectedModel = model;
      _notifEnabled = notif.enabled;
      _notifTime = TimeOfDay(hour: notif.hour, minute: notif.minute);
    });
  }

  Future<void> _save() async {
    await OpenAiService.saveApiKey(_keyCtrl.text);
    await OpenAiService.saveModel(_selectedModel);
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
      backgroundColor: const Color(0xFFF7F3EE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '설정',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2C2C2C)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 알림 섹션 ───────────────────────────────────
          _buildSection(
            icon: Icons.notifications_outlined,
            title: '매일 일기 알림',
            children: [_buildNotifSettings()],
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

  Widget _buildNotifSettings() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('알림 켜기',
                      style: TextStyle(fontWeight: FontWeight.w600)),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF6B9B7A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF6B9B7A).withValues(alpha: 0.3)),
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
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF6B9B7A))),
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
        const Text('API 키',
            style: TextStyle(fontSize: 13, color: Colors.grey)),
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
        const Text('모델 선택',
            style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                    ? const Color(0xFF6B9B7A).withValues(alpha: 0.1)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF6B9B7A)
                      : Colors.grey.shade200,
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
}
