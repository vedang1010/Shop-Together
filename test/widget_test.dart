import 'package:flutter_test/flutter_test.dart';
import 'package:shoptogether/features/shopping/models/item_model.dart';

void main() {
  test('creates item model from Firestore data', () {
    final item = ItemModel.fromFirestore('item-1', {
      'name': 'Milk',
      'quantity': 2,
      'addedToCart': false,
      'addedBy': 'user-1',
      'addedByName': 'Asha',
    });

    expect(item.id, 'item-1');
    expect(item.name, 'Milk');
    expect(item.quantity, 2);
    expect(item.addedToCart, isFalse);
    expect(item.addedBy, 'user-1');
    expect(item.addedByName, 'Asha');
  });
}
