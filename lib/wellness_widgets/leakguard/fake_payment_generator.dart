import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:femn/customization/colors.dart'; 
import 'package:google_fonts/google_fonts.dart';

// ==========================================
// SCREEN 1: THE INPUT FORM
// ==========================================
class FakePaymentForm extends StatefulWidget {
  @override
  _FakePaymentFormState createState() => _FakePaymentFormState();
}

class _FakePaymentFormState extends State<FakePaymentForm> {
  // Controllers
  final _amountController = TextEditingController();
  final _currencyController = TextEditingController(text: "₦"); // New Currency Input
  final _recipientNameController = TextEditingController();
  final _recipientAccountController = TextEditingController();
  final _senderNameController = TextEditingController(); 
  final _senderBankController = TextEditingController(text: "MONIE POINT"); // Default to match screenshot example
  
  // Defaults
  String _selectedRecipientBank = "OPay";
  String _status = "Successful"; // Changed default to "Successful" to match image
  DateTime _transactionDate = DateTime.now();

  // Bank Options
  final List<String> _banks = [
    "OPay", "PalmPay", "Access Bank", "GTBank", "Zenith Bank", "UBA", 
    "Kuda", "First Bank", "Fidelity Bank", "Monie Point"
  ];

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
        title: Text("Decoy Generator", style: TextStyle(color: AppColors.textHigh)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             // Privacy Warning
             Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Feather.eye_off, color: Colors.orange, size: 16),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Tip: Use 'Pending' status to stall. It implies network issues.",
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Currency"),
                      _buildInput(_currencyController, "₦"),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       _buildLabel("Decoy Amount"),
                       _buildInput(_amountController, "e.g. 7,000", isNumber: true),
                    ],
                  ),
                ),
              ],
            ),

            _buildLabel("Receiver Name (The Extortionist)"),
            _buildInput(_recipientNameController, "e.g. PRECIOUS EKE THANKGOD"),

            _buildLabel("Receiver Account Number"),
            _buildInput(_recipientAccountController, "e.g. 913 207 2555", isNumber: true),

            _buildLabel("Receiver Bank"),
            _buildDropdown(),

            Divider(color: AppColors.elevation, height: 40),

            _buildLabel("Your Name (Sender Name)"),
            _buildInput(_senderNameController, "e.g. OLUWAFERANMI FIYINFOLU"),

            _buildLabel("Sender Bank Name"),
            _buildInput(_senderBankController, "e.g. MONIE POINT"),

            SizedBox(height: 20),
            
            _buildLabel("Transaction Status"),
            Row(
              children: [
                _buildStatusChip("Successful", Colors.green),
                SizedBox(width: 10),
                _buildStatusChip("Pending", Colors.orange), 
              ],
            ),

            SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00C853), // OPay Green
                  padding: EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  if (_amountController.text.isEmpty) return;

                  // Generate Random IDs (Longer to match screenshot)
                  String refId = "260108${Random().nextInt(999999)}${Random().nextInt(999999)}${Random().nextInt(999999)}";
                  String sessionId = "090405260108${Random().nextInt(99999999)}${Random().nextInt(99999999)}";
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OPayReceiptScreen(
                        amount: _amountController.text,
                        currency: _currencyController.text,
                        recipientName: _recipientNameController.text,
                        recipientAccount: _recipientAccountController.text,
                        recipientBank: _selectedRecipientBank,
                        senderName: _senderNameController.text.isEmpty ? "User" : _senderNameController.text,
                        senderBank: _senderBankController.text,
                        status: _status,
                        date: _transactionDate,
                        refId: refId,
                        sessionId: sessionId,
                      ),
                    ),
                  );
                },
                child: Text(
                  "Generate Receipt", 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 12),
      child: Text(text, style: TextStyle(color: AppColors.textMedium, fontSize: 13)),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: AppColors.textHigh),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textDisabled),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRecipientBank,
          dropdownColor: AppColors.surface,
          isExpanded: true,
          items: _banks.map((bank) {
            return DropdownMenuItem(
              value: bank,
              child: Text(bank, style: TextStyle(color: AppColors.textHigh)),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedRecipientBank = val!),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    bool isSelected = _status == label;
    return GestureDetector(
      onTap: () => setState(() => _status = label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? color : AppColors.textDisabled),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textDisabled,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SCREEN 2: THE OPAY REPLICA (Renderer)
// ==========================================
class OPayReceiptScreen extends StatefulWidget {
  final String amount;
  final String currency;
  final String recipientName;
  final String recipientAccount;
  final String recipientBank;
  final String senderName;
  final String senderBank;
  final String status;
  final DateTime date;
  final String refId;
  final String sessionId;

  const OPayReceiptScreen({
    Key? key,
    required this.amount,
    required this.currency,
    required this.recipientName,
    required this.recipientAccount,
    required this.recipientBank,
    required this.senderName,
    required this.senderBank,
    required this.status,
    required this.date,
    required this.refId,
    required this.sessionId,
  }) : super(key: key);

  @override
  State<OPayReceiptScreen> createState() => _OPayReceiptScreenState();
}

class _OPayReceiptScreenState extends State<OPayReceiptScreen> {
  
  @override
  void initState() {
    super.initState();
    // Trigger the SnackBar immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Feather.camera, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text("Screenshot this NOW!")),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 10),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Exact Colors from Screenshot
    final opayGreen = Color(0xFF00BFA5); // Slightly tealish green
    final opayLogoGreen = Color(0xFF00C853);
    final opayLogoPurple = Color(0xFF1B0F6B); 
    final labelGrey = Color(0xFF9E9E9E);
    final textDark = Colors.black.withOpacity(0.85);

    // Format currency manually to insert the user's custom symbol
    String formattedAmount = "${widget.currency}${widget.amount}";

    return Scaffold(
      backgroundColor: Colors.white, // White background for the whole page
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Feather.chevron_left, color: Colors.grey, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Share Receipt", 
          style: TextStyle(color: textDark, fontSize: 18, fontWeight: FontWeight.normal)
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
          child: Container(
            // This container acts as the "paper"
            decoration: BoxDecoration(
              color: Colors.white,
              // Optional: Add shadow if you want it to look like a card, 
              // but the screenshot looks flat/clean.
            ),
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                
                // 1. HEADER (Logo + Title)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // OPay Logo Construction
                    Row(
                      children: [
                        // The Logo Icon (Green broken circle)
                         Stack(
                           alignment: Alignment.center,
                           children: [
                             Container(
                               width: 28, height: 28,
                               decoration: BoxDecoration(
                                 shape: BoxShape.circle,
                                 border: Border.all(color: opayLogoGreen, width: 4),
                               ),
                             ),
                             // White cut to make it look like a 'C' or 'O'
                             Positioned(
                               right: -2,
                               child: Container(color: Colors.white, width: 8, height: 10)
                              )
                           ],
                         ),
                        SizedBox(width: 4),
                        // The 'Pay' Text
                        Text(
                          "Pay",
                          style: TextStyle(
                            color: opayLogoPurple,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ],
                    ),
                    
                    Text(
                      "Transaction Receipt",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 40),

                // 2. AMOUNT & STATUS
                Text(
                  formattedAmount,
                  style: TextStyle(
                    color: opayGreen,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  widget.status, // "Successful"
                  style: TextStyle(
                    color: Color(0xFF424242), // Dark grey/black for status
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  DateFormat('MMM dd, yyyy HH:mm:ss').format(widget.date),
                  style: TextStyle(color: labelGrey, fontSize: 11),
                ),

                SizedBox(height: 20),
                Divider(thickness: 0.5, color: Colors.grey[300]),
                SizedBox(height: 20),

                // 3. DETAILS BLOCK
                // The screenshot uses a specific layout: Left Label, Right Value (Right aligned)
                
                _buildRecipientDetailRow(
                  "Recipient Details", 
                  widget.recipientName.toUpperCase(), 
                  "${widget.recipientBank} | ${widget.recipientAccount}",
                  textDark, labelGrey
                ),
                SizedBox(height: 20),
                
                _buildRecipientDetailRow(
                  "Sender Details", 
                  widget.senderName.toUpperCase(), 
                  "${widget.senderBank} | 553****951", // Masked sender number like screenshot
                  textDark, labelGrey
                ),
                SizedBox(height: 20),

                _buildSimpleRow("Transaction Type", "Bank Deposit", textDark, labelGrey),
                SizedBox(height: 20),

                _buildSimpleRow("Transaction No.", widget.refId, textDark, labelGrey),
                SizedBox(height: 20),
                
                _buildSimpleRow("Session ID", widget.sessionId, textDark, labelGrey),

                SizedBox(height: 50),

                // 4. FOOTER (Exact Text)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text(
                    "Enjoy a better life with OPay. Get free transfers, withdrawals, bill payments, instant loans, and good annual interest on your savings. OPay is licensed by the Central Bank of Nigeria and insured by the NDIC.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.caveat( // Handwriting style font
                      color: labelGrey,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ),
                SizedBox(height: 40),
                
                // Bottom Pattern (Optional representation of receipt tear)
                Row(
                  children: List.generate(30, (index) => Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                    ),
                  )),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Row for "Transaction Type", "Ref", "Session"
  Widget _buildSimpleRow(String label, String value, Color dark, Color grey) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: TextStyle(color: grey, fontSize: 13))
        ),
        Expanded(
          flex: 3,
          child: Text(
            value, 
            textAlign: TextAlign.right,
            style: TextStyle(color: dark, fontSize: 13, fontWeight: FontWeight.normal),
          ),
        ),
      ],
    );
  }

  // Row for Recipient/Sender (Two lines for value)
  Widget _buildRecipientDetailRow(String label, String mainValue, String subValue, Color dark, Color grey) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: TextStyle(color: grey, fontSize: 13))
        ),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                mainValue, 
                textAlign: TextAlign.right,
                style: TextStyle(color: dark, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                subValue, 
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}