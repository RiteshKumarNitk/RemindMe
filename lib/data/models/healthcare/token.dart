import 'json_utils.dart';

/// How a doctor takes bookings, exactly as the backend's `BookingMode`.
enum BookingMode {
  scheduled('SCHEDULED'),
  sameDayToken('SAME_DAY_TOKEN'),
  both('BOTH');

  const BookingMode(this.apiValue);

  final String apiValue;

  /// Unknown/missing values fall back to [scheduled] — the backend default, and
  /// the behaviour every doctor had before tokens existed.
  static BookingMode fromApi(Object? value) {
    final raw = asString(value)?.toUpperCase();
    for (final mode in BookingMode.values) {
      if (mode.apiValue == raw) return mode;
    }
    return BookingMode.scheduled;
  }

  bool get offersTokens => this == sameDayToken || this == both;
  bool get offersSlots => this == scheduled || this == both;
}

/// A doctor's same-day token window for *today*, computed by the server in the
/// clinic's timezone (`GET /api/public/doctors/:id/token-window`).
///
/// The app never decides on its own whether booking is open — not from the
/// device clock and not from the device timezone. It shows what this says,
/// and the booking endpoint re-checks the same computation.
class TokenWindow {
  const TokenWindow({
    required this.status,
    required this.bookable,
    required this.date,
    required this.timezone,
    required this.opensAt,
    required this.closesAt,
    required this.queueStartAt,
    this.reason,
    this.errorCode,
  });

  /// `OPEN`, `NOT_YET_OPEN`, `CLOSED` or `UNAVAILABLE`.
  final String status;
  final bool bookable;

  /// Clinic-local day, `YYYY-MM-DD`.
  final String date;
  final String timezone;

  /// Clinic-local wall times, `HH:MM`.
  final String opensAt;
  final String closesAt;
  final String queueStartAt;

  /// The server's own sentence for why booking is refused.
  final String? reason;
  final String? errorCode;

  bool get isNotYetOpen => status == 'NOT_YET_OPEN';
  bool get isLimitReached => errorCode == 'TOKEN_LIMIT_REACHED';
  bool get isUnavailable => status == 'UNAVAILABLE';

  factory TokenWindow.fromJson(Map<String, dynamic> json) {
    return TokenWindow(
      status: asStringOr(json['status'], 'UNAVAILABLE'),
      bookable: asBool(json['bookable']) ?? false,
      date: asStringOr(json['date']),
      timezone: asStringOr(json['timezone'], 'UTC'),
      opensAt: asStringOr(json['opensAt']),
      closesAt: asStringOr(json['closesAt']),
      queueStartAt: asStringOr(json['queueStartAt']),
      reason: asString(json['reason']),
      errorCode: asString(json['errorCode']),
    );
  }
}

/// The result of taking a token (`POST /api/patient/appointments/token`).
class TokenBooking {
  const TokenBooking({
    required this.appointmentId,
    required this.tokenNumber,
    required this.reused,
    required this.queueDate,
    required this.queueStartAt,
    this.doctorName,
  });

  final String appointmentId;
  final int tokenNumber;

  /// True when the patient already had a token today and got it back instead
  /// of a second one.
  final bool reused;
  final String queueDate;
  final String queueStartAt;
  final String? doctorName;

  factory TokenBooking.fromJson(Map<String, dynamic> json) {
    return TokenBooking(
      appointmentId: asStringOr(json['appointmentId']),
      tokenNumber: asInt(json['tokenNumber']) ?? 0,
      reused: asBool(json['reused']) ?? false,
      queueDate: asStringOr(json['queueDate']),
      queueStartAt: asStringOr(json['queueStartAt']),
      doctorName: asString(json['doctorName']),
    );
  }
}

/// A patient's live token status (`GET /api/patient/token-status`) — the same
/// queue rows reception and the doctor see. Deliberately has no ETA: the
/// backend does not estimate consultation times, so neither does the app.
class TokenStatus {
  const TokenStatus({
    required this.appointmentId,
    required this.tokenNumber,
    required this.state,
    required this.ahead,
    required this.queueDate,
    required this.queueStartAt,
    required this.advice,
    required this.adviceTone,
    this.nowServingToken,
    this.doctorName,
    this.appointmentStatus = 'WAITING',
  });

  final String appointmentId;
  final int tokenNumber;

  /// The appointment's own status. Authoritative over [state]: a cancelled
  /// token's queue entry is parked as SKIPPED.
  final String appointmentStatus;

  /// Queue state: WAITING, CALLED, HOLD, SKIPPED, IN_CONSULTATION, COMPLETED, NO_SHOW.
  final String state;

  /// People still ahead in the WAITING line, counted by the server. 0 when not waiting.
  final int ahead;
  final int? nowServingToken;
  final String queueDate;
  final String queueStartAt;

  /// Server-written next step ("Please go to the consultation room.").
  final String advice;

  /// WAIT, ACT_NOW, SEE_RECEPTION, DONE or PROBLEM.
  final String adviceTone;
  final String? doctorName;

  bool get isWaiting => state == 'WAITING';

  bool get isWithdrawn =>
      appointmentStatus == 'CANCELLED' || appointmentStatus == 'RESCHEDULED';

  /// Still moving — worth polling. Never for a closed appointment.
  bool get isLive =>
      !isWithdrawn &&
      appointmentStatus != 'NO_SHOW' &&
      appointmentStatus != 'COMPLETED' &&
      const {
        'WAITING',
        'CALLED',
        'HOLD',
        'SKIPPED',
        'IN_CONSULTATION',
      }.contains(state);

  factory TokenStatus.fromJson(Map<String, dynamic> json) {
    return TokenStatus(
      appointmentId: asStringOr(json['appointmentId']),
      tokenNumber: asInt(json['tokenNumber']) ?? 0,
      state: asStringOr(json['state'], 'WAITING'),
      ahead: asInt(json['ahead']) ?? 0,
      nowServingToken: asInt(json['nowServingToken']),
      queueDate: asStringOr(json['queueDate']),
      queueStartAt: asStringOr(json['queueStartAt']),
      advice: asStringOr(json['advice']),
      adviceTone: asStringOr(json['adviceTone'], 'WAIT'),
      doctorName: asString(json['doctorName']),
      appointmentStatus: asStringOr(json['appointmentStatus'], 'WAITING'),
    );
  }
}
