//
//  OllamacApp.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 03/11/23.
//

import OllamaKit
import SwiftUI
import SwiftData

@main
struct OllamacApp: App {
    @State private var commandViewModel: CommandViewModel
    @State private var ollamaViewModel: OllamaViewModel
    @State private var chatViewModel: ChatViewModel
    @State private var messageViewModel: MessageViewModel

    private var proxyProcess: ProxyProcess? = nil

    var sharedModelContainer: ModelContainer = {
        let storeURL = URL.applicationSupportDirectory.appending(path: "ollamac.sqlite")
        let schema = Schema([Chat.self, Message.self, OllamaModel.self])
        let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        let modelContext = sharedModelContainer.mainContext

        // Initialize with "normal" Ollama endpoint.
        // TODO: Read the (confirmed) @AppStorage string and use that on startup.
        let ollamaKit = OllamaKit(baseURL: URL(string: "http://localhost:11434")!)
//        let ollamaKit = OllamaKit(baseURL: URL(string: "https://stockist/ollama-proxy")!)
//        let ollamaKit = OllamaKit(baseURL: URL(string: "http://127.0.0.1:6633/ollama-proxy")!)

//        do {
//            let helper = Bundle.main.path(forAuxiliaryExecutable: "proxy-server")
//            guard helper != nil else {
//                throw NSError(
//                    domain: "Ollamac ProxyProcess failed, got \"nil\" for path in bundle",
//                    code: 0)
//            }
//            
//            self.proxyProcess = ProxyProcess([helper!])
//            self.proxyProcess!.launch { result, stdoutData in
//            }
//
//            ollamaKit = OllamaKit(baseURL: URL(string: "http://localhost:9750/ollama-proxy")!)
//        }
//        catch {}

        let commandViewModel = CommandViewModel()
        _commandViewModel = State(initialValue: commandViewModel)
        
        let ollamaViewModel = OllamaViewModel(modelContext: modelContext, ollamaKit: ollamaKit)
        _ollamaViewModel = State(initialValue: ollamaViewModel)

        let messageViewModel = MessageViewModel(modelContext: modelContext, ollamaKit: ollamaKit)
        _messageViewModel = State(initialValue: messageViewModel)
        
        let chatViewModel = ChatViewModel(modelContext: modelContext)
        _chatViewModel = State(initialValue: chatViewModel)
    }

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(commandViewModel)
                .environment(chatViewModel)
                .environment(messageViewModel)
                .environment(ollamaViewModel)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    commandViewModel.isAddChatViewPresented = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(replacing: .textEditing) {
                if let selectedChat = commandViewModel.selectedChat {
                    ChatContextMenu(commandViewModel, for: selectedChat)
                }
            }
        }
    }
}
