//
//  ChatSidebarListView.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 05/11/23.
//

import SwiftUI
import ViewCondition


fileprivate func dateToString(_ date: Date) -> String {
    let calendar = Calendar(identifier: .iso8601)
    let chatDate = calendar.startOfDay(for: date)

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"

    return dateFormatter.string(from: chatDate)
}


func dateToISOString(_ date: Date) -> String {
    let calendar = Calendar(identifier: .iso8601)
    // Manually fetch the day-of-week, because dateFormat 'e' counts days from Sunday and is off by one.
    let components = calendar.dateComponents([.weekdayOrdinal], from: date)

    let formatter = DateFormatter()
    // en_US_POSIX is specifically designed to return fixed format, English dates
    // https://developer.apple.com/library/archive/qa/qa1480/_index.html
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(abbreviation: "UTC")
    formatter.dateFormat = "YYYY-'ww'ww.e-LLL-dd"
    formatter.dateFormat = "YYYY-'ww'ww.'\(components.weekdayOrdinal! + 1)'-LLL-dd"

    return formatter.string(from: date)
}


func dateToSectionName(_ date: Date) -> String {
    let sectionName = dateToISOString(date)

    // If the date was more than a week ago, just return the week-name
    if date.timeIntervalSinceNow < -168 * 24 * 3600 {
        return String(sectionName.prefix(9))
    }
    
    // If it's in the previous week, truncate so it's just the week-name
    let todaySection = dateToISOString(Date.now)
    if sectionName.prefix(9) != todaySection.prefix(9) {
        return String(sectionName.prefix(9))
    }

    return sectionName
}


struct ChatSidebarListView: View {
    @Environment(CommandViewModel.self) private var commandViewModel
    @Environment(ChatViewModel.self) private var chatViewModel
    
    private var sortedSectionNamesAndChats: [(String, [Chat])] {
        let sectionedChats = Dictionary(grouping: chatViewModel.chats) { dateToSectionName($0.modifiedAt) }
        return Array(sectionedChats)
            .map { ($0.0, $0.1.sorted(by: { $0.modifiedAt > $1.modifiedAt })) }
            .sorted { $0.0 > $1.0 }
    }

    var body: some View {
        @Bindable var commandViewModelBindable = commandViewModel
        
        List(sortedSectionNamesAndChats, id: \.0, selection:$commandViewModelBindable.selectedChat) { pair in
            let (sectionName, chats) = pair

            Section(header: Text(sectionName)) {
                ForEach(chats) { chat in
                    Label(chat.name, systemImage: "bubble")
                        .contextMenu {
                            ChatContextMenu(commandViewModel, for: chat)
                        }
                        .tag(chat)
                }
            }
        }
        .listStyle(.sidebar)
        .task {
            try? chatViewModel.fetch()
        }
        .toolbar {
            ToolbarItemGroup {
                Spacer()
                
                Button("New Chat", systemImage: "square.and.pencil") {
                    commandViewModel.isAddChatViewPresented = true
                }
                .buttonStyle(.accessoryBar)
                .help("New Chat (⌘ + N)")
            }
        }
        .navigationDestination(for: Chat.self) { chat in
            MessageView(for: chat)
        }
        .sheet(
            isPresented: $commandViewModelBindable.isAddChatViewPresented
        ) {
            AddChatView() { createdChat in
                self.commandViewModel.selectedChat = createdChat
            }
        }
        .sheet(
            isPresented: $commandViewModelBindable.isRenameChatViewPresented
        ) {
            if let chatToRename = commandViewModel.chatToRename {
                RenameChatView(for: chatToRename)
            }
        }
        .confirmationDialog(
            AppMessages.chatDeletionTitle,
            isPresented: $commandViewModelBindable.isDeleteChatConfirmationPresented
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: deleteAction)
        } message: {
            Text(AppMessages.chatDeletionMessage)
        }
        .dialogSeverity(.critical)
    }
    
    // MARK: - Actions
    func deleteAction() {
        guard let chatToDelete = commandViewModel.chatToDelete else { return }
        try? chatViewModel.delete(chatToDelete)
        
        commandViewModel.chatToDelete = nil
        commandViewModel.selectedChat = nil
    }
}
