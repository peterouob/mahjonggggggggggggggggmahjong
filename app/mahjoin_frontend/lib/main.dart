import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/config/app_env.dart';
import 'core/design/tokens.dart';
import 'core/feedback/global_notice_overlay.dart';
import 'core/network/ws_client.dart';
import 'core/router/router.dart';
import 'core/storage/session.dart';
import 'data/services/broadcast_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  enforceMockModeSafety();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Restore persisted session before the first frame.
  await Session.instance.restore();
  if (Session.instance.isLoggedIn) {
    WsClient.instance.connect(Session.instance.userId!);
    BroadcastService.instance.restore();
  }

  runApp(const MahJoinApp());
}

class MahJoinApp extends StatelessWidget {
  const MahJoinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MahJoin',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: AppRouter.router,
      builder: (context, child) =>
          GlobalNoticeOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}
