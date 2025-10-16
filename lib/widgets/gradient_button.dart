import 'package:flutter/material.dart';
import '../theme/palette.dart';

class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;

  const GradientButton({
    super.key,
    required this.child,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    this.radius  = const BorderRadius.all(Radius.circular(16)),
  });

  factory GradientButton.icon({
    Key? key,
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    return GradientButton(
      key: key,
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: kWhite),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(
            color: kWhite, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: disabled
                ? [kGradA.withOpacity(.45), kGradB.withOpacity(.45)]
                : [kGradA, kGradB],
          ),
          borderRadius: radius,
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Padding(padding: padding, child: Center(child: child)),
        ),
      ),
    );
  }
}