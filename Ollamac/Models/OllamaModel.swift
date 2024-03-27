//
//  OllamaModel.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 03/11/23.
//

import Foundation
import SwiftData

@Model
final class OllamaModel: Identifiable {
    @Attribute(.unique) var name: String
    var isAvailable: Bool = false

    @Attribute var modelParameters: String?
    @Attribute var promptTemplate: String?
    @Attribute var systemPrompt: String?

    @Relationship(deleteRule: .cascade, inverse: \Chat.model)
    var chats: [Chat] = []
    
    init(name: String) {
        self.name = name
    }
    
    @Transient var isNotAvailable: Bool {
        isAvailable == false
    }
}
