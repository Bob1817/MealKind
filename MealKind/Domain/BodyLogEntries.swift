import Foundation

enum SleepQuality: String, Codable, CaseIterable, Identifiable, Equatable {
    case poor
    case fair
    case good

    var id: String { rawValue }

    func localizedName(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .poor: return "较差"
            case .fair: return "一般"
            case .good: return "良好"
            }
        }
        switch self {
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        }
    }

    var recoveryBoost: Int {
        switch self {
        case .poor: return -6
        case .fair: return 0
        case .good: return 6
        }
    }
}

struct SleepLog: Identifiable, Equatable {
    var id: UUID = UUID()
    var hoursSlept: Double
    var quality: SleepQuality
    var bedTime: Date?
    var wakeTime: Date?
    var note: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        hoursSlept: Double,
        quality: SleepQuality = .fair,
        bedTime: Date? = nil,
        wakeTime: Date? = nil,
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.hoursSlept = max(0, min(hoursSlept, 14))
        self.quality = quality
        self.bedTime = bedTime
        self.wakeTime = wakeTime
        self.note = note
        self.createdAt = createdAt
    }
}

struct WaterLog: Identifiable, Equatable {
    var id: UUID = UUID()
    var cupDelta: Int
    var loggedAt: Date
    var note: String

    init(
        id: UUID = UUID(),
        cupDelta: Int,
        loggedAt: Date = Date(),
        note: String = ""
    ) {
        self.id = id
        self.cupDelta = min(max(cupDelta, -20), 20)
        self.loggedAt = loggedAt
        self.note = note
    }
}

enum SupplementCategory: String, Codable, CaseIterable, Identifiable, Equatable {
    case creatine
    case fishOil
    case vitaminD
    case magnesium
    case electrolyte
    case multivitamin
    case custom

    var id: String { rawValue }

    func localizedName(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .creatine: return "肌酸"
            case .fishOil: return "鱼油"
            case .vitaminD: return "维生素 D3"
            case .magnesium: return "镁"
            case .electrolyte: return "电解质"
            case .multivitamin: return "复合维生素"
            case .custom: return "自定义"
            }
        }
        switch self {
        case .creatine: return "Creatine"
        case .fishOil: return "Fish oil"
        case .vitaminD: return "Vitamin D3"
        case .magnesium: return "Magnesium"
        case .electrolyte: return "Electrolyte"
        case .multivitamin: return "Multivitamin"
        case .custom: return "Custom"
        }
    }
}

struct SupplementLog: Identifiable, Equatable {
    var id: UUID = UUID()
    var category: SupplementCategory
    var name: String
    var dosage: String
    var takenAt: Date
    var note: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        category: SupplementCategory = .creatine,
        name: String,
        dosage: String = "",
        takenAt: Date = Date(),
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.dosage = dosage
        self.takenAt = takenAt
        self.note = note
        self.createdAt = createdAt
    }
}

enum MeasurementKind: String, Codable, CaseIterable, Identifiable, Equatable {
    case waist
    case hip
    case chest
    case thigh
    case arm
    case bodyFatPercentage

    var id: String { rawValue }

    var defaultUnit: String {
        switch self {
        case .bodyFatPercentage: return "%"
        default: return "cm"
        }
    }

    func localizedName(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .waist: return "腰围"
            case .hip: return "臀围"
            case .chest: return "胸围"
            case .thigh: return "大腿围"
            case .arm: return "臂围"
            case .bodyFatPercentage: return "体脂率"
            }
        }
        switch self {
        case .waist: return "Waist"
        case .hip: return "Hip"
        case .chest: return "Chest"
        case .thigh: return "Thigh"
        case .arm: return "Arm"
        case .bodyFatPercentage: return "Body fat %"
        }
    }
}

struct MeasurementLog: Identifiable, Equatable {
    var id: UUID = UUID()
    var kind: MeasurementKind
    var value: Double
    var unit: String
    var takenAt: Date
    var note: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        kind: MeasurementKind,
        value: Double,
        unit: String? = nil,
        takenAt: Date = Date(),
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.value = value
        self.unit = unit ?? kind.defaultUnit
        self.takenAt = takenAt
        self.note = note
        self.createdAt = createdAt
    }
}
