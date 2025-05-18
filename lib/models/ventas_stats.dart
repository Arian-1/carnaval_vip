class VentasStats {
  // Sillas
  final int seatsSold;
  final int seatsPaid;
  final int seatsPending;
  final double seatsSubtotalPaid;
  final double seatsSubtotalPending;
  final double seatsTotal;

  // Lotes
  final int lotsSold;
  final int lotsPaid;
  final int lotsPending;
  final double lotsSubtotalPaid;
  final double lotsSubtotalPending;
  final double lotsTotal;

  // Proveedores
  final double providersExpense;

  VentasStats({
    required this.seatsSold,
    required this.seatsPaid,
    required this.seatsPending,
    required this.seatsSubtotalPaid,
    required this.seatsSubtotalPending,
    required this.seatsTotal,
    required this.lotsSold,
    required this.lotsPaid,
    required this.lotsPending,
    required this.lotsSubtotalPaid,
    required this.lotsSubtotalPending,
    required this.lotsTotal,
    required this.providersExpense,
  });

  double get totalGross => seatsTotal + lotsTotal;
  double get totalNet   => totalGross - providersExpense;
}
