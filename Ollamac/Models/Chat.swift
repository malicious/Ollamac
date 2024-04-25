//
//  Chat.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 04/11/23.
//

import Foundation
import SwiftData

struct ModelInfoPair: Identifiable, Codable {
    let id = UUID()
    let description: String
    let content: String
    
    init(description: String, content: String) {
        self.description = description
        self.content = content
    }
}

@Model
final class Chat: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    
    var name: String
    var createdAt: Date = Date.now
    var modifiedAt: Date = Date.now

    @Relationship
    var model: OllamaModel?

    @Transient var modelInfo: [ModelInfoPair] = []

    @Relationship(deleteRule: .cascade, inverse: \Message.chat)
    var messages: [Message] = []
    
    init(name: String) {
        self.name = name
    }
}
