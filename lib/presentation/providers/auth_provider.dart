import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/rail_type.dart';
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
  final RailType railType;

  const AuthState({
    this.isLoggedIn = false,
    this.isLoading = false,
    this.isCheckingAuth = true,
    this.errorMessage,
    this.userName = '',
    this.railType = RailType.ktx,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isLoading,
    bool? isCheckingAuth,
    String? errorMessage,
    String? userName,
    RailType? railType,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      isCheckingAuth: isCheckingAuth ?? this.isCheckingAuth,
      errorMessage: errorMessage,
      userName: userName ?? this.userName,
      railType: railType ?? this.railType,
    );
  }
}

/// 인증 상태 관리 Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  TrainRepository _repository;

  AuthNotifier({TrainRepository? repository})
      : _repository = repository ?? TrainRepository(),
        super(const AuthState()) {
    _tryAutoLogin();
  }

  /// 저장된 자격 증명으로 자동 로그인 시도
  Future<void> _tryAutoLogin() async {
    try {
      // 마지막 사용 철도 타입 확인
      final lastRailType = await ApiClient.instance.readLastRailType();

      final autoLoginEnabled =
          await ApiClient.instance.readAutoLoginSetting(railType: lastRailType);
      if (!autoLoginEnabled) {
        state = state.copyWith(isCheckingAuth: false, railType: lastRailType);
        return;
      }

      final credentials =
          await ApiClient.instance.readSavedCredentials(railType: lastRailType);
      if (credentials != null) {
        _ensureRepository(lastRailType);
        final loginResponse =
            await _repository.login(credentials.id, credentials.pw);
        if (loginResponse.sessionToken.isNotEmpty) {
          state = state.copyWith(
            isLoggedIn: true,
            isCheckingAuth: false,
            userName: loginResponse.name,
            railType: lastRailType,
          );
          return;
        }
      }
    } catch (_) {
      // 자동 로그인 실패 시 로그인 화면으로
    }
    state = state.copyWith(isCheckingAuth: false);
  }

  /// Repository를 railType에 맞게 교체
  void _ensureRepository(RailType railType) {
    if (_repository.railType != railType) {
      _repository = TrainRepository(railType: railType);
    }
  }

  /// 수동 로그인
  Future<bool> login(
    String id,
    String pw, {
    bool autoLogin = true,
    RailType railType = RailType.ktx,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      railType: railType,
    );

    _ensureRepository(railType);

    try {
      final loginResponse =
          await _repository.login(id, pw, saveCredentials: autoLogin);

      if (loginResponse.sessionToken.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '로그인에 실패했습니다. 다시 시도해주세요.',
        );
        return false;
      }

      await ApiClient.instance.saveAutoLoginSetting(
        autoLogin,
        railType: railType,
      );
      await ApiClient.instance.saveLastRailType(railType);

      if (!autoLogin) {
        await ApiClient.instance.clearCredentials(railType: railType);
      }
      state = state.copyWith(
        isLoggedIn: true,
        isLoading: false,
        userName: loginResponse.name,
        railType: railType,
      );
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
    // API 서버 로그아웃 (쿠키/세션 정리)
    _repository.logout();

    final apiClient = ApiClient.instance;
    apiClient.clearSessionToken();
    await apiClient.clearCredentials(railType: state.railType);
    state = AuthState(isCheckingAuth: false, railType: state.railType);
  }

  /// 세션 만료 처리
  void onSessionExpired() {
    ApiClient.instance.clearSessionToken();
    state = state.copyWith(
      isLoggedIn: false,
      errorMessage: '세션이 만료되었습니다. 다시 로그인해주세요.',
    );
  }

  String _parseError(Object e) {
    if (e is ApiError) {
      if (e.error == 'SERVER_ERROR') {
        return e.detail;
      }
      if (e.isLoginFailed) {
        return e.detail.isNotEmpty ? e.detail : '회원번호 또는 비밀번호가 올바르지 않습니다';
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
