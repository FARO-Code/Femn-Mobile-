import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  Future<String?> signIn(String email, String password) async {
    return await _authService.signIn(email, password);
  }

  // Generic Sign Up (retained for backward compatibility or personal use)
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required DateTime dateOfBirth,
    required List<String> interests,
    String profileImage = '',
    String bio = '',
  }) async {
    return await _authService.signUp(
      email: email,
      password: password,
      username: username,
      fullName: fullName,
      dateOfBirth: dateOfBirth,
      interests: interests,
      profileImage: profileImage,
      bio: bio,
    );
  }

  // Personal Account Sign Up
  Future<String?> signUpPersonal({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required DateTime dateOfBirth,
    required List<String> interests,
    String profileImage = '',
    String bio = '',
  }) async {
    return await _authService.signUpPersonal(
      email: email,
      password: password,
      username: username,
      fullName: fullName,
      dateOfBirth: dateOfBirth,
      interests: interests,
      profileImage: profileImage,
      bio: bio,
    );
  }

  // Organization Account Sign Up
  // Organization Account Sign Up
  Future<String?> signUpOrganization({
    required String email,
    required String password,
    required String organizationName,
    required String category,
    required String country,
    required String missionStatement,
    String username = '',
    String profileImage = '', // CHANGED FROM logo to profileImage
    String website = '',
    String phone = '',
    String address = '',
    List<String> socialLinks = const [],
    String bio = '',
    List<String> areasOfFocus = const [],
  }) async {
    return await _authService.signUpOrganization(
      email: email,
      password: password,
      organizationName: organizationName,
      category: category,
      country: country,
      missionStatement: missionStatement,
      username: username,
      profileImage: profileImage, // CHANGED FROM logo to profileImage
      website: website,
      phone: phone,
      address: address,
      socialLinks: socialLinks,
      bio: bio,
      areasOfFocus: areasOfFocus,
    );
  }

  // Therapist Account Sign Up
  Future<String?> signUpTherapist({
    required String email,
    required String password,
    required String fullName,
    required String username,
    required List<String> specialization,
    required String experienceLevel,
    required String bio,
    required String availableHours,
    String profileImage = '',
    List<String> certifications = const [],
    List<String> languages = const [],
    String genderPreference = 'Open to all',
    String region = '',
  }) async {
    return await _authService.signUpTherapist(
      email: email,
      password: password,
      fullName: fullName,
      username: username,
      specialization: specialization,
      experienceLevel: experienceLevel,
      bio: bio,
      availableHours: availableHours,
      profileImage: profileImage,
      certifications: certifications,
      languages: languages,
      genderPreference: genderPreference,
      region: region,
    );
  }

  Future<void> signOut() async {
    await _authService.signOut();
    notifyListeners();
  }
}