import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyQuoteService {
  static const String appGroupId = 'group.femn_daily_quote'; // Optional, mainly for iOS
  static const String androidWidgetName = 'DailyQuoteWidgetProvider';

  static final List<Map<String, String>> _dailyQuotes = [
    {"quote": "Deeds, not words.", "author": "Emmeline Pankhurst"},
    {
      "quote": "Feminism is the radical notion that women are people.",
      "author": "Marie Shear",
    },
    {
      "quote": "Well-behaved women seldom make history.",
      "author": "Laurel Thatcher Ulrich",
    },
    {
      "quote":
          "If they don't give you a seat at the table, bring a folding chair.",
      "author": "Shirley Chisholm",
    },
    {
      "quote":
          "My silences had not protected me. Your silence will not protect you.",
      "author": "Audre Lorde",
    },
    {
      "quote": "Women belong in all places where decisions are being made.",
      "author": "Ruth Bader Ginsburg",
    },
    {
      "quote": "We cannot all succeed when half of us are held back.",
      "author": "Malala Yousafzai",
    },
    {
      "quote":
          "The most common way people give up their power is by thinking they don't have any.",
      "author": "Alice Walker",
    },
    {
      "quote":
          "I am not free while any woman is unfree, even when her shackles are very different from my own.",
      "author": "Audre Lorde",
    },
    {
      "quote": "No pride for some of us without liberation for all of us.",
      "author": "Marsha P. Johnson",
    },
  ];

  /// Returns today's quote based on the day of the year/month to ensure same quote for everyone on same day
  static Map<String, String> getTodaysQuote() {
    final DateTime now = DateTime.now();
    // Use day of year or just day of month cycling through list
    final int quoteIndex = now.day % _dailyQuotes.length;
    return _dailyQuotes[quoteIndex];
  }

  /// Updates the Home Screen Widget with today's quote
  static Future<void> updateWidget() async {
    final quoteData = getTodaysQuote();
    final quote = quoteData['quote'] ?? '';
    final author = quoteData['author'] ?? '';

    try {
      // Save data to SharedPreferences (used by home_widget)
      await HomeWidget.saveWidgetData<String>('quote_text', quote);
      await HomeWidget.saveWidgetData<String>('quote_author', author);
      
      // Update the widget
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
      );
      print("Widget updated with: $quote");
    } catch (e) {
      print("Error updating widget: $e");
    }
  }
}
