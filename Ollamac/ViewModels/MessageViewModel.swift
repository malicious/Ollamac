//
//  MessageViewModel.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 04/11/23.
//

import Combine
import Foundation
import OllamaKit
import SwiftData
import ViewState

@Observable
final class MessageViewModel {
    private var generation: AnyCancellable?
    
    private var modelContext: ModelContext
    private var ollamaKit: OllamaKit
    private var stayAwake: StayAwake?
    
    var messages: [Message] = []
    var sendViewState: ViewState? = nil
    
    init(modelContext: ModelContext, ollamaKit: OllamaKit) {
        self.modelContext = modelContext
        self.ollamaKit = ollamaKit
    }
    
    deinit {
        self.stopGenerate()
    }
    
    func fetch(for chat: Chat) throws {
        let chatId = chat.id
        let predicate = #Predicate<Message>{ $0.chat?.id == chatId }
        let sortDescriptor = SortDescriptor(\Message.promptCreatedAt)
        let fetchDescriptor = FetchDescriptor<Message>(predicate: predicate, sortBy: [sortDescriptor])
        
        messages = try modelContext.fetch(fetchDescriptor)
    }
    
    @MainActor
    func send(_ message: Message) async {
        self.sendViewState = .loading
        if self.stayAwake != nil {
            print("DEBUG: trying to stay awake twice, ignoring")
        }
        self.stayAwake = try! StayAwake(reason: "OllamaKit send()")

        messages.append(message)
        modelContext.insert(message)
        try? modelContext.saveChanges()
        
        if await ollamaKit.reachable() {
            message.responseRequestedAt = Date.now
            let data = message.convertToOKGenerateRequestData()
            
            generation = ollamaKit.generate(data: data)
                .sink(receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        self?.handleComplete()
                    case .failure(let error):
                        self?.handleError(error.localizedDescription)
                    }
                }, receiveValue: { [weak self] response in
                    self?.handleReceive(response)
                })
        } else {
            self.handleError(AppMessages.ollamaServerUnreachable)
        }
    }
    
    @MainActor
    func regenerate(_ message: Message) async {
        self.sendViewState = .loading
        if self.stayAwake != nil {
            print("DEBUG: trying to stay awake twice, ignoring")
        }
        self.stayAwake = try! StayAwake(reason: "OllamaKit regenerate()")
        
        messages[messages.endIndex - 1] = message
        try? modelContext.saveChanges()
        
        if await ollamaKit.reachable() {
            message.responseRequestedAt = Date.now
            message.responseFirstTokenAt = nil
            message.responseLastTokenAt = nil
            let data = message.convertToOKGenerateRequestData()
            
            generation = ollamaKit.generate(data: data)
                .sink(receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        self?.handleComplete()
                    case .failure(let error):
                        self?.handleError(error.localizedDescription)
                    }
                }, receiveValue: { [weak self] response in
                    self?.handleReceive(response)
                })
        } else {
            self.handleError(AppMessages.ollamaServerUnreachable)
        }
    }
    
    func stopGenerate() {
        self.sendViewState = nil
        self.generation?.cancel()

        // TODO: This will be confusing in the UI. The state of a message is actually very complex.
        let lastIndex = self.messages.count - 1
        self.messages[lastIndex].responseLastTokenAt = Date.now
        
        try? self.modelContext.saveChanges()
    }
    
    private func handleReceive(_ response: OKGenerateResponse) {
        // DEBUG: dump tokens so we can figure out why spaces disappear sometimes
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        print("[\(df.string(from: Date.now))] new token(s) -- \"\(response.response)\"")

        // This can happen if we get out of sync with the server; ignore it and move on.
        // TODO: Specifically, we don't close our Ollama connections, and can keep receiving data.
        if self.messages.isEmpty { return }

        let lastMessage = self.messages.last!
        if lastMessage.response == nil {
            lastMessage.response = response.response
        }
        else {
            lastMessage.response = "\(lastMessage.response!)\(response.response)"
        }

        lastMessage.context = response.context

        if lastMessage.responseFirstTokenAt == nil {
            lastMessage.responseFirstTokenAt = Date.now
        }

        self.sendViewState = .loading
    }
    
    private func handleError(_ errorMessage: String) {
        self.stayAwake = nil
        if self.messages.isEmpty { return }
        
        let lastIndex = self.messages.count - 1
        self.messages[lastIndex].errorMessage = errorMessage
        self.messages[lastIndex].errorOccurredAt = Date.now
        self.messages[lastIndex].done = false
        self.messages[lastIndex].responseLastTokenAt = Date.now
        
        try? self.modelContext.saveChanges()
        self.sendViewState = .error(message: errorMessage)
    }
    
    private func handleComplete() {
        self.stayAwake = nil
        if self.messages.isEmpty { return }
        
        let lastIndex = self.messages.count - 1
        self.messages[lastIndex].errorMessage = nil
        self.messages[lastIndex].errorOccurredAt = nil
        self.messages[lastIndex].done = true
        self.messages[lastIndex].responseLastTokenAt = Date.now
        
        try? self.modelContext.saveChanges()
        self.sendViewState = nil
    }
}
