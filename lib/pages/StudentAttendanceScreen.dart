// Platform-aware export
// Web: Use OTP + anti-cheating version
// Mobile: Use old simple version (no OTP, no tab monitoring)
export 'StudentAttendanceScreen_web.dart' if (dart.library.io) 'StudentAttendanceScreen_mobile.dart';
