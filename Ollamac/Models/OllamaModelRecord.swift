import Foundation
import OllamaKit
import SwiftData

@Model
final class OllamaModelRecord: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()

    var modelName: String
    var createdAt: Date

    var modelParameters: String? = nil
    var promptTemplate: String? = nil
    var systemPrompt: String? = nil

    init(name: String, createdAt: Date? = nil) {
        self.modelName = name
        self.createdAt = createdAt ?? Date.now
    }
    
    init(modelInfo: OKModelInfoResponse, createdAt: Date = Date.now) {
        self.modelName = "[test]"
        self.createdAt = createdAt
    }
}

extension OllamaModelRecord: Hashable {
    func hashValue() -> Int {
        return modelName.hashValue ^ modelParameters.hashValue ^ promptTemplate.hashValue ^ systemPrompt.hashValue
    }
}
