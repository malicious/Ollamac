//
//  OllamaViewModel.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 04/11/23.
//

import SwiftData
import SwiftUI
import ViewState
import OllamaKit

@Observable
final class OllamaViewModel {
    private var modelContext: ModelContext
    private var ollamaKit: OllamaKit
    
    var models: [OllamaModel] = []
    
    init(modelContext: ModelContext, ollamaKit: OllamaKit) {
        self.modelContext = modelContext
        self.ollamaKit = ollamaKit
    }
    
    func isReachable() async -> Bool {
        await ollamaKit.reachable()
    }
    
    @MainActor
    func fetch() async throws {
        let prevModels = try self.fetchFromLocal()
        let newModels = try await self.fetchFromRemote()
        
        for model in prevModels {
            if newModels.contains(where: { $0.name == model.name }) {
                model.isAvailable = true
                do {
                    try await populateInfo(model)
                    try await populateRawInfo(model.name)
                }
                catch {}
            } else {
                model.isAvailable = false
            }
        }

        for newModel in newModels {
            let model = OllamaModel(name: newModel.name)
            model.isAvailable = true
            do {
                try await populateInfo(model)
                try await populateRawInfo(model.name)
            }
            catch {}

            self.modelContext.insert(model)
        }
        
        try self.modelContext.saveChanges()
        models = try self.fetchFromLocal()
    }
    
    func populateInfo(_ model: OllamaModel) async throws {
        let modelInfo: OKModelInfoResponse = try await ollamaKit.modelInfo(data: OKModelInfoRequestData(name: model.name))
        model.modelParameters = modelInfo.parameters
        model.promptTemplate = modelInfo.template
        model.systemPrompt = modelInfo.system
        
        _ = tryAddModelRecord(modelInfo: modelInfo)
    }
    
    func populateRawInfo(_ modelName: String) async throws {
        let rawModelInfoResponse = try await ollamaKit.rawModelInfo(data: OKModelInfoRequestData(name: modelName))
        print(String(data: rawModelInfoResponse, encoding: .utf8))
    }
    
    private func fetchLatestModelInfo(modelName: String) -> OllamaModelRecord? {
        return nil
    }

    private func tryAddModelRecord(modelInfo: OKModelInfoResponse) -> OllamaModelRecord? {
//        let existingModels: Set<Model> = []
//        for model in ModelContext.shared.fetchAllModels() {
//            existingModels.insert(model)
//        }
//
//        if existingModels.contains(where: { $0.data == newModel.data }) {
//            // Model already exists with similar data
//        } else {
//            // Add the new model to the context
//        }
        return nil
    }

    private func fetchFromRemote() async throws -> [OKModelResponse.Model] {
        let response = try await ollamaKit.models()
        let models = response.models
        
        return models
    }
    
    private func fetchFromLocal() throws -> [OllamaModel] {
        let sortDescriptor = SortDescriptor(\OllamaModel.name)
        let fetchDescriptor = FetchDescriptor<OllamaModel>(sortBy: [sortDescriptor])
        let models = try modelContext.fetch(fetchDescriptor)
        
        return models
    }
}
