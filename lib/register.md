1. System Architecture Overview

Data Privacy: All sensitive user data (evidence, screenshots, chat logs) must be encrypted at rest (AES-256) on the user's device before being synced to the cloud.

Offline Capability: Crisis features (Panic Button, Negotiation Playbook) must function 100% offline.

State Management: The app must persist the "Crisis State" (active threat vs. peacetime) to alter the UI layout dynamically.

2. Detailed Functional Requirements (By Feature)

Phase 1: BEFORE (Prevention & Deterrence)

1. Social Media "Airlock" Preparation

Functionality: A guided audit to restrict public visibility on external platforms.

Input: User selects target platform (Instagram, Facebook, LinkedIn, TikTok).

System Process:

The app invokes Deep Links (URL Schemes) to navigate directly to specific settings pages on the target apps (e.g., twitter://settings/privacy). Note: Third-party apps cannot change these settings via API; they must guide the user.

State Tracking: A boolean flag is_airlocked_instagram toggles to TRUE upon user confirmation.

Output: Deep link navigation; Visual progress bar (0% to 100% Secure).

Ease of Flow: One-tap navigation. The user should not have to hunt for settings menus manually.

2. The "Deepfake" Defense Strategy

Functionality: Generates a strategic PR statement denying authenticity of leaks.

Input:

User Selection: Relationship to attacker (Ex, Stranger, Hacker).

Platform: Where the leak might happen (Group chat, Public post).

System Process:

Logic Engine: Selects from a JSON library of pre-written templates based on input variables.

Variable Injection: Inserts User Name, Date, and specific denial phrases.

Output: Copy-pasteable text block.

Format: Plain Text (UTF-8).

Connection: Output can be saved to Evidence Locker as a "Planned Response."

Phase 2: DURING (Crisis Management)

3. The "Panic Button" (Total Social Lockdown)

Functionality: Rapid guidance to deactivate accounts and anonymize profiles.

Input: Single tap on "SOS / Panic" widget.

System Process:

UI Override: App enters "High Contrast Mode" (Dark background, large text).

Asset Replacement: Provides a downloadable "Generic Avatar" (grey silhouette) to replace user profile pics.

Clipboard Action: Auto-copies a generic "Taking a social media break" status message.

Output: Sequential Deep Links to "Deactivate Account" pages for FB/IG/X.

Ease of Flow: Linear Wizard (Step 1 -> Step 2). No skipping allowed to ensure safety.

4. The Crisis Negotiation Playbook

Functionality: Interactive Decision Tree for communicating with the attacker.

Input: User selects the latest message type from attacker (e.g., "They asked for money," "They sent the photo," "They are threatening family").

System Process:

Logic: If Input == "Money Demand" THEN Show "Stall Tactic Script".

Logic: If Input == "Threat to send to Mom" THEN Show "Grey Rock Script".

Output: A specific, psychologist-vetted script displayed in large text.

Format: String (Text).

Ease of Flow: Chat-like interface. The user feels like they are chatting with a bot, but they are selecting options.

5. Fake Payment Interface

Functionality: Generates a realistic-looking "Transaction Successful" or "Processing" receipt.

Input:

Currency (NGN, USD, BTC).

Amount.

Bank Name / Wallet Address (Optional).

System Process:

Rendering Engine: HTML-to-Image or Canvas rendering. Overlays input text onto a high-res receipt template.

Randomization: Generates a random 12-digit "Transaction Ref ID" to look authentic.

Output: High-quality PNG/JPG image saved to the system gallery.

Functionality Note: Must include subtle "Pending" status to justify why the money hasn't arrived yet (buying time).

6. Automated Cease & Desist Generator

Functionality: Creates a legal PDF.

Input:

Attacker Name (or Handle).

Attacker Phone/Email (if known).

Jurisdiction (User selects "Nigeria" -> Loads Cybercrimes Act 2015; "USA" -> Loads federal statutes).

System Process:

PDF Generation: Maps inputs to a rigorous legal template.

Watermarking: Adds "LEGAL NOTICE" header.

Output: PDF File (Downloadable/Shareable).

Connection: File is automatically backed up to the Evidence Locker.

7. The Evidence Locker (Tamper-Proof Logging)

Functionality: Secure storage for proofs.

Input: Media Picker (Images, Videos), Microphone (Voice Notes), Text Input (Paste chat logs).

System Process:

hashing: Generate SHA-256 hash of every file upon import (to prove data integrity/non-tampering in court).

Timestamping: Append Unix timestamp + Geolocation metadata.

Encryption: Encrypt file using user's PIN/Biometrics (AES-256).

Cloud Sync: Background upload to secure bucket (Firebase Storage / AWS S3) with "WORM" policy (Write Once, Read Many) – prevents accidental deletion.

Output: A structured "Case File" (ZIP archive) containing all evidence + a manifest.json log.

Phase 3: AFTER (Recovery & Takedown)

8. StopNCII Integration (The Hash Generator)

Functionality: Privacy-preserving image reporting.

Input: User selects the compromising image from their local gallery.

System Process:

Local Processing: The app runs a hashing algorithm (MD5 or SHA-1 per StopNCII specs) locally on the device.

Constraint: The actual image MUST NOT leave the device. Only the hash string is sent.

API Call: POST hash to StopNCII.org API (or simulation if API is closed).

Output: "Case Reference Number" from StopNCII.

Ease of Flow: Must explicitly explain to the user: "We are NOT uploading your nude photo. We are scanning its digital fingerprint."

9. Legal Templating for "Revenge Porn"

Functionality: Generates restraining order applications.

Input: User details, Attacker details, Summary of incident (pulled from Evidence Locker if available).

System Process:

Template Logic: Fills placeholders in a "Motion for Restraining Order" document.

Clause Injection: Specifically injects "Digital Harassment" and "Non-Consensual Image Distribution" clauses.

Output: PDF Document ready for printing/filing.

Connection: Pulls metadata from Evidence Locker to fill the "Incident Date" fields automatically.

3. Non-Functional Requirements

A. User Experience (UX) & Flow

The "Panic Mode" Switch:

The interface must strip away all non-essential elements (colors, animations, unrelated menus) when Panic Mode is active.

Load Time: < 2 seconds. A victim cannot wait for a splash screen.

Cognitive Load:

Text must be Grade 6 reading level. No complex legal jargon in the instructional steps (only in the final PDF output).

Buttons must be "Thumb Zone" friendly and colored semantically (Green = Safe/Action, Red = Stop/Danger).

B. Security & Data

Zero-Knowledge Storage: The app backend should not be able to view the contents of the Evidence Locker. Encryption keys should be stored in the device's Secure Enclave (Keychain/Keystore).

Disguise: The app icon and name in the OS settings should be camouflaged (e.g., "Calculator" or "System Tools") to prevent an abuser from spotting it if they check the phone.

C. Connections & Interdependencies

Evidence Locker <-> Cease & Desist: The Locker acts as the database for the Generator.

Panic Button <-> Airlock: If Airlock was completed in Phase 1, the Panic Button skips those steps in Phase 2, saving time.

Negotiation Playbook <-> Fake Payment: The Playbook script for "Stalling" should provide a direct button to "Generate Fake Receipt."





Phase 1: BEFORE (Prevention & Deterrence)

Goal: To harden the user's digital footprint and prepare a psychological defense strategy before a crisis occurs.

1. Social Media "Airlock" Preparation



The Feature: A tool that analyzes the user's social media privacy settings, identifying public friend lists and open profiles.

The Logic: Extortionists (especially exes) leverage follower lists to threaten victims (e.g., "I will send this to your mother/boss"). This prompts users to hide friend lists preemptively, removing the attacker's ammunition.

2. The "Deepfake" Defense (Plausible Deniability)



The Feature: An educational module or AI tool helping users construct a "Deepfake Defense" strategy.

The Logic: In the age of AI, claiming a leaked photo is a "deepfake" is a highly effective reputation saver. This prepares the user to publicly deny the authenticity of images, even if they are real, reducing the social stigma the extortionist relies on.

Phase 2: DURING (Crisis Management)

Goal: To stop the panic, secure evidence, stall the attacker, and shift the power dynamic.

3. The "Panic Button" (Total Social Lockdown)



The Feature: A single button guiding the user to temporarily deactivate or lock down main socials (Instagram, Facebook, LinkedIn) and change profile pictures to generic avatars.

The Logic: If the extortionist cannot find the user's accounts or message their friends/family immediately, their leverage drops. It buys critical time.

4. The Crisis Negotiation Playbook (Strategic Guidance)



The Feature: A tactical decision tree functioning as a strict "Do’s and Don’ts" dashboard to guide behavior.

The "Never" List:

The Payment Trap: Warnings that paying marks you as a "high-value target" and never stops the leak.

The Apology Paradox: Instructions never to beg or apologize, as this validates the attacker's power.

The Content Freeze: A reminder never to send "one last photo" to appease them.

The "Action" Options:

The "Grey Rock" Method: How to become uninteresting and unresponsive without blocking immediately (to avoid triggering rage).

The Stall Tactic: Guidance on buying time (e.g., "I need 24 hours to sell my phone for cash").

The "Silence" Check: Determining when it is safe to stop responding entirely (calling the bluff).

The Logic: Prevents emotional mistakes. Shifts the dynamic from "Victim vs. Monster" to "Target vs. Scammer."

5. Fake Payment Interface



The Feature: A generated image or link that looks like a transaction confirmation or a "pending" bank transfer.

The Logic: A sophisticated stalling tactic. It convinces the extortionist money is coming, buying the victim hours or days to contact authorities or lock down their life.

6. Automated Cease & Desist Generator



The Feature: A form where the user inputs the extortionist's details (if known, like an ex). The app generates a formally worded legal PDF citing local statutes (e.g., Cybercrimes Act) and penalties for non-consensual pornography.

The Logic: When an ex-partner realizes this is a legal matter with jail time attached, rather than personal drama, they often back down immediately.

7. The Evidence Locker (Tamper-Proof Logging)



The Feature: A secure, cloud-backed vault to import screenshots, screen recordings, and voice notes before the user deletes them from their phone out of panic.

The Logic: Creates a timestamped chain of custody. Ensures the user has an organized legal packet for the police, even if they panic-delete the original chats.

Phase 3: AFTER (Recovery & Takedown)

Goal: To remove content from the internet and secure legal protection.

8. StopNCII Integration (The Hash Generator)



The Feature: Integration with the StopNCII.org API. The user selects the original image on their phone (without uploading it). The app generates a "digital fingerprint" (hash) and sends it to major platforms (Meta, TikTok, Reddit).

The Logic: If the extortionist tries to upload that image, the platforms recognize the hash and block the upload automatically.

9. Legal Templating for "Revenge Porn"



The Feature: Specific templates for filing restraining orders that explicitly include digital harassment clauses.

The Logic: Standard restraining orders often fail to mention digital leaks. This ensures the legal paperwork specifically bars the ex from releasing data or contacting the victim digitally.