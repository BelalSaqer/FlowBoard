import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flowboard/models/member.dart';
import 'package:flowboard/providers/profile_provider.dart';
import 'package:flowboard/theme/app_colors.dart';
import 'package:flowboard/widgets/member_avatar.dart';

const _member = Member(id: 'alice', name: 'Alice', initials: 'AL', color: AppColors.primary);

void main() {
  testWidgets('MemberAvatar shows initials when no photo is set', (tester) async {
    final db = FakeFirebaseFirestore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [firestoreProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: MemberAvatar(member: _member, size: 40))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AL'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('MemberAvatar shows the uploaded photo instead of initials once set', (tester) async {
    final db = FakeFirebaseFirestore();
    final tiny = img.Image(width: 2, height: 2);
    final jpg = img.encodeJpg(tiny);
    await db.collection('users').doc('alice').set({'photoBase64': base64Encode(jpg)});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [firestoreProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: MemberAvatar(member: _member, size: 40))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('AL'), findsNothing);
  });

  testWidgets('MemberAvatar keeps its color fill behind a photo (transparent-photo regression)', (tester) async {
    // A photo with transparent pixels (or a decode glitch) must not
    // leave the avatar see-through — it should always have the member's
    // color behind it, matching the initials-only case.
    final db = FakeFirebaseFirestore();
    final tiny = img.Image(width: 2, height: 2); // fully transparent by default
    final png = img.encodePng(tiny);
    await db.collection('users').doc('alice').set({'photoBase64': base64Encode(png)});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [firestoreProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: MemberAvatar(member: _member, size: 40))),
      ),
    );
    await tester.pumpAndSettle();

    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AppColors.primary);
  });
}
