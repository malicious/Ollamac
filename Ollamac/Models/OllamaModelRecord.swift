import Foundation
import OllamaKit
import SwiftData

@Model
final class OllamaModelRecord: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()

    var modelName: String

    var data: Data
    var createdAt: Date

    init(name: String, data: Data, createdAt: Date? = nil) {
        self.modelName = name
        self.data = data
        self.createdAt = createdAt ?? Date.now
    }
}

extension OllamaModelRecord: Hashable {
    func hashValue() -> Int {
        return modelName.hashValue ^ data.hashValue
    }
}
