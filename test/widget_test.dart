import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowboard/main.dart';
import 'package:flowboard/providers/auth_provider.dart';
import 'package:flowboard/providers/profile_provider.dart';
import 'package:flowboard/screens/onboarding_screen.dart';
import 'package:flowboard/screens/sign_in_screen.dart';
import 'package:flowboard/screens/splash_screen.dart';
import 'package:flowboard/widgets/empty_states.dart';
import 'package:flowboard/widgets/flowboard_logo.dart';

void main() {
  testWidgets('Boards list renders seeded boards', (WidgetTester tester) async {
    // Skip onboarding, matching a returning user's real-world state.
    SharedPreferences.setMockInitialValues({'hasSeenOnboarding': true});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(
              signedIn: true,
              mockUser: MockUser(uid: 'test-uid', isAnonymous: true),
            ),
          ),
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        ],
        child: const FlowBoardApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Boards'), findsOneWidget);
    expect(find.text('Mobile App v2'), findsOneWidget);
  });

  testWidgets('BoardsEmptyState renders its call to action', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardsEmptyState(onCreateBoard: () {}, onJoinWithLink: () {}),
        ),
      ),
    );

    expect(find.text('Create your first board'), findsOneWidget);
    expect(find.text('+ New board'), findsOneWidget);
    expect(find.text('Join with an invite link'), findsOneWidget);
  });

  testWidgets('OnboardingScreen skip triggers onDone', (WidgetTester tester) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onDone: () => done = true)),
    );

    expect(find.text('Organize visually'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(done, isTrue);
  });

  testWidgets('SplashScreen shows the brand mark and app name', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.byType(FlowBoardLogo), findsOneWidget);
    expect(find.text('FlowBoard'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('SignInScreen offers Google, Microsoft, email, and guest', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(signedIn: false)),
        ],
        child: const MaterialApp(home: SignInScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Microsoft'), findsOneWidget);
    expect(find.text('Continue with Email'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);

    // Expanding the email section should reveal the new field labels.
    await tester.tap(find.text('Continue with Email'));
    await tester.pumpAndSettle();
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
  });
}
