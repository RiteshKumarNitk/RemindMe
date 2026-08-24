import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/data/models/medicine.dart';

void main() {
  group('Medicine model', () {
    test('stock tracking fields default to null', () {
      final med = Medicine(
        name: 'Aspirin',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(med.stockCount, isNull);
      expect(med.refillAt, isNull);
      expect(med.hasStockTracking, isFalse);
      expect(med.needsRefill, isFalse);
    });

    test('needsRefill returns true when stock <= refill threshold', () {
      final med = Medicine(
        name: 'Aspirin',
        stockCount: 3,
        refillAt: 5,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(med.hasStockTracking, isTrue);
      expect(med.needsRefill, isTrue);
    });

    test('needsRefill returns false when stock > refill threshold', () {
      final med = Medicine(
        name: 'Aspirin',
        stockCount: 10,
        refillAt: 5,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(med.needsRefill, isFalse);
    });

    test('copyWith preserves stock fields', () {
      final med = Medicine(
        name: 'Aspirin',
        stockCount: 20,
        refillAt: 5,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final updated = med.copyWith(name: 'Aspirin Plus');
      expect(updated.name, 'Aspirin Plus');
      expect(updated.stockCount, 20);
      expect(updated.refillAt, 5);
    });

    test('toMap includes stock fields', () {
      final med = Medicine(
        name: 'Aspirin',
        stockCount: 15,
        refillAt: 3,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final map = med.toMap();
      expect(map['stock_count'], 15);
      expect(map['refill_at'], 3);
    });

    test('fromMap reads stock fields', () {
      final map = {
        'name': 'Aspirin',
        'dosage': '',
        'dosage_unit': '',
        'notes': '',
        'food_instruction': 'none',
        'frequency': 'daily',
        'selected_days': '',
        'once_date': null,
        'active': 1,
        'stock_count': 12,
        'refill_at': 4,
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      };
      final med = Medicine.fromMap(map);
      expect(med.stockCount, 12);
      expect(med.refillAt, 4);
    });
  });
}
