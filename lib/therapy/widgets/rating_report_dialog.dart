import 'package:flutter/material.dart';
import 'package:femn/customization/colors.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import '../services/therapy_service.dart';

class RatingReportDialog extends StatefulWidget {
  final String therapistId;
  final String therapistName;
  final bool isReporting;

  RatingReportDialog({required this.therapistId, required this.therapistName, this.isReporting = false});

  @override
  _RatingReportDialogState createState() => _RatingReportDialogState();
}

class _RatingReportDialogState extends State<RatingReportDialog> {
  final TherapyService _therapyService = TherapyService();
  double _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.isReporting ? 'Report Abuse' : 'Rate Experience',
        style: TextStyle(color: AppColors.textHigh),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isReporting
                  ? 'Is ${widget.therapistName} doing fishy business? Let us know why.'
                  : 'How was your session with ${widget.therapistName}?',
              style: TextStyle(color: AppColors.textMedium, fontSize: 14),
            ),
            SizedBox(height: 20),
            if (!widget.isReporting) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      Feather.star,
                      color: index < _rating ? AppColors.accentMustard : AppColors.textDisabled.withOpacity(0.3),
                      size: 30,
                    ),
                    onPressed: () => setState(() => _rating = index + 1.0),
                  );
                }),
              ),
              SizedBox(height: 10),
            ],
            TextField(
              controller: _commentController,
              maxLines: 3,
              style: TextStyle(color: AppColors.textHigh),
              decoration: InputDecoration(
                hintText: widget.isReporting ? 'Reason for report...' : 'Leave a comment (optional)...',
                hintStyle: TextStyle(color: AppColors.textDisabled),
                filled: true,
                fillColor: AppColors.elevation,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: AppColors.textMedium)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isReporting ? AppColors.error : AppColors.primaryLavender,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.backgroundDeep))
              : Text(widget.isReporting ? 'Report' : 'Submit', style: TextStyle(color: AppColors.backgroundDeep)),
        ),
      ],
    );
  }

  void _handleSubmit() async {
    if (widget.isReporting && _commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please provide a reason.')));
      return;
    }

    setState(() => _isLoading = true);
    if (widget.isReporting) {
      await _therapyService.reportTherapist(widget.therapistId, _commentController.text);
    } else {
      await _therapyService.rateTherapist(widget.therapistId, _rating, _commentController.text);
    }
    setState(() => _isLoading = false);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.isReporting ? 'Report submitted.' : 'Thank you for your rating!')),
    );
  }
}
