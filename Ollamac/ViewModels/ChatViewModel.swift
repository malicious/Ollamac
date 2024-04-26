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
    
    private func tryPopulateModelInfo(_ chat: Chat) {
        // TODO: We have to actually provide a predicate
//        let predicate = #Predicate<OllamaModelRecord>{ $0.modelName == chat.name }
        let fetchDescriptor = FetchDescriptor<OllamaModelRecord>(
//            predicate: predicate,
            sortBy: [SortDescriptor(\OllamaModelRecord.createdAt)]
        )

        do {
            // TODO: We only need one record. Also, make sure it's the most recent, not the least recent.
            var targetRecord: OllamaModelRecord? = nil

            let allRecords = try modelContext.fetch(fetchDescriptor)
            for testRecord in allRecords {
                if testRecord.modelName == chat.model?.name {
                    targetRecord = testRecord
                    break
                }
            }
            guard targetRecord != nil else { return }

            var infoString = String(data: targetRecord!.data, encoding: .utf8) ?? ""
            infoString = infoString.replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\\"", with: "\"")

            chat.modelInfo.append(ModelInfoPair(
                description: "Entire info blob",
                content: infoString))

//            // Parse the raw data into appropriate JSON
//            var jsonDict = try JSONSerialization.jsonObject(with: targetRecord.data, options: []) as! [String: Any]
//            jsonDict.removeValue(forKey: "modelfile")
//
//            jsonDict.forEach { (key, value) in
//                var valueAsString = "[failed to re-encode]"
//
//                do {
//                    let reencoded = try JSONSerialization.data(withJSONObject: value, options: [])
//                    if let reencodedAsString = String(data: reencoded, encoding: .utf8) {
//                        valueAsString = reencodedAsString
//                    }
//                }
//                catch {
//                    print("[ERROR] Failed to re-encode JSON value for \(key)")
//                }
//
//                chat.modelInfo.append(ModelInfoPair(description: key, content: valueAsString))
//            }
        }
        catch {
            print("[WARNING] Failed to populate model info for \(chat.model?.name ?? "[no model name]")")
        }
    }

    func fetch() throws {
        let sortDescriptor = SortDescriptor(\Chat.modifiedAt, order: .reverse)
        let fetchDescriptor = FetchDescriptor<Chat>(sortBy: [sortDescriptor])

        self.chats = try self.modelContext.fetch(fetchDescriptor)
        for chat in self.chats {
            // While fetching messages, also try to fetch the model record/parameters
            tryPopulateModelInfo(chat)
        }
    }

    func create(_ chat: Chat) throws {
        self.modelContext.insert(chat)
        self.chats.insert(chat, at: 0)
        tryPopulateModelInfo(chat)
        
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
}
