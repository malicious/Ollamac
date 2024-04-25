//
//  MessageView.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 04/11/23.
//

import ChatField
import MarkdownUI
import SwiftUI
import SwiftUIIntrospect
import ViewCondition
import ViewState

struct MessageView: View {
    private var chat: Chat
    
    @Environment(\.modelContext) private var modelContext
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(MessageViewModel.self) private var messageViewModel
    @Environment(OllamaViewModel.self) private var ollamaViewModel
    
    @State private var viewState: ViewState? = nil
    
    @FocusState private var promptFocused: Bool
    @State private var prompt: String = ""
    
    init(for chat: Chat) {
        self.chat = chat
    }
    
    var isGenerating: Bool {
        messageViewModel.sendViewState == .loading
    }
    
    var body: some View {
        ScrollViewReader { scrollViewProxy in
//            ScrollView(.vertical) {
//                VStack(spacing: 0) {
                    if !chat.modelInfo.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(chat.modelInfo) { pair in
                                Text(pair.description)
                                    .font(.title3)
                                Text(pair.content)
                                    .padding([.leading], 8)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    
                    List(messageViewModel.messages.indices, id: \.self) { index in
                        let message = messageViewModel.messages[index]
                        
                        let rendered_prompt_text = MarkdownContent(message.prompt ?? "")
                        MessageListItemView(rendered_prompt_text)
                            .roleName("You")
                            .promptCreatedAt(message.promptCreatedAt)
                        
                        let rendered_response_text = MarkdownContent(message.response ?? "")
                        MessageListItemView(rendered_response_text) {
                            regenerateAction(for: message)
                        }
                        .roleName("Assistant")
                        .responseRequestedAt(message.responseRequestedAt)
                        .responseFirstTokenAt(message.responseFirstTokenAt)
                        .responseLastTokenAt(message.responseLastTokenAt)
                        .generating(message.response.isNil && isGenerating)
                        .finalMessage(index == messageViewModel.messages.endIndex - 1)
                        .error(message.errorMessage, errorOccurredAt: message.errorOccurredAt)
                        .id(message)
                    }
                    .onAppear {
                        scrollToBottom(scrollViewProxy)
                    }
                    .onChange(of: messageViewModel.messages) {
                        scrollToBottom(scrollViewProxy)
                    }
//                }
//            }
//            .frame(maxWidth: .infinity, maxHeight: scrollViewProxy.size.height)
            
            // TODO: Why is this in the scroll?
            HStack(alignment: .bottom) {
                ChatField("Message", text: $prompt, action: sendAction)
                    .textFieldStyle(CapsuleChatFieldStyle())
                    .focused($promptFocused)
                
                Button(action: sendAction) {
                    Image(systemName: "arrow.up.circle.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Send message")
                .hide(if: isGenerating, removeCompletely: true)
                
                Button(action: messageViewModel.stopGenerate) {
                    Image(systemName: "stop.circle.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Stop generation")
                .visible(if: isGenerating, removeCompletely: true)
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
            .padding(.horizontal)
        }
        .navigationTitle(chat.name)
        .navigationSubtitle(chat.model?.name ?? "")
        .task {
            initAction()
        }
        .onChange(of: chat) {
            initAction()
        }
    }
    
    // MARK: - Actions
    private func initAction() {
        try? messageViewModel.fetch(for: chat)

        promptFocused = true
    }
    
    private func sendAction() {
        guard messageViewModel.sendViewState.isNil else { return }
        guard prompt.trimmingCharacters(in: .whitespacesAndNewlines).count > 0 else { return }
        
        let message = Message(prompt: prompt, response: nil)
        message.context = chat.messages.last?.context ?? []
        message.chat = chat
        
        Task {
            try chatViewModel.modify(chat)
            prompt = ""
            await messageViewModel.send(message)
        }
    }
    
    private func regenerateAction(for message: Message) {
        guard messageViewModel.sendViewState.isNil || messageViewModel.sendViewState?.errorMessage != nil else { return }
        
        message.response = nil
        message.responseRequestedAt = Date.now
        message.responseFirstTokenAt = nil
        message.responseLastTokenAt = nil
        
        message.context = []
        message.done = false
        message.errorMessage = nil
        message.errorOccurredAt = nil
        
        let lastIndex = messageViewModel.messages.count - 1
        
        if lastIndex > 0 {
            message.context = messageViewModel.messages[lastIndex - 1].context
        }
        
        Task {
            try chatViewModel.modify(chat)
            await messageViewModel.regenerate(message)
        }
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard messageViewModel.messages.count > 0 else { return }
        let lastIndex = messageViewModel.messages.count - 1
        let lastMessage = messageViewModel.messages[lastIndex]
        
        proxy.scrollTo(lastMessage, anchor: .bottom)
    }
}
