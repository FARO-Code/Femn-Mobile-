import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:femn/customization/colors.dart'; 
import 'package:femn/wellness_widgets/leakguard/negotiation_data.dart';
import 'package:femn/wellness_widgets/leakguard/fake_payment_generator.dart';

class NegotiationPlaybookScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDeep,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Feather.arrow_left, color: AppColors.textHigh),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Negotiation Playbook", style: TextStyle(color: AppColors.textHigh)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. THE GOLDEN RULES CARD
          _buildGoldenRulesCard(),

          SizedBox(height: 10),

          // Section Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Text(
                  "WHAT IS HAPPENING NOW?",
                  style: TextStyle(
                    color: AppColors.textMedium,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // 2. SCENARIO LIST
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 20),
              itemCount: NegotiationData.scenarios.length,
              itemBuilder: (context, index) {
                return _buildScenarioTile(context, NegotiationData.scenarios[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoldenRulesCard() {
    return Container(
      margin: EdgeInsets.all(20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Feather.alert_octagon, color: Colors.redAccent, size: 20),
              SizedBox(width: 10),
              Text(
                "THE GOLDEN RULES",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...NegotiationData.goldenRules.map((rule) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("• ", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    rule,
                    style: TextStyle(color: AppColors.textHigh, fontSize: 14),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildScenarioTile(BuildContext context, PlaybookScenario scenario) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: () => _showScenarioDetails(context, scenario),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.elevation),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scenario.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(scenario.icon, color: scenario.color, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.trigger,
                      style: TextStyle(
                        color: AppColors.textHigh,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Use: ${scenario.title}",
                      style: TextStyle(color: scenario.color, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Icon(Feather.chevron_right, color: AppColors.textDisabled),
            ],
          ),
        ),
      ),
    );
  }

  // 3. BOTTOM SHEET DETAIL VIEW
  void _showScenarioDetails(BuildContext context, PlaybookScenario scenario) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textDisabled,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 24),
              
              // Title
              Row(
                children: [
                  Icon(scenario.icon, color: scenario.color),
                  SizedBox(width: 10),
                  Text(
                    scenario.title,
                    style: TextStyle(
                      color: AppColors.textHigh,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // THE SCRIPT (The Hero of the screen)
              Text("COPY & PASTE THIS:", style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDeep,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scenario.color.withOpacity(0.5)),
                ),
                child: SelectableText(
                  scenario.script,
                  style: TextStyle(
                    color: AppColors.textHigh,
                    fontSize: 18,
                    fontFamily: 'Courier', // Monospace font looks more "script-like"
                  ),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scenario.color,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: Icon(Feather.copy, color: Colors.white),
                      label: Text("Copy Text", style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: scenario.script));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Script copied to clipboard")),
                        );
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),
              
              // The Logic (Why this works)
              Text("WHY THIS WORKS:", style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
              SizedBox(height: 8),
              Text(
                scenario.logic,
                style: TextStyle(color: AppColors.textHigh, height: 1.5),
              ),

              Spacer(),
              
              // Optional: Fake Payment Link
              if (scenario.showFakePaymentOption)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primaryLavender),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: Icon(Feather.credit_card, color: AppColors.primaryLavender),
                    label: Text("Generate Fake Receipt", style: TextStyle(color: AppColors.primaryLavender)),
                    onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => FakePaymentForm()),
  );
},
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
