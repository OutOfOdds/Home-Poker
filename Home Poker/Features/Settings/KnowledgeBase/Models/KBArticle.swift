import SwiftUI

// MARK: - Knowledge Base Article Model

struct KBArticle: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let category: KBCategory
    let contentView: AnyView

    init(title: String, subtitle: String, icon: String, color: Color, category: KBCategory, @ViewBuilder content: () -> some View) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.category = category
        self.contentView = AnyView(content())
    }
}

// MARK: - Categories

enum KBCategory: String, CaseIterable {
    case gettingStarted = "Начало работы"
    case sessions = "Управление сессиями"
    case bank = "Учет"
    case timer = "Таймер турнира"
    case settlement = "Расчеты"
    case faq = "FAQ"

    var color: Color {
        switch self {
        case .gettingStarted: return .blue
        case .sessions: return .green
        case .bank: return .purple
        case .timer: return .orange
        case .settlement: return .red
        case .faq: return .gray
        }
    }

    var icon: String {
        switch self {
        case .gettingStarted: return "star.fill"
        case .sessions: return "list.star"
        case .bank: return "pencil.and.list.clipboard"
        case .timer: return "timer"
        case .settlement: return "dollarsign.arrow.circlepath"
        case .faq: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Static Content

extension KBArticle {
    static let allArticles: [KBArticle] = [
        // Начало работы
        KBArticle(
            title: "Создание первой сессии",
            subtitle: "Пошаговое руководство для новых пользователей",
            icon: "play.circle.fill",
            color: .blue,
            category: .gettingStarted
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Добро пожаловать в Home Poker! Это руководство поможет вам создать вашу первую покерную сессию.")

                ArticleSection(title: "Шаг 1: Открыть список сессий") {
                    Text("На главном экране нажмите на вкладку \"Сессии\" в нижней панели навигации.")
                        .foregroundStyle(.primary)
                        .overlay(
                            Text("\"Сессии\"")
                                .bold()
                                .opacity(0) // placeholder to keep style reference if needed
                        , alignment: .center)
                }

                ArticleSection(title: "Шаг 2: Создать новую сессию") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Нажмите кнопку \"+\" в правом верхнем углу")
                        BulletPoint("Откроется форма создания новой сессии")
                    }
                }

                ArticleSection(title: "Шаг 3: Заполнить информацию") {
                    VStack(alignment: .leading, spacing: 12) {
                        ParameterBlock(name: "Название", required: false) {
                            BulletPoint("Введите название, например: \"Домашняя игра 16 ноября\"")
                            BulletPoint("Помогает отличать сессии друг от друга")
                        }

                        ParameterBlock(name: "Начало", required: false) {
                            BulletPoint("Дата и время начала игры")
                            BulletPoint("По умолчанию устанавливается текущее время")
                        }

                        ParameterBlock(name: "Место проведения", required: true) {
                            BulletPoint("Укажите место, например: \"Дома\" или \"Клуб\"")
                            BulletPoint("Обязательное поле")
                        }

                        ParameterBlock(name: "Игра", required: false) {
                            BulletPoint("Выберите тип игры: NL Hold'em или PLO4")
                            BulletPoint("По умолчанию: NL Hold'em")
                        }

                        ParameterBlock(name: "1 фишка равна", required: true) {
                            BulletPoint("Соотношение фишки к деньгам (например, 10)")
                            BulletPoint("Обязательное поле для расчетов")
                        }

                        ParameterBlock(name: "Блайнды", required: false) {
                            BulletPoint("Small Blind и Big Blind (например, 1/2)")
                            BulletPoint("Big Blind автоматически = 2×Small Blind")
                            BulletPoint("Можно указать Ante при необходимости")
                        }
                    }
                }

                ArticleSection(title: "Шаг 4: Создать сессию") {
                    Text("Нажмите \"Создать\" в правом верхнем углу.")
                        .foregroundStyle(.primary)
                }

                ArticleSection(title: "Шаг 5: Добавить игроков") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("После создания сессии вы окажетесь на экране деталей:")

                        NumberedPoint(number: 1, text: "Нажмите \"Добавить игрока\"")
                        NumberedPoint(number: 2, text: "Введите имя игрока")
                        NumberedPoint(number: 3, text: "Подтвердите buy-in (или измените сумму)")
                        NumberedPoint(number: 4, text: "Нажмите \"Добавить\"")

                        Text("Повторите для всех игроков за столом.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("✅")
                        Text("Игра началась!").bold()
                    }

                    Text("Теперь вы можете:")
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: 6) {
                        BulletPoint("Добавлять rebuy для игроков")
                        BulletPoint("Отмечать cash-out когда игрок выходит")
                        BulletPoint("Добавлять расходы (еда, напитки)")
                        BulletPoint("Просматривать расчеты между игроками")
                    }
                }
            }
        }
    ]

    static func articles(for category: KBCategory) -> [KBArticle] {
        allArticles.filter { $0.category == category }
    }
}

// MARK: - Article Components

struct ArticleSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.bold())
            content
        }
    }
}

struct BulletPoint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct NumberedPoint: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .foregroundStyle(.secondary)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ParameterBlock<Content: View>: View {
    let name: String
    let required: Bool
    let content: Content

    init(name: String, required: Bool, @ViewBuilder content: () -> Content) {
        self.name = name
        self.required = required
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(name).bold()
                if required {
                    Text("(обязательно)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("(опционально)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
    }
}

struct TipBlock: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("💡")
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Совет").font(.subheadline).bold()
                Text(text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
