import 'package:uuid/uuid.dart';

import '../../database/daos/sale_dao.dart';
import '../../database/daos/till_session_dao.dart';
import '../../database/database.dart';
import '../../database/tables/till_tables.dart';

class TillAlreadyOpenException implements Exception {
  const TillAlreadyOpenException();

  @override
  String toString() =>
      'A till session is already open. Close it before opening a new one.';
}

class TillCloseResult {
  const TillCloseResult({
    required this.expectedCashKobo,
    required this.countedCashKobo,
    required this.varianceKobo,
  });

  final int expectedCashKobo;
  final int countedCashKobo;

  /// counted - expected. Negative means the drawer is short; positive means
  /// it's over.
  final int varianceKobo;
}

/// Opens/closes the single cash-drawer session a Nigerian till runs under a
/// shift. Only one till may be open at a time — this is a single-drawer
/// store model; multi-till/multi-branch is a Phase 5 concern.
class TillService {
  TillService(this._db)
      : _tillSessionDao = _db.tillSessionDao,
        _saleDao = _db.saleDao;

  final PosDatabase _db;
  final TillSessionDao _tillSessionDao;
  final SaleDao _saleDao;
  static const _uuid = Uuid();

  Future<TillSession> openTill({
    required String staffId,
    required int openingFloatKobo,
  }) async {
    if (openingFloatKobo < 0) {
      throw ArgumentError.value(
          openingFloatKobo, 'openingFloatKobo', 'must not be negative');
    }
    final existing = await _tillSessionDao.findOpen();
    if (existing != null) {
      throw const TillAlreadyOpenException();
    }
    final id = _uuid.v4();
    await _tillSessionDao.insertSession(TillSessionsCompanion.insert(
      id: id,
      staffId: staffId,
      openingFloatKobo: openingFloatKobo,
    ));
    return (await _tillSessionDao.findById(id))!;
  }

  /// Closes [tillSessionId], comparing the physically [countedCashKobo]
  /// against the expected drawer total (opening float + net cash tendered
  /// across every sale/refund posted under this session).
  Future<TillCloseResult> closeTill({
    required String tillSessionId,
    required int countedCashKobo,
  }) async {
    if (countedCashKobo < 0) {
      throw ArgumentError.value(
          countedCashKobo, 'countedCashKobo', 'must not be negative');
    }
    final session = await _tillSessionDao.findById(tillSessionId);
    if (session == null) {
      throw ArgumentError('Till session $tillSessionId not found');
    }
    if (session.status != TillSessionStatus.open) {
      throw StateError('Till session $tillSessionId is already closed');
    }

    late int expectedCashKobo;
    await _db.transaction(() async {
      final netCashMovement =
          await _saleDao.sumCashMovementForTillSession(tillSessionId);
      expectedCashKobo = session.openingFloatKobo + netCashMovement;

      await _tillSessionDao.closeSession(
        tillSessionId,
        expectedCashKobo: expectedCashKobo,
        countedCashKobo: countedCashKobo,
      );
    });

    return TillCloseResult(
      expectedCashKobo: expectedCashKobo,
      countedCashKobo: countedCashKobo,
      varianceKobo: countedCashKobo - expectedCashKobo,
    );
  }
}
