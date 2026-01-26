import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:femn/hub_screens/post.dart'; // <--- IMPORT THIS

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription? _linkSubscription;

  void initDeepLinks(BuildContext context) {
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleLink(uri, context);
    });

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri, context);
    });
  }

  void _handleLink(Uri uri, BuildContext context) {
    print("Deep Link Received: $uri");
    
    if (uri.pathSegments.contains('post')) {
      String postId = uri.pathSegments.last;

      // FIX: Use MaterialPageRoute directly
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PostDetailScreen(
            postId: postId,
            userId: null, // This is now allowed because of Step 1!
          ),
        ),
      );
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
