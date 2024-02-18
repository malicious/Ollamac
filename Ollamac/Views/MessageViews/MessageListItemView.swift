//
//  MessageListItemView.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 04/11/23.
//

import MarkdownUI
import SwiftUI
import ViewCondition

private func asString(_ d: Date?) -> String {
    if d == nil {
        return "-"
    }
    else {
        return d!.formatted(date: .numeric, time: .standard)
    }
}

struct MessageListItemView: View {
    private var isGenerating: Bool = false
    private var isFinalMessage: Bool = false

    // This field only exists for prompt-type messages
    private var promptCreatedAt: Date? = nil
    
    private var responseRequestedAt: Date? = nil
    private var responseFirstTokenAt: Date? = nil
    private var responseLastTokenAt: Date? = nil
    // TODO: bug where old value flashes on screen for a second, during regenerations
    let responseGenerationTimer = Timer.publish(every: 1, on: .current, in: .common).autoconnect()
    @State var responseGenerationElapsedTime = 0.0

    private var errorMessage: String? = nil
    private var errorOccurredAt: Date? = nil
    
    // TODO: should be some kind of enum, if those can support "agent"/RP names
    private var roleName: String = "[unknown]"

    let text: MarkdownContent
    let callerRegenerateAction: () -> Void
    
    init(_ text: MarkdownContent) {
        self.text = text
        self.callerRegenerateAction = {}
        
        self.responseGenerationElapsedTime = 0.0
        if self.responseFirstTokenAt != nil && self.responseLastTokenAt == nil {
            self.responseGenerationElapsedTime = Date.now.timeIntervalSince(self.responseFirstTokenAt!)
        }
    }
    
    init(_ text: MarkdownContent, regenerateAction: @escaping () -> Void) {
        self.text = text
        self.callerRegenerateAction = regenerateAction
        
        self.responseGenerationElapsedTime = 0.0
        if self.responseFirstTokenAt != nil && self.responseLastTokenAt == nil {
            self.responseGenerationElapsedTime = Date.now.timeIntervalSince(self.responseFirstTokenAt!)
        }
    }
    
    @State private var isHovered: Bool = false
    @State private var isCopied: Bool = false
    
    private var isCopyButtonVisible: Bool {
        isHovered && !isGenerating
    }
    
