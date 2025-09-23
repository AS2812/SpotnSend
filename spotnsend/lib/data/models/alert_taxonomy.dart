/// Severity colors (hex) for UI chips and mapping
class SeverityColorHex {
  static const String red = "#D32F2F"; // Critical / طارئ حرج
  static const String yellow = "#FBC02D"; // Hazard / خطر متوسط
  static const String green = "#388E3C"; // Advisory / تنويه
  // Optional
  static const String orange = "#F57C00"; // Severe but stabilized / شديد
  static const String blue = "#1976D2"; // Information / FYI
  static const String grey = "#9E9E9E"; // Test / Drill
}

enum AlertCategory {
  roadTraffic,
  roadwayHazard,
  fireExplosion,
  buildingInfra,
  railPublicTransport,
  utilities,
  envWeather,
  medicalEmergency,
  occupationalIndustrial,
  publicSafetyCrime,
  marineWaterway,
}

/// Default severity color per category (string hex)
const Map<AlertCategory, String> categoryDefaultSeverityHex = {
  // RED
  AlertCategory.roadTraffic: SeverityColorHex.red,
  AlertCategory.fireExplosion: SeverityColorHex.red,
  AlertCategory.buildingInfra: SeverityColorHex.red,
  AlertCategory.railPublicTransport: SeverityColorHex.red,
  AlertCategory.medicalEmergency: SeverityColorHex.red,
  AlertCategory.occupationalIndustrial: SeverityColorHex.red,
  AlertCategory.marineWaterway: SeverityColorHex.red,
  // YELLOW
  AlertCategory.roadwayHazard: SeverityColorHex.yellow,
  AlertCategory.envWeather: SeverityColorHex.yellow,
  // GREEN
  AlertCategory.utilities: SeverityColorHex.green,
  AlertCategory.publicSafetyCrime: SeverityColorHex.green,
};

/// Subtype overrides → severity color hex (optional)
const Map<String, String> subtypeSeverityOverridesHex = {
  // ENV_WEATHER
  'FLASH_FLOOD': SeverityColorHex.red,
  'COASTAL_SURGE': SeverityColorHex.red,
  // UTILITIES
  'GAS_EMERGENCY': SeverityColorHex.red,
  // ROADWAY_HAZARD
  'SINKHOLE': SeverityColorHex.red,
  'OIL_SPILL': SeverityColorHex.yellow,
  // PUBLIC_SAFETY_CRIME
  'ROBBERY_IN_PROGRESS': SeverityColorHex.yellow,
};

/// English keys plus Arabic labels for UI chips (per category)
const Map<AlertCategory, Map<String, String>> categorySubtypes = {
  AlertCategory.roadTraffic: {
    'VEHICLE_COLLISION': 'حوادث مركبات',
    'SINGLE_VEHICLE': 'حادث مركبة منفرد',
    'PEDESTRIAN_STRUCK': 'دهس مشاة',
    'MOTORCYCLE': 'دراجة نارية',
    'PILEUP': 'تصادم متسلسل',
  },
  AlertCategory.roadwayHazard: {
    'POTHOLE': 'حفرة',
    'SINKHOLE': 'هبوط أرضي',
    'DEBRIS': 'مخلفات/عوائق',
    'OIL_SPILL': 'تسرب زيت',
    'SIGNAL_OUTAGE': 'تعطل إشارة',
    'STREETLIGHT_OUTAGE': 'تعطل إنارة',
  },
  AlertCategory.fireExplosion: {
    'BUILDING_FIRE': 'حريق مبنى',
    'VEHICLE_FIRE': 'حريق مركبة',
    'ELECTRICAL_FIRE': 'حريق كهربائي',
    'GAS_LEAK': 'تسرب غاز',
    'CYLINDER_BLAST': 'انفجار أسطوانة',
  },
  AlertCategory.buildingInfra: {
    'COLLAPSE': 'انهيار',
    'PARTIAL_COLLAPSE': 'انهيار جزئي',
    'FALLING_FACADE': 'سقوط واجهة',
    'ELEVATOR_FAILURE': 'تعطل مصعد',
    'SCAFFOLD_COLLAPSE': 'انهيار سقالة',
  },
  AlertCategory.railPublicTransport: {
    'TRAIN_COLLISION': 'تصادم قطار',
    'DERAILMENT': 'خروج عن المسار',
    'METRO_INCIDENT': 'حادث مترو',
    'BUS_CRASH': 'حادث حافلة',
  },
  AlertCategory.utilities: {
    'POWER_OUTAGE': 'انقطاع كهرباء',
    'WATER_CUT': 'انقطاع ماء',
    'GAS_EMERGENCY': 'طارئ غاز',
    'TELECOM_OUTAGE': 'انقطاع اتصالات',
  },
  AlertCategory.envWeather: {
    'SANDSTORM_KHAMASEEN': 'عاصفة رملية/خماسينية',
    'FLASH_FLOOD': 'سيول جارفة',
    'HEAVY_RAIN': 'أمطار غزيرة',
    'COASTAL_SURGE': 'مد بحري',
    'ROCKSLIDE': 'انهيار صخري',
  },
  AlertCategory.medicalEmergency: {
    'CARDIAC': 'قلبي',
    'RESPIRATORY': 'تنفسي',
    'INJURY_NO_COLLISION': 'إصابة دون حادث طريق',
    'MCI': 'إصابات جماعية',
  },
  AlertCategory.occupationalIndustrial: {
    'FACTORY_ACCIDENT': 'حادث مصنع',
    'CHEMICAL_SPILL': 'تسرب كيميائي',
    'CONSTRUCTION_INJURY': 'إصابة موقع عمل',
  },
  AlertCategory.publicSafetyCrime: {
    'VIOLENCE_NEARBY': 'عنف قريب',
    'ROBBERY_IN_PROGRESS': 'سطو جارٍ',
    'SUSPICIOUS_PACKAGE': 'طرد مشبوه',
  },
  AlertCategory.marineWaterway: {
    'BOAT_INCIDENT': 'حادث قارب',
    'DROWNING_RISK': 'خطر غرق',
    'PORT_HAZARD': 'خطر بالميناء',
  },
};
