//
//  Chat.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 04/11/23.
//

import Foundation
import SwiftData

@Model
final class Chat: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    
    var name: String
    var createdAt: Date = Date.now
    var modifiedAt: Date = Date.now

    @Relationship
    var model: OllamaModel?

    @Transient
    var modelRecord: OllamaModelRecord?

    @Relationship(deleteRule: .cascade, inverse: \Message.chat)
    var messages: [Message] = []
    
    init(name: String) {
        self.name = name
    }
    
    var hasModelInfo: Bool {
        return modelRecord != nil
    }
    
    var modelInfo: [ModelInfoPair] {
        guard modelRecord != nil else { return [] }
        return modelRecord!.asModelInfoPairs()
    }
}
