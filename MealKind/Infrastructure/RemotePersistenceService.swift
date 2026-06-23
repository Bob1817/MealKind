import Foundation

struct RemotePersistenceConfig: Sendable {
    var baseURL: URL?

    static var appDefault: RemotePersistenceConfig {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: "PersistenceEndpoint") as? String
        return RemotePersistenceConfig(baseURL: rawValue.flatMap(URL.init(string:)))
    }
}

struct RemotePersistenceService {
    typealias DataLoader = @MainActor (URLRequest) async throws -> (Data, URLResponse)

    private let config: RemotePersistenceConfig
    private let dataLoader: DataLoader
    private let store: UserDefaults

    init(
        config: RemotePersistenceConfig = .appDefault,
        store: UserDefaults = .standard,
        dataLoader: @escaping DataLoader = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.config = config
        self.store = store
        self.dataLoader = dataLoader
    }

    @MainActor
    func sync(snapshot: RemotePersistenceSnapshot, language: AppLanguage) async {
        guard let baseURL = config.baseURL else { return }

        do {
            let token = try await token(baseURL: baseURL, language: language)
            let request = ClientSyncRequest(records: snapshot.records, replaceAll: true)
            _ = try await send(
                request,
                to: baseURL.appending(path: "api/client/sync"),
                token: token,
                responseType: ClientSyncResponse.self
            )
            store.set(Date().timeIntervalSince1970, forKey: Keys.lastSyncAt)
        } catch {
            store.set(Date().timeIntervalSince1970, forKey: Keys.lastSyncFailedAt)
        }
    }

    @MainActor
    func export(language: AppLanguage) async -> RemotePersistenceExport? {
        guard let baseURL = config.baseURL else { return nil }

        do {
            let token = try await token(baseURL: baseURL, language: language)
            return try await get(
                baseURL.appending(path: "api/client/export"),
                token: token,
                responseType: RemotePersistenceExport.self
            )
        } catch {
            return nil
        }
    }

    @MainActor
    func clearRemoteData(language: AppLanguage) async -> Bool {
        guard let baseURL = config.baseURL else { return false }

        do {
            let token = try await token(baseURL: baseURL, language: language)
            _ = try await send(
                EmptyRequest(),
                to: baseURL.appending(path: "api/client/clear"),
                token: token,
                responseType: BasicClientResponse.self
            )
            return true
        } catch {
            return false
        }
    }

    @MainActor
    func deleteRemoteAccount(language: AppLanguage, reason: String = "client_request") async -> Bool {
        guard let baseURL = config.baseURL else { return false }

        do {
            let token = try await token(baseURL: baseURL, language: language)
            _ = try await send(
                DeleteAccountRequest(reason: reason),
                to: baseURL.appending(path: "api/client/delete-account"),
                token: token,
                responseType: BasicClientResponse.self
            )
            store.removeObject(forKey: Keys.token)
            store.removeObject(forKey: Keys.userId)
            return true
        } catch {
            return false
        }
    }

    @MainActor
    private func token(baseURL: URL, language: AppLanguage) async throws -> String {
        if let existing = store.string(forKey: Keys.token), existing.isEmpty == false {
            return existing
        }

        let installId: String
        if let existing = store.string(forKey: Keys.installId), existing.isEmpty == false {
            installId = existing
        } else {
            installId = UUID().uuidString
            store.set(installId, forKey: Keys.installId)
        }

        let response = try await send(
            ClientSessionRequest(installId: installId, locale: language.localeIdentifier),
            to: baseURL.appending(path: "api/client/session"),
            token: nil,
            responseType: ClientSessionResponse.self
        )
        store.set(response.token, forKey: Keys.token)
        store.set(response.user.id, forKey: Keys.userId)
        return response.token
    }

    @MainActor
    private func send<Body: Encodable, Response: Decodable>(
        _ body: Body,
        to url: URL,
        token: String?,
        responseType: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let encoder = JSONEncoder.mealKind
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await dataLoader(request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw APIClientError.badResponse
        }
        let decoder = JSONDecoder.mealKind
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(responseType, from: data)
    }

    @MainActor
    private func get<Response: Decodable>(
        _ url: URL,
        token: String,
        responseType: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await dataLoader(request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw APIClientError.badResponse
        }
        let decoder = JSONDecoder.mealKind
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(responseType, from: data)
    }

    private enum Keys {
        static let installId = "mealkind.persistence.installId"
        static let token = "mealkind.persistence.token"
        static let userId = "mealkind.persistence.userId"
        static let lastSyncAt = "mealkind.persistence.lastSyncAt"
        static let lastSyncFailedAt = "mealkind.persistence.lastSyncFailedAt"
    }
}

struct RemotePersistenceSnapshot: Sendable {
    var records: [RemoteSyncRecord]

