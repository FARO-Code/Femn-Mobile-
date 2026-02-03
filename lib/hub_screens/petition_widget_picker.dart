import 'package:femn/customization/colors.dart';
import 'package:femn/widgets/femn_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:femn/circle/petitions.dart';
import 'package:femn/services/petition_widget_service.dart';

class PetitionWidgetPicker extends StatefulWidget {
  @override
  _PetitionWidgetPickerState createState() => _PetitionWidgetPickerState();
}

class _PetitionWidgetPickerState extends State<PetitionWidgetPicker> {
  bool _isLoading = true;
  List<Petition> _petitions = [];

  @override
  void initState() {
    super.initState();
    _loadPetitions();
  }

  Future<void> _loadPetitions() async {
    setState(() => _isLoading = true);
    final petitions = await PetitionWidgetService.getSignedPetitions();
    if (mounted) {
      setState(() {
        _petitions = petitions;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectPetition(Petition petition) async {
    await PetitionWidgetService.updateWidget(petition);
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Widget updated to track: ${petition.title}"),
        backgroundColor: AppColors.success,
      ),
    );
     // Optional: Wait a bit or just let user stay here? 
     // For now, we stay here so they can confirm it's done.
  }

  @override
  Widget build(BuildContext context) {
    return FemnBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            "Select Petition to Track",
            style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold),
          ),
          iconTheme: IconThemeData(color: AppColors.primaryLavender),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.primaryLavender))
            : _petitions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Feather.clipboard, size: 48, color: AppColors.textMedium),
                          SizedBox(height: 16),
                          Text(
                            "No Petitions Signed",
                            style: TextStyle(
                              color: AppColors.textHigh,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Sign a petition first to track its progress on your home screen.",
                            style: TextStyle(color: AppColors.textMedium),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _petitions.length,
                    itemBuilder: (context, index) {
                      final petition = _petitions[index];
                      return Card(
                        color: AppColors.surface,
                        margin: EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          title: Text(
                            petition.title,
                            style: TextStyle(
                              color: AppColors.textHigh,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: petition.progress,
                                backgroundColor: AppColors.elevation,
                                color: AppColors.primaryLavender,
                              ),
                              SizedBox(height: 4),
                              Text(
                                "${petition.currentSignatures} of ${petition.goal} signatures",
                                style: TextStyle(color: AppColors.textMedium, fontSize: 12),
                              ),
                            ],
                          ),
                          onTap: () => _selectPetition(petition),
                          trailing: Icon(Feather.check_circle, color: AppColors.secondaryTeal),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
