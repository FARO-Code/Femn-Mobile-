import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'colors.dart';

class ResponsiveLayout {
  /// Returns the number of columns for staggered grids based on screen width.
  /// 
  /// - Mobile (< 800): 2 (Unified baseline)
  /// - Tablet/Larger (> 800): 3
  /// - Desktop/Even Larger (> 1200): 4
  static int getColumnCount(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width > 1200) {
      return 4;
    } else if (width > 800) {
      return 3;
    } else {
      // 2 is better for staggered mobile grids generally, 
      // but some screens had 3. To follow "Uniformity", 
      // we'll use 2 as the mobile baseline unless the USER prefers otherwise.
      // However, the USER's prompt says "larger screens should be 3, even larger 4".
      // This strongly suggests that 2 is the non-larger (standard) size.
      return 2;
    }
  }
}

class GridShimmerSkeleton extends StatelessWidget {
  final int itemCount;
  final double horizontalPadding;
  final double verticalPadding;

  const GridShimmerSkeleton({
    Key? key,
    this.itemCount = 8,
    this.horizontalPadding = 16.0,
    this.verticalPadding = 10.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
      child: MasonryGridView.count(
        crossAxisCount: ResponsiveLayout.getColumnCount(context),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemCount: itemCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return ShimmerItem(index: index);
        },
      ),
    );
  }
}

class SliverGridShimmerSkeleton extends StatelessWidget {
  final int itemCount;
  final double horizontalPadding;
  final double verticalPadding;

  const SliverGridShimmerSkeleton({
    Key? key,
    this.itemCount = 8,
    this.horizontalPadding = 16.0,
    this.verticalPadding = 10.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: ResponsiveLayout.getColumnCount(context),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childCount: itemCount,
        itemBuilder: (context, index) {
          return ShimmerItem(index: index);
        },
      ),
    );
  }
}

class ShimmerItem extends StatelessWidget {
  final int index;
  const ShimmerItem({Key? key, required this.index}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<double> randomHeights = [200, 280, 180, 240, 300, 190, 250, 220];

    return Shimmer.fromColors(
      baseColor: AppColors.elevation,
      highlightColor: AppColors.surface,
      child: Container(
        height: randomHeights[index % randomHeights.length],
        decoration: BoxDecoration(
          color: AppColors.elevation,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 10, width: 80, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(height: 8, width: double.infinity, color: Colors.white),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}


