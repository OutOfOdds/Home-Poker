import SwiftUI

struct KnowledgeBaseArticleView: View {
    let article: KBArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Заголовок статьи
                HStack(spacing: 12) {
                    Image(systemName: article.icon)
                        .font(.title)
                        .foregroundStyle(article.color)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(article.title)
                            .font(.title2.bold())
                        Text(article.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)

                Divider()
                    .padding(.horizontal)

                // Контент статьи
                article.contentView
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        KnowledgeBaseArticleView(article: KBArticle.allArticles[0])
    }
}
