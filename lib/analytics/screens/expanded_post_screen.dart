import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import '../../customization/colors.dart';
import '../../hub_screens/post.dart';
import '../../widgets/femn_background.dart';

class ExpandedPostScreen extends StatelessWidget {
  final String postId;

  const ExpandedPostScreen({Key? key, required this.postId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.elevation.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Feather.arrow_left, color: AppColors.textHigh, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: FemnBackground(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(top: 80, bottom: 20),
          child: Column(
            children: [
              PostCardWithStream(postId: postId),
            ],
          ),
        ),
      ),
    );
  }
}