    init(
        settings: StoredUserSettings,
        habits: [StoredHabit],
        tasks: [StoredDailyTask],
        meals: [StoredMealRecord],
        workouts: [StoredWorkoutRecord],
        sleep: [StoredSleepRecord],
        water: [StoredWaterRecord],
        weight: [StoredWeightRecord],
        supplements: [StoredSupplementRecord],
        measurements: [StoredMeasurementRecord],
        strategies: [StoredDailyStrategy],
        reviews: [StoredWeeklyReview],
        cycles: [StoredTrainingCycle]
    ) {
        records = []
        records.append(.settings(settings))
        records += habits.map(RemoteSyncRecord.habit)
        records += tasks.map(RemoteSyncRecord.dailyTask)
        records += meals.map(RemoteSyncRecord.meal)
        records += workouts.map(RemoteSyncRecord.workout)
        records += sleep.map(RemoteSyncRecord.sleep)
        records += water.map(RemoteSyncRecord.water)
        records += weight.map(RemoteSyncRecord.weight)
        records += supplements.map(RemoteSyncRecord.supplement)
        records += measurements.map(RemoteSyncRecord.measurement)
        records += strategies.map(RemoteSyncRecord.dailyStrategy)
        records += reviews.map(RemoteSyncRecord.weeklyReview)
        records += cycles.map(RemoteSyncRecord.trainingCycle)
    }
}

struct RemotePersistenceExport: Decodable, Sendable {
    var user: RemoteExportUser?
    var data: [String: [RemotePayload]]
    var exportedAt: String?

    var hasUserRecords: Bool {
        data.contains { collection, records in
            collection != "settings" && records.isEmpty == false
        }
    }

    func records(for collection: String) -> [RemotePayload] {
        data[collection] ?? []
    }
}

struct RemoteExportUser: Decodable, Sendable {
    var id: String?
    var email: String?
    var locale: String?
}

struct RemotePayload: Decodable, Sendable {
    var values: [String: RemoteJSONValue]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        values = try container.decode([String: RemoteJSONValue].self)
    }
}

struct RemoteSyncRecord: Encodable, Equatable, Sendable {
    var collection: String
    var id: String
    var payload: [String: RemoteJSONValue]
    var deleted: Bool = false

    static func settings(_ settings: StoredUserSettings) -> RemoteSyncRecord {
        record("settings", id: "current", [
            "selectedPlan": .string(settings.selectedPlanRawValue),
            "profile": .object([
                "basalMetabolicRate": .int(settings.basalMetabolicRate),
                "activityCalories": .int(settings.activityCalories),
                "exerciseCalories": .int(settings.exerciseCalories),
                "heightCentimeters": .optionalDouble(settings.heightCentimeters),
                "age": .optionalInt(settings.age),
                "biologicalSex": .optionalString(settings.biologicalSexRawValue),
                "targetWeightKilograms": .optionalDouble(settings.targetWeightKilograms),
                "currentBodyFatPercentage": .optionalDouble(settings.currentBodyFatPercentage),
                "targetBodyFatPercentage": .optionalDouble(settings.targetBodyFatPercentage),
                "workEnvironment": .optionalString(settings.workEnvironmentRawValue),
                "hasExerciseHabit": .optionalBool(settings.hasExerciseHabit),
                "weeklyWorkoutCount": .optionalInt(settings.weeklyWorkoutCount),
                "restDayRawValue": .optionalInt(settings.restDayRawValue),
                "fatLossWeeks": .optionalInt(settings.fatLossWeeks),
                "activityLevel": .optionalString(settings.activityLevelRawValue),
                "trainingExperience": .optionalString(settings.trainingExperienceRawValue)
            ]),
            "waterCups": .int(settings.waterCups),
            "weightKilograms": .double(settings.weightKilograms),
            "activityBurnGoal": .int(settings.activityBurnGoal),
            "hasCompletedOnboarding": .bool(settings.hasCompletedOnboarding),
            "hasSelectedLanguage": .bool(settings.hasSelectedLanguage),
            "registeredAt": .date(settings.registeredAt),
            "language": .string(settings.languageRawValue),
            "appearance": .string(settings.appearanceRawValue),
            "accountMode": .string(settings.accountModeRawValue),
            "subscriptionTier": .string(settings.subscriptionTierRawValue)
        ])
    }

    static func habit(_ habit: StoredHabit) -> RemoteSyncRecord {
        record("habits", id: habit.id.uuidString, [
            "title": .string(habit.title),
            "anchor": .string(habit.anchor),
            "tinyBehavior": .string(habit.tinyBehavior),
            "celebration": .string(habit.celebration),
            "difficulty": .int(habit.difficulty),
            "frequency": .string(habit.frequencyRawValue),
            "isActive": .bool(habit.isActive),
            "createdAt": .date(habit.createdAt)
        ])
    }

