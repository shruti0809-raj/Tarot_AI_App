import 'package:flutter/material.dart';
import 'payment_sheet.dart';

class PaymentPopupWidget extends StatelessWidget {
  final VoidCallback onClose;
  final void Function(String selectedPlanId)? onPlanSelected;

  const PaymentPopupWidget({
    super.key,
    required this.onClose,
    this.onPlanSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PaymentSheet(
      onClose: onClose,
      onPlanSelected: onPlanSelected,
    );
  }
}
