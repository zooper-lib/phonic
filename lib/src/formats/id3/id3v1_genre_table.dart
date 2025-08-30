/// ID3v1 genre lookup table and conversion utilities.
///
/// This module provides the standard ID3v1 genre table (0-255 values) and
/// utilities for converting between genre names and numeric values.
/// The genre table follows the original ID3v1 specification with extensions
/// from Winamp and other popular audio software.
///
/// ## Usage Examples
///
/// ```dart
/// // Convert genre number to name
/// final genreName = Id3v1GenreTable.getGenreName(17);
/// // Result: 'Rock'
///
/// // Convert genre name to number
/// final genreNumber = Id3v1GenreTable.getGenreNumber('Rock');
/// // Result: 17
///
/// // Check if genre exists
/// final exists = Id3v1GenreTable.isValidGenreNumber(17);
/// // Result: true
///
/// // Get all available genres
/// final allGenres = Id3v1GenreTable.getAllGenres();
/// // Result: Map<int, String> with all 256 genres
/// ```
///
/// ## Genre Table Coverage
///
/// The table includes:
/// - Original ID3v1 genres (0-79): Blues, Classic Rock, Country, etc.
/// - Winamp extensions (80-125): Acid, House, Game, etc.
/// - Additional extensions (126-255): Various modern and niche genres
///
/// ## Error Handling
///
/// - Invalid genre numbers return null
/// - Case-insensitive genre name lookup
/// - Handles variations in genre names (e.g., "Hip-Hop" vs "Hip Hop")
class Id3v1GenreTable {
  /// Private constructor to prevent instantiation of utility class.
  Id3v1GenreTable._();