    static func dailyTask(_ task: StoredDailyTask) -> RemoteSyncRecord {
        record("dailyTasks", id: task.id.uuidString, [
            "title": .string(task.title),
            "description": .string(task.taskDescription),
            "habitId": .optionalUUID(task.habitId),
            "taskType": .string(task.taskTypeRawValue),
            "status": .string(task.statusRawValue),
            "scheduledTime": .optionalDate(task.scheduledTime),
            "completedAt": .optionalDate(task.completedAt),
            "difficulty": .int(task.difficulty),
            "createdAt": .date(task.createdAt),
            "localDate": .string(task.localDate),
            "timezoneIdentifier": .string(task.timezoneIdentifier)
        ])
    }

    static func meal(_ meal: StoredMealRecord) -> RemoteSyncRecord {
        record("mealRecords", id: meal.id.uuidString, [
            "name": .string(meal.name),
            "calories": .int(meal.calories),
            "protein": .int(meal.protein),
            "carbs": .int(meal.carbs),
            "fat": .int(meal.fat),
            "servingDescription": .optionalString(meal.servingDescription),
            "createdAt": .date(meal.createdAt),
            "source": .string(meal.sourceRawValue),
            "localDate": .string(meal.localDate),
            "timezoneIdentifier": .string(meal.timezoneIdentifier),
            "imageBase64": .optionalData(meal.imageData)
        ])
    }

    static func workout(_ workout: StoredWorkoutRecord) -> RemoteSyncRecord {
        record("workoutRecords", id: workout.id.uuidString, [
            "type": .string(workout.typeRawValue),
            "durationMinutes": .int(workout.durationMinutes),
            "averageHeartRate": .optionalInt(workout.averageHeartRate),
            "calories": .int(workout.calories),
            "note": .string(workout.note),
            "createdAt": .date(workout.createdAt),
            "source": .string(workout.sourceRawValue),
            "localDate": .string(workout.localDate),
            "timezoneIdentifier": .string(workout.timezoneIdentifier),
            "imageBase64": .optionalData(workout.imageData)
        ])
    }

    static func sleep(_ sleep: StoredSleepRecord) -> RemoteSyncRecord {
        record("sleepRecords", id: sleep.id.uuidString, [
            "hoursSlept": .double(sleep.hoursSlept),
            "quality": .string(sleep.qualityRawValue),
            "bedTime": .optionalDate(sleep.bedTime),
            "wakeTime": .optionalDate(sleep.wakeTime),
            "note": .string(sleep.note),
            "createdAt": .date(sleep.createdAt),
            "localDate": .string(sleep.localDate),
            "timezoneIdentifier": .string(sleep.timezoneIdentifier)
        ])
    }

    static func water(_ water: StoredWaterRecord) -> RemoteSyncRecord {
        record("waterRecords", id: water.id.uuidString, [
            "cupDelta": .int(water.cupDelta),
            "loggedAt": .date(water.loggedAt),
            "note": .string(water.note),
            "createdAt": .date(water.createdAt),
            "localDate": .string(water.localDate),
            "timezoneIdentifier": .string(water.timezoneIdentifier)
        ])
    }

    static func weight(_ weight: StoredWeightRecord) -> RemoteSyncRecord {
        record("weightRecords", id: weight.id.uuidString, [
            "weightKilograms": .double(weight.weightKilograms),
            "loggedAt": .date(weight.loggedAt),
            "createdAt": .date(weight.createdAt),
            "localDate": .string(weight.localDate),
            "timezoneIdentifier": .string(weight.timezoneIdentifier)
        ])
    }

    static func supplement(_ supplement: StoredSupplementRecord) -> RemoteSyncRecord {
        record("supplementRecords", id: supplement.id.uuidString, [
            "category": .string(supplement.categoryRawValue),
            "name": .string(supplement.name),
            "dosage": .string(supplement.dosage),
            "takenAt": .date(supplement.takenAt),
            "note": .string(supplement.note),
            "createdAt": .date(supplement.createdAt),
            "localDate": .string(supplement.localDate),
            "timezoneIdentifier": .string(supplement.timezoneIdentifier)
        ])
    }

    static func measurement(_ measurement: StoredMeasurementRecord) -> RemoteSyncRecord {
        record("measurementRecords", id: measurement.id.uuidString, [
            "kind": .string(measurement.kindRawValue),
            "value": .double(measurement.value),
            "unit": .string(measurement.unit),
            "takenAt": .date(measurement.takenAt),
            "note": .string(measurement.note),
            "createdAt": .date(measurement.createdAt),
            "localDate": .string(measurement.localDate),
            "timezoneIdentifier": .string(measurement.timezoneIdentifier)
        ])
    }

