// ignore_for_file: lines_longer_than_80_chars

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ht_countries_client/ht_countries_client.dart';

/// {@template ht_countries_firestore}
/// A Firestore implementation of the [HtCountriesClient] interface.
///
/// This class interacts with a Cloud Firestore database to perform CRUD
/// operations on country data.
/// {@endtemplate}
class HtCountriesFirestore implements HtCountriesClient {
  /// {@macro ht_countries_firestore}
  ///
  /// Requires a [FirebaseFirestore] instance to interact with the database.
  /// Optionally, a [collectionName] can be provided (defaults to 'countries').
  HtCountriesFirestore({
    required FirebaseFirestore firestore,
    String collectionName = 'countries',
  })  : _firestore = firestore,
        _collectionName = collectionName;

  final FirebaseFirestore _firestore;
  final String _collectionName;

  /// Returns a [CollectionReference] to the configured countries collection.
  CollectionReference<Map<String, dynamic>> get _countriesCollection =>
      _firestore.collection(_collectionName);

  @override
  Future<List<Country>> fetchCountries({
    required int limit,
    String? startAfterId,
  }) async {
    try {
      var query = _countriesCollection.orderBy('iso_code').limit(limit);

      if (startAfterId != null) {
        // Firestore pagination requires the document snapshot of the last item.
        // We fetch the document corresponding to startAfterId first.
        // Note: Using iso_code as the document ID for simplicity here.
        // If 'id' is a separate field, adjust accordingly.
        final startAfterDoc =
            await _countriesCollection.doc(startAfterId).get();
        if (startAfterDoc.exists) {
          query = query.startAfterDocument(startAfterDoc);
        } else {
          // Handle case where the startAfterId document doesn't exist,
          // perhaps return empty list or throw a specific error?
          // For now, let the query run without startAfter, effectively
          // fetching the first page again if the ID was invalid.
          // Consider logging this scenario.
        }
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        // Combine document data with the document ID if 'id' field isn't
        // explicitly stored within the document data itself.
        // Assuming iso_code is the document ID here based on create/update logic.
        final data = doc.data();
        // Ensure 'id' field is populated correctly based on Country model
        // If 'id' is expected to be the Firestore document ID (iso_code),
        // ensure it's included. If 'id' is a separate field within the doc,
        // this merge might not be needed or should be adjusted.
        // Assuming Country.fromJson handles missing 'id' or uses iso_code.
        return Country.fromJson({...data, 'id': doc.id});
      }).toList();
    } catch (e, s) {
      // Log the original error e and stack trace s
      throw CountryFetchFailure(e, s);
    }
  }

  @override
  Future<Country> fetchCountry(String isoCode) async {
    try {
      // Assuming isoCode is the document ID
      final docSnapshot = await _countriesCollection.doc(isoCode).get();

      if (!docSnapshot.exists) {
        throw CountryNotFound('Country with isoCode "$isoCode" not found.');
      }
      final data = docSnapshot.data();
      if (data == null) {
        // This case should ideally not happen if docSnapshot.exists is true,
        // but handle defensively.
        throw CountryFetchFailure(
          'Document data is null for existing country "$isoCode".',
        );
      }
      // Combine document data with the document ID
      // Null check already performed above
      return Country.fromJson({...data, 'id': docSnapshot.id});
    } on CountryNotFound {
      rethrow; // Propagate CountryNotFound specifically
    } catch (e, s) {
      // Log the original error e and stack trace s
      throw CountryFetchFailure(e, s);
    }
  }

  @override
  Future<void> createCountry(Country country) async {
    try {
      // Use isoCode as the document ID for uniqueness and easy lookup
      await _countriesCollection.doc(country.isoCode).set(country.toJson());
    } catch (e, s) {
      // Log the original error e and stack trace s
      throw CountryCreateFailure(e, s);
    }
  }

  @override
  Future<void> updateCountry(Country country) async {
    final docRef = _countriesCollection.doc(country.isoCode);
    try {
      // Check for existence first to throw CountryNotFound as per contract
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        throw CountryNotFound(
          'Cannot update country with isoCode "${country.isoCode}": Not found.',
        );
      }
      await docRef.update(country.toJson());
    } on CountryNotFound {
      rethrow;
    } catch (e, s) {
      // Log the original error e and stack trace s
      throw CountryUpdateFailure(e, s);
    }
  }

  @override
  Future<void> deleteCountry(String isoCode) async {
    final docRef = _countriesCollection.doc(isoCode);
    try {
      // Check for existence first because delete() doesn't throw if not found
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        throw CountryNotFound(
          'Cannot delete country with isoCode "$isoCode": Not found.',
        );
      }
      await docRef.delete();
    } on CountryNotFound {
      rethrow;
    } catch (e, s) {
      // Log the original error e and stack trace s
      throw CountryDeleteFailure(e, s);
    }
  }
}
