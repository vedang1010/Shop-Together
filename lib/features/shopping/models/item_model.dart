class ItemModel {
  final String id;
  final String name;
  final int quantity;
  final bool addedToCart;
  final String addedBy;
  final String addedByName;
  final String notes;
  final bool isUrgent;

  ItemModel({
    required this.id,
    required this.name,
    required this.quantity,
    required this.addedToCart,
    required this.addedBy,
    required this.addedByName,
    required this.notes,
    required this.isUrgent,
  });

  factory ItemModel.fromFirestore(String id, Map<String, dynamic> data) {
    return ItemModel(
      id: id,
      name: data['name'] ?? '',
      quantity: data['quantity'] ?? 1,
      addedToCart: data['addedToCart'] ?? false,
      addedBy: data['addedBy'] ?? '',
      addedByName: data['addedByName'] ?? '',
      notes: data['notes'] ?? '',
      isUrgent: data['isUrgent'] ?? false,
    );
  }
}
