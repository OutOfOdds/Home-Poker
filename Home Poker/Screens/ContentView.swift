//
//  ContentView.swift
//  Home Poker
//
//  Created by Odds on 02.10.2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query private var sessions: [Session]
    @State private var showingNewSession = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
                    NavigationLink {
                        SessionDetailView(session: session)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(session.startTime, format: .dateTime)
                            Text("Игра: \(session.gameType.rawValue)")
                            Text("Блайнды: \(session.smallBlind)/\(session.bigBlind)")

                            if session.status == .active {
                                Text(session.status.rawValue)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            delete(session)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteSessions)
            }
            .onAppear {
                print(sessions)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewSession = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewSession) {
                NewSessionView()
            }
            .navigationTitle("Сессии")
        }
    }
    
    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = sessions[index]
            context.delete(session)
        }
    }
    
    private func delete(_ session: Session) {
        context.delete(session)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Session.self, inMemory: true)
}
