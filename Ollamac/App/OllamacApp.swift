//
//  OllamacApp.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 03/11/23.
//

import OllamaKit
import SwiftUI
import SwiftData

func startOrCheckOllama(forceProxy: Bool = true) -> URL {
    do {
        // For now, we manually include this with something like:
        //
        //     cd ~/Library/Developer/Xcode/DerivedData/Ollamac-*/Build/Products/Debug/Ollamac.app/Contents/MacOS
        //     ln -s /path/to/proxy-server proxy-server
        let process = Process()
        let helper = Bundle.main.path(forAuxiliaryExecutable: "proxy-server")!
        process.executableURL = URL(fileURLWithPath: helper)
        
        // TODO: Merge tool code from https://developer.apple.com/forums/thread/690310
        let pipe = Pipe()
        process.standardOutput = pipe
        
        let outHandle = pipe.fileHandleForReading
        outHandle.readabilityHandler = { pipe in
            if let line = String(data: pipe.availableData, encoding: .utf8) {
                if !line.isEmpty {
                    print("[proxy-server] \(line)")
                }
            } else {
                print("Error decoding proxy-server data: \(pipe.availableData)")
            }
        }

        // Try running the embedded Ollama server, first
        try process.run()
        print("[INFO] Starting proxy-server with pid \(process.processIdentifier)")

        return URL(string: "http://localhost:9750/ollama-proxy")!
    }
    catch {
        if forceProxy {
            print("Forcing use of Ollama proxy on port 9750: \(error)")
            return URL(string: "http://localhost:9750/ollama-proxy")!
        }

        print("Failed to run embedded Ollama proxy, falling back to direct Ollama connection: \(error)")
        return URL(string: "http://localhost:11434")!
    }
}

@main
struct OllamacApp: App {
    @State private var commandViewModel: CommandViewModel
    @State private var ollamaViewModel: OllamaViewModel
    @State private var chatViewModel: ChatViewModel
    @State private var messageViewModel: MessageViewModel
    
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

        let commandViewModel = CommandViewModel()
        _commandViewModel = State(initialValue: commandViewModel)

        let ollamaKit = OllamaKit(baseURL: startOrCheckOllama())

        let ollamaViewModel = OllamaViewModel(modelContext: modelContext, ollamaKit: ollamaKit)
        _ollamaViewModel = State(initialValue: ollamaViewModel)

        let messageViewModel = MessageViewModel(modelContext: modelContext, ollamaKit: ollamaKit)
        _messageViewModel = State(initialValue: messageViewModel)
        
        let chatViewModel = ChatViewModel(modelContext: modelContext)
        _chatViewModel = State(initialValue: chatViewModel)
        
        // Disable init until we can package Python or figure out how to do this cross-system
        //configureTokenizerPython()
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
