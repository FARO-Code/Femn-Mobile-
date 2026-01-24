import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:femn/customization/colors.dart';
import '../services/therapy_service.dart';
import '../models/therapy_models.dart';

class BookingFlowDialog extends StatefulWidget {
  final String therapistId;
  final String therapistName;

  BookingFlowDialog({required this.therapistId, required this.therapistName});

  @override
  _BookingFlowDialogState createState() => _BookingFlowDialogState();
}

class _BookingFlowDialogState extends State<BookingFlowDialog> {
  final TherapyService _therapyService = TherapyService();
  SessionType _selectedType = SessionType.oneDay;
  bool _isLoading = false;
  final TextEditingController _problemController = TextEditingController();

  @override
  void dispose() {
    _problemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enlist ${widget.therapistName}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textHigh),
          ),
          SizedBox(height: 8),
          Text(
            'Select your therapy journey type. You can have a quick rescue or a long-term companion.',
            style: TextStyle(color: AppColors.textMedium, fontSize: 14),
          ),
          SizedBox(height: 24),
          _buildOption(
            title: 'One-Day Rescue',
            subtitle: 'Perfect for casual advice or immediate situation relief.',
            type: SessionType.oneDay,
            icon: Feather.zap,
          ),
          SizedBox(height: 12),
          _buildOption(
            title: 'Multi-Day Journey',
            subtitle: 'For follow-ups and working through complex matters together.',
            type: SessionType.multiDay,
            icon: Feather.award,
          ),
          SizedBox(height: 24),
          Text(
            'What is the potential problem?',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh, fontSize: 14),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _problemController,
            maxLines: 3,
            style: TextStyle(color: AppColors.textHigh, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Describe your situation briefly...',
              hintStyle: TextStyle(color: AppColors.textDisabled),
              filled: true,
              fillColor: AppColors.elevation,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLavender,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: AppColors.backgroundDeep)
                  : Text('Confirm Booking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOption({required String title, required String subtitle, required SessionType type, required IconData icon}) {
    bool isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondaryTeal.withOpacity(0.1) : AppColors.elevation,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.secondaryTeal : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.secondaryTeal : AppColors.textDisabled, size: 30),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
                ],
              ),
            ),
            if (isSelected) Icon(Feather.check_circle, color: AppColors.secondaryTeal),
          ],
        ),
      ),
    );
  }

  void _handleBooking() async {
    if (_problemController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Please describe your problem briefly."),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() => _isLoading = true);
    final error = await _therapyService.bookTherapist(
      widget.therapistId, 
      _selectedType, 
      _problemController.text.trim()
    );
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error));
    } else {
      Navigator.pop(context);
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Journey Started', style: TextStyle(color: AppColors.textHigh)),
        content: Text('You have successfully booked ${widget.therapistName}. They will reach out to you soon.', style: TextStyle(color: AppColors.textMedium)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text('Awesome', style: TextStyle(color: AppColors.secondaryTeal))),
        ],
      ),
    );
  }
}
