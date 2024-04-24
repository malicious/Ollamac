//
//  Message.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 04/11/23.
//

import OllamaKit
import Foundation
import SwiftData

@Model
final class Message: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    
    var prompt: String?
    @Attribute(originalName: "createdAt")
    var promptCreatedAt: Date = Date.now

    var response: String?
    var responseRequestedAt: Date? = nil
    var responseFirstTokenAt: Date? = nil
    var responseLastTokenAt: Date? = nil

    var context: [Int]?
    var done: Bool = false
    var errorMessage: String? = nil
    var errorOccurredAt: Date? = nil
    
    @Relationship var chat: Chat?
    var modelRecord: OllamaModelRecord?

    init(prompt: String?, response: String?) {
        self.prompt = prompt
        self.response = response
    }
    
    @Transient var model: String {
        chat?.model?.name ?? ""
    }
}

extension Message {
    func convertToOKGenerateRequestData() -> OKGenerateRequestData {
        var data = OKGenerateRequestData(model: self.model, prompt: self.prompt ?? "")
        data.context = self.context
        
        return data
    }
}
