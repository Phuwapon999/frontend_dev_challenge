import 'deal_model.dart';
import 'reservation_model.dart';

class CartItemModel {
  final DealModel deal;
  int quantity;
  String? reservationId;
  DateTime? expiresAt;

  /// Stock hold for this line item. The starter app does not reserve stock —
  /// see the "Reservations" feature task.
  ReservationModel? reservation;

  CartItemModel(
      {required this.deal,
      this.quantity = 1,
      this.reservation,
      this.reservationId,
      this.expiresAt});

  num get lineTotal => deal.price * quantity;
}
