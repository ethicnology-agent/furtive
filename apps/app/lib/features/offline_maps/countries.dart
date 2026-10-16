// GENERATED — do not edit by hand. See tool/generate_countries.py.
//
// Bounding boxes for the primary region of each country, from Natural Earth
// 110m admin-0 (public domain, naturalearthdata.com).
//
// "Primary region" rather than the whole country: a box around every piece of
// France would stretch from French Guiana to the Rhine, and a box around
// every piece of Fiji would wrap the planet. So each box covers the
// country's largest landmass, plus any part that is either within 500 km of
// it or at least a quarter of its size.
//
// Both halves of that are needed. Distance alone put Kuala Lumpur outside
// Malaysia, because the peninsula is 66% of the country's largest landmass
// and sits 833 km from it. Share alone would have pulled in French Guiana,
// which is 16% of metropolitan France and 6,879 km away. Together they keep
// Corsica with France and Northern Ireland with the United Kingdom, and
// leave out Hawaii and the Canaries.
//
// Names are English, as Natural Earth records them. They are not translated:
// the application ships 26 locales and no translated country list, and a
// half-translated picker reads worse than a consistently English one.

import 'package:geo/geo.dart';

/// A country the user can ask to keep, and the box it covers.
class Country {
  const Country(this.code, this.name, this.bounds);

  /// ISO 3166-1 alpha-2.
  final String code;

  final String name;

  final GeoBounds bounds;
}

