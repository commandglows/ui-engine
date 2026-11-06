import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import 'clerk_auth_exception.dart';

/// Opens the authorization URL and returns the full callback URL.
abstract interface class ClerkBrowser {
  Future<String> authenticate({
    required Uri url,
    required String callbackScheme,
  });
}

/// Seconds the desktop loopback listener stays open. The plugin default is
/// 5 minutes, too short for Clerk's e-mail code flow.
const _desktopLoopbackTimeoutSeconds = 900;

/// The system browser: a Custom Tab on Android; on desktop the default
/// browser with a loopback listener (no embedded webview, per RFC 8252).
class SystemClerkBrowser implements ClerkBrowser {
  const SystemClerkBrowser();

  @override
  Future<String> authenticate({
    required Uri url,
    required String callbackScheme,
  }) async {
    try {
      return await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: callbackScheme,
        options: const FlutterWebAuth2Options(
          useWebview: false,
          timeout: _desktopLoopbackTimeoutSeconds,
        ),
      );
    } on PlatformException catch (error) {
      if (error.code == 'CANCELED') {
        throw const ClerkAuthException('canceled', 'Sign-in closed.');
      }
      throw ClerkAuthException('browser', error.message ?? error.code);
    } on Exception catch (error) {
      // For example the desktop loopback port is already in use.
      throw ClerkAuthException('browser', error.runtimeType.toString());
    } on ArgumentError catch (error) {
      throw ClerkAuthException('browser', error.runtimeType.toString());
    }
  }
}
