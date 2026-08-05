/// Central index of every image shipped with the game.
///
/// The source art arrives as large atlases; a build-time pass cuts them into
/// individual transparent PNGs under `assets/sprites/<atlas>/NN.png`. The
/// constants below name the slices the game actually uses.
class Sprites {
  const Sprites._();

  static const _sprites = 'assets/sprites';
  static const _extra = 'assets/Velvet_Jester_Spin_additional_assets';
  static const _gameplay = 'assets/Velvet_Jester_Spin_gameplay_assets';

  static String _n(String dir, int i) => '$_sprites/$dir/${i.toString().padLeft(2, '0')}.png';

  // ---------------------------------------------------------------- screens
  static const gameName = '$_extra/Game_Name.webp';
  static const loadingPortrait = '$_extra/Vertical_Loading_Screen.webp';
  static const loadingLandscape = '$_extra/Horizontal_Loading_Screen.webp';

  /// Circular top-down arena floors, one per unlockable scene.
  static const stageFloors = <String>[
    '$_gameplay/bg_location_2_asset.webp',
    '$_gameplay/bg_location_6_asset.webp',
    '$_gameplay/bg_location_1_asset.webp',
    '$_gameplay/bg_location_3_asset.webp',
    '$_gameplay/bg_location_5_asset.webp',
    '$_gameplay/bg_location_4_asset.webp',
    '$_gameplay/bg_location_7_asset.webp',
  ];

  // ------------------------------------------------------------- role icons
  static String roleIcon(int i) => _n('role_icons_transformation_symbols', i);

  // ----------------------------------------------------------------- jester
  static String jester(int i) => _n('jester_character', i);

  static const jesterIdle = 0;
  static const jesterReady = 3;
  static const jesterPoint = 5;
  static const jesterCheer = 6;
  static const jesterShock = 7;
  static const jesterWand = 8;
  static const jesterLeap = 9;

  static String jesterSkin(int i) => _n('jester_skins', i);
  static const jesterSkinCount = 16;

  // -------------------------------------------------------- stage performers
  static String card(int i) => _n('playing_cards', i);
  static String spotlight(int i) => _n('spotlights', i);
  static String instrument(int i) => _n('musical_instruments', i);
  static String prop(int i) => _n('circus_props', i);
  static String animal(int i) => _n('circus_animals', i);
  static String audience(int i) => _n('audience_characters', i);
  static const audienceCount = 64;

  // ---------------------------------------------------------------- effects
  static String magic(int i) => _n('magic_effects', i);
  static String celebration(int i) => _n('celebration_effects', i);
  static String decoration(int i) => _n('stage_decorations', i);
  static String rope(int i) => _n('ropes_stage_elements', i);

  static const magicRings = <int>[0, 1, 2, 3, 4, 5, 6, 7];
  static const magicSparks = <int>[8, 9, 10, 11, 12, 13];
  static const magicSwirls = <int>[14, 15, 16, 17, 18];
  static const magicBursts = <int>[31, 32, 33, 34, 35];
  static const magicBeams = <int>[36, 37, 38, 39, 40];
  static const magicOrbs = <int>[47, 48, 49, 50];
  static const magicStars = <int>[51, 52, 53, 54, 55];
  static const magicPortals = <int>[68, 69, 70, 71, 72];
  static const magicFlames = <int>[73, 74, 75, 76, 77];

  static const confettiPoppers = <int>[15, 17, 18, 12, 13];
  static const fireworkRockets = <int>[0, 1, 2, 3];
  static const balloons = <int>[20, 21, 22, 24, 25];
  static const ribbons = <int>[30, 31, 32, 33];
  static const partyStars = <int>[38, 39, 40, 41];
  static const crown = 58;
  static const topHat = 55;
  static const carnivalMask = 56;

  static const curtainWide = 0;
  static const curtainDraped = 24;
  static const goldFlourish = 13;
  static const rosette = 39;
  static const circusTent = 44;

  /// Object pools drawn on the arena ring.
  static const cardPool = <int>[16, 17, 18, 19, 20, 21, 22, 23, 24, 30, 31, 32, 33, 25, 26, 27, 28, 29];
  static const spotlightPool = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
  static const instrumentPool = <int>[0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19, 20];
  static const propPool = <int>[2, 7, 12, 13, 20, 21, 26, 34, 35, 36, 38, 39, 40, 49, 50, 51, 59, 61];
  static const animalPool = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
}