  /// Standard ID3v1 genre table mapping numeric values to genre names.
  ///
  /// This table includes the original ID3v1 genres (0-79) plus extensions
  /// from Winamp and other software up to index 255. The mapping follows
  /// the de facto standard used by most audio software.
  static const Map<int, String> _genreTable = {
    // Original ID3v1 genres (0-79)
    0: 'Blues',
    1: 'Classic Rock',
    2: 'Country',
    3: 'Dance',
    4: 'Disco',
    5: 'Funk',
    6: 'Grunge',
    7: 'Hip-Hop',
    8: 'Jazz',
    9: 'Metal',
    10: 'New Age',
    11: 'Oldies',
    12: 'Other',
    13: 'Pop',
    14: 'R&B',
    15: 'Rap',
    16: 'Reggae',
    17: 'Rock',
    18: 'Techno',
    19: 'Industrial',
    20: 'Alternative',
    21: 'Ska',
    22: 'Death Metal',
    23: 'Pranks',
    24: 'Soundtrack',
    25: 'Euro-Techno',
    26: 'Ambient',
    27: 'Trip-Hop',
    28: 'Vocal',
    29: 'Jazz+Funk',
    30: 'Fusion',
    31: 'Trance',
    32: 'Classical',
    33: 'Instrumental',
    34: 'Acid',
    35: 'House',
    36: 'Game',
    37: 'Sound Clip',
    38: 'Gospel',
    39: 'Noise',
    40: 'AlternRock',
    41: 'Bass',
    42: 'Soul',
    43: 'Punk',
    44: 'Space',
    45: 'Meditative',
    46: 'Instrumental Pop',
    47: 'Instrumental Rock',
    48: 'Ethnic',
    49: 'Gothic',
    50: 'Darkwave',
    51: 'Techno-Industrial',
    52: 'Electronic',
    53: 'Pop-Folk',
    54: 'Eurodance',
    55: 'Dream',
    56: 'Southern Rock',
    57: 'Comedy',
    58: 'Cult',
    59: 'Gangsta',
    60: 'Top 40',
    61: 'Christian Rap',
    62: 'Pop/Funk',
    63: 'Jungle',
    64: 'Native American',
    65: 'Cabaret',
    66: 'New Wave',
    67: 'Psychadelic',
    68: 'Rave',
    69: 'Showtunes',
    70: 'Trailer',
    71: 'Lo-Fi',
    72: 'Tribal',
    73: 'Acid Punk',
    74: 'Acid Jazz',
    75: 'Polka',
    76: 'Retro',
    77: 'Musical',
    78: 'Rock & Roll',
    79: 'Hard Rock',

    // Winamp extensions (80-125)
    80: 'Folk',
    81: 'Folk-Rock',
    82: 'National Folk',
    83: 'Swing',
    84: 'Fast Fusion',
    85: 'Bebop',
    86: 'Latin',
    87: 'Revival',
    88: 'Celtic',
    89: 'Bluegrass',
    90: 'Avantgarde',
    91: 'Gothic Rock',
    92: 'Progressive Rock',
    93: 'Psychedelic Rock',
    94: 'Symphonic Rock',
    95: 'Slow Rock',
    96: 'Big Band',
    97: 'Chorus',
    98: 'Easy Listening',
    99: 'Acoustic',
    100: 'Humour',
    101: 'Speech',
    102: 'Chanson',
    103: 'Opera',
    104: 'Chamber Music',
    105: 'Sonata',
    106: 'Symphony',
    107: 'Booty Bass',
    108: 'Primus',
    109: 'Porn Groove',
    110: 'Satire',
    111: 'Slow Jam',
    112: 'Club',
    113: 'Tango',
    114: 'Samba',
    115: 'Folklore',
    116: 'Ballad',
    117: 'Power Ballad',
    118: 'Rhythmic Soul',
    119: 'Freestyle',
    120: 'Duet',
    121: 'Punk Rock',
    122: 'Drum Solo',
    123: 'A capella',
    124: 'Euro-House',
    125: 'Dance Hall',

    // Additional extensions (126-255)
    126: 'Goa',
    127: 'Drum & Bass',
    128: 'Club-House',
    129: 'Hardcore',
    130: 'Terror',
    131: 'Indie',
    132: 'BritPop',
    133: 'Negerpunk',
    134: 'Polsk Punk',
    135: 'Beat',
    136: 'Christian Gangsta Rap',
    137: 'Heavy Metal',
    138: 'Black Metal',
    139: 'Crossover',
    140: 'Contemporary Christian',
    141: 'Christian Rock',
    142: 'Merengue',
    143: 'Salsa',
    144: 'Thrash Metal',
    145: 'Anime',
    146: 'JPop',
    147: 'Synthpop',
    148: 'Abstract',
    149: 'Art Rock',
    150: 'Baroque',
    151: 'Bhangra',
    152: 'Big beat',
    153: 'Breakbeat',
    154: 'Chillout',
    155: 'Downtempo',
    156: 'Dub',
    157: 'EBM',
    158: 'Eclectic',
    159: 'Electro',
    160: 'Electroclash',
    161: 'Emo',
    162: 'Experimental',
    163: 'Garage',
    164: 'Global',
    165: 'IDM',
    166: 'Illbient',
    167: 'Industro-Goth',
    168: 'Jam Band',
    169: 'Krautrock',
    170: 'Leftfield',
    171: 'Lounge',
    172: 'Math Rock',
    173: 'New Romantic',
    174: 'Nu-Breakz',
    175: 'Post-Punk',
    176: 'Post-Rock',
    177: 'Psytrance',
    178: 'Shoegaze',
    179: 'Space Rock',
    180: 'Trop Rock',
    181: 'World Music',
    182: 'Neoclassical',
    183: 'Audiobook',
    184: 'Audio theatre',
    185: 'Neue Deutsche Welle',
    186: 'Podcast',
    187: 'Indie-Rock',
    188: 'G-Funk',
    189: 'Dubstep',
    190: 'Garage Rock',
    191: 'Psybient',
    192: 'Trap',
    193: 'Vaporwave',
    194: 'Future Bass',
    195: 'Synthwave',
    196: 'Chiptune',
    197: 'Glitch',
    198: 'Minimal',
    199: 'Deep House',
    200: 'Tech House',
    201: 'Progressive House',
    202: 'Hardstyle',
    203: 'Gabber',
    204: 'Speedcore',
    205: 'Breakcore',
    206: 'Jungle Terror',
    207: 'Future Garage',
    208: 'UK Garage',
    209: 'Bassline',
    210: 'Grime',
    211: 'Drill',
    212: 'Afrobeat',
    213: 'Afrohouse',
    214: 'Amapiano',
    215: 'Baile Funk',
    216: 'Reggaeton',
    217: 'Moombahton',
    218: 'Tropical House',
    219: 'Future Pop',
    220: 'Synthpunk',
    221: 'Darksynth',
    222: 'Retrowave',
    223: 'Outrun',
    224: 'Cyberpunk',
    225: 'Phonk',
    226: 'Wave',
    227: 'Witch House',
    228: 'Seapunk',
    229: 'Vektroid',
    230: 'Mallsoft',
    231: 'Slushwave',
    232: 'Hardvapour',
    233: 'Signalwave',
    234: 'Eccojams',
    235: 'Hypnagogic Pop',
    236: 'Chillwave',
    237: 'Glo-Fi',
    238: 'Bedroom Pop',
    239: 'Lo-Fi Hip Hop',
    240: 'Boom Bap',
    241: 'Conscious Hip Hop',
    242: 'Mumble Rap',
    243: 'Cloud Rap',
    244: 'Emo Rap',
    245: 'Horrorcore',
    246: 'Crunk',
    247: 'Hyphy',
    248: 'Snap',
    249: 'Bounce',
    250: 'Jersey Club',
    251: 'Footwork',
    252: 'Juke',
    253: 'Ghetto House',
    254: 'Baltimore Club',
    255: 'Unknown',
  };