    private var isRegenerateButtonVisible: Bool {
        isCopyButtonVisible && isFinalMessage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(roleName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.accent)

                if promptCreatedAt != nil {
                    Text("first sent \(promptCreatedAt!.formatted(date: .numeric, time: .standard))")
                        .foregroundStyle(.brown)
                } else {
                    if responseRequestedAt != nil && responseFirstTokenAt == nil && errorMessage == nil {
                        Text(String(format: "last requested: \(asString(responseRequestedAt)), %.00f seconds ago", responseGenerationElapsedTime))
                            .foregroundStyle(.brown)
                            .onReceive(responseGenerationTimer) { currentTime in
                                responseGenerationElapsedTime = currentTime.timeIntervalSince(responseRequestedAt!)
                            }
                    }
                    else {
                        Text("last requested: \(asString(responseRequestedAt))")
                            .foregroundStyle(.brown)
                    }
                }

                Spacer()
                
                Button(action: copyAction) {
                    Image(systemName: isCopied ? "list.clipboard.fill" : "clipboard")
                }
                .buttonStyle(.accessoryBar)
                .clipShape(.circle)
                .help("Copy")
                .foregroundColor(.accentColor)
                .visible(if: isCopyButtonVisible)

                Button(action: callerRegenerateAction) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.accessoryBar)
                .clipShape(.circle)
                .help("Regenerate")
                .foregroundColor(.accentColor)
                // TODO: This still occupies a space on the bar, need to make this visibly disabled.
                .visible(if: isRegenerateButtonVisible)
            }
            
            // TODO: This is actually a very complex state machine.
            //       We make do by doing a bunch of if checks.
            if isGenerating {
                ProgressView()
                    .controlSize(.extraLarge)
            }
            else if promptCreatedAt == nil {
                if responseRequestedAt != nil && responseFirstTokenAt != nil {
                    Text(String(format: "firstTokenAt: \(asString(responseFirstTokenAt)) — %.02f seconds elapsed after request", responseFirstTokenAt!.timeIntervalSince(responseRequestedAt!)))
                        .foregroundStyle(.brown)
                }
                else {
                    Text("firstTokenAt: \(asString(responseFirstTokenAt))")
                        .foregroundStyle(.brown)
                }
                
                if responseLastTokenAt != nil && responseRequestedAt != nil {
                    Text(String(format: "lastTokenAt: \(asString(responseLastTokenAt)) — %.02f seconds elapsed after request", responseLastTokenAt!.timeIntervalSince(responseRequestedAt!)))
                        .foregroundStyle(.brown)
                }
                else {
                    Text("lastTokenAt: \(asString(responseLastTokenAt))")
                        .foregroundStyle(.brown)
                }
            }
            
            let estimatedTokenCount: Int = {
                let characterSet = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
                let components = text.renderPlainText().components(separatedBy: characterSet)
                
                let wordsOnly = components.filter { !$0.isEmpty }
                return wordsOnly.count
            }()
            Text("estimated token count: \(estimatedTokenCount)")
                .foregroundStyle(.brown)

            if let errorMessage {
                TextError(errorMessage)
            }

            Markdown(text)
                .textSelection(.enabled)
                .markdownTextStyle(\.text) {
                    FontSize(NSFont.preferredFont(forTextStyle: .title3).pointSize)
                }
                .markdownTextStyle(\.code) {
                    FontFamily(.system(.monospaced))
                }
                .markdownBlockStyle(\.codeBlock) { configuration in
                    configuration
                        .label
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .markdownTextStyle {
                            FontSize(NSFont.preferredFont(forTextStyle: .title3).pointSize)
                            FontFamily(.system(.monospaced))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(nsColor: .separatorColor))
                        }
                        .padding(.bottom)
                }
                .hide(if: isGenerating, removeCompletely: true)
            
            HStack(alignment: .center, spacing: 8) {
                Button(action: copyAction) {
                    Image(systemName: isCopied ? "list.clipboard.fill" : "clipboard")
                }
                .buttonStyle(.accessoryBar)
                .clipShape(.circle)
                .help("Copy")
                .visible(if: isCopyButtonVisible)
                
                Button(action: callerRegenerateAction) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.accessoryBar)
                .clipShape(.circle)
                .help("Regenerate")
                .visible(if: isRegenerateButtonVisible)
            }
            .padding(.top, 8)
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onHover {
            isHovered = $0
            isCopied = false
        }
    }
    
    private func copyAction() {
        let plainText = text.renderPlainText()
        
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(plainText, forType: .string)
        
        isCopied = true
    }
    
    // MARK: - Modifiers
    public func roleName(_ roleName: String) -> MessageListItemView {
        var view = self
        view.roleName = roleName
        
        return view
    }
    
    public func promptCreatedAt(_ promptCreatedAt: Date) -> MessageListItemView {
        var view = self
        view.promptCreatedAt = promptCreatedAt

        return view
    }
    
    public func responseRequestedAt(_ responseRequestedAt: Date?) -> MessageListItemView {
        var view = self
        view.responseRequestedAt = responseRequestedAt

        return view
    }
    
    public func responseFirstTokenAt(_ responseFirstTokenAt: Date?) -> MessageListItemView {
        var view = self
        view.responseFirstTokenAt = responseFirstTokenAt

        return view
    }
    
    public func responseLastTokenAt(_ responseLastTokenAt: Date?) -> MessageListItemView {
        var view = self
        view.responseLastTokenAt = responseLastTokenAt

        return view
    }
    
    public func generating(_ isGenerating: Bool) -> MessageListItemView {
        var view = self
        view.isGenerating = isGenerating
        
        return view
    }
    
    public func finalMessage(_ isFinalMessage: Bool) -> MessageListItemView {
        var view = self
        view.isFinalMessage = isFinalMessage
        
        return view
    }
    
    public func error(_ errorMessage: String?, errorOccurredAt: Date? = nil) -> MessageListItemView {
        var view = self
        view.errorMessage = errorMessage
        view.errorOccurredAt = errorOccurredAt
        
        return view
    }
}
