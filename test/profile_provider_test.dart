import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowboard/providers/profile_provider.dart';
import 'package:flowboard/theme/app_colors.dart';

void main() {
  group('claimUsername / findMemberByUsername', () {
    test('claiming a fresh username reserves it and finds the owner back', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('alice').set({
        'id': 'alice',
        'name': 'Alice',
        'initials': 'AL',
        'color': AppColors.primary.toARGB32(),
      });

      final error = await claimUsername(db, 'alice', 'AliceW');
      expect(error, isNull);

      final usernameDoc = await db.collection('usernames').doc('alicew').get();
      expect(usernameDoc.exists, isTrue);
      expect(usernameDoc.data()!['uid'], 'alice');

      final found = await findMemberByUsername(db, 'AliceW');
      expect(found?.id, 'alice');
    });

    test('rejects a username already taken by someone else', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('usernames').doc('taken').set({'uid': 'someone-else'});

      final error = await claimUsername(db, 'alice', 'taken');
      expect(error, 'That username is already taken.');
    });

    test('rejects invalid characters and lengths', () async {
      final db = FakeFirebaseFirestore();
      expect(await claimUsername(db, 'alice', 'ab'), isNotNull); // too short
      expect(await claimUsername(db, 'alice', 'has space'), isNotNull);
      expect(await claimUsername(db, 'alice', 'Has-Dash'), isNotNull);
    });

    test('changing username releases the old reservation', () async {
      final db = FakeFirebaseFirestore();
      await claimUsername(db, 'alice', 'oldname');
      expect((await db.collection('usernames').doc('oldname').get()).exists, isTrue);

      final error = await claimUsername(db, 'alice', 'newname', previousUsername: 'oldname');
      expect(error, isNull);
      expect((await db.collection('usernames').doc('oldname').get()).exists, isFalse);
      expect((await db.collection('usernames').doc('newname').get()).exists, isTrue);
    });

    test('findMemberByUsername returns null for an unknown username', () async {
      final db = FakeFirebaseFirestore();
      expect(await findMemberByUsername(db, 'nobody'), isNull);
    });

    test('re-claiming a name already reserved by the same uid recovers instead of failing', () async {
      // Simulates an interrupted change: the new reservation exists and
      // already belongs to this uid, but users/{uid}.username was never
      // updated to match (e.g. the app closed mid-write).
      final db = FakeFirebaseFirestore();
      await db.collection('usernames').doc('newname').set({'uid': 'alice'});
      await db.collection('usernames').doc('oldname').set({'uid': 'alice'});
      await db.collection('users').doc('alice').set({'username': 'oldname'});

      final error = await claimUsername(db, 'alice', 'newname', previousUsername: 'oldname');
      expect(error, isNull);

      final userDoc = await db.collection('users').doc('alice').get();
      expect(userDoc.data()!['username'], 'newname');
      expect((await db.collection('usernames').doc('oldname').get()).exists, isFalse);
    });
  });
}
