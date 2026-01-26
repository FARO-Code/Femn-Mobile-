import 'dart:io';
import 'dart:typed_data';
import 'package:femn/customization/colors.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:femn/customization/layout.dart';

class CustomGalleryScreen extends StatefulWidget {
  @override
  _CustomGalleryScreenState createState() => _CustomGalleryScreenState();
}

class _CustomGalleryScreenState extends State<CustomGalleryScreen> {
  List<AssetEntity> _assets = [];
  bool _isLoading = true;
  int _selectedFilterIndex = 0; // 0: All, 1: Photos, 2: Videos

  @override
  void initState() {
    super.initState();
    _fetchAssets();
  }

  // Map index to RequestType
  RequestType _getMediaTypeForIndex(int index) {
    switch (index) {
      case 0: return RequestType.common; // All
      case 1: return RequestType.image;  // Photos
      case 2: return RequestType.video;  // Videos
      default: return RequestType.common;
    }
  }

Future<void> _fetchAssets({RequestType type = RequestType.common}) async {
    setState(() => _isLoading = true);

    // Request permission
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      
      // 1. Define the sort order: Creation Date, Descending (Newest first)
      final FilterOptionGroup filterOption = FilterOptionGroup(
        orders: [
          OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      );

      // 2. Pass 'filterOption' to getAssetPathList
      List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: type,
        filterOption: filterOption, 
      );

      if (albums.isNotEmpty) {
        // Since we sorted the query, the range 0-100 will now be the 100 MOST RECENT items.
        // You can increase 'end' to load more, or implement pagination.
        List<AssetEntity> media = await albums[0].getAssetListRange(start: 0, end: 100);
        
        setState(() {
          _assets = media;
          _isLoading = false;
        });
      } else {
        setState(() {
          _assets = [];
          _isLoading = false;
        });
      }
    } else {
      setState(() => _isLoading = false);
      PhotoManager.openSetting();
    }
  }

  void _onFilterChanged(int index) {
    if (_selectedFilterIndex != index) {
      setState(() {
        _selectedFilterIndex = index;
      });
      _fetchAssets(type: _getMediaTypeForIndex(index));
    }
  }

  Future<void> _selectAsset(AssetEntity asset) async {
    File? file = await asset.file;
    if (file != null) {
      Navigator.pop(context, file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomHeader(),
            _buildFilterPills(),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.primaryLavender))
                  : _assets.isEmpty
                      ? Center(child: Text("No media found", style: TextStyle(color: AppColors.textMedium)))
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: MasonryGridView.count(
                            crossAxisCount: ResponsiveLayout.getColumnCount(context), // Responsive columns
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            itemCount: _assets.length,
                            itemBuilder: (context, index) {
                              final asset = _assets[index];
                              return _buildMediaItem(asset);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Custom Header (Matches your PostDetailScreen style)
  Widget _buildCustomHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close Button
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.elevation,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              // Standardized to Feather.x
              icon: Icon(Feather.x, color: Colors.white, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          // Title
          Text(
            "Gallery",
            style: TextStyle(
              color: AppColors.textHigh,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),

          // Invisible spacer to balance the row
          SizedBox(width: 42),
        ],
      ),
    );
  }

  // 2. Filter Pills (Matches your FeedScreen style)
  Widget _buildFilterPills() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPill('All', 0),
          _buildPill('Photos', 1),
          _buildPill('Videos', 2),
        ],
      ),
    );
  }

  Widget _buildPill(String title, int index) {
    final bool isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () => _onFilterChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondaryTeal : AppColors.elevation,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.3 : 0.1),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 3),
            ),
          ],
          border: isSelected 
            ? Border.all(color: AppColors.secondaryTeal, width: 1)
            : Border.all(color: Colors.transparent),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14.0,
            color: isSelected ? AppColors.textOnSecondary : AppColors.textMedium,
          ),
        ),
      ),
    );
  }

  // 3. Staggered Grid Item
  Widget _buildMediaItem(AssetEntity asset) {
    // Calculate aspect ratio so the grid staggers correctly
    // Default to square 1.0 if dimensions are 0 for some reason
    double aspectRatio = (asset.width > 0 && asset.height > 0) 
        ? asset.width / asset.height 
        : 1.0;

    return GestureDetector(
      onTap: () => _selectAsset(asset),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              // Use AspectRatio to enforce the stagger height
              AspectRatio(
                aspectRatio: aspectRatio,
                child: FutureBuilder<Uint8List?>(
                  future: asset.thumbnailDataWithSize(ThumbnailSize(400, 400)), // Request decent quality thumbnail
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                      );
                    }
                    return Container(
                      color: AppColors.elevation,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2, 
                          color: AppColors.primaryLavender
                        )
                      ),
                    );
                  },
                ),
              ),
              
              // Video Indicator / Duration
              if (asset.type == AssetType.video)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Standardized to Feather.play
                        Icon(Feather.play, color: Colors.white, size: 10),
                        SizedBox(width: 4),
                        Text(
                          _formatDuration(asset.duration),
                          style: TextStyle(
                            color: Colors.white, 
                            fontSize: 10, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inMinutes}:$twoDigitSeconds";
  }
}
