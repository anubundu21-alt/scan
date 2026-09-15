/// App Store Connect starting prices for monthly Scanella Pro
/// (`scanella_pro_monthly`), from Starting Price 2.csv, keyed by storefront.
class StorefrontPrice {
  const StorefrontPrice(this.currencyCode, this.amount);

  final String currencyCode;
  final double amount;

  static StorefrontPrice? monthly(String countryCode) =>
      monthlyStartingPrices[countryCode.toUpperCase()];
}

const monthlyStartingPrices = <String, StorefrontPrice>{
  'AE': StorefrontPrice('AED', 12.99), // United Arab Emirates
  'AF': StorefrontPrice('USD', 2.99), // Afghanistan
  'AG': StorefrontPrice('USD', 2.99), // Antigua and Barbuda
  'AI': StorefrontPrice('USD', 2.99), // Anguilla
  'AL': StorefrontPrice('USD', 3.99), // Albania
  'AM': StorefrontPrice('USD', 3.99), // Armenia
  'AO': StorefrontPrice('USD', 2.99), // Angola
  'AR': StorefrontPrice('USD', 2.99), // Argentina
  'AT': StorefrontPrice('EUR', 2.99), // Austria
  'AU': StorefrontPrice('AUD', 4.99), // Australia
  'AZ': StorefrontPrice('USD', 3.99), // Azerbaijan
  'BA': StorefrontPrice('EUR', 2.99), // Bosnia and Herzegovina
  'BB': StorefrontPrice('USD', 3.99), // Barbados
  'BE': StorefrontPrice('EUR', 2.99), // Belgium
  'BF': StorefrontPrice('USD', 2.99), // Burkina Faso
  'BG': StorefrontPrice('EUR', 2.99), // Bulgaria
  'BH': StorefrontPrice('USD', 2.99), // Bahrain
  'BJ': StorefrontPrice('USD', 3.99), // Benin
  'BM': StorefrontPrice('USD', 2.99), // Bermuda
  'BN': StorefrontPrice('USD', 2.99), // Brunei
  'BO': StorefrontPrice('USD', 2.99), // Bolivia
  'BR': StorefrontPrice('BRL', 19.9), // Brazil
  'BS': StorefrontPrice('USD', 2.99), // Bahamas
  'BT': StorefrontPrice('USD', 2.99), // Bhutan
  'BW': StorefrontPrice('USD', 2.99), // Botswana
  'BY': StorefrontPrice('USD', 3.99), // Belarus
  'BZ': StorefrontPrice('USD', 2.99), // Belize
  'CA': StorefrontPrice('CAD', 3.99), // Canada
  'CD': StorefrontPrice('USD', 2.99), // Congo, Democratic Republic of the
  'CG': StorefrontPrice('USD', 3.99), // Congo, Republic of the
  'CH': StorefrontPrice('CHF', 3), // Switzerland
  'CI': StorefrontPrice('USD', 3.99), // Côte d’Ivoire
  'CL': StorefrontPrice('CLP', 2990), // Chile
  'CM': StorefrontPrice('USD', 3.99), // Cameroon
  'CN': StorefrontPrice('CNY', 22), // China mainland
  'CO': StorefrontPrice('COP', 14900), // Colombia
  'CR': StorefrontPrice('USD', 2.99), // Costa Rica
  'CV': StorefrontPrice('USD', 2.99), // Cape Verde
  'CY': StorefrontPrice('EUR', 2.99), // Cyprus
  'CZ': StorefrontPrice('CZK', 79), // Czech Republic
  'DE': StorefrontPrice('EUR', 2.99), // Germany
  'DK': StorefrontPrice('DKK', 29), // Denmark
  'DM': StorefrontPrice('USD', 2.99), // Dominica
  'DO': StorefrontPrice('USD', 2.99), // Dominican Republic
  'DZ': StorefrontPrice('USD', 2.99), // Algeria
  'EC': StorefrontPrice('USD', 2.99), // Ecuador
  'EE': StorefrontPrice('EUR', 2.99), // Estonia
  'EG': StorefrontPrice('EGP', 149.99), // Egypt
  'ES': StorefrontPrice('EUR', 2.99), // Spain
  'FI': StorefrontPrice('EUR', 2.99), // Finland
  'FJ': StorefrontPrice('USD', 2.99), // Fiji
  'FM': StorefrontPrice('USD', 2.99), // Micronesia
  'FR': StorefrontPrice('EUR', 2.99), // France
  'GA': StorefrontPrice('USD', 2.99), // Gabon
  'GB': StorefrontPrice('GBP', 2.99), // United Kingdom
  'GD': StorefrontPrice('USD', 2.99), // Grenada
  'GE': StorefrontPrice('USD', 3.99), // Georgia
  'GH': StorefrontPrice('USD', 3.99), // Ghana
  'GM': StorefrontPrice('USD', 2.99), // Gambia
  'GR': StorefrontPrice('EUR', 2.99), // Greece
  'GT': StorefrontPrice('USD', 2.99), // Guatemala
  'GW': StorefrontPrice('USD', 2.99), // Guinea-Bissau
  'GY': StorefrontPrice('USD', 2.99), // Guyana
  'HK': StorefrontPrice('HKD', 22), // Hong Kong
  'HN': StorefrontPrice('USD', 2.99), // Honduras
  'HR': StorefrontPrice('EUR', 2.99), // Croatia
  'HU': StorefrontPrice('HUF', 1490), // Hungary
  'ID': StorefrontPrice('IDR', 59000), // Indonesia
  'IE': StorefrontPrice('EUR', 2.99), // Ireland
  'IL': StorefrontPrice('ILS', 9.9), // Israel
  'IN': StorefrontPrice('INR', 299), // India
  'IQ': StorefrontPrice('USD', 2.99), // Iraq
  'IS': StorefrontPrice('USD', 3.99), // Iceland
  'IT': StorefrontPrice('EUR', 2.99), // Italy
  'JM': StorefrontPrice('USD', 2.99), // Jamaica
  'JO': StorefrontPrice('USD', 2.99), // Jordan
  'JP': StorefrontPrice('JPY', 500), // Japan
  'KE': StorefrontPrice('USD', 3.99), // Kenya
  'KG': StorefrontPrice('USD', 2.99), // Kyrgyzstan
  'KH': StorefrontPrice('USD', 2.99), // Cambodia
  'KN': StorefrontPrice('USD', 2.99), // St. Kitts and Nevis
  'KR': StorefrontPrice('KRW', 4400), // Korea, Republic of
  'KW': StorefrontPrice('USD', 2.99), // Kuwait
  'KY': StorefrontPrice('USD', 2.99), // Cayman Islands
  'KZ': StorefrontPrice('KZT', 1790), // Kazakhstan
  'LA': StorefrontPrice('USD', 2.99), // Laos
  'LB': StorefrontPrice('USD', 2.99), // Lebanon
  'LC': StorefrontPrice('USD', 2.99), // St. Lucia
  'LK': StorefrontPrice('USD', 2.99), // Sri Lanka
  'LR': StorefrontPrice('USD', 2.99), // Liberia
  'LT': StorefrontPrice('EUR', 2.99), // Lithuania
  'LU': StorefrontPrice('EUR', 2.99), // Luxembourg
  'LV': StorefrontPrice('EUR', 2.99), // Latvia
  'LY': StorefrontPrice('USD', 2.99), // Libya
  'MA': StorefrontPrice('USD', 3.99), // Morocco
  'MD': StorefrontPrice('USD', 3.99), // Moldova
  'ME': StorefrontPrice('EUR', 2.99), // Montenegro
  'MG': StorefrontPrice('USD', 2.99), // Madagascar
  'MK': StorefrontPrice('USD', 2.99), // North Macedonia
  'ML': StorefrontPrice('USD', 2.99), // Mali
  'MM': StorefrontPrice('USD', 2.99), // Myanmar
  'MN': StorefrontPrice('USD', 2.99), // Mongolia
  'MO': StorefrontPrice('USD', 2.99), // Macau
  'MR': StorefrontPrice('USD', 2.99), // Mauritania
  'MS': StorefrontPrice('USD', 2.99), // Montserrat
  'MT': StorefrontPrice('EUR', 2.99), // Malta
  'MU': StorefrontPrice('USD', 3.99), // Mauritius
  'MV': StorefrontPrice('USD', 2.99), // Maldives
  'MW': StorefrontPrice('USD', 2.99), // Malawi
  'MX': StorefrontPrice('MXN', 69), // Mexico
  'MY': StorefrontPrice('MYR', 14.9), // Malaysia
  'MZ': StorefrontPrice('USD', 2.99), // Mozambique
  'NA': StorefrontPrice('USD', 2.99), // Namibia
  'NE': StorefrontPrice('USD', 2.99), // Niger
  'NG': StorefrontPrice('NGN', 4900), // Nigeria
  'NI': StorefrontPrice('USD', 2.99), // Nicaragua
  'NL': StorefrontPrice('EUR', 2.99), // Netherlands
  'NO': StorefrontPrice('NOK', 39), // Norway
  'NP': StorefrontPrice('USD', 3.99), // Nepal
  'NR': StorefrontPrice('USD', 2.99), // Nauru
  'NZ': StorefrontPrice('NZD', 4.99), // New Zealand
  'OM': StorefrontPrice('USD', 2.99), // Oman
  'PA': StorefrontPrice('USD', 2.99), // Panama
  'PE': StorefrontPrice('PEN', 12.9), // Peru
  'PG': StorefrontPrice('USD', 2.99), // Papua New Guinea
  'PH': StorefrontPrice('PHP', 199), // Philippines
  'PK': StorefrontPrice('PKR', 900), // Pakistan
  'PL': StorefrontPrice('PLN', 14.99), // Poland
  'PT': StorefrontPrice('EUR', 2.99), // Portugal
  'PW': StorefrontPrice('USD', 2.99), // Palau
  'PY': StorefrontPrice('USD', 2.99), // Paraguay
  'QA': StorefrontPrice('QAR', 9.99), // Qatar
  'RO': StorefrontPrice('RON', 14.99), // Romania
  'RS': StorefrontPrice('EUR', 2.99), // Serbia
  'RU': StorefrontPrice('RUB', 249), // Russia
  'RW': StorefrontPrice('USD', 2.99), // Rwanda
  'SA': StorefrontPrice('SAR', 12.99), // Saudi Arabia
  'SB': StorefrontPrice('USD', 2.99), // Solomon Islands
  'SC': StorefrontPrice('USD', 2.99), // Seychelles
  'SE': StorefrontPrice('SEK', 39), // Sweden
  'SG': StorefrontPrice('SGD', 3.98), // Singapore
  'SI': StorefrontPrice('EUR', 2.99), // Slovenia
  'SK': StorefrontPrice('EUR', 2.99), // Slovakia
  'SL': StorefrontPrice('USD', 2.99), // Sierra Leone
  'SN': StorefrontPrice('USD', 3.99), // Senegal
  'SR': StorefrontPrice('USD', 2.99), // Suriname
  'ST': StorefrontPrice('USD', 2.99), // São Tomé and Príncipe
  'SV': StorefrontPrice('USD', 2.99), // El Salvador
  'SZ': StorefrontPrice('USD', 2.99), // Eswatini
  'TC': StorefrontPrice('USD', 2.99), // Turks and Caicos Islands
  'TD': StorefrontPrice('USD', 2.99), // Chad
  'TH': StorefrontPrice('THB', 99), // Thailand
  'TJ': StorefrontPrice('USD', 2.99), // Tajikistan
  'TM': StorefrontPrice('USD', 2.99), // Turkmenistan
  'TN': StorefrontPrice('USD', 2.99), // Tunisia
  'TO': StorefrontPrice('USD', 2.99), // Tonga
  'TR': StorefrontPrice('TRY', 149.99), // Türkiye
  'TT': StorefrontPrice('USD', 2.99), // Trinidad and Tobago
  'TW': StorefrontPrice('TWD', 90), // Taiwan
  'TZ': StorefrontPrice('TZS', 9900), // Tanzania
  'UA': StorefrontPrice('USD', 3.99), // Ukraine
  'UG': StorefrontPrice('USD', 3.99), // Uganda
  'US': StorefrontPrice('USD', 2.99), // United States
  'UY': StorefrontPrice('USD', 2.99), // Uruguay
  'UZ': StorefrontPrice('USD', 2.99), // Uzbekistan
  'VC': StorefrontPrice('USD', 2.99), // St. Vincent and the Grenadines
  'VE': StorefrontPrice('USD', 2.99), // Venezuela
  'VG': StorefrontPrice('USD', 2.99), // British Virgin Islands
  'VN': StorefrontPrice('VND', 99000), // Vietnam
  'VU': StorefrontPrice('USD', 2.99), // Vanuatu
  'XK': StorefrontPrice('EUR', 2.99), // Kosovo
  'YE': StorefrontPrice('USD', 2.99), // Yemen
  'ZA': StorefrontPrice('ZAR', 59.99), // South Africa
  'ZM': StorefrontPrice('USD', 3.99), // Zambia
  'ZW': StorefrontPrice('USD', 3.99), // Zimbabwe
};
