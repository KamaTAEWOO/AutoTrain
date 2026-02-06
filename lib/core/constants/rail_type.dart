/// 철도 사업자 구분
enum RailType {
  ktx,
  srt;

  /// 표시 이름 (KTX / SRT)
  String get displayName => switch (this) {
        ktx => 'KTX',
        srt => 'SRT',
      };

  /// 로그인 화면 서브타이틀
  String get loginLabel => switch (this) {
        ktx => '코레일 계정으로 로그인하세요',
        srt => 'SR 계정으로 로그인하세요',
      };

  /// 로그인 ID 입력 라벨
  String get memberLabel => switch (this) {
        ktx => '회원번호 / 휴대폰 번호 / 이메일',
        srt => '회원번호 / 휴대폰 번호 / 이메일',
      };

  /// 로그인 ID 힌트
  String get memberHint => switch (this) {
        ktx => '회원번호, 전화번호 또는 이메일',
        srt => '회원번호, 전화번호 또는 이메일',
      };

  /// AppBar 타이틀
  String get appBarTitle => switch (this) {
        ktx => '코레일톡',
        srt => 'SRT',
      };

  /// iOS App Store URL
  String get appStoreUrl => switch (this) {
        ktx => 'https://apps.apple.com/kr/app/id1000558562',
        srt => 'https://apps.apple.com/kr/app/id1350286957',
      };

  /// Android Play Store URL
  String get playStoreUrl => switch (this) {
        ktx => 'market://details?id=com.korail.talk',
        srt => 'market://details?id=kr.co.srail.newapp',
      };

  /// Android Play Store 웹 URL (fallback)
  String get playStoreWebUrl => switch (this) {
        ktx => 'https://play.google.com/store/apps/details?id=com.korail.talk',
        srt => 'https://play.google.com/store/apps/details?id=kr.co.srail.newapp',
      };

  /// 결제 안내 앱 이름
  String get paymentAppName => switch (this) {
        ktx => '코레일톡',
        srt => 'SRT',
      };

  /// 안내사항 텍스트
  String get infoText => switch (this) {
        ktx =>
          '• 회원번호, 휴대폰 번호, 이메일 중 하나로 로그인합니다.\n'
              '• 로그인 정보는 기기에 암호화되어 안전하게 저장됩니다.\n'
              '• 세션 만료 시 자동으로 재로그인됩니다.',
        srt =>
          '• 회원번호, 휴대폰 번호, 이메일 중 하나로 로그인합니다.\n'
              '• 로그인 정보는 기기에 암호화되어 안전하게 저장됩니다.\n'
              '• 세션 만료 시 자동으로 재로그인됩니다.',
      };

  /// 저장소 키 이름용 접두사
  String get storagePrefix => switch (this) {
        ktx => 'korail',
        srt => 'srt',
      };
}
