import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/korail_colors.dart';
import '../../data/services/api_client.dart';
import '../providers/auth_provider.dart';

/// 코레일 로그인 화면
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  final _idFocusNode = FocusNode();
  final _pwFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _autoLogin = true;

  @override
  void initState() {
    super.initState();
    _loadAutoLoginSetting();
  }

  Future<void> _loadAutoLoginSetting() async {
    final saved = await ApiClient.instance.readAutoLoginSetting();
    if (mounted) {
      setState(() => _autoLogin = saved);
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    _idFocusNode.dispose();
    _pwFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // 에러 메시지 스낵바 표시
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.errorMessage != null && prev?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: KorailColors.statusFailure,
          ),
        );
      }
    });

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 상단 블루 그라데이션 영역 (로고 + 타이틀)
            _buildHeader(),

            // 로그인 폼
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 회원번호 입력
                  _buildLabel('회원번호 (코레일멤버십)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _idController,
                    focusNode: _idFocusNode,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    enabled: !authState.isLoading,
                    decoration: InputDecoration(
                      hintText: '회원번호 10자리 입력',
                      hintStyle: const TextStyle(color: KorailColors.textHint),
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusButton),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusButton),
                        borderSide: const BorderSide(
                          color: KorailColors.korailBlue,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _pwFocusNode.requestFocus(),
                  ),

                  const SizedBox(height: 20),

                  // 비밀번호 입력
                  _buildLabel('비밀번호'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pwController,
                    focusNode: _pwFocusNode,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    enabled: !authState.isLoading,
                    decoration: InputDecoration(
                      hintText: '비밀번호 입력',
                      hintStyle: const TextStyle(color: KorailColors.textHint),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: KorailColors.textHint,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusButton),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusButton),
                        borderSide: const BorderSide(
                          color: KorailColors.korailBlue,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _handleLogin(),
                  ),

                  const SizedBox(height: 16),

                  // 자동 로그인 체크박스
                  GestureDetector(
                    onTap: authState.isLoading
                        ? null
                        : () => setState(() => _autoLogin = !_autoLogin),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _autoLogin,
                            onChanged: authState.isLoading
                                ? null
                                : (v) => setState(() => _autoLogin = v ?? true),
                            activeColor: KorailColors.korailBlue,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '자동 로그인',
                          style: TextStyle(
                            fontSize: 14,
                            color: KorailColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 로그인 버튼
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KorailColors.korailBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            KorailColors.korailBlue.withAlpha(150),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusButton),
                        ),
                      ),
                      child: authState.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              '로그인',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 안내 텍스트
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: KorailColors.background,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusButton),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: KorailColors.textSecondary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '안내사항',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: KorailColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• 코레일멤버십 회원번호와 비밀번호로 로그인합니다.\n'
                          '• 로그인 정보는 기기에 암호화되어 안전하게 저장됩니다.\n'
                          '• 세션 만료 시 자동으로 재로그인됩니다.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.6,
                            color: KorailColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: KorailColors.blueGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
          child: Column(
            children: [
              // KTX 아이콘
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.train,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'KTX 자동예약',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '코레일 계정으로 로그인하세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withAlpha(200),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: KorailColors.textPrimary,
      ),
    );
  }

  Future<void> _handleLogin() async {
    final id = _idController.text.trim();
    final pw = _pwController.text.trim();

    if (id.isEmpty || pw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('회원번호와 비밀번호를 모두 입력해주세요'),
          backgroundColor: KorailColors.statusFailure,
        ),
      );
      return;
    }

    // 키보드 닫기
    FocusScope.of(context).unfocus();

    await ref.read(authProvider.notifier).login(id, pw, autoLogin: _autoLogin);
  }
}
