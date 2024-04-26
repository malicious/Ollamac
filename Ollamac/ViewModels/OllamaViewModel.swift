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
        let onlineModels = try await self.fetchFromRemote()
        
        for model in prevModels {
            if onlineModels.contains(where: { $0.name == model.name }) {
                model.isAvailable = true
            } else {
                model.isAvailable = false
            }
        }

        for newModel in onlineModels {
            let model = OllamaModel(name: newModel.name)
            model.isAvailable = true

            self.modelContext.insert(model)

            // Capture + construct raw model info record
            if let rawModelInfo = await fetchRawModelInfo(newModel.name) {
                print(String(data: rawModelInfo, encoding: .utf8))
                _ = tryAddModelRecord(newModel.name, data: rawModelInfo)
            }
        }

        try self.modelContext.saveChanges()
        models = try self.fetchFromLocal()
    }

    private func fetchRawModelInfo(_ modelName: String) async -> Data? {
        do {
            return try await ollamaKit.rawModelInfo(data: OKModelInfoRequestData(name: modelName))
        }
        catch {
            return nil
        }
    }

    private func tryAddModelRecord(_ name: String, data rawModelInfo: Data) -> OllamaModelRecord? {
        let sortDescriptor = SortDescriptor(\OllamaModelRecord.createdAt)
        let fetchDescriptor = FetchDescriptor<OllamaModelRecord>(
            sortBy: [SortDescriptor(\OllamaModelRecord.createdAt),
                     SortDescriptor(\OllamaModelRecord.modelName)])

        var returnedModel: OllamaModelRecord? = nil
        do {
            let existingModels = try modelContext.fetch(fetchDescriptor)
            if existingModels.contains(where: { $0.data == rawModelInfo }) {
                print("[DEBUG] model + identical data already exists, returning nil")
                returnedModel = nil
            } else {
                returnedModel = OllamaModelRecord(name: name, data: rawModelInfo)
                modelContext.insert(returnedModel!)
            }
        }
        catch {}

        return returnedModel
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
