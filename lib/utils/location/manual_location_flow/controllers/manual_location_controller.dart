// ─────────────────────────────────────────
// Controller: ManualLocationController
// Description: State controller for the manual location flow steps.
// Contains: currentStep, selectedContinent/Country/City
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import '../models/manual_location_data.dart';
import '../models/world_data.dart';
import '../services/location_validation_service.dart';

/// State management for the 4-step manual location flow
/// Step 1: Continent → Step 2: Country → Step 3: City → Step 4: Street
class ManualLocationController extends ChangeNotifier {
  final LocationValidationService _validationService;

  ManualLocationController({
    required LocationValidationService validationService,
  }) : _validationService = validationService;

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════════════════════════════════════

  int _currentStep = 0;
  int get currentStep => _currentStep;
  int get totalSteps => 4;

  // Step 1: Continent
  ContinentData? _selectedContinent;
  ContinentData? get selectedContinent => _selectedContinent;

  // Step 2: Country
  CountryData? _selectedCountry;
  CountryData? get selectedCountry => _selectedCountry;
  String _countrySearchQuery = '';
  String get countrySearchQuery => _countrySearchQuery;

  // Step 3: City
  String _selectedCity = '';
  String get selectedCity => _selectedCity;
  double _cityLatitude = 0.0;
  double _cityLongitude = 0.0;
  double get cityLatitude => _cityLatitude;
  double get cityLongitude => _cityLongitude;
  List<CitySuggestion> _citySuggestions = [];
  List<CitySuggestion> get citySuggestions => _citySuggestions;
  bool _isCityValid = false;
  bool get isCityValid => _isCityValid;

  // Step 4: Street
  String _selectedStreet = '';
  String get selectedStreet => _selectedStreet;
  double _streetLatitude = 0.0;
  double _streetLongitude = 0.0;
  double get streetLatitude => _streetLatitude;
  double get streetLongitude => _streetLongitude;
  String _formattedAddress = '';
  String get formattedAddress => _formattedAddress;
  List<StreetSuggestion> _streetSuggestions = [];
  List<StreetSuggestion> get streetSuggestions => _streetSuggestions;
  bool _isStreetValid = false;
  bool get isStreetValid => _isStreetValid;

  // Loading & Error
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ═══════════════════════════════════════════════════════════════════════════
  // NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════════

  bool get canGoBack => _currentStep > 0;
  bool get canGoNext {
    switch (_currentStep) {
      case 0:
        return _selectedContinent != null;
      case 1:
        return _selectedCountry != null;
      case 2:
        return _isCityValid;
      case 3:
        return _isStreetValid;
      default:
        return false;
    }
  }

  void goBack() {
    if (_currentStep > 0) {
      _currentStep--;
      _errorMessage = null;
      notifyListeners();
    }
  }

  void goNext() {
    if (_currentStep < 3 && canGoNext) {
      _currentStep++;
      _errorMessage = null;
      notifyListeners();
    }
  }

