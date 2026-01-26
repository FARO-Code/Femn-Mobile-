import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:femn/customization/colors.dart'; 

class CeaseDesistScreen extends StatefulWidget {
  @override
  _CeaseDesistScreenState createState() => _CeaseDesistScreenState();
}

class _CeaseDesistScreenState extends State<CeaseDesistScreen> {
  // Form Controllers
  final _perpNameController = TextEditingController();
  final _perpDetailsController = TextEditingController(); // Email/Phone/Handle
  final _perpAddressController = TextEditingController(); // Optional
  final _userNameController = TextEditingController();
  final _userLocationController = TextEditingController(); // City, Country
  final _userEmailController = TextEditingController();
  
  String _sendMethod = "Email"; // Default
  final List<String> _sendMethods = ["Email", "WhatsApp", "DM (Direct Message)", "Certified Mail"];

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
        title: Text("Legal Notice Generator", style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 30),

            // SECTION 1: THE PERPETRATOR
            Text("THE PERPETRATOR (TARGET)", style: TextStyle(color: AppColors.textMedium, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            SizedBox(height: 15),
            
            _buildTextField(_perpNameController, "Their Name", Feather.user_x, "e.g. John Doe (or 'Unknown')"),
            SizedBox(height: 15),
            _buildTextField(_perpDetailsController, "Their Contact (Phone/Email/Handle)", Feather.at_sign, "e.g. +234... or @username"),
            SizedBox(height: 15),
            _buildTextField(_perpAddressController, "Their Address (Optional)", Feather.map_pin, "Leave blank if unknown"),

            SizedBox(height: 30),

            // SECTION 2: YOUR DETAILS
            Text("YOUR DETAILS (THE SENDER)", style: TextStyle(color: AppColors.textMedium, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            SizedBox(height: 15),
            
            _buildTextField(_userNameController, "Your Full Name", Feather.user, "Required for legal validity"),
            SizedBox(height: 15),
            _buildTextField(_userLocationController, "Your City, Country", Feather.map, "e.g. Lagos, Nigeria"),
            SizedBox(height: 15),
            _buildTextField(_userEmailController, "Secure Email Address", Feather.mail, "Use a secondary email for safety"),

            SizedBox(height: 30),

            // SECTION 3: DELIVERY METHOD
            Text("METHOD OF DELIVERY", style: TextStyle(color: AppColors.textMedium, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            SizedBox(height: 15),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.elevation),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sendMethod,
                  dropdownColor: AppColors.surface,
                  isExpanded: true,
                  icon: Icon(Feather.chevron_down, color: AppColors.textHigh),
                  items: _sendMethods.map((m) {
                    return DropdownMenuItem(value: m, child: Text(m, style: TextStyle(color: AppColors.textHigh)));
                  }).toList(),
                  onChanged: (val) => setState(() => _sendMethod = val!),
                ),
              ),
            ),

            SizedBox(height: 40),

            // ACTION BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Feather.printer, color: Colors.white),
                label: Text("Generate Formal PDF"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLavender,
                  padding: EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _generatePDF(context),
              ),
            ),
            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevation),
      ),
      child: Row(
        children: [
          Icon(Feather.briefcase, color: AppColors.primaryLavender, size: 30),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Formal Legal Notice",
                  style: TextStyle(color: AppColors.textHigh, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 5),
                Text(
                  "Generates a 'Cease & Desist' document using standard court typography (Serif fonts, Justified text) to maximize intimidation.",
                  style: TextStyle(color: AppColors.textMedium, fontSize: 12),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, String hint) {
    return TextField(
      controller: controller,
      style: TextStyle(color: AppColors.textHigh),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textMedium),
        prefixIcon: Icon(icon, color: AppColors.textDisabled, size: 18),
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textDisabled),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  // ==========================================
  // PDF GENERATION LOGIC
  // ==========================================
  Future<void> _generatePDF(BuildContext context) async {
    final pdf = pw.Document();
    
    // 1. Load Professional Serif Fonts (Tinos is a free Google Font alternative to Times New Roman)
    final fontRegular = await PdfGoogleFonts.tinosRegular();
    final fontBold = await PdfGoogleFonts.tinosBold();
    final fontItalic = await PdfGoogleFonts.tinosItalic();

    // 2. Prepare Data
    final today = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    final caseRef = "CASE-${DateTime.now().year}-${Random().nextInt(99999)}"; // Random Case ID
    
    final perpName = _perpNameController.text.isEmpty ? "John/Jane Doe" : _perpNameController.text;
    final perpContact = _perpDetailsController.text;
    final perpAddress = _perpAddressController.text;
    
    final userName = _userNameController.text.isEmpty ? "[Your Legal Name]" : _userNameController.text;
    final userLoc = _userLocationController.text.isEmpty ? "[Your City, Country]" : _userLocationController.text;
    final userEmail = _userEmailController.text.isEmpty ? "[Your Email]" : _userEmailController.text;

    // 3. Build Page
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold, italic: fontItalic),
          margin: const pw.EdgeInsets.all(72), // 1 inch margins
        ),
        build: (pw.Context context) {
          return [
            // --- HEADER ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("URGENT LEGAL NOTICE", style: pw.TextStyle(color: PdfColors.red, fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text("VIA: ${_sendMethod.toUpperCase()}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ]
            ),
            pw.SizedBox(height: 20),

            // --- PARTIES BLOCK ---
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(width: 2))),
              padding: pw.EdgeInsets.only(left: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("FROM:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(userName),
                  pw.Text(userLoc),
                  pw.Text(userEmail),
                  pw.SizedBox(height: 10),
                  pw.Text("TO:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(perpName),
                  if (perpContact.isNotEmpty) pw.Text(perpContact),
                  if (perpAddress.isNotEmpty) pw.Text(perpAddress),
                  pw.SizedBox(height: 10),
                  pw.Text("DATE: $today"),
                  pw.Text("FILE REF: $caseRef", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ]
              )
            ),
            pw.SizedBox(height: 25),

            // --- SUBJECT LINE ---
            pw.Center(
              child: pw.Text(
                "RE: FORMAL DEMAND TO CEASE AND DESIST: EXTORTION, HARASSMENT, AND THREAT OF NON-CONSENSUAL IMAGE ABUSE",
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
              )
            ),
            pw.SizedBox(height: 20),

            // --- INTRODUCTION ---
            pw.Text("To $perpName:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text(
              "This letter constitutes formal legal notice demanding that you immediately CEASE AND DESIST all unlawful actions against me, specifically the possession, threat of distribution, and actual distribution of private, sexually explicit, or intimate images/videos (\"Private Media\") depicting me.",
              textAlign: pw.TextAlign.justify,
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              "Your threats to release this Private Media unless specific demands are met constitute Criminal Extortion and Blackmail.",
              textAlign: pw.TextAlign.justify,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)
            ),
            pw.SizedBox(height: 20),

            // --- SECTION 1: LEGAL VIOLATIONS ---
            pw.Text("LEGAL VIOLATIONS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, decoration: pw.TextDecoration.underline)),
            pw.SizedBox(height: 10),
            pw.Text(
              "Be advised that your conduct violates criminal and civil laws recognized in international jurisdictions, including but not limited to:",
              textAlign: pw.TextAlign.justify
            ),
            pw.SizedBox(height: 10),
            _buildNumberedItem("1", "Criminal Extortion & Blackmail", "The act of demanding money, goods, or acts in exchange for withholding the release of private information is a felony in the United States, United Kingdom, European Union, Nigeria, and most sovereign nations."),
            _buildNumberedItem("2", "Non-Consensual Pornography (Revenge Porn)", "The distribution of private sexual images without consent is a specific criminal offense in many jurisdictions punishable by imprisonment and registration as a sex offender."),
            _buildNumberedItem("3", "Invasion of Privacy", "Your actions give rise to civil liability, for which I reserve the right to sue for significant monetary damages."),
            _buildNumberedItem("4", "Copyright Infringement", "As the creator/subject of these images, I own the copyright. Unauthorized reproduction is a violation of international copyright treaties and the DMCA."),
            
            pw.SizedBox(height: 20),

            // --- SECTION 2: DEMANDS ---
            pw.Text("DEMANDS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, decoration: pw.TextDecoration.underline)),
            pw.SizedBox(height: 10),
            pw.Text("I hereby demand that you immediately:", textAlign: pw.TextAlign.justify),
            pw.SizedBox(height: 10),
            _buildNumberedItem("1", null, "PERMANENTLY DELETE all copies of the Private Media from all devices, cloud storage, hard drives, and communication platforms in your control."),
            _buildNumberedItem("2", null, "CEASE all communication with me, my family, my employer, and my acquaintances."),
            _buildNumberedItem("3", null, "ABSTAIN from sharing, uploading, or showing the Private Media to any third party or online platform."),
            
            pw.SizedBox(height: 20),

            // --- SECTION 3: SPOLIATION WARNING (BOXED) ---
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              padding: pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("NOTICE TO PRESERVE EVIDENCE (SPOLIATION WARNING)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    "This is a formal notice to preserve all evidence related to this matter. You are legally required to retain all text messages, call logs, emails, metadata, and files related to your communications with me. Deleting or altering this evidence acts as an admission of guilt and may lead to additional criminal charges for Spoliation of Evidence or Obstruction of Justice.",
                    textAlign: pw.TextAlign.justify,
                    style: pw.TextStyle(fontSize: 10)
                  ),
                ]
              )
            ),

            pw.SizedBox(height: 20),

            // --- SECTION 4: NEXT STEPS ---
            pw.Text("NEXT STEPS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, decoration: pw.TextDecoration.underline)),
            pw.SizedBox(height: 10),
            pw.Text("If you fail to comply with these demands immediately, I will:", textAlign: pw.TextAlign.justify),
            pw.SizedBox(height: 10),
            _buildNumberedItem("1", null, "File formal criminal complaints with local law enforcement and the Interpol Cybercrime Directorate."),
            _buildNumberedItem("2", null, "File \"Takedown Notices\" with all relevant Internet Service Providers (ISPs) and social media platforms, alerting them to your illegal use of their services, which will result in the termination of your accounts."),
            _buildNumberedItem("3", null, "Retain legal counsel to pursue maximum civil damages and criminal prosecution to the fullest extent of the law in your governing jurisdiction."),

            pw.SizedBox(height: 30),
            pw.Center(child: pw.Text("GOVERN YOURSELF ACCORDINGLY.", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 50),

            // --- SIGNATURE ---
            pw.Divider(),
            pw.Text(userName),
            pw.Text("Victim / Claimant"),
          ];
        }
      )
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // Helper for Numbered Lists in PDF
  pw.Widget _buildNumberedItem(String number, String? title, String text) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 20, child: pw.Text("$number.", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(
            child: pw.RichText(
              textAlign: pw.TextAlign.justify,
              text: pw.TextSpan(
                children: [
                  if (title != null) 
                    pw.TextSpan(text: "$title: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.TextSpan(text: text),
                ]
              )
            )
          )
        ]
      )
    );
  }
}
