// ignore_for_file: prefer_const_constructors

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ht_countries_client/ht_countries_client.dart';
import 'package:ht_countries_firestore/ht_countries_firestore.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class FakeDocumentSnapshot extends Fake implements DocumentSnapshot<Object?> {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeDocumentSnapshot());
    registerFallbackValue(Timestamp.now());
  });

  group('HtCountriesFirestore', () {
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference mockCollectionReference;
    late MockQuery mockQuery;
    late HtCountriesFirestore client;

    const collectionName = 'test_countries';

    MockQueryDocumentSnapshot createMockQueryDocumentSnapshot(
      String id,
      Map<String, dynamic> data,
    ) {
      final mock = MockQueryDocumentSnapshot();
      when(() => mock.id).thenReturn(id);
      when(() => mock.data()).thenReturn(data);
      when(() => mock.exists).thenReturn(true);
      return mock;
    }

    MockDocumentSnapshot createMockDocumentSnapshot(
      String id,
      Map<String, dynamic>? data, {
      bool exists = true,
    }) {
      final mock = MockDocumentSnapshot();
      when(() => mock.id).thenReturn(id);
      when(() => mock.data()).thenReturn(data);
      when(() => mock.exists).thenReturn(exists);
      return mock;
    }

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockCollectionReference = MockCollectionReference();
      mockQuery = MockQuery();

      when(() => mockFirestore.collection(collectionName))
          .thenReturn(mockCollectionReference);

      when(() => mockCollectionReference.orderBy(any())).thenReturn(mockQuery);
      when(() => mockQuery.limit(any())).thenReturn(mockQuery);
      when(() => mockQuery.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() =>
              mockQuery.where(any(), isNotEqualTo: any(named: 'isNotEqualTo')))
          .thenReturn(mockQuery);

      client = HtCountriesFirestore(
        firestore: mockFirestore,
        collectionName: collectionName,
      );
    });

    test('can be instantiated', () {
      expect(client, isNotNull);
    });

    group('fetchCountries', () {
      final countryData1 = {
        'iso_code': 'US',
        'name': 'United States',
        'flag_url': 'url1'
      };
      final countryData2 = {
        'iso_code': 'CA',
        'name': 'Canada',
        'flag_url': 'url2'
      };
      final countryData3 = {
        'iso_code': 'MX',
        'name': 'Mexico',
        'flag_url': 'url3'
      };

      final country1 = Country.fromJson({...countryData1, 'id': 'US'});
      final country2 = Country.fromJson({...countryData2, 'id': 'CA'});
      final country3 = Country.fromJson({...countryData3, 'id': 'MX'});

      test('fetches first page successfully', () async {
        final mockSnapshot = MockQuerySnapshot();
        final doc1 = createMockQueryDocumentSnapshot('US', countryData1);
        final doc2 = createMockQueryDocumentSnapshot('CA', countryData2);

        when(() => mockSnapshot.docs).thenReturn([doc1, doc2]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);

        final result = await client.fetchCountries(limit: 2);

        expect(result, equals([country1, country2]));
        verify(() => mockCollectionReference.orderBy('iso_code')).called(1);
        verify(() => mockQuery.limit(2)).called(1);
        verifyNever(() => mockCollectionReference.doc(any()));
        verifyNever(() => mockQuery.startAfterDocument(any()));
        verify(() => mockQuery.get()).called(1);
      });

      test('fetches next page using startAfterId successfully', () async {
        final startAfterDocSnapshot =
            createMockDocumentSnapshot('US', countryData1);
        final mockResultSnapshot = MockQuerySnapshot();
        final doc3 = createMockQueryDocumentSnapshot('MX', countryData3);
        final mockStartAfterDocRef = MockDocumentReference();

        when(() => mockCollectionReference.doc('US'))
            .thenReturn(mockStartAfterDocRef);
        when(() => mockStartAfterDocRef.get())
            .thenAnswer((_) async => startAfterDocSnapshot);

        when(() => mockQuery.startAfterDocument(startAfterDocSnapshot))
            .thenReturn(mockQuery);
        when(() => mockResultSnapshot.docs).thenReturn([doc3]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockResultSnapshot);

        final result =
            await client.fetchCountries(limit: 1, startAfterId: 'US');

        expect(result, equals([country3]));
        verify(() => mockCollectionReference.orderBy('iso_code')).called(1);
        verify(() => mockCollectionReference.doc('US').get()).called(1);
        verify(() => mockQuery.limit(1)).called(1);
        verify(() => mockQuery.startAfterDocument(startAfterDocSnapshot))
            .called(1);
        verify(() => mockQuery.get()).called(1);
      });

      test('handles non-existent startAfterId by fetching first page',
          () async {
        final nonExistentStartAfterDoc =
            createMockDocumentSnapshot('XX', null, exists: false);
        final mockFirstPageSnapshot = MockQuerySnapshot();
        final doc1 = createMockQueryDocumentSnapshot('US', countryData1);
        final doc2 = createMockQueryDocumentSnapshot('CA', countryData2);
        final mockNonExistentDocRef = MockDocumentReference();

        when(() => mockCollectionReference.doc('XX'))
            .thenReturn(mockNonExistentDocRef);
        when(() => mockNonExistentDocRef.get())
            .thenAnswer((_) async => nonExistentStartAfterDoc);

        when(() => mockFirstPageSnapshot.docs).thenReturn([doc1, doc2]);
        when(() => mockQuery.get())
            .thenAnswer((_) async => mockFirstPageSnapshot);

        final result =
            await client.fetchCountries(limit: 2, startAfterId: 'XX');

        expect(result, equals([country1, country2]));
        verify(() => mockCollectionReference.orderBy('iso_code')).called(1);
        verify(() => mockCollectionReference.doc('XX').get()).called(1);
        verify(() => mockQuery.limit(2)).called(1);
        verifyNever(() => mockQuery.startAfterDocument(any()));
        verify(() => mockQuery.get()).called(1);
      });

      test('returns empty list when no countries match', () async {
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);

        final result = await client.fetchCountries(limit: 5);

        expect(result, isEmpty);
        verify(() => mockQuery.get()).called(1);
      });

      test('throws CountryFetchFailure on Firestore error', () async {
        final exception =
            FirebaseException(plugin: 'firestore', message: 'Test error');
        when(() => mockQuery.get()).thenThrow(exception);

        expect(
          () => client.fetchCountries(limit: 5),
          throwsA(isA<CountryFetchFailure>()),
        );
        verify(() => mockQuery.get()).called(1);
      });
    });

    group('fetchCountry', () {
      final countryData = {
        'iso_code': 'GB',
        'name': 'United Kingdom',
        'flag_url': 'url_gb'
      };
      final country = Country.fromJson({...countryData, 'id': 'GB'});
      late MockDocumentReference mockDocumentReference;

      setUp(() {
        mockDocumentReference = MockDocumentReference();
        when(() => mockCollectionReference.doc('GB'))
            .thenReturn(mockDocumentReference);
      });

      test('fetches country successfully when document exists', () async {
        final mockDocSnapshot = createMockDocumentSnapshot('GB', countryData);
        when(() => mockDocumentReference.get())
            .thenAnswer((_) async => mockDocSnapshot);

        final result = await client.fetchCountry('GB');

        expect(result, equals(country));
        verify(() => mockCollectionReference.doc('GB')).called(1);
        verify(() => mockDocumentReference.get()).called(1);
      });

      test('throws CountryNotFound when document does not exist', () async {
        final mockDocSnapshot =
            createMockDocumentSnapshot('GB', null, exists: false);
        when(() => mockDocumentReference.get())
            .thenAnswer((_) async => mockDocSnapshot);

        expect(
          () => client.fetchCountry('GB'),
          throwsA(isA<CountryNotFound>().having(
            (e) => e.error,
            'error message',
            'Country with isoCode "GB" not found.',
          )),
        );
        verify(() => mockCollectionReference.doc('GB')).called(1);
        verify(() => mockDocumentReference.get()).called(1);
      });

      test('throws CountryFetchFailure when document exists but data is null',
          () async {
        final mockDocSnapshot =
            createMockDocumentSnapshot('GB', null, exists: true);
        when(() => mockDocumentReference.get())
            .thenAnswer((_) async => mockDocSnapshot);

        expect(
          () => client.fetchCountry('GB'),
          throwsA(
            isA<CountryFetchFailure>().having(
              (e) => e.toString(),
              'toString()',
              'CountryFetchFailure: CountryFetchFailure: Document data is null for existing country "GB".',
            ),
          ),
        );
        verify(() => mockCollectionReference.doc('GB')).called(1);
        verify(() => mockDocumentReference.get()).called(1);
      });

      test('throws CountryFetchFailure on Firestore error during get',
          () async {
        final exception =
            FirebaseException(plugin: 'firestore', message: 'Fetch error');
        when(() => mockDocumentReference.get()).thenThrow(exception);

        expect(
          () => client.fetchCountry('GB'),
          throwsA(isA<CountryFetchFailure>()),
        );
        verify(() => mockCollectionReference.doc('GB')).called(1);
        verify(() => mockDocumentReference.get()).called(1);
      });
    });

    group('createCountry', () {
      final countryData = {
        'iso_code': 'DE',
        'name': 'Germany',
        'flag_url': 'url_de'
      };
      final country = Country.fromJson({...countryData, 'id': 'DE'});
      late MockDocumentReference mockDocumentReference;

      setUp(() {
        mockDocumentReference = MockDocumentReference();
        when(() => mockCollectionReference.doc(country.isoCode))
            .thenReturn(mockDocumentReference);
      });

      test('creates country successfully', () async {
        when(() => mockDocumentReference.set(country.toJson()))
            .thenAnswer((_) async {});

        await client.createCountry(country);

        verify(() => mockCollectionReference.doc(country.isoCode)).called(1);
        verify(() => mockDocumentReference.set(country.toJson())).called(1);
      });

      test('throws CountryCreateFailure on Firestore error during set',
          () async {
        final exception =
            FirebaseException(plugin: 'firestore', message: 'Create error');
        when(() => mockDocumentReference.set(country.toJson()))
            .thenThrow(exception);

        expect(
          () => client.createCountry(country),
          throwsA(isA<CountryCreateFailure>()),
        );

        verify(() => mockCollectionReference.doc(country.isoCode)).called(1);
        verify(() => mockDocumentReference.set(country.toJson())).called(1);
      });
    });

    group('updateCountry', () {
      final countryData = {
        'iso_code': 'FR',
        'name': 'France',
        'flag_url': 'url_fr'
      };
      final updatedData = {
        'iso_code': 'FR',
        'name': 'France Republic',
        'flag_url': 'url_fr_new'
      };
      final country = Country.fromJson({...updatedData, 'id': 'FR'});
      late MockDocumentReference mockDocumentReference;
      late MockDocumentSnapshot mockExistingDocSnapshot;
      late MockDocumentSnapshot mockNonExistingDocSnapshot;

      setUp(() {
        mockDocumentReference = MockDocumentReference();
        mockExistingDocSnapshot = createMockDocumentSnapshot('FR', countryData);
        mockNonExistingDocSnapshot =
            createMockDocumentSnapshot('FR', null, exists: false);

        when(() => mockCollectionReference.doc(country.isoCode))
            .thenReturn(mockDocumentReference);
      });

      test('updates country successfully when document exists', () async {
        when(() => mockDocumentReference.get())
            .thenAnswer((_) async => mockExistingDocSnapshot);
        when(() => mockDocumentReference.update(country.toJson()))
            .thenAnswer((_) async {});

        await client.updateCountry(country);

        verify(() => mockCollectionReference.doc(country.isoCode)).called(1);
        verify(() => mockDocumentReference.get()).called(1);
        verify(() => mockDocumentReference.update(country.toJson())).called(1);
      });

      test('throws CountryNotFound when document does not exist', () async {
        when(() => mockDocumentReference.get())
            .thenAnswer((_) async => mockNonExistingDocSnapshot);

        expect(
          () => client.updateCountry(country),
          throwsA(isA<CountryNotFound>().having(
            (e) => e.error,
            'error message',
            'Cannot update country with isoCode "FR": Not found.',
          )),
        );

        verify(() => mockCollectionReference.doc(country.isoCode)).called(1);
        verify(() => mockDocumentReference.get()).called(1);
        verifyNever(() => mockDocumentReference.update(any()));
      });

      test('throws CountryUpdateFailure on Firestore error during get',
          () async {
        final exception = FirebaseException(
            plugin: 'firestore', message: 'Get error for update');
        when(() => mockDocumentReference.get()).thenThrow(exception);

        expect(
          () => client.updateCountry(country),
          throwsA(isA<CountryUpdateFailure>()),
        );

        verify(() => mockCollectionReference.doc(country.isoCode)).called(1);
        verify(() => mockDocumentReference.get()).called(1);
        verifyNever(() => mockDocumentReference.update(any()));
      });

      test('throws CountryUpdateFailure on Firestore error during update',
          () async {
        final exception =
            FirebaseException(plugin: 'firestore', message: 'Update error');
        when(() => mockDocumentReference.get())
            .thenAnswer((_) async => mockExistingDocSnapshot);
        when(() => mockDocumentReference.update(country.toJson()))
            .thenThrow(exception);

        expect(
          () => client.updateCountry(country),
          throwsA(isA<CountryUpdateFailure>()),
        );

        verify(() => mockCollectionReference.doc(country.isoCode)).called(1);
        verify(() => mockDocumentReference.get()).called(1);
      });
    });

    group('deleteCountry', () {
      const isoCodeToDelete = 'JP';
      late MockDocumentReference mockDocumentReference;
      late MockDocumentSnapshot mockExistingDocSnapshot;
      late MockDocumentSnapshot mockNonExistingDocSnapshot;

      setUp(() {
        mockDocumentReference = MockDocumentReference();
        mockExistingDocSnapshot =
            createMockDocumentSnapshot(isoCodeToDelete, {'name': 'Japan'});
        mockNonExistingDocSnapshot =
            createMockDocumentSnapshot(isoCodeToDelete, null, exists: false);

        when(() => mockCollectionReference.doc(isoCodeToDelete))
            .thenReturn(mockDocumentReference);
      });

      test('deletes country successfully when document exists', () async {
        when(() => mockDocumentReference.get())
            .thenAnswer((_) async => mockExistingDocSnapshot);
        when(() => mockDocumentReference.delete()).thenAnswer((_) async {});

        await client.deleteCountry(isoCodeToDelete);

        verify(() => mockCollectionReference.doc(isoCodeToDelete)).called(1);
        verify(() => mockDocumentReference.get()).called(1);
        verify(() => mockDocumentReference.delete()).called(1);
      });

      test('throws CountryNotFound when document does not exist', () async {
        when(() => mockDocumentReference.get())
            .thenAnswer((_) async => mockNonExistingDocSnapshot);

        expect(
          () => client.deleteCountry(isoCodeToDelete),
          throwsA(isA<CountryNotFound>().having(
            (e) => e.error,
            'error message',
            'Cannot delete country with isoCode "JP": Not found.',
          )),
        );

        verify(() => mockCollectionReference.doc(isoCodeToDelete)).called(1);
        verify(() => mockDocumentReference.get()).called(1);
        verifyNever(() => mockDocumentReference.delete());
      });

      test('throws CountryDeleteFailure on Firestore error during get',
          () async {
        final exception = FirebaseException(
            plugin: 'firestore', message: 'Get error for delete');
        when(() => mockDocumentReference.get()).thenThrow(exception);

        expect(
          () => client.deleteCountry(isoCodeToDelete),
          throwsA(isA<CountryDeleteFailure>()),
        );

        verify(() => mockCollectionReference.doc(isoCodeToDelete)).called(1);
        verify(() => mockDocumentReference.get()).called(1);
        verifyNever(() => mockDocumentReference.delete());
      });

      test('throws CountryDeleteFailure on Firestore error during delete',
          () async {
        final exception =
            FirebaseException(plugin: 'firestore', message: 'Delete error');
        when(() => mockDocumentReference.get())
            .thenAnswer((_) async => mockExistingDocSnapshot);
        when(() => mockDocumentReference.delete()).thenThrow(exception);

        expect(
          () => client.deleteCountry(isoCodeToDelete),
          throwsA(isA<CountryDeleteFailure>()),
        );

        verify(() => mockCollectionReference.doc(isoCodeToDelete)).called(1);
        verify(() => mockDocumentReference.get()).called(1);
      });
    });
  });
}