  void goToStep(int step) {
    if (step >= 0 && step <= 3) {
      _currentStep = step;
      _errorMessage = null;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 1: CONTINENT
  // ═══════════════════════════════════════════════════════════════════════════

  List<ContinentData> get continents => WorldData.continents;

  void selectContinent(ContinentData continent) {
    _selectedContinent = continent;
    // Reset subsequent selections
    _selectedCountry = null;
    _selectedCity = '';
    _cityLatitude = 0.0;
    _cityLongitude = 0.0;
    _isCityValid = false;
    _selectedStreet = '';
    _streetLatitude = 0.0;
    _streetLongitude = 0.0;
    _isStreetValid = false;
    _formattedAddress = '';
    _countrySearchQuery = '';
    _citySuggestions = [];
    _streetSuggestions = [];
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 2: COUNTRY
  // ═══════════════════════════════════════════════════════════════════════════

  List<CountryData> get availableCountries {
    if (_selectedContinent == null) return [];

    final countries = List<CountryData>.from(_selectedContinent!.countries);
    countries.sort((a, b) => a.name.compareTo(b.name));

    if (_countrySearchQuery.isEmpty) return countries;

    final query = _countrySearchQuery.toLowerCase();
    return countries
        .where((c) =>
            c.name.toLowerCase().contains(query) ||
            c.code.toLowerCase().contains(query))
        .toList();
  }

  void setCountrySearchQuery(String query) {
    _countrySearchQuery = query;
    notifyListeners();
  }

  void selectCountry(CountryData country) {
    _selectedCountry = country;
    // Reset subsequent selections
    _selectedCity = '';
    _cityLatitude = 0.0;
    _cityLongitude = 0.0;
    _isCityValid = false;
    _selectedStreet = '';
    _streetLatitude = 0.0;
    _streetLongitude = 0.0;
    _isStreetValid = false;
    _formattedAddress = '';
    _citySuggestions = [];
    _streetSuggestions = [];
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 3: CITY
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> searchCities(String query) async {
    if (_selectedCountry == null) return;
    if (query.length < 2) {
      _citySuggestions = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _citySuggestions = await _validationService.searchCities(
        query,
        countryCode: _selectedCountry!.code,
      );
    } catch (e) {
      _errorMessage = 'Error searching cities: $e';
      _citySuggestions = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  void selectCity(CitySuggestion city) {
    _selectedCity = city.name;
    _cityLatitude = city.latitude;
    _cityLongitude = city.longitude;
    _isCityValid = city.hasValidCoordinates;
    _citySuggestions = [];
    // Reset street
    _selectedStreet = '';
    _streetLatitude = 0.0;
    _streetLongitude = 0.0;
    _isStreetValid = false;
    _formattedAddress = '';
    _streetSuggestions = [];
    notifyListeners();
  }

  Future<void> validateCity(String cityName) async {
    if (_selectedCountry == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _validationService.validateCity(
        cityName,
        countryCode: _selectedCountry!.code,
      );

      if (result.isValid) {
        _selectedCity = result.cityName;
        _cityLatitude = result.latitude;
        _cityLongitude = result.longitude;
        _isCityValid = true;
      } else {
        _isCityValid = false;
        _errorMessage = result.errorMessage;
      }
    } catch (e) {
      _isCityValid = false;
      _errorMessage = 'Error validating city: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  void setCityManually(String cityName) {
    _selectedCity = cityName;
    _isCityValid = false; // Must be validated
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 4: STREET
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> searchStreets(String query) async {
    if (_selectedCountry == null || !_isCityValid) return;
    if (query.length < 2) {
      _streetSuggestions = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _streetSuggestions = await _validationService.searchStreets(
        query,
        city: _selectedCity,
        countryCode: _selectedCountry!.code,
        cityLat: _cityLatitude,
        cityLng: _cityLongitude,
      );
    } catch (e) {
      _errorMessage = 'Error searching streets: $e';
      _streetSuggestions = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  void selectStreet(StreetSuggestion street) {
    _selectedStreet = street.name;
    _streetLatitude = street.latitude;
    _streetLongitude = street.longitude;
    _formattedAddress = street.fullAddress;
    _isStreetValid = street.hasValidCoordinates;
    _streetSuggestions = [];
    notifyListeners();
  }

  Future<void> validateStreet(String streetName) async {
    if (_selectedCountry == null || !_isCityValid) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _validationService.validateStreet(
        streetName,
        city: _selectedCity,
        countryCode: _selectedCountry!.code,
        cityLat: _cityLatitude,
        cityLng: _cityLongitude,
      );

      if (result.isValid) {
        _selectedStreet = result.streetName;
        _streetLatitude = result.latitude;
        _streetLongitude = result.longitude;
        _formattedAddress = result.formattedAddress;
        _isStreetValid = true;
      } else {
        _isStreetValid = false;
        _errorMessage = result.errorMessage;
      }
    } catch (e) {
      _isStreetValid = false;
      _errorMessage = 'Error validating street: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  void setStreetManually(String streetName) {
    _selectedStreet = streetName;
    _isStreetValid = false; // Must be validated
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FINAL LOCATION DATA
  // ═══════════════════════════════════════════════════════════════════════════

  bool get isComplete =>
      _selectedContinent != null &&
      _selectedCountry != null &&
      _isCityValid &&
      _isStreetValid;

  ManualLocationData? getLocationData() {
    if (!isComplete) return null;

    return ManualLocationData(
      continent: _selectedContinent!.name,
      country: _selectedCountry!.name,
      countryCode: _selectedCountry!.code,
      city: _selectedCity,
      street: _selectedStreet,
      latitude: _streetLatitude,
      longitude: _streetLongitude,
      formattedAddress: _formattedAddress.isNotEmpty
          ? _formattedAddress
          : '$_selectedStreet, $_selectedCity, ${_selectedCountry!.name}',
      createdAt: DateTime.now(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESET
  // ═══════════════════════════════════════════════════════════════════════════

  void reset() {
    _currentStep = 0;
    _selectedContinent = null;
    _selectedCountry = null;
    _countrySearchQuery = '';
    _selectedCity = '';
    _cityLatitude = 0.0;
    _cityLongitude = 0.0;
    _isCityValid = false;
    _citySuggestions = [];
    _selectedStreet = '';
    _streetLatitude = 0.0;
    _streetLongitude = 0.0;
    _isStreetValid = false;
    _formattedAddress = '';
    _streetSuggestions = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
