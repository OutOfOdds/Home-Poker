import SwiftUI

struct KnowledgeBaseView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Категория: Начало работы
                categorySection(category: .gettingStarted)

                // Категория: Управление сессиями
                categorySection(category: .sessions)

                // Категория: Банк сессии
                categorySection(category: .bank)

                // Категория: Таймер турнира
                categorySection(category: .timer)

                // Категория: Расчеты
                categorySection(category: .settlement)

                // Категория: FAQ
                categorySection(category: .faq)
            }
            .padding()
        }
        .navigationTitle("База знаний")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func categorySection(category: KBCategory) -> some View {
        let articles = KBArticle.articles(for: category)

        if !articles.isEmpty {
            VStack(spacing: 12) {
                // Заголовок категории
                HStack {
                    Image(systemName: category.icon)
                        .foregroundStyle(category.color)
                    Text(category.rawValue)
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal, 4)

                // Статьи в категории
                ForEach(articles) { article in
                    NavigationLink {
                        KnowledgeBaseArticleView(article: article)
                    } label: {
                        DashboardCard(backgroundColor: category.color.opacity(0.15)) {
                            articleCardContent(article)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func articleCardContent(_ article: KBArticle) -> some View {
        HStack(spacing: 16) {
            Image(systemName: article.icon)
                .font(.system(size: 28))
                .foregroundStyle(article.color)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(article.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        KnowledgeBaseView()
    }
}
