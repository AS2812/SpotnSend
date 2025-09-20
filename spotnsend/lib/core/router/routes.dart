class RoutePaths {
  static const String login = '/login';
  static const String signupStep1 = '/signup/step-1';
  static const String signupStep2 = '/signup/step-2';
  static const String signupStep3 = '/signup/step-3';
  static const String home = '/home';
  static const String homeMap = '/home/map';
  static const String homeReport = '/home/report';
  static const String homeNotifications = '/home/notifications';
  static const String homeAccount = '/home/account';
  static const String homeSettings = '/home/settings';
}

enum AppRoute {
  login(RoutePaths.login),
  signupStep1(RoutePaths.signupStep1),
  signupStep2(RoutePaths.signupStep2),
  signupStep3(RoutePaths.signupStep3),
  home(RoutePaths.home),
  homeMap(RoutePaths.homeMap),
  homeReport(RoutePaths.homeReport),
  homeNotifications(RoutePaths.homeNotifications),
  homeAccount(RoutePaths.homeAccount),
  homeSettings(RoutePaths.homeSettings);

  const AppRoute(this.path);
  final String path;
}
