import 'package:flutter/material.dart';
import 'package:femn/customization/colors.dart';

class FemnBackground extends StatelessWidget {
  final Widget child;
  final double opacity;
  final String imagePath;

  const FemnBackground({
    Key? key,
    required this.child,
    this.opacity = 0.9,
    this.imagePath = 'assets/femn_state.png',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundDeep,
        image: DecorationImage(
          image: AssetImage(imagePath),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(opacity),
            BlendMode.darken,
          ),
        ),
      ),
      child: child,
    );
  }
}
