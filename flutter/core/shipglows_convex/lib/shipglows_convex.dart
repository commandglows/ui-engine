/// Convex HTTP client for native ShipGlows Flutter apps (Android, Windows).
///
/// Apps use Convex instead of Firestore. This package calls the deployment's
/// HTTP API (`/api/query`, `/api/mutation`, `/api/action`) with a bearer
/// token. There is no realtime subscription, no Convex SDK and no codegen.
///
/// - [ConvexHttpClient]: `query`, `mutation`, `action`, `uploadBytes`, `close`.
/// - [ConvexException]: every failure, with a stable `code`.
/// - [convexMillisToDateTime] and [dateTimeToConvexMillis]: timestamps as
///   epoch milliseconds.
library;

export 'src/convex_exception.dart';
export 'src/convex_http_client.dart';
export 'src/convex_time.dart';
