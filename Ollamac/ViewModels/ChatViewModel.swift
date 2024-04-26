//
//  ChatViewModel.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 04/11/23.
//

import Foundation
import SwiftData
import SwiftUI

@Observable
final class ChatViewModel {
    private var modelContext: ModelContext
        
    var chats: [Chat] = []
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetch() throws {
        let sortDescriptor = SortDescriptor(\Chat.modifiedAt, order: .reverse)
        let fetchDescriptor = FetchDescriptor<Chat>(sortBy: [sortDescriptor])

        self.chats = try self.modelContext.fetch(fetchDescriptor)
        // Look up OllamaModelRecords as soon as we have our list of chats.
        // TODO: We shouldn't have to populate every chat at once, we should be able to defer this.
        for chat in self.chats {
            self.populateModelRecord(chat)
        }
    }

    func create(_ chat: Chat) throws {
        self.modelContext.insert(chat)
        self.chats.insert(chat, at: 0)
        self.populateModelRecord(chat)

        try self.modelContext.saveChanges()
    }

    func rename(_ chat: Chat) throws {
        if let index = self.chats.firstIndex(where: { $0.id == chat.id }) {
            self.chats[index] = chat
        }
        
        try self.modelContext.saveChanges()
    }
    
    func delete(_ chat: Chat) throws {
        self.modelContext.delete(chat)
        self.chats.removeAll(where: { $0.id == chat.id })
        
        try self.modelContext.saveChanges()
    }
    
    func modify(_ chat: Chat) throws {
        chat.modifiedAt = .now

        if let index = self.chats.firstIndex(where: { $0.id == chat.id }) {
            self.chats.remove(at: index)
            self.chats.insert(chat, at: 0)
        }

        try self.modelContext.saveChanges()
    }

    private func populateModelRecord(_ chat: Chat) {
        // Find any record that matches the Ollama model name.
        // Don't bother with `createdAt` or `modifiedAt`, since we'd need to embed that info into the chat's messages to be useful.
        let targetModelName = chat.model?.name ?? ""
        let predicate = #Predicate<OllamaModelRecord>{ $0.modelName == targetModelName }
        let fetchDescriptor = FetchDescriptor<OllamaModelRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\OllamaModelRecord.createdAt)]
        )

        do {
            let allRecords = try self.modelContext.fetch(fetchDescriptor)
            guard !allRecords.isEmpty else { return }

            let targetRecord = allRecords.first!
            chat.modelRecord = targetRecord
        }
        catch {
            print("[WARNING] Failed to populate Chat.modelRecord for \(chat.name): \(chat.model?.name ?? "[no model name]")")
        }
    }
}