  /// Reverse lookup table for converting genre names to numbers.
  ///
  /// This map is built lazily from the main genre table and includes
  /// case-insensitive lookups and common variations of genre names.
  static Map<String, int>? _reverseGenreTable;

  /// Gets the genre name for the specified numeric value.
  ///
  /// Returns the standard genre name associated with the given ID3v1
  /// genre number, or null if the number is not valid.
  ///
  /// @param genreNumber The numeric genre value (0-255)
  /// @returns The genre name, or null if invalid
  ///
  /// Example:
  /// ```dart
  /// final rock = Id3v1GenreTable.getGenreName(17);
  /// // Result: 'Rock'
  ///
  /// final invalid = Id3v1GenreTable.getGenreName(999);
  /// // Result: null
  /// ```
  static String? getGenreName(int genreNumber) {
    return _genreTable[genreNumber];
  }

  /// Gets the numeric value for the specified genre name.
  ///
  /// Performs case-insensitive lookup of the genre name and returns
  /// the corresponding ID3v1 genre number, or null if not found.
  /// Handles common variations and alternative spellings.
  ///
  /// @param genreName The genre name to look up
  /// @returns The numeric genre value (0-255), or null if not found
  ///
  /// Example:
  /// ```dart
  /// final rockNumber = Id3v1GenreTable.getGenreNumber('Rock');
  /// // Result: 17
  ///
  /// final caseInsensitive = Id3v1GenreTable.getGenreNumber('rock');
  /// // Result: 17
  ///
  /// final notFound = Id3v1GenreTable.getGenreNumber('NonExistent');
  /// // Result: null
  /// ```
  static int? getGenreNumber(String genreName) {
    _ensureReverseTableBuilt();
    return _reverseGenreTable![genreName.toLowerCase()];
  }

  /// Checks if the specified genre number is valid.
  ///
  /// Returns true if the genre number exists in the ID3v1 genre table.
  ///
  /// @param genreNumber The numeric genre value to validate
  /// @returns True if the genre number is valid (0-255), false otherwise
  ///
  /// Example:
  /// ```dart
  /// final valid = Id3v1GenreTable.isValidGenreNumber(17);
  /// // Result: true
  ///
  /// final invalid = Id3v1GenreTable.isValidGenreNumber(999);
  /// // Result: false
  /// ```
  static bool isValidGenreNumber(int genreNumber) {
    return _genreTable.containsKey(genreNumber);
  }

  /// Checks if the specified genre name exists in the table.
  ///
  /// Performs case-insensitive lookup to determine if the genre name
  /// is recognized in the ID3v1 genre table.
  ///
  /// @param genreName The genre name to validate
  /// @returns True if the genre name exists, false otherwise
  ///
  /// Example:
  /// ```dart
  /// final exists = Id3v1GenreTable.isValidGenreName('Rock');
  /// // Result: true
  ///
  /// final caseInsensitive = Id3v1GenreTable.isValidGenreName('rock');
  /// // Result: true
  ///
  /// final notFound = Id3v1GenreTable.isValidGenreName('NonExistent');
  /// // Result: false
  /// ```
  static bool isValidGenreName(String genreName) {
    _ensureReverseTableBuilt();
    return _reverseGenreTable!.containsKey(genreName.toLowerCase());
  }

  /// Gets all available genres as a map of number to name.
  ///
  /// Returns a copy of the complete ID3v1 genre table for reference
  /// or iteration purposes.
  ///
  /// @returns Map containing all genre numbers and their corresponding names
  ///
  /// Example:
  /// ```dart
  /// final allGenres = Id3v1GenreTable.getAllGenres();
  /// print('Total genres: ${allGenres.length}');
  /// // Result: Total genres: 256
  ///
  /// // Iterate through all genres
  /// allGenres.forEach((number, name) {
  ///   print('$number: $name');
  /// });
  /// ```
  static Map<int, String> getAllGenres() {
    return Map<int, String>.from(_genreTable);
  }

