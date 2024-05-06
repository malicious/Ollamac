//
//  AddChatView.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 04/11/23.
//

import SwiftData
import SwiftUI
import ViewCondition
import ViewState

struct AddChatView: View {
    private var onCreated: (_ createdChat: Chat) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(OllamaViewModel.self) private var ollamaViewModel
    @Environment(MessageViewModel.self) private var messageViewModel

    @State private var viewState: ViewState? = .loading

    @State private var name: String = "New Chat"
    @State private var selectedModel: OllamaModel?

    @AppStorage("ollamaUri") private var storedOllamaUri: String = "http://localhost:11434"
    @State private var enteredOllamaUri: String = ""

    init(onCreated: @escaping (_ chat: Chat) -> Void) {
        self.onCreated = onCreated
    }

    private var createButtonDisabled: Bool {
        if name.isEmpty { return true }
        if selectedModel.isNil { return true }
        if let selectedModel, selectedModel.isNotAvailable { return true }
        
        return false
    }
    
    private var isLoading: Bool {
        viewState == .loading
    }
    
    private var isError: Bool {
        viewState?.errorMessage != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .disabled(isLoading)
                }

                Section(content: {
                    TextField("Ollama", text: $enteredOllamaUri)
                        .disabled(isLoading)
                        .onSubmit {
                            viewState = .loading
                            if let targetURL = URL(string: enteredOllamaUri) {
                                ollamaViewModel.updateOllamaUri(targetURL)
                                fetchAction()
                                messageViewModel.updateOllamaUri(targetURL)
                                storedOllamaUri = enteredOllamaUri
                            } else {
                                viewState = .error(message: "Invalid endpoint, edit and press [Enter] to try again")
                            }
                        }

                    Picker("Model", selection: $selectedModel) {
                        Text("Select a model")
                            .tag(nil as OllamaModel?)

                        ForEach(ollamaViewModel.models) { model in
                            Text(model.name)
                                .lineLimit(1)
                                .tag(model as OllamaModel?)
                        }
                    }
                    .padding(.top, 8)
                    .disabled(isLoading)
                }, header: {
                }, footer: {
                    if let selectedModel, selectedModel.isNotAvailable {
                        TextError(AppMessages.ollamaModelUnavailable)
                            .padding(.top, 8)
                    }

                    if let errorMessage = viewState?.errorMessage {
                        HStack {
                            TextError("\"\(enteredOllamaUri)\": \(errorMessage)")
                                .lineLimit(4)

                            Button("Try Again", action: fetchAction)
                                .buttonStyle(.plain)
                                .foregroundStyle(.accent)
                                .visible(
                                    if: errorMessage == AppMessages.ollamaServerUnreachable,
                                    removeCompletely: true
                                )
                        }
                        .padding(.top, 8)
                    }
                })
            }
            .padding()
            .frame(width: 512)
            .navigationTitle("New Chat")
            .task {
                // TODO: This seems like it could get out of sync extremely easily, can it?
                if enteredOllamaUri == "" {
                    enteredOllamaUri = storedOllamaUri
                }
                fetchAction()
            }
            .toolbar {
                ToolbarItem {
                    Text("Loading...")
                        .visible(if: isLoading, removeCompletely: true)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: createAction)
                        .disabled(createButtonDisabled)
                        .disabled(isLoading)
                }
            }
        }
    }
    
    // MARK: - Actions
    private func runIfReachable(_ function: @escaping () async -> Void) async {
        viewState = .loading
        
        if await ollamaViewModel.isReachable() {
            await function()
        } else {
            viewState = .error(message: AppMessages.ollamaServerUnreachable)
        }
    }

    private func fetchAction() {
        Task {
            await runIfReachable {
                do {
                    try await ollamaViewModel.fetch()
                    viewState = ollamaViewModel.models.isEmpty ? .empty : nil
                } catch {
                    viewState = .error(message: AppMessages.generalErrorMessage)
                }
            }
        }
    }

    private func createAction() {
        let chat = Chat(name: name)
        chat.model = selectedModel
        
        Task {
            await runIfReachable {
                do {
                    try chatViewModel.create(chat)
                    onCreated(chat)
                    dismiss()
                } catch {
                    viewState = .error(message: AppMessages.generalErrorMessage)
                }
            }
        }
    }
}
