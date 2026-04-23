import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  static const int _maxPinLength = 6;
  static const int _minPinLength = 4;
  final _pin = StringBuffer();
  bool _error = false;
  bool _checkingBiometric = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _maybeTriggerBiometric();
  }

  Future<void> _maybeTriggerBiometric() async {
    final enabled = await AuthService.isBiometricEnabled();
    final available = await AuthService.canUseBiometrics();
    if (!mounted) return;
    setState(() => _biometricAvailable = available);
    if (enabled && available) {
      _triggerBiometric(auto: true);
    }
  }

  Future<void> _triggerBiometric({bool auto = false}) async {
    if (_checkingBiometric) return;
    setState(() => _checkingBiometric = true);
    final result = await AuthService.authenticateWithBiometrics();
    if (!mounted) return;
    setState(() => _checkingBiometric = false);
    if (result == BiometricResult.success) {
      widget.onUnlocked();
    } else if (!auto) {
      _showBiometricError(result);
    }
  }

  void _showBiometricError(BiometricResult result) {
    final msg = switch (result) {
      BiometricResult.notAvailable => '생체 인증을 사용할 수 없습니다.',
      BiometricResult.notEnrolled => '등록된 생체 정보가 없습니다. 기기 설정에서 등록해주세요.',
      BiometricResult.failed => '생체 인증에 실패했습니다.',
      BiometricResult.canceled => '생체 인증이 취소되었습니다.',
      BiometricResult.success => '',
    };
    if (msg.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _appendDigit(String digit) async {
    if (_pin.length >= _maxPinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin.write(digit);
      _error = false;
    });
    if (_pin.length == _maxPinLength) {
      await _tryUnlock();
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      final s = _pin.toString();
      _pin
        ..clear()
        ..write(s.substring(0, s.length - 1));
      _error = false;
    });
  }

  Future<void> _tryUnlock() async {
    final ok = await AuthService.verifyPin(_pin.toString());
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _error = true;
        _pin.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.lock_outline, size: 56, color: Color(0xFF6B9B7A)),
            const SizedBox(height: 16),
            const Text(
              'PIN을 입력하세요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            _buildPinIndicator(),
            const SizedBox(height: 12),
            SizedBox(
              height: 20,
              child: _error
                  ? const Text(
                      'PIN이 일치하지 않습니다',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    )
                  : null,
            ),
            const Spacer(),
            _buildKeypad(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPinIndicator() {
    final filled = _pin.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_maxPinLength, (i) {
        final isFilled = i < filled;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? const Color(0xFF6B9B7A) : Colors.transparent,
            border: Border.all(
              color: _error ? Colors.red : const Color(0xFF6B9B7A),
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildKeypad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: [
          for (var i = 1; i <= 9; i++) _digit('$i'),
          _leftActionButton(),
          _digit('0'),
          _backspaceButton(),
        ],
      ),
    );
  }

  Widget _digit(String d) {
    return InkWell(
      onTap: () => _appendDigit(d),
      borderRadius: BorderRadius.circular(40),
      child: Center(
        child: Text(
          d,
          style:
              const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _leftActionButton() {
    // PIN이 4자리 이상 입력되면 확인 버튼, 그 외에는 생체 인증 버튼(가능할 때만)
    if (_pin.length >= _minPinLength) {
      return InkWell(
        onTap: _tryUnlock,
        borderRadius: BorderRadius.circular(40),
        child: const Center(
          child: Icon(Icons.check_circle,
              size: 32, color: Color(0xFF6B9B7A)),
        ),
      );
    }
    if (!_biometricAvailable) return const SizedBox.shrink();
    return InkWell(
      onTap: _checkingBiometric ? null : () => _triggerBiometric(),
      borderRadius: BorderRadius.circular(40),
      child: Center(
        child: _checkingBiometric
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.fingerprint,
                size: 28, color: Color(0xFF6B9B7A)),
      ),
    );
  }

  Widget _backspaceButton() {
    return InkWell(
      onTap: _backspace,
      borderRadius: BorderRadius.circular(40),
      child: const Center(
        child: Icon(Icons.backspace_outlined, size: 24),
      ),
    );
  }
}
