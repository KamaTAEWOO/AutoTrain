import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/rail_type.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/korail_colors.dart';
import '../../core/theme/rail_colors.dart';
import '../../data/services/api_client.dart';
import '../providers/auth_provider.dart';
import '../providers/search_provider.dart';
import '../providers/monitor_provider.dart';

/// KTX / SRT 로그인 화면
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
  RailType _selectedRailType = RailType.ktx;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final lastType = await ApiClient.instance.readLastRailType();
    final saved = await ApiClient.instance.readAutoLoginSetting(railType: lastType);
    if (mounted) {
      setState(() {
        _selectedRailType = lastType;
        _autoLogin = saved;
      });
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
    final brandColor = RailColors.primary(_selectedRailType);

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
            // 상단 그라데이션 영역 (로고 + 타이틀 + 탭)
            _buildHeader(brandColor),

            // 로그인 폼
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 회원번호 입력
                  _buildLabel(_selectedRailType.memberLabel),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _idController,
                    focusNode: _idFocusNode,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    enabled: !authState.isLoading,
                    decoration: InputDecoration(
                      hintText: _selectedRailType.memberHint,
                      hintStyle: const TextStyle(color: KorailColors.textHint),
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusButton),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusButton),
                        borderSide: BorderSide(
                          color: brandColor,
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
                        borderSide: BorderSide(
                          color: brandColor,
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
                            activeColor: brandColor,
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
                        backgroundColor: brandColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: brandColor.withAlpha(150),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
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
                        const SizedBox(height: 8),
                        Text(
                          _selectedRailType.infoText,
                          style: const TextStyle(
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

  Widget _buildHeader(Color brandColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: RailColors.gradient(_selectedRailType),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              // KTX / SRT 탭
              _buildRailTypeTab(),

              const SizedBox(height: 20),

              // 아이콘
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
              Text(
                '${_selectedRailType.displayName} 자동예약',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedRailType.loginLabel,
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

  Widget _buildRailTypeTab() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildTabItem(RailType.ktx),
          _buildTabItem(RailType.srt),
        ],
      ),
    );
  }

  Widget _buildTabItem(RailType type) {
    final isSelected = _selectedRailType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedRailType != type) {
            setState(() {
              _selectedRailType = type;
              _idController.clear();
              _pwController.clear();
            });
            // 해당 타입의 자동 로그인 설정 로드
            ApiClient.instance.readAutoLoginSetting(railType: type).then((v) {
              if (mounted) setState(() => _autoLogin = v);
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              type.displayName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? RailColors.primary(type)
                    : Colors.white.withAlpha(180),
              ),
            ),
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

    final success = await ref.read(authProvider.notifier).login(
      id,
      pw,
      autoLogin: _autoLogin,
      railType: _selectedRailType,
    );

    if (success) {
      // 검색 조건 및 모니터 상태 초기화
      ref.read(searchProvider.notifier).reset();
      ref.read(monitorProvider.notifier).reset();
    }
  }
}