/// Sorted by name, so a picker can show them as they come.
const countries = <Country>[
  Country(
    'AF',
    'Afghanistan',
    GeoBounds(west: 60.53, south: 29.32, east: 75.16, north: 38.49),
  ),
  Country(
    'AL',
    'Albania',
    GeoBounds(west: 19.30, south: 39.62, east: 21.02, north: 42.69),
  ),
  Country(
    'DZ',
    'Algeria',
    GeoBounds(west: -8.68, south: 19.06, east: 12.00, north: 37.12),
  ),
  Country(
    'AO',
    'Angola',
    GeoBounds(west: 11.64, south: -17.93, east: 24.08, north: -4.44),
  ),
  Country(
    'AR',
    'Argentina',
    GeoBounds(west: -73.42, south: -55.25, east: -53.63, north: -21.83),
  ),
  Country(
    'AM',
    'Armenia',
    GeoBounds(west: 43.58, south: 38.74, east: 46.51, north: 41.25),
  ),
  Country(
    'AU',
    'Australia',
    GeoBounds(west: 113.34, south: -43.63, east: 153.57, north: -10.67),
  ),
  Country(
    'AT',
    'Austria',
    GeoBounds(west: 9.48, south: 46.43, east: 16.98, north: 49.04),
  ),
  Country(
    'AZ',
    'Azerbaijan',
    GeoBounds(west: 44.79, south: 38.27, east: 50.39, north: 41.86),
  ),
  Country(
    'BD',
    'Bangladesh',
    GeoBounds(west: 88.08, south: 20.67, east: 92.67, north: 26.45),
  ),
  Country(
    'BY',
    'Belarus',
    GeoBounds(west: 23.20, south: 51.32, east: 32.69, north: 56.17),
  ),
  Country(
    'BE',
    'Belgium',
    GeoBounds(west: 2.51, south: 49.53, east: 6.16, north: 51.48),
  ),
  Country(
    'BZ',
    'Belize',
    GeoBounds(west: -89.23, south: 15.89, east: -88.11, north: 18.50),
  ),
  Country(
    'BJ',
    'Benin',
    GeoBounds(west: 0.77, south: 6.14, east: 3.80, north: 12.24),
  ),
  Country(
    'BT',
    'Bhutan',
    GeoBounds(west: 88.81, south: 26.72, east: 92.10, north: 28.30),
  ),
  Country(
    'BO',
    'Bolivia',
    GeoBounds(west: -69.59, south: -22.87, east: -57.50, north: -9.76),
  ),
  Country(
    'BA',
    'Bosnia and Herzegovina',
    GeoBounds(west: 15.75, south: 42.65, east: 19.60, north: 45.23),
  ),
  Country(
    'BW',
    'Botswana',
    GeoBounds(west: 19.90, south: -26.83, east: 29.43, north: -17.66),
  ),
  Country(
    'BR',
    'Brazil',
    GeoBounds(west: -73.99, south: -33.77, east: -34.73, north: 5.24),
  ),
  Country(
    'BN',
    'Brunei',
    GeoBounds(west: 114.20, south: 4.01, east: 115.45, north: 5.45),
  ),
  Country(
    'BG',
    'Bulgaria',
    GeoBounds(west: 22.38, south: 41.23, east: 28.56, north: 44.23),
  ),
  Country(
    'BF',
    'Burkina Faso',
    GeoBounds(west: -5.47, south: 9.61, east: 2.18, north: 15.12),
  ),
  Country(
    'BI',
    'Burundi',
    GeoBounds(west: 29.02, south: -4.50, east: 30.75, north: -2.35),
  ),
  Country(
    'KH',
    'Cambodia',
    GeoBounds(west: 102.35, south: 10.49, east: 107.61, north: 14.57),
  ),
  Country(
    'CM',
    'Cameroon',
    GeoBounds(west: 8.49, south: 1.73, east: 16.01, north: 12.86),
  ),
  Country(
    'CA',
    'Canada',
    GeoBounds(west: -141.00, south: 41.68, east: -52.65, north: 81.26),
  ),
  Country(
    'CF',
    'Central African Republic',
    GeoBounds(west: 14.46, south: 2.27, east: 27.37, north: 11.14),
  ),
  Country(
    'TD',
    'Chad',
    GeoBounds(west: 13.54, south: 7.42, east: 23.89, north: 23.41),
  ),
  Country(
    'CL',
    'Chile',
    GeoBounds(west: -75.64, south: -55.61, east: -66.96, north: -17.58),
  ),
  Country(
    'CN',
    'China',
    GeoBounds(west: 73.68, south: 18.20, east: 135.03, north: 53.46),
  ),
  Country(
    'CO',
    'Colombia',
    GeoBounds(west: -78.99, south: -4.30, east: -66.88, north: 12.44),
  ),
  Country(
    'CR',
    'Costa Rica',
    GeoBounds(west: -85.94, south: 8.23, east: -82.55, north: 11.22),
  ),
  Country(
    'HR',
    'Croatia',
    GeoBounds(west: 13.66, south: 42.48, east: 19.39, north: 46.50),
  ),
  Country(
    'CU',
    'Cuba',
    GeoBounds(west: -84.97, south: 19.86, east: -74.18, north: 23.19),
  ),
  Country(
    'CY',
    'Cyprus',
    GeoBounds(west: 32.26, south: 34.57, east: 34.00, north: 35.17),
  ),
  Country(
    'CZ',
    'Czechia',
    GeoBounds(west: 12.24, south: 48.56, east: 18.85, north: 51.12),
  ),
  Country(
    'CD',
    'Democratic Republic of the Congo',
    GeoBounds(west: 12.18, south: -13.26, east: 31.17, north: 5.26),
  ),
  Country(
    'DK',
    'Denmark',
    GeoBounds(west: 8.09, south: 54.80, east: 12.69, north: 57.73),
  ),
  Country(
    'DJ',
    'Djibouti',
    GeoBounds(west: 41.66, south: 10.93, east: 43.32, north: 12.70),
  ),
  Country(
    'DO',
    'Dominican Republic',
    GeoBounds(west: -71.95, south: 17.60, east: -68.32, north: 19.88),
  ),
  Country(
    'TL',
    'East Timor',
    GeoBounds(west: 124.97, south: -9.39, east: 127.34, north: -8.27),
  ),
  Country(
    'EC',
    'Ecuador',
    GeoBounds(west: -80.97, south: -4.96, east: -75.23, north: 1.38),
  ),
  Country(
    'EG',
    'Egypt',
    GeoBounds(west: 24.70, south: 22.00, east: 36.87, north: 31.59),
  ),
  Country(
    'SV',
    'El Salvador',
    GeoBounds(west: -90.10, south: 13.15, east: -87.72, north: 14.42),
  ),
  Country(
    'GQ',
    'Equatorial Guinea',
    GeoBounds(west: 9.31, south: 1.01, east: 11.29, north: 2.28),
  ),
  Country(
    'ER',
    'Eritrea',
    GeoBounds(west: 36.32, south: 12.46, east: 43.08, north: 18.00),
  ),
  Country(
    'EE',
    'Estonia',
    GeoBounds(west: 23.34, south: 57.47, east: 28.13, north: 59.61),
  ),
  Country(
    'ET',
    'Ethiopia',
    GeoBounds(west: 32.95, south: 3.42, east: 47.79, north: 14.96),
  ),
  Country(
    'FK',
    'Falkland Islands',
    GeoBounds(west: -61.20, south: -52.30, east: -57.75, north: -51.10),
  ),
  Country(
    'FJ',
    'Fiji',
    GeoBounds(west: 177.29, south: -18.29, east: 180.00, north: -16.07),
  ),
  Country(
    'FI',
    'Finland',
    GeoBounds(west: 20.65, south: 59.85, east: 31.52, north: 70.16),
  ),
  Country(
    'FR',
    'France',
    GeoBounds(west: -4.59, south: 41.38, east: 9.56, north: 51.15),
  ),
  Country(
    'TF',
    'French Southern and Antarctic Lands',
    GeoBounds(west: 68.72, south: -49.77, east: 70.56, north: -48.62),
  ),
  Country(
    'GA',
    'Gabon',
    GeoBounds(west: 8.80, south: -3.98, east: 14.43, north: 2.33),
  ),
  Country(
    'GM',
    'Gambia',
    GeoBounds(west: -16.84, south: 13.13, east: -13.84, north: 13.88),
  ),
  Country(
    'GE',
    'Georgia',
    GeoBounds(west: 39.96, south: 41.06, east: 46.64, north: 43.55),
  ),
  Country(
    'DE',
    'Germany',
    GeoBounds(west: 5.99, south: 47.30, east: 15.02, north: 54.98),
  ),
  Country(
    'GH',
    'Ghana',
    GeoBounds(west: -3.24, south: 4.71, east: 1.06, north: 11.10),
  ),
  Country(
    'GR',
    'Greece',
    GeoBounds(west: 20.15, south: 34.92, east: 26.60, north: 41.83),
  ),
  Country(
    'GL',
    'Greenland',
    GeoBounds(west: -73.30, south: 60.04, east: -12.21, north: 83.65),
  ),
  Country(
    'GT',
    'Guatemala',
    GeoBounds(west: -92.23, south: 13.74, east: -88.23, north: 17.82),
  ),
  Country(
    'GN',
    'Guinea',
    GeoBounds(west: -15.13, south: 7.31, east: -7.83, north: 12.59),
  ),
  Country(
    'GW',
    'Guinea-Bissau',
    GeoBounds(west: -16.68, south: 11.04, east: -13.70, north: 12.63),
  ),
  Country(
    'GY',
    'Guyana',
    GeoBounds(west: -61.41, south: 1.27, east: -56.54, north: 8.37),
  ),
  Country(
    'HT',
    'Haiti',
    GeoBounds(west: -74.46, south: 18.03, east: -71.62, north: 19.92),
  ),
  Country(
    'HN',
    'Honduras',
    GeoBounds(west: -89.35, south: 12.98, east: -83.15, north: 16.01),
  ),
  Country(
    'HU',
    'Hungary',
    GeoBounds(west: 16.20, south: 45.76, east: 22.71, north: 48.62),
  ),
  Country(
    'IS',
    'Iceland',
    GeoBounds(west: -24.33, south: 63.50, east: -13.61, north: 66.53),
  ),
  Country(
    'IN',
    'India',
    GeoBounds(west: 68.18, south: 7.97, east: 97.40, north: 35.49),
  ),
  Country(
    'ID',
    'Indonesia',
    GeoBounds(west: 95.29, south: -10.36, east: 141.03, north: 5.48),
  ),
  Country(
    'IR',
    'Iran',
    GeoBounds(west: 44.11, south: 25.08, east: 63.32, north: 39.71),
  ),
  Country(
    'IQ',
    'Iraq',
    GeoBounds(west: 38.79, south: 29.10, east: 48.57, north: 37.39),
  ),
  Country(
    'IE',
    'Ireland',
    GeoBounds(west: -9.98, south: 51.67, east: -6.03, north: 55.13),
  ),
  Country(
    'IL',
    'Israel',
    GeoBounds(west: 34.27, south: 29.50, east: 35.84, north: 33.28),
  ),
  Country(
    'IT',
    'Italy',
    GeoBounds(west: 6.75, south: 36.62, east: 18.48, north: 47.12),
  ),
  Country(
    'CI',
    'Ivory Coast',
    GeoBounds(west: -8.60, south: 4.34, east: -2.56, north: 10.52),
  ),
  Country(
    'JM',
    'Jamaica',
    GeoBounds(west: -78.34, south: 17.70, east: -76.20, north: 18.52),
  ),
  Country(
    'JP',
    'Japan',
    GeoBounds(west: 129.41, south: 31.03, east: 145.54, north: 45.55),
  ),
  Country(
    'JO',
    'Jordan',
    GeoBounds(west: 34.92, south: 29.20, east: 39.20, north: 33.38),
  ),
  Country(
    'KZ',
    'Kazakhstan',
    GeoBounds(west: 46.47, south: 40.66, east: 87.36, north: 55.39),
  ),
  Country(
    'KE',
    'Kenya',
    GeoBounds(west: 33.89, south: -4.68, east: 41.86, north: 5.51),
  ),
  Country(
    'XK',
    'Kosovo',
    GeoBounds(west: 20.07, south: 41.85, east: 21.78, north: 43.27),
  ),
  Country(
    'KW',
    'Kuwait',
    GeoBounds(west: 46.57, south: 28.53, east: 48.42, north: 30.06),
  ),
  Country(
    'KG',
    'Kyrgyzstan',
    GeoBounds(west: 69.46, south: 39.28, east: 80.26, north: 43.30),
  ),
  Country(
    'LA',
    'Laos',
    GeoBounds(west: 100.12, south: 13.88, east: 107.56, north: 22.46),
  ),
  Country(
    'LV',
    'Latvia',
    GeoBounds(west: 21.06, south: 55.62, east: 28.18, north: 57.97),
  ),
  Country(
    'LB',
    'Lebanon',
    GeoBounds(west: 35.13, south: 33.09, east: 36.61, north: 34.64),
  ),
  Country(
    'LS',
    'Lesotho',
    GeoBounds(west: 27.00, south: -30.65, east: 29.33, north: -28.65),
  ),
  Country(
    'LR',
    'Liberia',
    GeoBounds(west: -11.44, south: 4.36, east: -7.54, north: 8.54),
  ),
  Country(
    'LY',
    'Libya',
    GeoBounds(west: 9.32, south: 19.58, east: 25.16, north: 33.14),
  ),
  Country(
    'LT',
    'Lithuania',
    GeoBounds(west: 21.06, south: 53.91, east: 26.59, north: 56.37),
  ),
  Country(
    'LU',
    'Luxembourg',
    GeoBounds(west: 5.67, south: 49.44, east: 6.24, north: 50.13),
  ),
  Country(
    'MG',
    'Madagascar',
    GeoBounds(west: 43.25, south: -25.60, east: 50.48, north: -12.04),
  ),
  Country(
    'MW',
    'Malawi',
    GeoBounds(west: 32.69, south: -16.80, east: 35.77, north: -9.23),
  ),
  Country(
    'MY',
    'Malaysia',
    GeoBounds(west: 100.09, south: 0.77, east: 119.18, north: 6.93),
  ),
  Country(
    'ML',
    'Mali',
    GeoBounds(west: -12.17, south: 10.10, east: 4.27, north: 24.97),
  ),
  Country(
    'MR',
    'Mauritania',
    GeoBounds(west: -17.06, south: 14.62, east: -4.92, north: 27.40),
  ),
  Country(
    'MX',
    'Mexico',
    GeoBounds(west: -117.13, south: 14.54, east: -86.81, north: 32.72),
  ),
  Country(
    'MD',
    'Moldova',
    GeoBounds(west: 26.62, south: 45.49, east: 30.02, north: 48.47),
  ),
  Country(
    'MN',
    'Mongolia',
    GeoBounds(west: 87.75, south: 41.60, east: 119.77, north: 52.05),
  ),
  Country(
    'ME',
    'Montenegro',
    GeoBounds(west: 18.45, south: 41.88, east: 20.34, north: 43.52),
  ),
  Country(
    'MA',
    'Morocco',
    GeoBounds(west: -17.02, south: 21.42, east: -1.12, north: 35.76),
  ),
  Country(
    'MZ',
    'Mozambique',
    GeoBounds(west: 30.18, south: -26.74, east: 40.78, north: -10.32),
  ),
  Country(
    'MM',
    'Myanmar',
    GeoBounds(west: 92.30, south: 9.93, east: 101.18, north: 28.34),
  ),
  Country(
    'NA',
    'Namibia',
    GeoBounds(west: 11.73, south: -29.05, east: 25.08, north: -16.94),
  ),
  Country(
    'NP',
    'Nepal',
    GeoBounds(west: 80.09, south: 26.40, east: 88.17, north: 30.42),
  ),
  Country(
    'NL',
    'Netherlands',
    GeoBounds(west: 3.31, south: 50.80, east: 7.09, north: 53.51),
  ),
  Country(
    'NC',
    'New Caledonia',
    GeoBounds(west: 164.03, south: -22.40, east: 167.12, north: -20.11),
  ),
  Country(
    'NZ',
    'New Zealand',
    GeoBounds(west: 166.51, south: -46.64, east: 178.52, north: -34.45),
  ),
  Country(
    'NI',
    'Nicaragua',
    GeoBounds(west: -87.67, south: 10.73, east: -83.15, north: 15.02),
  ),
  Country(
    'NE',
    'Niger',
    GeoBounds(west: 0.30, south: 11.66, east: 15.90, north: 23.47),
  ),
  Country(
    'NG',
    'Nigeria',
    GeoBounds(west: 2.69, south: 4.24, east: 14.58, north: 13.87),
  ),
  Country(
    'KP',
    'North Korea',
    GeoBounds(west: 124.27, south: 37.67, east: 130.78, north: 42.99),
  ),
  Country(
    'MK',
    'North Macedonia',
    GeoBounds(west: 20.46, south: 40.84, east: 22.95, north: 42.32),
  ),
  Country(
    'NO',
    'Norway',
    GeoBounds(west: 4.99, south: 58.08, east: 31.29, north: 71.19),
  ),
  Country(
    'OM',
    'Oman',
    GeoBounds(west: 52.00, south: 16.65, east: 59.81, north: 26.40),
  ),
  Country(
    'PK',
    'Pakistan',
    GeoBounds(west: 60.87, south: 23.69, east: 77.84, north: 37.13),
  ),
  Country(
    'PS',
    'Palestine',
    GeoBounds(west: 34.93, south: 31.35, east: 35.55, north: 32.53),
  ),
  Country(
    'PA',
    'Panama',
    GeoBounds(west: -82.97, south: 7.22, east: -77.24, north: 9.61),
  ),
  Country(
    'PG',
    'Papua New Guinea',
    GeoBounds(west: 141.00, south: -10.65, east: 156.02, north: -2.50),
  ),
  Country(
    'PY',
    'Paraguay',
    GeoBounds(west: -62.69, south: -27.55, east: -54.29, north: -19.34),
  ),
  Country(
    'PE',
    'Peru',
    GeoBounds(west: -81.41, south: -18.35, east: -68.67, north: -0.06),
  ),
  Country(
    'PH',
    'Philippines',
    GeoBounds(west: 117.17, south: 5.58, east: 126.54, north: 18.51),
  ),
  Country(
    'PL',
    'Poland',
    GeoBounds(west: 14.07, south: 49.03, east: 24.03, north: 54.85),
  ),
  Country(
    'PT',
    'Portugal',
    GeoBounds(west: -9.53, south: 36.84, east: -6.39, north: 42.28),
  ),
  Country(
    'PR',
    'Puerto Rico',
    GeoBounds(west: -67.24, south: 17.95, east: -65.59, north: 18.52),
  ),
  Country(
    'QA',
    'Qatar',
    GeoBounds(west: 50.74, south: 24.56, east: 51.61, north: 26.11),
  ),
  Country(
    'RS',
    'Republic of Serbia',
    GeoBounds(west: 18.83, south: 42.25, east: 22.99, north: 46.17),
  ),
  Country(
    'CG',
    'Republic of the Congo',
    GeoBounds(west: 11.09, south: -5.04, east: 18.45, north: 3.73),
  ),
  Country(
    'RO',
    'Romania',
    GeoBounds(west: 20.22, south: 43.69, east: 29.63, north: 48.22),
  ),
  Country(
    'RU',
    'Russia',
    GeoBounds(west: 19.66, south: 41.15, east: 180.00, north: 81.25),
  ),
  Country(
    'RW',
    'Rwanda',
    GeoBounds(west: 29.02, south: -2.92, east: 30.82, north: -1.13),
  ),
  Country(
    'SA',
    'Saudi Arabia',
    GeoBounds(west: 34.63, south: 16.35, east: 55.67, north: 32.16),
  ),
  Country(
    'SN',
    'Senegal',
    GeoBounds(west: -17.63, south: 12.33, east: -11.47, north: 16.60),
  ),
  Country(
    'SL',
    'Sierra Leone',
    GeoBounds(west: -13.25, south: 6.79, east: -10.23, north: 10.05),
  ),
  Country(
    'SK',
    'Slovakia',
    GeoBounds(west: 16.88, south: 47.76, east: 22.56, north: 49.57),
  ),
  Country(
    'SI',
    'Slovenia',
    GeoBounds(west: 13.70, south: 45.45, east: 16.56, north: 46.85),
  ),
  Country(
    'SB',
    'Solomon Islands',
    GeoBounds(west: 156.49, south: -10.83, east: 162.40, north: -6.60),
  ),
  Country(
    'SO',
    'Somalia',
    GeoBounds(west: 40.98, south: -1.68, east: 51.13, north: 12.02),
  ),
  Country(
    'ZA',
    'South Africa',
    GeoBounds(west: 16.34, south: -34.82, east: 32.83, north: -22.09),
  ),
  Country(
    'KR',
    'South Korea',
    GeoBounds(west: 126.12, south: 34.39, east: 129.47, north: 38.61),
  ),
  Country(
    'SS',
    'South Sudan',
    GeoBounds(west: 23.89, south: 3.51, east: 35.30, north: 12.25),
  ),
  Country(
    'ES',
    'Spain',
    GeoBounds(west: -9.39, south: 35.95, east: 3.04, north: 43.75),
  ),
  Country(
    'LK',
    'Sri Lanka',
    GeoBounds(west: 79.70, south: 5.97, east: 81.79, north: 9.82),
  ),
  Country(
    'SD',
    'Sudan',
    GeoBounds(west: 21.94, south: 8.23, east: 38.41, north: 22.00),
  ),
  Country(
    'SR',
    'Suriname',
    GeoBounds(west: -58.04, south: 1.82, east: -53.96, north: 6.03),
  ),
  Country(
    'SE',
    'Sweden',
    GeoBounds(west: 11.03, south: 55.36, east: 23.90, north: 69.11),
  ),
  Country(
    'CH',
    'Switzerland',
    GeoBounds(west: 6.02, south: 45.78, east: 10.44, north: 47.83),
  ),
  Country(
    'SY',
    'Syria',
    GeoBounds(west: 35.70, south: 32.31, east: 42.35, north: 37.23),
  ),
  Country(
    'TW',
    'Taiwan',
    GeoBounds(west: 120.11, south: 21.97, east: 121.95, north: 25.30),
  ),
  Country(
    'TJ',
    'Tajikistan',
    GeoBounds(west: 67.44, south: 36.74, east: 74.98, north: 40.96),
  ),
  Country(
    'TH',
    'Thailand',
    GeoBounds(west: 97.38, south: 5.69, east: 105.59, north: 20.42),
  ),
  Country(
    'BS',
    'The Bahamas',
    GeoBounds(west: -78.98, south: 23.71, east: -77.00, north: 27.04),
  ),
  Country(
    'TG',
    'Togo',
    GeoBounds(west: -0.05, south: 5.93, east: 1.87, north: 11.02),
  ),
  Country(
    'TT',
    'Trinidad and Tobago',
    GeoBounds(west: -61.95, south: 10.00, east: -60.90, north: 10.89),
  ),
  Country(
    'TN',
    'Tunisia',
    GeoBounds(west: 7.52, south: 30.31, east: 11.49, north: 37.35),
  ),
  Country(
    'TR',
    'Turkey',
    GeoBounds(west: 26.04, south: 35.82, east: 44.79, north: 42.14),
  ),
  Country(
    'TM',
    'Turkmenistan',
    GeoBounds(west: 52.50, south: 35.27, east: 66.55, north: 42.75),
  ),
  Country(
    'UG',
    'Uganda',
    GeoBounds(west: 29.58, south: -1.44, east: 35.04, north: 4.25),
  ),
  Country(
    'UA',
    'Ukraine',
    GeoBounds(west: 22.09, south: 45.29, east: 40.08, north: 52.34),
  ),
  Country(
    'AE',
    'United Arab Emirates',
    GeoBounds(west: 51.58, south: 22.50, east: 56.40, north: 26.06),
  ),
  Country(
    'GB',
    'United Kingdom',
    GeoBounds(west: -7.57, south: 49.96, east: 1.68, north: 58.63),
  ),
  Country(
    'TZ',
    'United Republic of Tanzania',
    GeoBounds(west: 29.34, south: -11.72, east: 40.32, north: -0.95),
  ),
  Country(
    'US',
    'United States of America',
    GeoBounds(west: -124.69, south: 25.08, east: -66.96, north: 49.39),
  ),
  Country(
    'UY',
    'Uruguay',
    GeoBounds(west: -58.43, south: -34.95, east: -53.21, north: -30.11),
  ),
  Country(
    'UZ',
    'Uzbekistan',
    GeoBounds(west: 55.93, south: 37.14, east: 73.06, north: 45.59),
  ),
  Country(
    'VU',
    'Vanuatu',
    GeoBounds(west: 166.63, south: -16.60, east: 167.84, north: -14.63),
  ),
  Country(
    'VE',
    'Venezuela',
    GeoBounds(west: -73.30, south: 0.72, east: -59.76, north: 12.16),
  ),
  Country(
    'VN',
    'Vietnam',
    GeoBounds(west: 102.17, south: 8.60, east: 109.34, north: 23.35),
  ),
  Country(
    'EH',
    'Western Sahara',
    GeoBounds(west: -17.06, south: 21.00, east: -8.67, north: 27.66),
  ),
  Country(
    'YE',
    'Yemen',
    GeoBounds(west: 42.60, south: 12.59, east: 53.11, north: 19.00),
  ),
  Country(
    'ZM',
    'Zambia',
    GeoBounds(west: 21.89, south: -17.96, east: 33.49, north: -8.24),
  ),
  Country(
    'ZW',
    'Zimbabwe',
    GeoBounds(west: 25.26, south: -22.27, east: 32.85, north: -15.51),
  ),
  Country(
    'SZ',
    'eSwatini',
    GeoBounds(west: 30.68, south: -27.29, east: 32.07, north: -25.66),
  ),
];
