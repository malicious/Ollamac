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

            // Capture + persist raw model info record
            do {
                if let rawModelInfo = try await fetchRawModelInfo(newModel.name) {
                    if let newModelRecord = try addModelRecord(newModel.name, data: rawModelInfo) {
                        modelContext.insert(newModelRecord)
                    }
                }
            }
            catch {}
        }

        try self.modelContext.saveChanges()

        // Refresh the entire list, once it's been merged into ModelContext
        models = try self.fetchFromLocal()
    }

    private func fetchRawModelInfo(_ modelName: String) async throws -> Data? {
        return try await ollamaKit.rawModelInfo(data: OKModelInfoRequestData(name: modelName))
    }

    private func addModelRecord(_ name: String, data rawModelInfo: Data) throws -> OllamaModelRecord? {
        let fetchDescriptor = FetchDescriptor<OllamaModelRecord>(
            sortBy: [SortDescriptor(\OllamaModelRecord.createdAt),
                     SortDescriptor(\OllamaModelRecord.modelName)])

        let existingRecords = try modelContext.fetch(fetchDescriptor)
        if existingRecords.contains(where: { $0.data == rawModelInfo }) {
            return nil
        }

        print("[DEBUG] updated modelRecord + parameters for: \(name)")
        return OllamaModelRecord(name: name, data: rawModelInfo)
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