    static func dailyStrategy(_ strategy: StoredDailyStrategy) -> RemoteSyncRecord {
        record("dailyStrategies", id: strategy.id.uuidString, [
            "localDate": .string(strategy.localDate),
            "timezoneIdentifier": .string(strategy.timezoneIdentifier),
            "generatedAt": .date(strategy.generatedAt),
            "payloadBase64": .data(strategy.payload)
        ])
    }

    static func weeklyReview(_ review: StoredWeeklyReview) -> RemoteSyncRecord {
        record("weeklyReviews", id: review.id.uuidString, [
            "weekStartLocalDate": .string(review.weekStartLocalDate),
            "generatedAt": .date(review.generatedAt),
            "timezoneIdentifier": .string(review.timezoneIdentifier),
            "payloadBase64": .data(review.payload)
        ])
    }

    static func trainingCycle(_ cycle: StoredTrainingCycle) -> RemoteSyncRecord {
        record("trainingCycles", id: cycle.id.uuidString, [
            "title": .string(cycle.title),
            "goal": .string(cycle.goalRawValue),
            "startDate": .date(cycle.startDate),
            "durationValue": .int(cycle.durationValue),
            "durationUnit": .string(cycle.durationUnitRawValue),
            "arrangement": .string(cycle.arrangementRawValue),
            "cycleDayCount": .optionalInt(cycle.cycleDayCount),
            "daySchedulesBase64": .data(cycle.daySchedulesData),
            "dietPlanType": .string(cycle.dietPlanTypeRawValue),
            "customProteinMultiplier": .optionalDouble(cycle.customProteinMultiplier),
            "customCarbMultiplier": .optionalDouble(cycle.customCarbMultiplier),
            "customFatMultiplier": .optionalDouble(cycle.customFatMultiplier),
            "supplementsBase64": .data(cycle.supplementsData),
            "status": .string(cycle.statusRawValue),
            "createdAt": .date(cycle.createdAt),
            "localDate": .string(cycle.localDate),
            "timezoneIdentifier": .string(cycle.timezoneIdentifier)
        ])
    }

    private static func record(_ collection: String, id: String, _ payload: [String: RemoteJSONValue]) -> RemoteSyncRecord {
        var payload = payload
        payload["id"] = .string(id)
        return RemoteSyncRecord(collection: collection, id: id, payload: payload)
    }
}

enum RemoteJSONValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: RemoteJSONValue])
    case array([RemoteJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: RemoteJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([RemoteJSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    static func optionalString(_ value: String?) -> RemoteJSONValue {
        value.map(RemoteJSONValue.string) ?? .null
    }

    static func optionalInt(_ value: Int?) -> RemoteJSONValue {
        value.map(RemoteJSONValue.int) ?? .null
    }

    static func optionalDouble(_ value: Double?) -> RemoteJSONValue {
        value.map(RemoteJSONValue.double) ?? .null
    }

    static func optionalBool(_ value: Bool?) -> RemoteJSONValue {
        value.map(RemoteJSONValue.bool) ?? .null
    }

    static func optionalUUID(_ value: UUID?) -> RemoteJSONValue {
        value.map { .string($0.uuidString) } ?? .null
    }

    static func date(_ value: Date) -> RemoteJSONValue {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return .string(formatter.string(from: value))
    }

    static func optionalDate(_ value: Date?) -> RemoteJSONValue {
        value.map(RemoteJSONValue.date) ?? .null
    }

    static func data(_ value: Data) -> RemoteJSONValue {
        .string(value.base64EncodedString())
    }

    static func optionalData(_ value: Data?) -> RemoteJSONValue {
        value.map(RemoteJSONValue.data) ?? .null
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .int(let value): return value
        case .double(let value): return Int(value)
        case .string(let value): return Int(value)
        default: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .double(let value): return value
        case .int(let value): return Double(value)
        case .string(let value): return Double(value)
        default: return nil
        }
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var dataValue: Data? {
        guard let stringValue else { return nil }
        return Data(base64Encoded: stringValue)
    }

    var dateValue: Date? {
        guard let stringValue else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: stringValue) {
            return date
        }
        return ISO8601DateFormatter().date(from: stringValue)
    }

    var uuidValue: UUID? {
        stringValue.flatMap(UUID.init(uuidString:))
    }
}

private struct ClientSessionRequest: Encodable {
    var installId: String
    var locale: String
}

private struct ClientSyncRequest: Encodable {
    var records: [RemoteSyncRecord]
    var replaceAll: Bool
}

private struct EmptyRequest: Encodable {}

private struct DeleteAccountRequest: Encodable {
    var reason: String
}

private struct ClientSessionResponse: Decodable {
    var token: String
    var user: RemoteUser
}

private struct RemoteUser: Decodable {
    var id: String
}

private struct ClientSyncResponse: Decodable {
    var ok: Bool
    var upserted: Int
    var deleted: Int
}

private struct BasicClientResponse: Decodable {
    var ok: Bool
}
