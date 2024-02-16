//
//  MessageListItemView.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 04/11/23.
//

import MarkdownUI
import SwiftUI
import ViewCondition

struct MessageListItemView: View {
    private var isGenerating: Bool = false
    private var isFinalMessage: Bool = false

    private var hasErrorOccurred: Bool = false
    private var errorMessage: String? = nil
    @State private var isErrorViewVisible: Bool = false
    
    // TODO: should be some kind of enum, if those can support "agent"/RP names
    private var roleName: String = "[unknown]"

    let text: String
    let regenerateAction: () -> Void
    
    init(_ text: String) {
        self.text = text
        self.regenerateAction = {}
    }
    
    init(_ text: String, regenerateAction: @escaping () -> Void) {
        self.text = text
        self.regenerateAction = regenerateAction
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
            HStack(alignment: .bottom, spacing: 0) {
                Text(roleName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.accent)
                
                Spacer()
                
                Button (action: errorAction) {
                    Image(systemName: isErrorViewVisible ? "exclamationmark.circle.fill" : "exclamationmark.circle")
                }
                .buttonStyle(.accessoryBar)
                .clipShape(.circle)
                .help("Show error message")
                .foregroundColor(.accentColor)
                .visible(if: isHovered)

                Button(action: copyAction) {
                    Image(systemName: isCopied ? "list.clipboard.fill" : "clipboard")
                }
                .buttonStyle(.accessoryBar)
                .clipShape(.circle)
                .help("Copy")
                .foregroundColor(.accentColor)
                .visible(if: isCopyButtonVisible)

                Button(action: regenerateAction) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.accessoryBar)
                .clipShape(.circle)
                .help("Regenerate")
                .foregroundColor(.accentColor)
                // TODO: This still occupies a space on the bar, need to make this visibly disabled.
                .visible(if: isRegenerateButtonVisible)
            }

            ProgressView()
                .controlSize(.small)
                .visible(if: isGenerating, removeCompletely: true)

            let errorViewText = {
                if hasErrorOccurred {
                    errorMessage ?? AppMessages.generalErrorMessage
                } else {
                    "[no error]"
                }
            }()
            TextError(errorViewText)
                .visible(if: isErrorViewVisible, removeCompletely: true)

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
                .hide(if: hasErrorOccurred, removeCompletely: true)
            
            HStack(alignment: .center, spacing: 8) {
                Button(action: copyAction) {
                    Image(systemName: isCopied ? "list.clipboard.fill" : "clipboard")
                }
                .buttonStyle(.accessoryBar)
                .clipShape(.circle)
                .help("Copy")
                .visible(if: isCopyButtonVisible)
                
                Button(action: regenerateAction) {
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
    
    // MARK: - Actions
    private func copyAction() {
        let content = MarkdownContent(text)
        let plainText = content.renderPlainText()
        
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(plainText, forType: .string)
        
        isCopied = true
    }
    
    private func errorAction() {
        if isErrorViewVisible {
            isErrorViewVisible = false
        } else {
            isErrorViewVisible = true
        }
    }
    
    // MARK: - Modifiers
    public func roleName(_ roleName: String) -> MessageListItemView {
        var view = self
        view.roleName = roleName
        
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
    
    public func error(_ isError: Bool, message: String?) -> MessageListItemView {
        var view = self
        view.hasErrorOccurred = isError
        view.errorMessage = message
        view.isErrorViewVisible = true
        
        return view
    }
}
