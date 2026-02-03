import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/api_error.dart';
import '../../data/repositories/train_repository.dart';
import '../../data/services/api_client.dart';

/// 인증 상태
class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final bool isCheckingAuth;
  final String? errorMessage;
  final String userName;

  const AuthState({
    this.isLoggedIn = false,
    this.isLoading = false,
    this.isCheckingAuth = true,
    this.errorMessage,
    this.userName = '',
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isLoading,
    bool? isCheckingAuth,
    String? errorMessage,
    String? userName,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      isCheckingAuth: isCheckingAuth ?? this.isCheckingAuth,
      errorMessage: errorMessage,
      userName: userName ?? this.userName,
    );
  }
}

/// 인증 상태 관리 Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final TrainRepository _repository;

  AuthNotifier({TrainRepository? repository})
      : _repository = repository ?? TrainRepository(),
        super(const AuthState()) {
    // 생성 시 저장된 자격 증명으로 자동 로그인 시도
    _tryAutoLogin();
  }

  /// 저장된 자격 증명으로 자동 로그인 시도
  Future<void> _tryAutoLogin() async {
    try {
      final autoLoginEnabled =
          await ApiClient.instance.readAutoLoginSetting();
      if (!autoLoginEnabled) {
        state = state.copyWith(isCheckingAuth: false);
        return;
      }

      final credentials = await ApiClient.instance.readSavedCredentials();
      if (credentials != null) {
        final loginResponse =
            await _repository.login(credentials.id, credentials.pw);
        if (loginResponse.sessionToken.isNotEmpty) {
          state = state.copyWith(
            isLoggedIn: true,
            isCheckingAuth: false,
            userName: loginResponse.name,
          );
          return;
        }
      }
    } catch (_) {
      // 자동 로그인 실패 시 로그인 화면으로
    }
    state = state.copyWith(isCheckingAuth: false);
  }

  /// 수동 로그인
  ///
  /// [autoLogin]이 true이면 자격 증명을 저장하여 다음 앱 시작 시
  /// 자동 로그인이 동작한다. false이면 저장하지 않는다.
  Future<bool> login(String id, String pw, {bool autoLogin = true}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final loginResponse =
          await _repository.login(id, pw, saveCredentials: autoLogin);

      // 세션 토큰이 비어있으면 로그인 실패로 처리
      if (loginResponse.sessionToken.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '로그인에 실패했습니다. 다시 시도해주세요.',
        );
        return false;
      }

      await ApiClient.instance.saveAutoLoginSetting(autoLogin);
      if (!autoLogin) {
        await ApiClient.instance.clearCredentials();
      }
      state = state.copyWith(isLoggedIn: true, isLoading: false, userName: loginResponse.name);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _parseError(e),
      );
      return false;
    }
  }

  /// 로그아웃
  Future<void> logout() async {
    final apiClient = ApiClient.instance;
    apiClient.clearSessionToken();
    await apiClient.clearCredentials();
    state = const AuthState(isCheckingAuth: false);
  }

  String _parseError(Object e) {
    if (e is ApiError) {
      if (e.isLoginFailed) {
        return '회원번호 또는 비밀번호가 올바르지 않습니다';
      }
      if (e.isSessionExpired) {
        return '세션이 만료되었습니다. 다시 로그인해주세요.';
      }
      return e.detail;
    }
    if (e is NetworkError) {
      return '서버에 연결할 수 없습니다';
    }
    final msg = e.toString();
    if (msg.contains('연결')) return '서버에 연결할 수 없습니다';
    return '로그인에 실패했습니다: $msg';
  }
}

/// 인증 상태 Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
