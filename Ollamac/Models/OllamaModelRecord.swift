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


struct ModelInfoPair: Identifiable, Codable {
    let id = UUID()
    let description: String
    let content: String
    
    init(description: String, content: String) {
        self.description = description
        self.content = content
    }
}

extension OllamaModelRecord {
    func asModelInfoPairs(enumerateAllInfo: Bool = false) -> [ModelInfoPair] {
        var resultModelInfo: [ModelInfoPair] = []

        if enumerateAllInfo {
            var infoString = String(data: self.data, encoding: .utf8) ?? ""
            infoString = infoString.replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\\"", with: "\"")

            resultModelInfo.append(ModelInfoPair(
                description: "Entire info blob",
                content: infoString))
        }

        // Parse the raw data into appropriate JSON
        var jsonDict: [String: Any] = [:]
        do {
            jsonDict = try JSONSerialization.jsonObject(with: self.data, options: []) as! [String: Any]
        }
        catch {
            return resultModelInfo
        }

        if !enumerateAllInfo {
            jsonDict.removeValue(forKey: "modelfile")
            jsonDict.removeValue(forKey: "license")  // testable with llama2:13b
        }

        jsonDict.forEach { (key, value) in
            var encodedValueAsString = "[failed to re-encode JSON value]"

            do {
                if let valueAsString = value as? String {
                    encodedValueAsString = valueAsString
                }
                else {
                    let reencoded = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted])
                    if let reencodedAsString = String(data: reencoded, encoding: .utf8) {
                        encodedValueAsString = reencodedAsString
                    }
                }
            }
            catch {
                print("[ERROR] Failed to re-encode JSON value for \(key)")
            }

            resultModelInfo.append(ModelInfoPair(description: key, content: encodedValueAsString))
        }

        return resultModelInfo.sorted { $0.description < $1.description }
    }
}
