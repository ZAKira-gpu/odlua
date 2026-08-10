// ─────────────────────────────────────────
// Widget: StructuredLocationInputWidget
// Description: Multi-field address input (street, city, country, zip).
// Contains: Structured fields, validation, geocoding
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:odlua/utils/location/services/structured_location_service.dart';
import 'package:odlua/utils/models/location_search_models.dart';
import 'package:odlua/utils/models/structured_address_model.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

/// Structured location input widget with improved 6-step wizard
/// Step 1: Country → Step 2: State → Step 3: City → Step 4: Street →
/// Step 5: Building details → Step 6: Review
class StructuredLocationInputWidget extends StatefulWidget {
  final Function(StructuredAddress) onAddressComplete;
  final StructuredAddress? initialAddress;
  final bool isRequired;
  final String? countryCode; // Pre-select country (e.g., 'EG', 'SA')

  const StructuredLocationInputWidget({
    super.key,
    required this.onAddressComplete,
    this.initialAddress,
    this.isRequired = true,
    this.countryCode,
  });

  @override
  State<StructuredLocationInputWidget> createState() =>
      _StructuredLocationInputWidgetState();
}

class _StructuredLocationInputWidgetState
    extends State<StructuredLocationInputWidget> {
  final _locationService = StructuredLocationService();

  // Step tracking
  int _currentStep = 0;

  // Step 1: Country
  String? _selectedCountry;
  String? _selectedCountryCode;
  final List<Map<String, String>> _countries = [
    // Priority countries at top (most common)
    {'name': 'France', 'code': 'FR', 'flag': '🇫🇷'},
    {'name': 'Germany', 'code': 'DE', 'flag': '🇩🇪'},
    {'name': 'United States', 'code': 'US', 'flag': '🇺🇸'},
    {'name': 'United Kingdom', 'code': 'GB', 'flag': '🇬🇧'},
    {'name': 'Canada', 'code': 'CA', 'flag': '🇨🇦'},
    {'name': 'Australia', 'code': 'AU', 'flag': '🇦🇺'},

    // Europe
    {'name': 'Albania', 'code': 'AL', 'flag': '🇦🇱'},
    {'name': 'Andorra', 'code': 'AD', 'flag': '🇦🇩'},
    {'name': 'Austria', 'code': 'AT', 'flag': '🇦🇹'},
    {'name': 'Belarus', 'code': 'BY', 'flag': '🇧🇾'},
    {'name': 'Belgium', 'code': 'BE', 'flag': '🇧🇪'},
    {'name': 'Bosnia and Herzegovina', 'code': 'BA', 'flag': '🇧🇦'},
    {'name': 'Bulgaria', 'code': 'BG', 'flag': '🇧🇬'},
    {'name': 'Croatia', 'code': 'HR', 'flag': '🇭🇷'},
    {'name': 'Cyprus', 'code': 'CY', 'flag': '🇨🇾'},
    {'name': 'Czech Republic', 'code': 'CZ', 'flag': '🇨🇿'},
    {'name': 'Denmark', 'code': 'DK', 'flag': '🇩🇰'},
    {'name': 'Estonia', 'code': 'EE', 'flag': '🇪🇪'},
    {'name': 'Finland', 'code': 'FI', 'flag': '🇫🇮'},
    {'name': 'Greece', 'code': 'GR', 'flag': '🇬🇷'},
    {'name': 'Hungary', 'code': 'HU', 'flag': '🇭🇺'},
    {'name': 'Iceland', 'code': 'IS', 'flag': '🇮🇸'},
    {'name': 'Ireland', 'code': 'IE', 'flag': '🇮🇪'},
    {'name': 'Italy', 'code': 'IT', 'flag': '🇮🇹'},
    {'name': 'Kosovo', 'code': 'XK', 'flag': '🇽🇰'},
    {'name': 'Latvia', 'code': 'LV', 'flag': '🇱🇻'},
    {'name': 'Liechtenstein', 'code': 'LI', 'flag': '🇱🇮'},
    {'name': 'Lithuania', 'code': 'LT', 'flag': '🇱🇹'},
    {'name': 'Luxembourg', 'code': 'LU', 'flag': '🇱🇺'},
    {'name': 'Malta', 'code': 'MT', 'flag': '🇲🇹'},
    {'name': 'Moldova', 'code': 'MD', 'flag': '🇲🇩'},
    {'name': 'Monaco', 'code': 'MC', 'flag': '🇲🇨'},
    {'name': 'Montenegro', 'code': 'ME', 'flag': '🇲🇪'},
    {'name': 'Netherlands', 'code': 'NL', 'flag': '🇳🇱'},
    {'name': 'North Macedonia', 'code': 'MK', 'flag': '🇲🇰'},
    {'name': 'Norway', 'code': 'NO', 'flag': '🇳🇴'},
    {'name': 'Poland', 'code': 'PL', 'flag': '🇵🇱'},
    {'name': 'Portugal', 'code': 'PT', 'flag': '🇵🇹'},
    {'name': 'Romania', 'code': 'RO', 'flag': '🇷🇴'},
    {'name': 'Russia', 'code': 'RU', 'flag': '🇷🇺'},
    {'name': 'San Marino', 'code': 'SM', 'flag': '🇸🇲'},
    {'name': 'Serbia', 'code': 'RS', 'flag': '🇷🇸'},
    {'name': 'Slovakia', 'code': 'SK', 'flag': '🇸🇰'},
    {'name': 'Slovenia', 'code': 'SI', 'flag': '🇸🇮'},
    {'name': 'Spain', 'code': 'ES', 'flag': '🇪🇸'},
    {'name': 'Sweden', 'code': 'SE', 'flag': '🇸🇪'},
    {'name': 'Switzerland', 'code': 'CH', 'flag': '🇨🇭'},
    {'name': 'Ukraine', 'code': 'UA', 'flag': '🇺🇦'},
    {'name': 'Vatican City', 'code': 'VA', 'flag': '🇻🇦'},

    // Middle East & North Africa
    {'name': 'Algeria', 'code': 'DZ', 'flag': '🇩🇿'},
    {'name': 'Bahrain', 'code': 'BH', 'flag': '🇧🇭'},
    {'name': 'Egypt', 'code': 'EG', 'flag': '🇪🇬'},
    {'name': 'Iraq', 'code': 'IQ', 'flag': '🇮🇶'},
    {'name': 'Israel', 'code': 'IL', 'flag': '🇮🇱'},
    {'name': 'Jordan', 'code': 'JO', 'flag': '🇯🇴'},
    {'name': 'Kuwait', 'code': 'KW', 'flag': '🇰🇼'},
    {'name': 'Lebanon', 'code': 'LB', 'flag': '🇱🇧'},
    {'name': 'Libya', 'code': 'LY', 'flag': '🇱🇾'},
    {'name': 'Morocco', 'code': 'MA', 'flag': '🇲🇦'},
    {'name': 'Oman', 'code': 'OM', 'flag': '🇴🇲'},
    {'name': 'Palestine', 'code': 'PS', 'flag': '🇵🇸'},
    {'name': 'Qatar', 'code': 'QA', 'flag': '🇶🇦'},
    {'name': 'Saudi Arabia', 'code': 'SA', 'flag': '🇸🇦'},
    {'name': 'Sudan', 'code': 'SD', 'flag': '🇸🇩'},
    {'name': 'Syria', 'code': 'SY', 'flag': '🇸🇾'},
    {'name': 'Tunisia', 'code': 'TN', 'flag': '🇹🇳'},
    {'name': 'Turkey', 'code': 'TR', 'flag': '🇹🇷'},
    {'name': 'United Arab Emirates', 'code': 'AE', 'flag': '🇦🇪'},
    {'name': 'Yemen', 'code': 'YE', 'flag': '🇾🇪'},

    // Asia
    {'name': 'Bangladesh', 'code': 'BD', 'flag': '🇧🇩'},
    {'name': 'China', 'code': 'CN', 'flag': '🇨🇳'},
    {'name': 'Hong Kong', 'code': 'HK', 'flag': '🇭🇰'},
    {'name': 'India', 'code': 'IN', 'flag': '🇮🇳'},
    {'name': 'Indonesia', 'code': 'ID', 'flag': '🇮🇩'},
    {'name': 'Japan', 'code': 'JP', 'flag': '🇯🇵'},
    {'name': 'Kazakhstan', 'code': 'KZ', 'flag': '🇰🇿'},
    {'name': 'Malaysia', 'code': 'MY', 'flag': '🇲🇾'},
    {'name': 'Pakistan', 'code': 'PK', 'flag': '🇵🇰'},
    {'name': 'Philippines', 'code': 'PH', 'flag': '🇵🇭'},
    {'name': 'Singapore', 'code': 'SG', 'flag': '🇸🇬'},
    {'name': 'South Korea', 'code': 'KR', 'flag': '🇰🇷'},
    {'name': 'Sri Lanka', 'code': 'LK', 'flag': '🇱🇰'},
    {'name': 'Taiwan', 'code': 'TW', 'flag': '🇹🇼'},
    {'name': 'Thailand', 'code': 'TH', 'flag': '🇹🇭'},
    {'name': 'Vietnam', 'code': 'VN', 'flag': '🇻🇳'},

    // Africa
    {'name': 'Ghana', 'code': 'GH', 'flag': '🇬🇭'},
    {'name': 'Kenya', 'code': 'KE', 'flag': '🇰🇪'},
    {'name': 'Nigeria', 'code': 'NG', 'flag': '🇳🇬'},
    {'name': 'South Africa', 'code': 'ZA', 'flag': '🇿🇦'},
    {'name': 'Tanzania', 'code': 'TZ', 'flag': '🇹🇿'},
    {'name': 'Uganda', 'code': 'UG', 'flag': '🇺🇬'},

    // Americas
    {'name': 'Argentina', 'code': 'AR', 'flag': '🇦🇷'},
    {'name': 'Brazil', 'code': 'BR', 'flag': '🇧🇷'},
    {'name': 'Chile', 'code': 'CL', 'flag': '🇨🇱'},
    {'name': 'Colombia', 'code': 'CO', 'flag': '🇨🇴'},
    {'name': 'Costa Rica', 'code': 'CR', 'flag': '🇨🇷'},
    {'name': 'Cuba', 'code': 'CU', 'flag': '🇨🇺'},
    {'name': 'Dominican Republic', 'code': 'DO', 'flag': '🇩🇴'},
    {'name': 'Ecuador', 'code': 'EC', 'flag': '🇪🇨'},
    {'name': 'Guatemala', 'code': 'GT', 'flag': '🇬🇹'},
    {'name': 'Jamaica', 'code': 'JM', 'flag': '🇯🇲'},
    {'name': 'Mexico', 'code': 'MX', 'flag': '🇲🇽'},
    {'name': 'Panama', 'code': 'PA', 'flag': '🇵🇦'},
    {'name': 'Peru', 'code': 'PE', 'flag': '🇵🇪'},
    {'name': 'Puerto Rico', 'code': 'PR', 'flag': '🇵🇷'},
    {'name': 'Uruguay', 'code': 'UY', 'flag': '🇺🇾'},
    {'name': 'Venezuela', 'code': 'VE', 'flag': '🇻🇪'},

    // Oceania
    {'name': 'New Zealand', 'code': 'NZ', 'flag': '🇳🇿'},
  ];

  // Step 2: State/Province (OPTIONAL - can be skipped)
  final _stateController = TextEditingController();
  List<CityResult> _stateSuggestions = [];
  String? _selectedState;
  bool _stateLoading = false;

  // Step 3: City
  CityResult? _selectedCity;
  final _cityController = TextEditingController();
  List<CityResult> _citySuggestions = [];
  bool _cityLoading = false;

  // Step 4: Street
  StreetResult? _selectedStreet;
  final _streetController = TextEditingController();
  List<StreetResult> _streetSuggestions = [];
  bool _streetLoading = false;

  // Step 5: Building details
  final _buildingNumberController = TextEditingController();
  final _buildingNameController = TextEditingController();
  final _floorController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _entranceController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _additionalInfoController = TextEditingController();

  // Geocoding state
  bool _isGeocoding = false;

  // Error states
  String? _stateSearchError;
  String? _citySearchError;
  String? _streetSearchError;

  @override
  void initState() {
    super.initState();

    // Pre-select country if provided
    if (widget.countryCode != null) {
      final country = _countries.firstWhere(
        (c) => c['code'] == widget.countryCode,
        orElse: () => _countries[0],
      );
      _selectedCountry = country['name'];
      _selectedCountryCode = country['code'];
      _currentStep = 1; // Skip to state selection
    }

    if (widget.initialAddress != null) {
      _loadInitialAddress(widget.initialAddress!);
    }
  }

  void _loadInitialAddress(StructuredAddress address) {
    // Pre-fill form with initial address
    _selectedCountry = address.country;
    _selectedCountryCode = address.countryCode;
    _selectedState = ''; // We don't store state separately yet
    _cityController.text = address.city;
    _streetController.text = address.streetName;
    _buildingNumberController.text = address.buildingNumber ?? '';
    _buildingNameController.text = address.buildingName ?? '';
    _floorController.text = address.floor ?? '';
    _apartmentController.text = address.apartmentNumber ?? '';
    _entranceController.text = address.entrance ?? '';
    _postalCodeController.text = address.postalCode ?? '';
    _landmarkController.text = address.landmark ?? '';
    _additionalInfoController.text = address.additionalInfo ?? '';

    // Create mock city and street results
    _selectedCity = CityResult(
      name: address.city,
      cityCode: address.cityCode,
      country: address.country,
      countryCode: address.countryCode,
      postalCode: address.postalCode,
      coordinates: address.coordinates,
      formattedAddress: address.toPublicAddress(),
    );

    _selectedStreet = StreetResult(
      name: address.streetName,
      type: address.streetType,
      city: address.city,
      cityCode: address.cityCode,
      coordinates: address.coordinates,
      formattedAddress: address.toApproximateAddress(),
    );

    _currentStep = 5; // Jump to review
  }

  @override
  void dispose() {
    _stateController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    _buildingNumberController.dispose();
    _buildingNameController.dispose();
    _floorController.dispose();
    _apartmentController.dispose();
    _entranceController.dispose();
    _postalCodeController.dispose();
    _landmarkController.dispose();
    _additionalInfoController.dispose();
    super.dispose();
  }

  // Search for states/provinces in selected country
  Future<void> _searchStates(String query) async {
    if (query.length < 2 || _selectedCountryCode == null) return;

    setState(() {
      _stateLoading = true;
      _stateSearchError = null;
    });

    try {
      // Search for admin regions (states/provinces) using city search with country filter
      final results = await _locationService.searchCities(
        query,
        countryCode: _selectedCountryCode!,
        limit: 20, // Show more results
      );

      setState(() {
        _stateSuggestions = results;
        _stateLoading = false;
      });
    } catch (e) {
      setState(() {
        _stateLoading = false;
        _stateSearchError = 'Unable to search. Please check your connection.';
      });
      DebugHelper.logError('State search error: $e');
    }
  }

  // Search for cities in selected state/country
  Future<void> _searchCities(String query) async {
    if (query.length < 2 || _selectedCountryCode == null) return;

    DebugHelper.log(
        'Searching cities: "$query" in country: $_selectedCountryCode');

    setState(() {
      _cityLoading = true;
      _citySearchError = null;
    });

    try {
      final results = await _locationService.searchCities(
        query,
        countryCode: _selectedCountryCode!,
        limit: 25, // Show even more cities
      );

      DebugHelper.logSuccess('Found ${results.length} cities for "$query"');

      setState(() {
        _citySuggestions = results;
        _cityLoading = false;
      });
    } catch (e) {
      DebugHelper.logError('City search error: $e');
      setState(() {
        _cityLoading = false;
        _citySearchError = 'Unable to search cities. Please try again.';
      });
    }
  }

  // Search for streets in selected city
  Future<void> _searchStreets(String query) async {
    if (query.length < 2 || _selectedCity == null) {
      DebugHelper.logWarning(
          'Cannot search streets: query too short or no city selected');
      return;
    }

    DebugHelper.log(
        'Searching streets: "$query" in ${_selectedCity!.name} (${_selectedCity!.cityCode})');

    setState(() {
      _streetLoading = true;
      _streetSearchError = null;
    });

    try {
      final results = await _locationService.searchStreets(
        query,
        _selectedCity!.cityCode ?? _selectedCity!.name,
        countryCode: _selectedCountryCode,
        limit: 30, // Show lots of street results
      );

      DebugHelper.logSuccess('Found ${results.length} streets for "$query"');

      setState(() {
        _streetSuggestions = results;
        _streetLoading = false;
      });
    } catch (e) {
      DebugHelper.logError('Street search error: $e');
      setState(() {
        _streetLoading = false;
        _streetSearchError = 'Unable to search streets. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Address',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getStepTitle(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Progress indicator
            _buildProgressIndicator(),
            const SizedBox(height: 24),

            // Step content
            _buildCurrentStep(),
            const SizedBox(height: 24),

            // Navigation buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Select your country';
      case 1:
        return 'Choose your state/region';
      case 2:
        return 'Find your city';
      case 3:
        return 'Pick your street';
      case 4:
        return 'Add details (optional)';
      case 5:
        return 'Review your address';
      default:
        return '';
    }
  }

  Widget _buildProgressIndicator() {
    final mainGreen = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: mainGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Step ${_currentStep + 1} of 6',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: mainGreen,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Text(
              '${(((_currentStep + 1) / 6) * 100).toInt()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: mainGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 6,
            minHeight: 10,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(mainGreen),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: List.generate(6, (index) {
            final isActive = index <= _currentStep;
            final isCompleted = index < _currentStep;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: isActive
                            ? mainGreen.withValues(alpha: 0.12)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive ? mainGreen : Colors.grey[300]!,
                          width: isActive ? 2.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? Icon(
                                Icons.check_circle,
                                color: mainGreen,
                                size: 20,
                              )
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isActive ? mainGreen : Colors.grey[400],
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (index < 5)
                    Container(
                      width: 6,
                      height: 2.5,
                      color:
                          index < _currentStep ? mainGreen : Colors.grey[300],
                    ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildCountryStep();
      case 1:
        return _buildStateStep();
      case 2:
        return _buildCityStep();
      case 3:
        return _buildStreetStep();
      case 4:
        return _buildDetailsStep();
      case 5:
        return _buildReviewStep();
      default:
        return Container();
    }
  }

  // Step 0: Country Selection
  Widget _buildCountryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.public, size: 26, color: Colors.blue),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Select Your Country',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Choose the country where you\'re located',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _countries.length,
              itemBuilder: (context, index) {
                final country = _countries[index];
                final isSelected = _selectedCountryCode == country['code'];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCountry = country['name'];
                        _selectedCountryCode = country['code'];
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).primaryColor.withValues(alpha: 0.12)
                            : null,
                        border: Border(
                          bottom:
                              BorderSide(color: Colors.grey[200]!, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            country['flag']!,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              country['name']!,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[800],
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // Step 1: State/Province Selection
  Widget _buildStateStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.map, size: 28, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'State or Region',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _selectedCountry ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _stateController,
          decoration: InputDecoration(
            labelText: 'State, Province, or Region',
            hintText: 'e.g., California, Ontario, Bavaria',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _stateLoading
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_stateSuggestions.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _stateController.clear();
                          setState(() => _stateSuggestions.clear());
                        },
                      )
                    : null),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            errorText: _stateSearchError,
          ),
          onChanged: (value) {
            _searchStates(value);
          },
        ),
        if (_stateSearchError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _stateSearchError!,
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_stateSuggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _stateSuggestions.length,
              itemBuilder: (context, index) {
                final state = _stateSuggestions[index];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedState = state.name;
                      _stateController.text = state.name;
                      _stateSuggestions.clear();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.map,
                            color: Colors.orange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (state.postalCode != null)
                                Text(
                                  state.postalCode!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // Step 2: City Selection (updated)
  Widget _buildCityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_city, size: 28, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Find Your City',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_selectedState ?? _selectedCountry}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _cityController,
          decoration: InputDecoration(
            labelText: 'City Name',
            hintText: 'e.g., Cairo, Los Angeles, London',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _cityLoading
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_citySuggestions.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _cityController.clear();
                          setState(() => _citySuggestions.clear());
                        },
                      )
                    : null),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            errorText: _citySearchError,
          ),
          onChanged: (value) {
            _searchCities(value);
          },
        ),
        if (_citySearchError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _citySearchError!,
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_citySuggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '${_citySuggestions.length} cities found',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 350),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _citySuggestions.length,
              itemBuilder: (context, index) {
                final city = _citySuggestions[index];
                return InkWell(
                  onTap: () => _selectCity(city),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_city,
                            color: Colors.green,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                city.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${city.country}${city.postalCode != null ? ' • ${city.postalCode}' : ''}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (_selectedCity != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected City',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        _selectedCity!.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Step 3: Street Selection (updated)
  Widget _buildStreetStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.signpost, size: 28, color: Colors.purple),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Your Street',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _selectedCity != null ? _selectedCity!.name : '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _streetController,
          decoration: InputDecoration(
            labelText: 'Street Name',
            hintText: 'e.g., Main Street, 5th Avenue, Tahrir Street',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _streetLoading
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_streetSuggestions.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _streetController.clear();
                          setState(() => _streetSuggestions.clear());
                        },
                      )
                    : null),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            errorText: _streetSearchError,
          ),
          onChanged: (value) {
            _searchStreets(value);
          },
        ),
        if (_streetSearchError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _streetSearchError!,
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_streetSuggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '${_streetSuggestions.length} streets found',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 350),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _streetSuggestions.length,
              itemBuilder: (context, index) {
                final street = _streetSuggestions[index];
                return InkWell(
                  onTap: () => _selectStreet(street),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.signpost,
                            color: Colors.purple,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                street.fullName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                street.city,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (_selectedStreet != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.purple, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Street',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple,
                        ),
                      ),
                      Text(
                        _selectedStreet!.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Step 4: Building Details (Optional)
  Widget _buildDetailsStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skip option at top
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This step is optional. Street address is usually enough for delivery.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Header with icon
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple.shade200, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.home_work,
                      size: 26, color: Colors.purple),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Additional Details (Optional)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.purple,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Help delivery find you faster',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Building Number (now Optional)
          const Text(
            'Building Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _buildingNumberController,
            decoration: InputDecoration(
              labelText: 'Building Number (Optional)',
              hintText: 'e.g., 123, 45A, Building 7',
              prefixIcon: const Icon(Icons.home, color: Colors.purple),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.purple, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            keyboardType: TextInputType.text,
            onChanged: (value) => setState(() {}), // Trigger validation check
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _buildingNameController,
            decoration: InputDecoration(
              labelText: 'Building/Complex Name (Optional)',
              hintText: 'e.g., Nile Towers, Al-Rehab City',
              prefixIcon: const Icon(Icons.apartment, color: Colors.purple),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.purple, width: 2),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Apartment Details (Optional)
          const Text(
            'Apartment Details (Optional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _floorController,
                  decoration: InputDecoration(
                    labelText: 'Floor',
                    hintText: 'e.g., 2nd, Ground',
                    prefixIcon: const Icon(Icons.stairs, color: Colors.purple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Colors.purple, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _apartmentController,
                  decoration: InputDecoration(
                    labelText: 'Apartment',
                    hintText: 'e.g., Apt 4B',
                    prefixIcon:
                        const Icon(Icons.door_front_door, color: Colors.purple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Colors.purple, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _entranceController,
            decoration: InputDecoration(
              labelText: 'Entrance (Optional)',
              hintText: 'e.g., Main entrance, Entrance A',
              prefixIcon: const Icon(Icons.input, color: Colors.purple),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.purple, width: 2),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Additional Information
          const Text(
            'Additional Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _postalCodeController,
            decoration: InputDecoration(
              labelText: 'Postal Code (Optional)',
              hintText: _selectedCity?.postalCode ?? 'e.g., 11511',
              prefixIcon:
                  const Icon(Icons.local_post_office, color: Colors.purple),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.purple, width: 2),
              ),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _landmarkController,
            decoration: InputDecoration(
              labelText: 'Nearby Landmark (Optional)',
              hintText: 'e.g., Near Carrefour, Behind hospital',
              prefixIcon: const Icon(Icons.place, color: Colors.purple),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.purple, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _additionalInfoController,
            decoration: InputDecoration(
              labelText: 'Delivery Instructions (Optional)',
              hintText: 'e.g., Ring doorbell twice, Call on arrival',
              prefixIcon: const Icon(Icons.info_outline, color: Colors.purple),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.purple, width: 2),
              ),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // Step 5: Review & Confirm
  Widget _buildReviewStep() {
    final mainGreen = Theme.of(context).primaryColor;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Clean white card with icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: mainGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 28,
                    color: mainGreen,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Review Your Address',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Verify all details before confirming',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Complete Address Preview - Clean card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: mainGreen.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: mainGreen, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Complete Address',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  _buildAddressPreview(),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section Title
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Address Details',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),

          // Detailed Breakdown - Clean cards
          _buildReviewItem(
            icon: Icons.public,
            label: 'Country',
            value: _selectedCountry ?? '',
            stepIndex: 0,
          ),
          if (_stateController.text.isNotEmpty)
            _buildReviewItem(
              icon: Icons.map,
              label: 'State/Province',
              value: _stateController.text,
              stepIndex: 1,
            ),
          if (_selectedCity != null)
            _buildReviewItem(
              icon: Icons.location_city,
              label: 'City',
              value: _selectedCity!.name,
              stepIndex: 2,
            ),
          if (_selectedStreet != null)
            _buildReviewItem(
              icon: Icons.route,
              label: 'Street',
              value: _selectedStreet!.name,
              stepIndex: 3,
            ),
          if (_buildingNumberController.text.isNotEmpty)
            _buildReviewItem(
              icon: Icons.home_work,
              label: 'Building',
              value: _buildingNumberController.text +
                  (_buildingNameController.text.isNotEmpty
                      ? ', ${_buildingNameController.text}'
                      : ''),
              stepIndex: 4,
            ),
          if (_apartmentController.text.isNotEmpty ||
              _floorController.text.isNotEmpty)
            _buildReviewItem(
              icon: Icons.apartment,
              label: 'Apartment',
              value: [
                if (_floorController.text.isNotEmpty)
                  'Floor ${_floorController.text}',
                if (_apartmentController.text.isNotEmpty)
                  _apartmentController.text,
              ].join(', '),
              stepIndex: 4,
            ),
          if (_entranceController.text.isNotEmpty)
            _buildReviewItem(
              icon: Icons.door_front_door,
              label: 'Entrance',
              value: _entranceController.text,
              stepIndex: 4,
            ),
          if (_postalCodeController.text.isNotEmpty)
            _buildReviewItem(
              icon: Icons.local_post_office,
              label: 'Postal Code',
              value: _postalCodeController.text,
              stepIndex: 4,
            ),
          if (_landmarkController.text.isNotEmpty)
            _buildReviewItem(
              icon: Icons.place,
              label: 'Nearby Landmark',
              value: _landmarkController.text,
              stepIndex: 4,
            ),
          if (_additionalInfoController.text.isNotEmpty)
            _buildReviewItem(
              icon: Icons.info_outline,
              label: 'Delivery Instructions',
              value: _additionalInfoController.text,
              stepIndex: 4,
            ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildReviewItem({
    required IconData icon,
    required String label,
    required String value,
    required int stepIndex,
  }) {
    final mainGreen = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _currentStep = stepIndex),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: mainGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: mainGreen, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final bool isLastStep = _currentStep == 5;
    final mainGreen = Theme.of(context).primaryColor;
    final bool canProceed = _canProceedToNextStep();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isGeocoding
                      ? null
                      : () => setState(() => _currentStep--),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    side: BorderSide(color: mainGreen, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(Icons.arrow_back, size: 20, color: mainGreen),
                  label: Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: mainGreen,
                    ),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: canProceed && !_isGeocoding
                      ? [
                          BoxShadow(
                            color: mainGreen.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: ElevatedButton.icon(
                  onPressed:
                      _isGeocoding ? null : (canProceed ? _handleNext : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    disabledBackgroundColor: Colors.grey[300],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isGeocoding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Icon(
                          isLastStep ? Icons.check_circle : Icons.arrow_forward,
                          size: 20,
                        ),
                  label: Text(
                    _isGeocoding
                        ? 'Processing...'
                        : (isLastStep ? 'Confirm Address' : 'Next Step'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (!canProceed && !_isGeocoding) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _getRequirementMessage(),
                    style: TextStyle(
                      color: Colors.orange[900],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _getRequirementMessage() {
    switch (_currentStep) {
      case 0:
        return 'Please select a country to continue';
      case 2:
        return 'Please search and select a city';
      case 3:
        return 'Please search and select a street';
      case 4:
        return 'Add building details or skip to continue';
      default:
        return 'Complete the required fields to continue';
    }
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0: // Country
        return _selectedCountry != null && _selectedCountry!.isNotEmpty;
      case 1: // State (optional for some countries)
        return true; // Can proceed even if empty
      case 2: // City
        return _selectedCity != null;
      case 3: // Street
        return _selectedStreet != null;
      case 4: // Building Details (now optional - street is enough)
        return true; // Can proceed with or without building details
      case 5: // Review
        return true; // Final step
      default:
        return false;
    }
  }

  void _handleNext() async {
    if (_currentStep < 5) {
      // Navigate to next step (0->1, 1->2, 2->3, 3->4, 4->5)
      setState(() => _currentStep++);
    } else if (_currentStep == 5) {
      // On review step (step 5) - complete the address
      await _completeAddress();
    }
  }

  Future<void> _completeAddress() async {
    setState(() => _isGeocoding = true);

    try {
      // Use city coordinates or street coordinates as base
      GeoPoint baseCoordinates = _selectedCity!.coordinates;
      if (_selectedStreet != null &&
          _selectedStreet!.coordinates.latitude != 0) {
        baseCoordinates = _selectedStreet!.coordinates;
      }

      DebugHelper.log(
          'Creating address with base coordinates: ${baseCoordinates.latitude}, ${baseCoordinates.longitude}');

      // Build structured address
      final address = StructuredAddress(
        city: _selectedCity!.name,
        cityCode: _selectedCity!.cityCode,
        country: _selectedCity!.country,
        countryCode: _selectedCity!.countryCode,
        streetName: _selectedStreet!.name,
        streetType: _selectedStreet!.type,
        buildingNumber: _buildingNumberController.text.isNotEmpty
            ? _buildingNumberController.text
            : null,
        buildingName: _buildingNameController.text.isNotEmpty
            ? _buildingNameController.text
            : null,
        floor: _floorController.text.isNotEmpty ? _floorController.text : null,
        apartmentNumber: _apartmentController.text.isNotEmpty
            ? _apartmentController.text
            : null,
        entrance: _entranceController.text.isNotEmpty
            ? _entranceController.text
            : null,
        postalCode: _postalCodeController.text.isNotEmpty
            ? _postalCodeController.text
            : _selectedCity!.postalCode,
        landmark: _landmarkController.text.isNotEmpty
            ? _landmarkController.text
            : null,
        additionalInfo: _additionalInfoController.text.isNotEmpty
            ? _additionalInfoController.text
            : null,
        coordinates: baseCoordinates, // Use base coordinates as fallback
        formattedAddress: '',
        createdAt: DateTime.now(),
      );

      DebugHelper.logInfo('Address created: ${address.toFullAddress()}');

      // Try to geocode to get precise coordinates (optional enhancement)
      GeoPoint finalCoordinates = baseCoordinates;
      try {
        final geocodedCoords = await _locationService.geocodeAddress(address);
        if (geocodedCoords.latitude != 0 && geocodedCoords.longitude != 0) {
          finalCoordinates = geocodedCoords;
          DebugHelper.logSuccess(
              'Geocoding successful: ${finalCoordinates.latitude}, ${finalCoordinates.longitude}');
        } else {
          DebugHelper.logWarning('Geocoding returned (0,0), using base coordinates');
        }
      } catch (e) {
        DebugHelper.logWarning('Geocoding failed, using base coordinates: $e');
      }

      // Create final address with best available coordinates
      final finalAddress = address.copyWith(
        coordinates: finalCoordinates,
        formattedAddress: address.toFullAddress(),
      );

      DebugHelper.logSuccess('Final address completed: ${finalAddress.formattedAddress}');
      DebugHelper.logInfo(
          'Final coordinates: ${finalAddress.coordinates.latitude}, ${finalAddress.coordinates.longitude}');

      if (mounted) {
        setState(() => _isGeocoding = false);
        widget.onAddressComplete(finalAddress);
      }
    } catch (e) {
      DebugHelper.logError('Error completing address: $e');
      if (mounted) {
        setState(() => _isGeocoding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing address: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String _buildAddressPreview() {
    final parts = <String>[];

    if (_buildingNumberController.text.isNotEmpty) {
      parts.add(_buildingNumberController.text);
    }
    if (_selectedStreet != null) {
      parts.add(_selectedStreet!.fullName);
    }
    if (_apartmentController.text.isNotEmpty) {
      parts.add('Apt ${_apartmentController.text}');
    }
    if (_floorController.text.isNotEmpty) {
      parts.add('Floor ${_floorController.text}');
    }
    if (_selectedCity != null) {
      parts.add(_selectedCity!.name);
    }

    return parts.isEmpty ? 'Complete all required fields' : parts.join(', ');
  }

  void _selectCity(CityResult city) {
    DebugHelper.log('City selected: ${city.name} (${city.cityCode})');
    DebugHelper.logInfo(
        'City coordinates: ${city.coordinates.latitude}, ${city.coordinates.longitude}');
    setState(() {
      _selectedCity = city;
      _cityController.text = city.name;
      _citySuggestions.clear();
      _postalCodeController.text = city.postalCode ?? '';
    });
  }

  void _selectStreet(StreetResult street) {
    DebugHelper.log('Street selected: ${street.name} in ${street.city}');
    DebugHelper.logInfo(
        'Street coordinates: ${street.coordinates.latitude}, ${street.coordinates.longitude}');
    setState(() {
      _selectedStreet = street;
      _streetController.text = street.fullName;
      _streetSuggestions.clear();
    });
  }
}