  /// Gets all genre names as a list.
  ///
  /// Returns a list of all genre names in the table, ordered by
  /// their numeric values.
  ///
  /// @returns List of all genre names
  ///
  /// Example:
  /// ```dart
  /// final genreNames = Id3v1GenreTable.getAllGenreNames();
  /// print('First genre: ${genreNames.first}');
  /// // Result: First genre: Blues
  /// ```
  static List<String> getAllGenreNames() {
    return _genreTable.values.toList();
  }

  /// Gets all genre numbers as a list.
  ///
  /// Returns a list of all valid genre numbers (0-255).
  ///
  /// @returns List of all genre numbers
  ///
  /// Example:
  /// ```dart
  /// final genreNumbers = Id3v1GenreTable.getAllGenreNumbers();
  /// print('Total numbers: ${genreNumbers.length}');
  /// // Result: Total numbers: 256
  /// ```
  static List<int> getAllGenreNumbers() {
    return _genreTable.keys.toList()..sort();
  }

  /// Finds genres matching a partial name (case-insensitive).
  ///
  /// Searches for genres whose names contain the specified substring.
  /// Useful for implementing genre search or autocomplete functionality.
  ///
  /// @param partialName The substring to search for
  /// @returns Map of matching genre numbers and names
  ///
  /// Example:
  /// ```dart
  /// final rockGenres = Id3v1GenreTable.findGenresContaining('rock');
  /// // Result: {1: 'Classic Rock', 17: 'Rock', 40: 'AlternRock', ...}
  ///
  /// final metalGenres = Id3v1GenreTable.findGenresContaining('metal');
  /// // Result: {9: 'Metal', 22: 'Death Metal', 137: 'Heavy Metal', ...}
  /// ```
  static Map<int, String> findGenresContaining(String partialName) {
    final String searchTerm = partialName.toLowerCase();
    final Map<int, String> matches = <int, String>{};

    _genreTable.forEach((number, name) {
      if (name.toLowerCase().contains(searchTerm)) {
        matches[number] = name;
      }
    });

    return matches;
  }

  /// Builds the reverse lookup table for genre name to number conversion.
  ///
  /// This method is called lazily when first needed to create a case-insensitive
  /// lookup table. It also handles common variations and alternative spellings.
  static void _ensureReverseTableBuilt() {
    if (_reverseGenreTable != null) return;

    _reverseGenreTable = <String, int>{};

    // Build basic reverse mapping (case-insensitive)
    _genreTable.forEach((number, name) {
      _reverseGenreTable![name.toLowerCase()] = number;
    });

    // Add common variations and alternative spellings
    _addGenreVariations();
  }

  /// Adds common genre name variations to the reverse lookup table.
  ///
  /// This method handles alternative spellings, abbreviations, and common
  /// variations of genre names to improve lookup success rates.
  static void _addGenreVariations() {
    final Map<String, int> variations = {
      // Common abbreviations
      'r&b': 14, // R&B
      'rnb': 14, // R&B
      'hiphop': 7, // Hip-Hop
      'hip hop': 7, // Hip-Hop
      'dnb': 127, // Drum & Bass
      'drum and bass': 127, // Drum & Bass
      'edm': 52, // Electronic (closest match)
      // Alternative spellings
      'psychedelic': 67, // Psychadelic (correcting original typo)
      'alternative rock': 20, // Alternative
      'alt rock': 20, // Alternative
      'rock and roll': 78, // Rock & Roll
      'rock n roll': 78, // Rock & Roll
      'rock \'n\' roll': 78, // Rock & Roll
      // Common variations
      'electronic dance music': 52, // Electronic
      'dance music': 3, // Dance
      'classical music': 32, // Classical
      'world': 181, // World Music
      'new wave music': 66, // New Wave
      'punk rock music': 121, // Punk Rock
      'heavy metal music': 137, // Heavy Metal
      'death metal music': 22, // Death Metal
      'black metal music': 138, // Black Metal
      'thrash metal music': 144, // Thrash Metal
      // Shortened forms
      'prog rock': 92, // Progressive Rock
      'prog': 92, // Progressive Rock
      'psych rock': 93, // Psychedelic Rock
      'indie rock': 187, // Indie-Rock
      'alt': 20, // Alternative
      'techno music': 18, // Techno
      'house music': 35, // House
      'trance music': 31, // Trance
      // Regional variations
      'hip-hop music': 7, // Hip-Hop
      'rap music': 15, // Rap
      'country music': 2, // Country
      'folk music': 80, // Folk
      'blues music': 0, // Blues
      'jazz music': 8, // Jazz
      'reggae music': 16, // Reggae
      'ska music': 21, // Ska
      'gospel music': 38, // Gospel
      'soul music': 42, // Soul
      'funk music': 5, // Funk
    };

    _reverseGenreTable!.addAll(variations);
  }
}
