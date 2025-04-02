# ht_countries_firestore

[![Coverage Status](coverage_badge.svg)](https://github.com/headlines-toolkit/ht-countries-firestore)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C8E.svg)](https://pub.dev/packages/very_good_analysis)
[![License: PolyForm Free Trial 1.0.0](https://img.shields.io/badge/License-PolyForm%20Free%20Trial%201.0.0-blue.svg)](LICENSE)

A Firestore implementation for the `ht_countries_client` interface, part of the Headlines Toolkit project. This package provides concrete methods for fetching, creating, updating, and deleting country data stored in Cloud Firestore.

**Note:** This software is licensed under the [PolyForm Free Trial License 1.0.0](LICENSE). Use is permitted only for evaluating the software for less than 32 consecutive days.

## Features

*   Implements the `HtCountriesClient` abstract class.
*   Provides CRUD operations for country data in Firestore.
*   Supports pagination for fetching countries.

## Installation

Since this package is hosted on GitHub and not published on pub.dev, add it to your `pubspec.yaml` as a Git dependency:

```yaml
dependencies:
  ht_countries_client:
    git:
      url: https://github.com/headlines-toolkit/ht-countries-client.git
  ht_countries_firestore:
    git:
      url: https://github.com/headlines-toolkit/ht-countries-firestore.git
      # Optionally, specify a ref (branch, tag, or commit hash):
      # ref: main
```

Then, run `flutter pub get`.

## Usage

Import the package and instantiate the client, providing a `FirebaseFirestore` instance:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ht_countries_firestore/ht_countries_firestore.dart';
import 'package:ht_countries_client/ht_countries_client.dart'; // For Country model and exceptions

void main() async {
  // Ensure Firebase is initialized
  // await Firebase.initializeApp(...);

  final firestore = FirebaseFirestore.instance;
  // Default collection name is 'countries'
  final countriesClient = HtCountriesFirestore(firestore: firestore); 

  try {
    // Fetch the first page of countries
    List<Country> firstPage = await countriesClient.fetchCountries(limit: 10);
    print('Fetched ${firstPage.length} countries:');
    for (var country in firstPage) {
      print('- ${country.name} (${country.isoCode})');
    }

    // Fetch a specific country
    Country usa = await countriesClient.fetchCountry('US');
    print('\nFetched specific country: ${usa.name}');

    // Fetch the next page (if available)
    if (firstPage.isNotEmpty) {
      // Use the isoCode as the document ID for pagination in this implementation
      String lastIsoCode = firstPage.last.isoCode; 
      List<Country> nextPage = await countriesClient.fetchCountries(limit: 10, startAfterId: lastIsoCode);
      print('\nFetched next page with ${nextPage.length} countries.');
    }

  } on CountryFetchFailure catch (e) {
    print('Error fetching countries: $e');
  } on CountryNotFound catch (e) {
    print('Error: $e');
  } catch (e) {
    print('An unexpected error occurred: $e');
  }
}
```

Remember to configure your Firestore database and security rules appropriately. The default collection name used by this client is `countries`, but you can override this via the constructor.

## Running Tests

This package uses `very_good_analysis` for linting and `flutter_test` with `mocktail` for testing.

To run the tests:

```bash
flutter test
```

To run tests and check coverage (requires `very_good_cli`):

```bash
very_good test --min-coverage 90
```

## License

This package is licensed under the [PolyForm Free Trial License 1.0.0](LICENSE). Please review the terms before use.
