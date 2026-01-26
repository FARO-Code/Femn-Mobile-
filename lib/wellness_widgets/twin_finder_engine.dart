import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class TwinFinderEngine {
  List<Map<String, dynamic>> _allQuestions = [];
  
  // Session State
  List<Map<String, dynamic>> _sessionQuestions = [];
  List<int?> _userAnswers = []; 
  
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;
  int get totalQuestions => _sessionQuestions.length;

  Future<void> loadQuestions() async {
    try {
      final String response = await rootBundle.loadString('assets/data/twin_finder_questions.json');
      final List<dynamic> data = jsonDecode(response);
      _allQuestions = data.cast<Map<String, dynamic>>();
      _allQuestions.shuffle(); // Randomize order
    } catch (e) {
      print("Error loading Twin Finder questions: $e");
    }
  }

  void startSession({int limit = 25}) {
    _currentIndex = 0;
    if (limit > _allQuestions.length) limit = _allQuestions.length;
    _sessionQuestions = _allQuestions.take(limit).toList();
    _userAnswers = List.filled(limit, null);
  }

  Map<String, dynamic>? get currentQuestion {
    if (_currentIndex < _sessionQuestions.length) {
      return _sessionQuestions[_currentIndex];
    }
    return null;
  }

  bool get isFinished => _currentIndex >= _sessionQuestions.length;
  double get progress => _currentIndex / _sessionQuestions.length;
  bool get canGoBack => _currentIndex > 0;
  bool get canGoForward => _currentIndex < _sessionQuestions.length - 1;

  // returns true if test is finished
  bool nextQuestion() {
    if (_currentIndex < _sessionQuestions.length - 1) {
      _currentIndex++;
      return false;
    }
    return true; // We are at the end
  }

  void previousQuestion() {
    if (_currentIndex > 0) {
      _currentIndex--;
    }
  }

  void setAnswer(int value) {
    if (_currentIndex < _userAnswers.length) {
      _userAnswers[_currentIndex] = value;
    }
  }

  int? get currentAnswer {
      if (_currentIndex < _userAnswers.length) {
      return _userAnswers[_currentIndex];
    }
    return null;
  }

  Map<String, dynamic> calculateResult() {
    // 1. Tally Scores based on _userAnswers
    Map<String, int> scores = {
      "Ni": 0, "Ne": 0, "Si": 0, "Se": 0,
      "Ti": 0, "Te": 0, "Fi": 0, "Fe": 0
    };

    for (int i = 0; i < _sessionQuestions.length; i++) {
        final ans = _userAnswers[i];
        if (ans == null) continue; // Should not happen in completed test
        
        final q = _sessionQuestions[i];
        final optionA = q['optionA'];
        final optionB = q['optionB'];
        
        // value 0: Strong A, 1: Slight A, 2: Slight B, 3: Strong B
        if (ans == 0 || ans == 1) {
             _addScores(scores, optionA['functions'], ans == 0 ? 2 : 1);
        } else {
             _addScores(scores, optionB['functions'], ans == 3 ? 2 : 1);
        }
    }

    // 2. Identify Dominant Function
    var sortedFunctions = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final dom = sortedFunctions[0].key;
    final aux = _findAuxiliary(dom, sortedFunctions);
    
    final archetype = _deriveArchetype(dom, aux);
    
    return {
      "archetype": archetype,
      "title": _getArchetypeTitle(archetype),
      "description": _getArchetypeDescription(archetype),
      "color": _getArchetypeColor(archetype),
      "scores": scores.toString() 
    };
  }

  void _addScores(Map<String, int> scores, Map<String, dynamic>? impact, int weight) {
    if (impact == null) return;
    impact.forEach((func, points) {
      if (scores.containsKey(func)) {
        scores[func] = scores[func]! + (points as int) * weight;
      }
    });
  }

  String _findAuxiliary(String dom, List<MapEntry<String, int>> sorted) {
    bool isDomIntroverted = dom.endsWith('i');
    bool isDomJudging = dom.startsWith('T') || dom.startsWith('F');

    for (var entry in sorted) {
      if (entry.key == dom) continue;
      
      bool isAuxIntroverted = entry.key.endsWith('i');
      bool isAuxJudging = entry.key.startsWith('T') || entry.key.startsWith('F');

      if (isDomIntroverted == isAuxIntroverted) continue;
      if (isDomJudging == isAuxJudging) continue;

      return entry.key;
    }
    
    return sorted[1].key; 
  }

  String _deriveArchetype(String dom, String aux) {
    if (dom == "Ni" && (aux == "Te" || aux == "Ti")) return "INTJ"; 
    if (dom == "Ni" && (aux == "Fe" || aux == "Fi")) return "INFJ";
    if (dom == "Ne" && (aux == "Ti" || aux == "Te")) return "ENTP";
    if (dom == "Ne" && (aux == "Fi" || aux == "Fe")) return "ENFP";
    
    if (dom == "Si" && (aux == "Te" || aux == "Ti")) return "ISTJ";
    if (dom == "Si" && (aux == "Fe" || aux == "Fi")) return "ISFJ";
    if (dom == "Se" && (aux == "Ti" || aux == "Te")) return "ESTP";
    if (dom == "Se" && (aux == "Fi" || aux == "Fe")) return "ESFP";

    if (dom == "Ti" && (aux == "Ne" || aux == "Ni")) return "INTP";
    if (dom == "Ti" && (aux == "Se" || aux == "Si")) return "ISTP";
    if (dom == "Fi" && (aux == "Ne" || aux == "Ni")) return "INFP";
    if (dom == "Fi" && (aux == "Se" || aux == "Si")) return "ISFP";

    if (dom == "Te" && (aux == "Ni" || aux == "Ne")) return "ENTJ";
    if (dom == "Te" && (aux == "Si" || aux == "Se")) return "ESTJ";
    if (dom == "Fe" && (aux == "Ni" || aux == "Ne")) return "ENFJ";
    if (dom == "Fe" && (aux == "Si" || aux == "Se")) return "ESFJ";

    return "INTP"; // Default Fallback
  }

  String _getArchetypeTitle(String code) {
    const titles = {
      "INTJ": "The Architect", "INTP": "The Logician",
      "ENTJ": "The Commander", "ENTP": "The Debater",
      "INFJ": "The Advocate", "INFP": "The Mediator",
      "ENFJ": "The Protagonist", "ENFP": "The Campaigner",
      "ISTJ": "The Logistician", "ISFJ": "The Defender",
      "ESTJ": "The Executive", "ESFJ": "The Consul",
      "ISTP": "The Virtuoso", "ISFP": "The Adventurer",
      "ESTP": "The Entrepreneur", "ESFP": "The Entertainer",
    };
    return titles[code] ?? "The Enigma";
  }

  String _getArchetypeColor(String code) {
    // NT Types (Purple) #805da1
    if (['INTJ', 'INTP', 'ENTJ', 'ENTP'].contains(code)) return "0xFF805da1";
    // NF Types (Green) #429a6d
    if (['INFJ', 'INFP', 'ENFJ', 'ENFP'].contains(code)) return "0xFF429a6d";
    // SJ Types (Teal/Blue) #3ba3b5
    if (['ISTJ', 'ISFJ', 'ESTJ', 'ESFJ'].contains(code)) return "0xFF3ba3b5";
    // SP Types (Yellow) #e1ad3d
    if (['ISTP', 'ISFP', 'ESTP', 'ESFP'].contains(code)) return "0xFFe1ad3d";
    
    return "0xFF805da1"; // Default purple
  }

  String _getArchetypeDescription(String code) {
    const descs = {
      "INTJ": "You possess a mind that is constantly simulating the future, treating reality like a chessboard where every move must be calculated ten steps in advance. You don’t just want to understand systems; you want to dismantle them and rebuild them better, ruthless in your pursuit of efficiency and logic. Small talk feels like a painful waste of bandwidth because you’d rather be discussing the heat death of the universe or a strategy to optimize global supply chains. You often feel like the only adult in a room full of people acting on impulse, and while you aren't devoid of emotion, you view it as a variable that needs to be managed rather than a guide to follow.\n\nPeople often mistake your quiet observation for arrogance, but really, you’re just vetting your ideas to ensure they are bulletproof before you speak. You value competence above all else, and your love language is essentially someone listening to your plan without interrupting.",
      "INTP": "You live inside a complex web of theories and \"what ifs,\" where the actual answer is often less interesting than the process of finding it. Your brain is a browser with 300 tabs open, and you are constantly cross-referencing ideas to see if they hold up to logical scrutiny. You have a habit of debating not to be difficult, but to test the structural integrity of an argument; if a fact doesn't click into your internal framework of truth, you simply cannot accept it. Routine is your kryptonite, and you’ve likely started a dozen brilliant projects this year that you abandoned the moment you figured out how they would work.\n\nYou are often detached, viewing social interactions as anthropological experiments rather than emotional exchanges. You crave precise language, and nothing frustrates you more than someone who says \"you know what I mean\" when you definitely do not.",
      "ENTJ": "You walk into a room and immediately spot the inefficiencies, feeling a physical itch to take charge and correct them. For you, relaxation is just another form of goal-setting, and you struggle to respect anyone who lacks a five-year plan or the drive to execute it. You aren’t necessarily trying to be bossy; you just genuinely believe that if everyone did what you said, the world would run perfectly. You process emotions through the lens of productivity—sadness or stress are problems to be solved with an action plan rather than feelings to be wallowed in.\n\nYour intensity can be intimidating, but it comes from a place of wanting everyone to reach their potential. You are the person who pushes the \"impossible\" button just to see if it breaks, because you know that with enough willpower and strategy, nothing actually is.",
      "ENTP": "You are a mental gymnast who delights in taking the opposing view just to see if the other person can defend their stance. You don't argue to be mean; you argue because friction creates sparks, and sparks light up the truth (or at least, a more interesting conversation). You are allergic to tradition and \"because I said so\" reasoning, preferring to dismantle rules to see why they were put there in the first place. Your mind moves faster than your mouth, often leading you to jump between three different topics in a single sentence, leaving others dizzy while you’re just getting warmed up.\n\nYou thrive in chaos and get bored the second a problem is solved. You are the person who invents a new way to do the dishes not because it's necessary, but because the old way was boring, and \"good enough\" is a phrase that isn't in your vocabulary.",
      "INFJ": "You feel like you are walking around with an X-ray vision that sees right into people’s souls, picking up on their hidden motives and unhealed traumas often before they do. You are a walking paradox: an extroverted introvert who loves humanity but finds humans exhausting. You have a rich, vivid inner world that feels more real than the physical one, and you are constantly searching for the deeper meaning behind every interaction. You are often the \"therapist\" friend, capable of absorbing everyone’s emotions, which leaves you needing to disappear for three days just to remember which feelings are actually yours.\n\nYou are driven by a quiet, intense conviction to change the world, not through force, but through shifting perspectives. You don't just want to be understood; you want to be known, but you rarely let anyone see the full depth of the galaxy inside your head.",
      "INFP": "You navigate the world through a lens of deep, unshakeable personal values, constantly checking if your actions align with your authentic self. You are a dreamer who often feels like you were born in the wrong century, longing for a reality that is kinder, more magical, and more poetic than the one you live in. You tend to romanticize everything—from your morning coffee to a stranger’s glance—and while you seem gentle and adaptable, you become immovable rock when a core value is threatened. You are prone to carrying the weight of the world’s sadness, taking things personally because you care so intensely.\n\nYou have a secret inner world of stories and scenarios that you rarely share because you’re afraid they won’t translate. You don't want a normal life; you want a life that feels like a novel, full of meaning, beauty, and emotional resonance.",
      "ENFJ": "You are the person who instinctively knows the emotional temperature of a room the second you walk in and immediately adjusts your behavior to bring harmony. You have a compulsion to help others realize their potential, often seeing a version of them that they can't even see themselves yet. You are a natural leader, not because you demand power, but because people naturally gravitate toward your warmth and charisma. However, you often neglect your own needs, feeling guilty if you aren't being useful or if someone around you is unhappy, taking it as a personal failure.\n\nYou are intense in your connections and crave deep, authentic communication, often feeling drained by surface-level interactions. You are the cheerleader who will drive three hours to support a friend, secretly hoping someone would do the same for you without you having to ask.",
      "ENFP": "You are a human firework, bursting with enthusiasm and the belief that everything is connected to everything else. You vacillate between being the life of the party and falling into a deep, existential introspection about the meaning of life. You collect people like souvenirs, fascinated by their stories and potential, and you possess a superpower for making anyone feel like the most interesting person in the world. Routine feels like a slow death to you; you need novelty, passion, and the freedom to chase your latest obsession, even if you drop it next week.\n\nDespite your bubbly exterior, you have a surprisingly dark and complex inner core that craves emotional intensity. You are constantly looking for the \"magic\" in everyday life, terrified of settling for a career or relationship that doesn't set your soul on fire.",
      "ISTJ": "You are the backbone of civilization, the person who actually reads the terms and conditions and keeps the receipt \"just in case.\" You find comfort in facts, traditions, and clear hierarchies because they provide a stable framework in a chaotic world. You don't need praise; you just need people to do their jobs correctly and show up on time, because reliability is your love language. You often feel like the only person who understands that rules exist to prevent disaster, and you get deeply frustrated by people who wing it or let their emotions dictate their decisions.\n\nYou show you care by fixing the leaky faucet or handling the taxes, not by writing poetry. You are steady, grounded, and fiercely loyal, and while you may not be the loudest in the room, you are usually the one keeping the roof from collapsing.",
      "ISFJ": "You are the quiet observer who remembers that your coworker is allergic to peanuts and that your friend’s mother has surgery next Tuesday. You navigate the world with a deep sense of duty and a desire to protect the peace, often working tirelessly behind the scenes without asking for credit. You have a filing cabinet in your brain storing every detail of your past interactions, which makes you incredibly sentimental but also prone to holding onto grudges or embarrassments from years ago. You struggle to say \"no\" because you terrified of letting people down or causing conflict.\n\nYou crave stability and struggle when plans change last minute, preferring a life that is predictable and harmonious. You are the one who makes a house a home, creating a safe, warm space for everyone else while secretly hoping someone will notice how hard you work.",
      "ESTJ": "You believe that if there isn't a procedure for it, you should write one, because chaos is just a failure of management. You value hard work, honesty, and competence, and you have zero patience for excuses or laziness. You are often the person organizing the group trip or taking charge of the project because you know that if you don't, it won't get done right. You are direct and objective, which can sometimes hurt people's feelings, but you genuinely believe that telling the truth is the most respectful thing you can do.\n\nYou respect tradition and authority, provided that authority is competent, and you act as a pillar of your community. You don't guess—you know, and you move through life with a decisiveness that makes others feel safer just by being around you.",
      "ESFJ": "You are the social glue of any group, the person who ensures everyone has a drink and feels included in the conversation. You define yourself by your relationships and your ability to provide for others, taking your responsibilities to your family and friends very seriously. You are highly sensitive to criticism and discord; if someone is mad at you, it feels like the end of the world, and you will work overtime to restore harmony. You love gossip, not out of malice, but because you are genuinely fascinated by the details of people's lives and social dynamics.\n\nYou thrive on clear expectations and social validation, loving nothing more than being appreciated for your efforts. You are the first to send a thank-you card and the last to leave the party, ensuring that every social obligation is met with grace and warmth.",
      "ISTP": "You are the quiet problem-solver who observes the world with a cool, detached curiosity, waiting for the moment things break so you can fix them. You learn by doing, preferring to get your hands dirty with the mechanics of reality rather than reading the manual. You have a limited social battery and a low tolerance for drama; you prefer relationships where you can sit in comfortable silence or do an activity together rather than talk about feelings. You are unpredictable, prone to sudden bursts of energy or impulsive adventures, and you hate feeling controlled or tied down.\n\nYou have a \"live and let live\" attitude, rarely judging others but expecting the same freedom in return. You are a master of crisis management, staying completely calm when everyone else is panicking, simply because you are too busy analyzing the variables to be afraid.",
      "ISFP": "You live your life as a canvas, constantly expressing your unique perspective through your style, your art, or your choices. You are deeply in touch with your senses, savoring the texture, sound, and color of the present moment more than any other type. You are gentle and unassuming, often underestimated by others, but you possess a core of steel when it comes to your personal freedom and values. You don't want to lead or control others; you just want the space to be yourself without interference.\n\nYou are prone to taking things at your own pace, which can look like laziness to others, but is actually you waiting for the \"vibe\" to be right. You are a free spirit who finds beauty in the tragic and the mundane, always prioritizing how a decision feels over what makes logical sense.",
      "ESTP": "You are a creature of the immediate moment, moving faster than everyone else and scanning the room for the next opportunity or thrill. You don't worry about the future because you know that you can talk your way out of whatever trouble you land in. You are brutally pragmatic and observant, noticing the small physical cues others miss, which makes you excellent at reading people and navigating social hierarchies. You hate abstract theory; if you can't touch it, eat it, or spend it, you aren't interested.\n\nYou are the person who jumps off the cliff first and builds the parachute on the way down. You have a magnetic charm and a boldness that draws people in, largely because you make life feel like an action movie where you are the invincible star.",
      "ESFP": "You are a burst of solar energy, terrified of missing out on anything and determined to make every moment fun. You treat the world like a stage, and you are happiest when you are the center of attention, making people laugh or bringing the energy up. You are incredibly observant of how people are feeling and will drop everything to comfort a friend, often offering a distraction or an adventure rather than advice. You struggle with long-term planning and \"boring\" responsibilities, preferring to deal with consequences only when they are staring you in the face.\n\nYou are generous to a fault, often giving your time and money freely because you believe life is meant to be shared. You don't just want to exist; you want to sparkle, and you want everyone around you to feel the glow.",
    };
    return descs[code] ?? "A unique personality that defies categorization.";
  }
}
