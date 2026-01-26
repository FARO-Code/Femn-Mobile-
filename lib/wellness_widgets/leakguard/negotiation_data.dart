import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:femn/wellness_widgets/leakguard/negotiation_playbook.dart';
class PlaybookScenario {
  final String title;
  final String trigger; // "They said..."
  final String script;
  final String logic;
  final IconData icon;
  final Color color;
  final bool showFakePaymentOption;

  PlaybookScenario({
    required this.title,
    required this.trigger,
    required this.script,
    required this.logic,
    required this.icon,
    required this.color,
    this.showFakePaymentOption = false,
  });
}

class NegotiationData {
  // THE GOLDEN RULES (The "Never" List)
  static final List<String> goldenRules = [
    "NEVER Pay. It marks you as a target who will pay again.",
    "NEVER Apologize. It validates their power over you.",
    "NEVER Send 'One Last Photo'. It is a trap.",
  ];

  // THE SCRIPTS (The "Action" Options)
  static final List<PlaybookScenario> scenarios = [
    PlaybookScenario(
      title: " The Stall Tactic",
      trigger: "They demanded money immediately.",
      icon: Feather.clock,
      color: Colors.blueAccent,
      script: "I don't have that amount in my account. I need 24 hours to sell my phone/laptop to get the cash. Please wait.",
      logic: "Extortionists want speed. This script forces them to wait without saying 'No'. It buys you time to contact police or lock your accounts.",
      showFakePaymentOption: true,
    ),
    PlaybookScenario(
      title: "The Grey Rock",
      trigger: "They are insulting or threatening you.",
      icon: Feather.shield,
      color: Colors.grey,
      script: "I understand.",
      logic: "Boring responses kill their thrill. If you don't cry or beg, they lose the emotional 'high' of the attack.",
      showFakePaymentOption: false,
    ),
    PlaybookScenario(
      title: "The Broken Record",
      trigger: "They keep pressuring you to pay NOW.",
      icon: Feather.repeat,
      color: Colors.orangeAccent,
      script: "As I said, I am trying to get the money. Screaming at me won't make the bank open faster.",
      logic: "Repetition shows you are not panicked. You are sticking to the plan (The Stall).",
      showFakePaymentOption: true,
    ),
    PlaybookScenario(
      title: "The Bluff Call",
      trigger: "They threaten to send it to your family.",
      icon: Feather.users,
      color: Colors.redAccent,
      script: "(Do not reply. Go Silent.)",
      logic: "If they were going to do it, they would have done it. They want you to beg. Silence makes them wonder if you've already gone to the police.",
      showFakePaymentOption: false,
    ),
  ];
}
