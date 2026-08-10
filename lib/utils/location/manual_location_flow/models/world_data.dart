// ─────────────────────────────────────────
// Model: WorldData
// Description: Static continent/country/city data for the manual picker.
// Contains: continents, countriesByContinent, cities
// ─────────────────────────────────────────

import 'manual_location_data.dart';

/// Complete list of all countries organized by continent
/// Full global coverage with flags and country codes
class WorldData {
  static const List<ContinentData> continents = [
    ContinentData(
      name: 'Africa',
      emoji: '🌍',
      countries: _africaCountries,
    ),
    ContinentData(
      name: 'Asia',
      emoji: '🌏',
      countries: _asiaCountries,
    ),
    ContinentData(
      name: 'Europe',
      emoji: '🇪🇺',
      countries: _europeCountries,
    ),
    ContinentData(
      name: 'North America',
      emoji: '🌎',
      countries: _northAmericaCountries,
    ),
    ContinentData(
      name: 'South America',
      emoji: '🌎',
      countries: _southAmericaCountries,
    ),
    ContinentData(
      name: 'Oceania',
      emoji: '🌊',
      countries: _oceaniaCountries,
    ),
  ];

  /// Get continent by name
  static ContinentData? getContinentByName(String name) {
    try {
      return continents.firstWhere(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Get country by code
  static CountryData? getCountryByCode(String code) {
    for (final continent in continents) {
      try {
        return continent.countries.firstWhere(
          (c) => c.code.toLowerCase() == code.toLowerCase(),
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Find continent for a country code
  static String? getContinentForCountry(String countryCode) {
    for (final continent in continents) {
      for (final country in continent.countries) {
        if (country.code.toLowerCase() == countryCode.toLowerCase()) {
          return continent.name;
        }
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AFRICA (54 countries)
  // ═══════════════════════════════════════════════════════════════════════════
  static const List<CountryData> _africaCountries = [
    CountryData(name: 'Algeria', code: 'DZ', flag: '🇩🇿', dialCode: '+213'),
    CountryData(name: 'Angola', code: 'AO', flag: '🇦🇴', dialCode: '+244'),
    CountryData(name: 'Benin', code: 'BJ', flag: '🇧🇯', dialCode: '+229'),
    CountryData(name: 'Botswana', code: 'BW', flag: '🇧🇼', dialCode: '+267'),
    CountryData(
        name: 'Burkina Faso', code: 'BF', flag: '🇧🇫', dialCode: '+226'),
    CountryData(name: 'Burundi', code: 'BI', flag: '🇧🇮', dialCode: '+257'),
    CountryData(name: 'Cabo Verde', code: 'CV', flag: '🇨🇻', dialCode: '+238'),
    CountryData(name: 'Cameroon', code: 'CM', flag: '🇨🇲', dialCode: '+237'),
    CountryData(
        name: 'Central African Republic',
        code: 'CF',
        flag: '🇨🇫',
        dialCode: '+236'),
    CountryData(name: 'Chad', code: 'TD', flag: '🇹🇩', dialCode: '+235'),
    CountryData(name: 'Comoros', code: 'KM', flag: '🇰🇲', dialCode: '+269'),
    CountryData(
        name: 'Congo (DRC)', code: 'CD', flag: '🇨🇩', dialCode: '+243'),
    CountryData(
        name: 'Congo (Republic)', code: 'CG', flag: '🇨🇬', dialCode: '+242'),
    CountryData(
        name: "Côte d'Ivoire", code: 'CI', flag: '🇨🇮', dialCode: '+225'),
    CountryData(name: 'Djibouti', code: 'DJ', flag: '🇩🇯', dialCode: '+253'),
    CountryData(name: 'Egypt', code: 'EG', flag: '🇪🇬', dialCode: '+20'),
    CountryData(
        name: 'Equatorial Guinea', code: 'GQ', flag: '🇬🇶', dialCode: '+240'),
    CountryData(name: 'Eritrea', code: 'ER', flag: '🇪🇷', dialCode: '+291'),
    CountryData(name: 'Eswatini', code: 'SZ', flag: '🇸🇿', dialCode: '+268'),
    CountryData(name: 'Ethiopia', code: 'ET', flag: '🇪🇹', dialCode: '+251'),
    CountryData(name: 'Gabon', code: 'GA', flag: '🇬🇦', dialCode: '+241'),
    CountryData(name: 'Gambia', code: 'GM', flag: '🇬🇲', dialCode: '+220'),
    CountryData(name: 'Ghana', code: 'GH', flag: '🇬🇭', dialCode: '+233'),
    CountryData(name: 'Guinea', code: 'GN', flag: '🇬🇳', dialCode: '+224'),
    CountryData(
        name: 'Guinea-Bissau', code: 'GW', flag: '🇬🇼', dialCode: '+245'),
    CountryData(name: 'Kenya', code: 'KE', flag: '🇰🇪', dialCode: '+254'),
    CountryData(name: 'Lesotho', code: 'LS', flag: '🇱🇸', dialCode: '+266'),
    CountryData(name: 'Liberia', code: 'LR', flag: '🇱🇷', dialCode: '+231'),
    CountryData(name: 'Libya', code: 'LY', flag: '🇱🇾', dialCode: '+218'),
    CountryData(name: 'Madagascar', code: 'MG', flag: '🇲🇬', dialCode: '+261'),
    CountryData(name: 'Malawi', code: 'MW', flag: '🇲🇼', dialCode: '+265'),
    CountryData(name: 'Mali', code: 'ML', flag: '🇲🇱', dialCode: '+223'),
    CountryData(name: 'Mauritania', code: 'MR', flag: '🇲🇷', dialCode: '+222'),
    CountryData(name: 'Mauritius', code: 'MU', flag: '🇲🇺', dialCode: '+230'),
    CountryData(name: 'Morocco', code: 'MA', flag: '🇲🇦', dialCode: '+212'),
    CountryData(name: 'Mozambique', code: 'MZ', flag: '🇲🇿', dialCode: '+258'),
    CountryData(name: 'Namibia', code: 'NA', flag: '🇳🇦', dialCode: '+264'),
    CountryData(name: 'Niger', code: 'NE', flag: '🇳🇪', dialCode: '+227'),
    CountryData(name: 'Nigeria', code: 'NG', flag: '🇳🇬', dialCode: '+234'),
    CountryData(name: 'Rwanda', code: 'RW', flag: '🇷🇼', dialCode: '+250'),
    CountryData(
        name: 'São Tomé and Príncipe',
        code: 'ST',
        flag: '🇸🇹',
        dialCode: '+239'),
    CountryData(name: 'Senegal', code: 'SN', flag: '🇸🇳', dialCode: '+221'),
    CountryData(name: 'Seychelles', code: 'SC', flag: '🇸🇨', dialCode: '+248'),
    CountryData(
        name: 'Sierra Leone', code: 'SL', flag: '🇸🇱', dialCode: '+232'),
    CountryData(name: 'Somalia', code: 'SO', flag: '🇸🇴', dialCode: '+252'),
    CountryData(
        name: 'South Africa', code: 'ZA', flag: '🇿🇦', dialCode: '+27'),
    CountryData(
        name: 'South Sudan', code: 'SS', flag: '🇸🇸', dialCode: '+211'),
    CountryData(name: 'Sudan', code: 'SD', flag: '🇸🇩', dialCode: '+249'),
    CountryData(name: 'Tanzania', code: 'TZ', flag: '🇹🇿', dialCode: '+255'),
    CountryData(name: 'Togo', code: 'TG', flag: '🇹🇬', dialCode: '+228'),
    CountryData(name: 'Tunisia', code: 'TN', flag: '🇹🇳', dialCode: '+216'),
    CountryData(name: 'Uganda', code: 'UG', flag: '🇺🇬', dialCode: '+256'),
    CountryData(name: 'Zambia', code: 'ZM', flag: '🇿🇲', dialCode: '+260'),
    CountryData(name: 'Zimbabwe', code: 'ZW', flag: '🇿🇼', dialCode: '+263'),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // ASIA (49 countries)
  // ═══════════════════════════════════════════════════════════════════════════
  static const List<CountryData> _asiaCountries = [
    CountryData(name: 'Afghanistan', code: 'AF', flag: '🇦🇫', dialCode: '+93'),
    CountryData(name: 'Armenia', code: 'AM', flag: '🇦🇲', dialCode: '+374'),
    CountryData(name: 'Azerbaijan', code: 'AZ', flag: '🇦🇿', dialCode: '+994'),
    CountryData(name: 'Bahrain', code: 'BH', flag: '🇧🇭', dialCode: '+973'),
    CountryData(name: 'Bangladesh', code: 'BD', flag: '🇧🇩', dialCode: '+880'),
    CountryData(name: 'Bhutan', code: 'BT', flag: '🇧🇹', dialCode: '+975'),
    CountryData(name: 'Brunei', code: 'BN', flag: '🇧🇳', dialCode: '+673'),
    CountryData(name: 'Cambodia', code: 'KH', flag: '🇰🇭', dialCode: '+855'),
    CountryData(name: 'China', code: 'CN', flag: '🇨🇳', dialCode: '+86'),
    CountryData(name: 'Cyprus', code: 'CY', flag: '🇨🇾', dialCode: '+357'),
    CountryData(name: 'Georgia', code: 'GE', flag: '🇬🇪', dialCode: '+995'),
    CountryData(name: 'India', code: 'IN', flag: '🇮🇳', dialCode: '+91'),
    CountryData(name: 'Indonesia', code: 'ID', flag: '🇮🇩', dialCode: '+62'),
    CountryData(name: 'Iran', code: 'IR', flag: '🇮🇷', dialCode: '+98'),
    CountryData(name: 'Iraq', code: 'IQ', flag: '🇮🇶', dialCode: '+964'),
    CountryData(name: 'Israel', code: 'IL', flag: '🇮🇱', dialCode: '+972'),
    CountryData(name: 'Japan', code: 'JP', flag: '🇯🇵', dialCode: '+81'),
    CountryData(name: 'Jordan', code: 'JO', flag: '🇯🇴', dialCode: '+962'),
    CountryData(name: 'Kazakhstan', code: 'KZ', flag: '🇰🇿', dialCode: '+7'),
    CountryData(name: 'Kuwait', code: 'KW', flag: '🇰🇼', dialCode: '+965'),
    CountryData(name: 'Kyrgyzstan', code: 'KG', flag: '🇰🇬', dialCode: '+996'),
    CountryData(name: 'Laos', code: 'LA', flag: '🇱🇦', dialCode: '+856'),
    CountryData(name: 'Lebanon', code: 'LB', flag: '🇱🇧', dialCode: '+961'),
    CountryData(name: 'Malaysia', code: 'MY', flag: '🇲🇾', dialCode: '+60'),
    CountryData(name: 'Maldives', code: 'MV', flag: '🇲🇻', dialCode: '+960'),
    CountryData(name: 'Mongolia', code: 'MN', flag: '🇲🇳', dialCode: '+976'),
    CountryData(name: 'Myanmar', code: 'MM', flag: '🇲🇲', dialCode: '+95'),
    CountryData(name: 'Nepal', code: 'NP', flag: '🇳🇵', dialCode: '+977'),
    CountryData(
        name: 'North Korea', code: 'KP', flag: '🇰🇵', dialCode: '+850'),
    CountryData(name: 'Oman', code: 'OM', flag: '🇴🇲', dialCode: '+968'),
    CountryData(name: 'Pakistan', code: 'PK', flag: '🇵🇰', dialCode: '+92'),
    CountryData(name: 'Palestine', code: 'PS', flag: '🇵🇸', dialCode: '+970'),
    CountryData(name: 'Philippines', code: 'PH', flag: '🇵🇭', dialCode: '+63'),
    CountryData(name: 'Qatar', code: 'QA', flag: '🇶🇦', dialCode: '+974'),
    CountryData(
        name: 'Saudi Arabia', code: 'SA', flag: '🇸🇦', dialCode: '+966'),
    CountryData(name: 'Singapore', code: 'SG', flag: '🇸🇬', dialCode: '+65'),
    CountryData(name: 'South Korea', code: 'KR', flag: '🇰🇷', dialCode: '+82'),
    CountryData(name: 'Sri Lanka', code: 'LK', flag: '🇱🇰', dialCode: '+94'),
    CountryData(name: 'Syria', code: 'SY', flag: '🇸🇾', dialCode: '+963'),
    CountryData(name: 'Taiwan', code: 'TW', flag: '🇹🇼', dialCode: '+886'),
    CountryData(name: 'Tajikistan', code: 'TJ', flag: '🇹🇯', dialCode: '+992'),
    CountryData(name: 'Thailand', code: 'TH', flag: '🇹🇭', dialCode: '+66'),
    CountryData(
        name: 'Timor-Leste', code: 'TL', flag: '🇹🇱', dialCode: '+670'),
    CountryData(name: 'Turkey', code: 'TR', flag: '🇹🇷', dialCode: '+90'),
    CountryData(
        name: 'Turkmenistan', code: 'TM', flag: '🇹🇲', dialCode: '+993'),
    CountryData(
        name: 'United Arab Emirates',
        code: 'AE',
        flag: '🇦🇪',
        dialCode: '+971'),
    CountryData(name: 'Uzbekistan', code: 'UZ', flag: '🇺🇿', dialCode: '+998'),
    CountryData(name: 'Vietnam', code: 'VN', flag: '🇻🇳', dialCode: '+84'),
    CountryData(name: 'Yemen', code: 'YE', flag: '🇾🇪', dialCode: '+967'),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // EUROPE (44 countries)
  // ═══════════════════════════════════════════════════════════════════════════
  static const List<CountryData> _europeCountries = [
    CountryData(name: 'Albania', code: 'AL', flag: '🇦🇱', dialCode: '+355'),
    CountryData(name: 'Andorra', code: 'AD', flag: '🇦🇩', dialCode: '+376'),
    CountryData(name: 'Austria', code: 'AT', flag: '🇦🇹', dialCode: '+43'),
    CountryData(name: 'Belarus', code: 'BY', flag: '🇧🇾', dialCode: '+375'),
    CountryData(name: 'Belgium', code: 'BE', flag: '🇧🇪', dialCode: '+32'),
    CountryData(
        name: 'Bosnia and Herzegovina',
        code: 'BA',
        flag: '🇧🇦',
        dialCode: '+387'),
    CountryData(name: 'Bulgaria', code: 'BG', flag: '🇧🇬', dialCode: '+359'),
    CountryData(name: 'Croatia', code: 'HR', flag: '🇭🇷', dialCode: '+385'),
    CountryData(
        name: 'Czech Republic', code: 'CZ', flag: '🇨🇿', dialCode: '+420'),
    CountryData(name: 'Denmark', code: 'DK', flag: '🇩🇰', dialCode: '+45'),
    CountryData(name: 'Estonia', code: 'EE', flag: '🇪🇪', dialCode: '+372'),
    CountryData(name: 'Finland', code: 'FI', flag: '🇫🇮', dialCode: '+358'),
    CountryData(name: 'France', code: 'FR', flag: '🇫🇷', dialCode: '+33'),
    CountryData(name: 'Germany', code: 'DE', flag: '🇩🇪', dialCode: '+49'),
    CountryData(name: 'Greece', code: 'GR', flag: '🇬🇷', dialCode: '+30'),
    CountryData(name: 'Hungary', code: 'HU', flag: '🇭🇺', dialCode: '+36'),
    CountryData(name: 'Iceland', code: 'IS', flag: '🇮🇸', dialCode: '+354'),
    CountryData(name: 'Ireland', code: 'IE', flag: '🇮🇪', dialCode: '+353'),
    CountryData(name: 'Italy', code: 'IT', flag: '🇮🇹', dialCode: '+39'),
    CountryData(name: 'Kosovo', code: 'XK', flag: '🇽🇰', dialCode: '+383'),
    CountryData(name: 'Latvia', code: 'LV', flag: '🇱🇻', dialCode: '+371'),
    CountryData(
        name: 'Liechtenstein', code: 'LI', flag: '🇱🇮', dialCode: '+423'),
    CountryData(name: 'Lithuania', code: 'LT', flag: '🇱🇹', dialCode: '+370'),
    CountryData(name: 'Luxembourg', code: 'LU', flag: '🇱🇺', dialCode: '+352'),
    CountryData(name: 'Malta', code: 'MT', flag: '🇲🇹', dialCode: '+356'),
    CountryData(name: 'Moldova', code: 'MD', flag: '🇲🇩', dialCode: '+373'),
    CountryData(name: 'Monaco', code: 'MC', flag: '🇲🇨', dialCode: '+377'),
    CountryData(name: 'Montenegro', code: 'ME', flag: '🇲🇪', dialCode: '+382'),
    CountryData(name: 'Netherlands', code: 'NL', flag: '🇳🇱', dialCode: '+31'),
    CountryData(
        name: 'North Macedonia', code: 'MK', flag: '🇲🇰', dialCode: '+389'),
    CountryData(name: 'Norway', code: 'NO', flag: '🇳🇴', dialCode: '+47'),
    CountryData(name: 'Poland', code: 'PL', flag: '🇵🇱', dialCode: '+48'),
    CountryData(name: 'Portugal', code: 'PT', flag: '🇵🇹', dialCode: '+351'),
    CountryData(name: 'Romania', code: 'RO', flag: '🇷🇴', dialCode: '+40'),
    CountryData(name: 'Russia', code: 'RU', flag: '🇷🇺', dialCode: '+7'),
    CountryData(name: 'San Marino', code: 'SM', flag: '🇸🇲', dialCode: '+378'),
    CountryData(name: 'Serbia', code: 'RS', flag: '🇷🇸', dialCode: '+381'),
    CountryData(name: 'Slovakia', code: 'SK', flag: '🇸🇰', dialCode: '+421'),
    CountryData(name: 'Slovenia', code: 'SI', flag: '🇸🇮', dialCode: '+386'),
    CountryData(name: 'Spain', code: 'ES', flag: '🇪🇸', dialCode: '+34'),
    CountryData(name: 'Sweden', code: 'SE', flag: '🇸🇪', dialCode: '+46'),
    CountryData(name: 'Switzerland', code: 'CH', flag: '🇨🇭', dialCode: '+41'),
    CountryData(name: 'Ukraine', code: 'UA', flag: '🇺🇦', dialCode: '+380'),
    CountryData(
        name: 'United Kingdom', code: 'GB', flag: '🇬🇧', dialCode: '+44'),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // NORTH AMERICA (23 countries)
  // ═══════════════════════════════════════════════════════════════════════════
  static const List<CountryData> _northAmericaCountries = [
    CountryData(
        name: 'Antigua and Barbuda',
        code: 'AG',
        flag: '🇦🇬',
        dialCode: '+1-268'),
    CountryData(name: 'Bahamas', code: 'BS', flag: '🇧🇸', dialCode: '+1-242'),
    CountryData(name: 'Barbados', code: 'BB', flag: '🇧🇧', dialCode: '+1-246'),
    CountryData(name: 'Belize', code: 'BZ', flag: '🇧🇿', dialCode: '+501'),
    CountryData(name: 'Canada', code: 'CA', flag: '🇨🇦', dialCode: '+1'),
    CountryData(name: 'Costa Rica', code: 'CR', flag: '🇨🇷', dialCode: '+506'),
    CountryData(name: 'Cuba', code: 'CU', flag: '🇨🇺', dialCode: '+53'),
    CountryData(name: 'Dominica', code: 'DM', flag: '🇩🇲', dialCode: '+1-767'),
    CountryData(
        name: 'Dominican Republic',
        code: 'DO',
        flag: '🇩🇴',
        dialCode: '+1-809'),
    CountryData(
        name: 'El Salvador', code: 'SV', flag: '🇸🇻', dialCode: '+503'),
    CountryData(name: 'Grenada', code: 'GD', flag: '🇬🇩', dialCode: '+1-473'),
    CountryData(name: 'Guatemala', code: 'GT', flag: '🇬🇹', dialCode: '+502'),
    CountryData(name: 'Haiti', code: 'HT', flag: '🇭🇹', dialCode: '+509'),
    CountryData(name: 'Honduras', code: 'HN', flag: '🇭🇳', dialCode: '+504'),
    CountryData(name: 'Jamaica', code: 'JM', flag: '🇯🇲', dialCode: '+1-876'),
    CountryData(name: 'Mexico', code: 'MX', flag: '🇲🇽', dialCode: '+52'),
    CountryData(name: 'Nicaragua', code: 'NI', flag: '🇳🇮', dialCode: '+505'),
    CountryData(name: 'Panama', code: 'PA', flag: '🇵🇦', dialCode: '+507'),
    CountryData(
        name: 'Saint Kitts and Nevis',
        code: 'KN',
        flag: '🇰🇳',
        dialCode: '+1-869'),
    CountryData(
        name: 'Saint Lucia', code: 'LC', flag: '🇱🇨', dialCode: '+1-758'),
    CountryData(
        name: 'Saint Vincent and the Grenadines',
        code: 'VC',
        flag: '🇻🇨',
        dialCode: '+1-784'),
    CountryData(
        name: 'Trinidad and Tobago',
        code: 'TT',
        flag: '🇹🇹',
        dialCode: '+1-868'),
    CountryData(
        name: 'United States', code: 'US', flag: '🇺🇸', dialCode: '+1'),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // SOUTH AMERICA (12 countries)
  // ═══════════════════════════════════════════════════════════════════════════
  static const List<CountryData> _southAmericaCountries = [
    CountryData(name: 'Argentina', code: 'AR', flag: '🇦🇷', dialCode: '+54'),
    CountryData(name: 'Bolivia', code: 'BO', flag: '🇧🇴', dialCode: '+591'),
    CountryData(name: 'Brazil', code: 'BR', flag: '🇧🇷', dialCode: '+55'),
    CountryData(name: 'Chile', code: 'CL', flag: '🇨🇱', dialCode: '+56'),
    CountryData(name: 'Colombia', code: 'CO', flag: '🇨🇴', dialCode: '+57'),
    CountryData(name: 'Ecuador', code: 'EC', flag: '🇪🇨', dialCode: '+593'),
    CountryData(name: 'Guyana', code: 'GY', flag: '🇬🇾', dialCode: '+592'),
    CountryData(name: 'Paraguay', code: 'PY', flag: '🇵🇾', dialCode: '+595'),
    CountryData(name: 'Peru', code: 'PE', flag: '🇵🇪', dialCode: '+51'),
    CountryData(name: 'Suriname', code: 'SR', flag: '🇸🇷', dialCode: '+597'),
    CountryData(name: 'Uruguay', code: 'UY', flag: '🇺🇾', dialCode: '+598'),
    CountryData(name: 'Venezuela', code: 'VE', flag: '🇻🇪', dialCode: '+58'),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // OCEANIA (14 countries)
  // ═══════════════════════════════════════════════════════════════════════════
  static const List<CountryData> _oceaniaCountries = [
    CountryData(name: 'Australia', code: 'AU', flag: '🇦🇺', dialCode: '+61'),
    CountryData(name: 'Fiji', code: 'FJ', flag: '🇫🇯', dialCode: '+679'),
    CountryData(name: 'Kiribati', code: 'KI', flag: '🇰🇮', dialCode: '+686'),
    CountryData(
        name: 'Marshall Islands', code: 'MH', flag: '🇲🇭', dialCode: '+692'),
    CountryData(name: 'Micronesia', code: 'FM', flag: '🇫🇲', dialCode: '+691'),
    CountryData(name: 'Nauru', code: 'NR', flag: '🇳🇷', dialCode: '+674'),
    CountryData(name: 'New Zealand', code: 'NZ', flag: '🇳🇿', dialCode: '+64'),
    CountryData(name: 'Palau', code: 'PW', flag: '🇵🇼', dialCode: '+680'),
    CountryData(
        name: 'Papua New Guinea', code: 'PG', flag: '🇵🇬', dialCode: '+675'),
    CountryData(name: 'Samoa', code: 'WS', flag: '🇼🇸', dialCode: '+685'),
    CountryData(
        name: 'Solomon Islands', code: 'SB', flag: '🇸🇧', dialCode: '+677'),
    CountryData(name: 'Tonga', code: 'TO', flag: '🇹🇴', dialCode: '+676'),
    CountryData(name: 'Tuvalu', code: 'TV', flag: '🇹🇻', dialCode: '+688'),
    CountryData(name: 'Vanuatu', code: 'VU', flag: '🇻🇺', dialCode: '+678'),
  ];
}
