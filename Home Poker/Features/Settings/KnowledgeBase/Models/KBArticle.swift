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

    init(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        category: KBCategory,
        @ViewBuilder content: () -> some View
    ) {
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
        KBArticle(
            title: "Быстрый старт: первая кеш-сессия",
            subtitle: "От пустого приложения до готовых расчетов",
            icon: "sparkles",
            color: .blue,
            category: .gettingStarted
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Ниже короткий сценарий, который закрывает полный цикл игры и расчётов.")

                ArticleSection(title: "Шаги запуска") {
                    VStack(alignment: .leading, spacing: 8) {
                        NumberedPoint(number: 1, text: "Создайте клуб")
                        NumberedPoint(number: 2, text: "Добавьте участников клуба")
                        NumberedPoint(number: 3, text: "Создайте кеш-сессию")
                        NumberedPoint(number: 4, text: "Добавьте игроков и ведите операции")
                        NumberedPoint(number: 5, text: "Закройте игру и откройте расчеты")
                    }
                }

                ArticleSection(title: "Мини-проверка результата") {
                    VStack(alignment: .leading, spacing: 8) {
                        CheckPoint("Все игроки завершили игру (не в статусе \"в игре\")")
                        CheckPoint("В кассе учтены взносы/выдачи")
                        CheckPoint("Расходы распределены корректно")
                        CheckPoint("Переводы в \"Расчетах\" сформированы без ошибок")
                    }
                }

                TipBlock(text: "Если вы только начинаете, не усложняйте: сначала ведите только игроков и кассу, затем подключайте расходы и рейкбек.")
            }
        },
        KBArticle(
            title: "Клубы и участники",
            subtitle: "База для корректного ведения сессий",
            icon: "person.3.fill",
            color: .green,
            category: .sessions
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("В приложении сначала создается клуб, затем в клуб добавляются участники, и только после этого их удобно добавлять в сессию.")

                ArticleSection(title: "Как настроить клуб") {
                    VStack(alignment: .leading, spacing: 8) {
                        NumberedPoint(number: 1, text: "Откройте вкладку \"Клубы\"")
                        NumberedPoint(number: 2, text: "Нажмите \"Создать\" и задайте название клуба")
                        NumberedPoint(number: 3, text: "Откройте клуб -> \"Участники\" -> добавьте игроков клуба")
                    }
                }

                ArticleSection(title: "Важно") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Игроки сессии привязываются к участникам клуба")
                        BulletPoint("Если участник удален из клуба, исторические сессии не удаляются")
                        BulletPoint("Связь в старых записях просто снимается, статистика пересчитывается")
                    }
                }
            }
        },
        KBArticle(
            title: "Создание кеш-сессии",
            subtitle: "Какие поля критичны и на что влияют",
            icon: "plus.rectangle.on.folder.fill",
            color: .green,
            category: .sessions
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Кеш-сессия — основной сценарий текущей версии приложения.")

                ArticleSection(title: "Обязательные данные") {
                    VStack(alignment: .leading, spacing: 12) {
                        ParameterBlock(name: "1 фишка равна", required: true) {
                            BulletPoint("Коэффициент конвертации фишек в деньги")
                            BulletPoint("Влияет на все денежные расчёты")
                        }
                    }
                }

                ArticleSection(title: "Рекомендуемые данные") {
                    VStack(alignment: .leading, spacing: 12) {
                        ParameterBlock(name: "Игра", required: false) {
                            BulletPoint("NL Hold'em или PLO4")
                        }
                        ParameterBlock(name: "Блайнды и анте", required: false) {
                            BulletPoint("Нужны для структуры игры и отчётности")
                        }
                    }
                }

                WarningBlock(text: "Если коэффициент фишка/деньги указан неправильно, финансовые результаты и settlement будут некорректны.")
            }
        },
        KBArticle(
            title: "Операции с игроками",
            subtitle: "buy-in, add-on, cash-out, возврат в игру",
            icon: "person.fill.badge.plus",
            color: .green,
            category: .sessions
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ArticleSection(title: "Что доступно в сессии") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Добавить игрока с первичной закупкой (buy-in)")
                        BulletPoint("Сделать докупку (add-on)")
                        BulletPoint("Завершить игру игрока (cash-out)")
                        BulletPoint("Вернуть игрока в игру с новой закупкой")
                    }
                }

                ArticleSection(title: "Деньги в кассу во время операций") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("При добавлении, докупке и выходе можно сразу учесть наличные в кассе")
                        BulletPoint("Это снижает количество ручных правок позже в разделе \"Касса\"")
                    }
                }

                ArticleSection(title: "Автостатус сессии") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Когда все игроки завершили игру, сессия переходит в \"Ожидание расчетов\"")
                        BulletPoint("Если хотя бы один игрок снова в игре, статус вернется в \"Активная\"")
                    }
                }
            }
        },
        KBArticle(
            title: "Касса: взносы и выдачи",
            subtitle: "Как вести фактическое движение денег",
            icon: "banknote.fill",
            color: .purple,
            category: .bank
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Касса хранит реальные денежные операции: кто внес, кому выдали, что оплачено из кассы.")

                ArticleSection(title: "Основные операции") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Принято от игрока (deposit)")
                        BulletPoint("Выдано игроку (withdrawal)")
                        BulletPoint("Оплата расхода из кассы")
                        BulletPoint("Оплата чаевых из кассы")
                    }
                }

                ArticleSection(title: "Что проверять регулярно") {
                    VStack(alignment: .leading, spacing: 8) {
                        CheckPoint("Баланс кассы не уходит в минус")
                        CheckPoint("Суммы депозитов соответствуют операциям игроков")
                        CheckPoint("Заметки к операциям заполнены для спорных случаев")
                    }
                }

                TipBlock(text: "Используйте заметки в кассовых операциях: это сильно упрощает разбор спорных ситуаций после игры.")
            }
        },
        KBArticle(
            title: "Расходы и их распределение",
            subtitle: "Как правильно учитывать еду, аренду и прочие траты",
            icon: "cart.fill",
            color: .purple,
            category: .bank
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Расход влияет на итоговые выплаты игрокам, поэтому важно корректно указать источник оплаты и распределение.")

                ArticleSection(title: "Источники оплаты") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Игрок: расход оплатил конкретный игрок")
                        BulletPoint("Касса: расход оплачен из кассы сессии")
                        BulletPoint("Рейк: расход покрывается резервом рейка")
                        BulletPoint("Организаторы: можно без вычета или с вычетом с игроков")
                        BulletPoint("Указать позже: для быстрых черновых записей")
                    }
                }

                ArticleSection(title: "Правило валидности распределения") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Для обычного расхода сумма распределения по игрокам должна совпадать с суммой расхода")
                        BulletPoint("Если расход полностью на организаторах без вычета — распределение может быть нулевым")
                    }
                }

                WarningBlock(text: "Частичная разметка расхода (когда распределено не всё и не ноль) оставляет расход в состоянии, требующем внимания.")
            }
        },
        KBArticle(
            title: "Рейк, чаевые и рейкбек",
            subtitle: "Как учитывать остаток фишек и резервы",
            icon: "percent",
            color: .purple,
            category: .bank
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Рейк и чаевые фиксируют, куда ушел остаток фишек после завершения игры.")

                ArticleSection(title: "Ключевое правило") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("В экране распределения остатка нужно разнести ВСЕ оставшиеся фишки между рейком и чаевыми")
                        BulletPoint("Итог должен ровно совпадать с остатком фишек на столе")
                    }
                }

                ArticleSection(title: "Рейкбек") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Рейкбек распределяется между выбранными игроками")
                        BulletPoint("Сумма распределения не может превышать доступный резерв рейка")
                        BulletPoint("Нераспределенная часть остаётся как организационный сбор")
                    }
                }

                ArticleSection(title: "Компенсация расходов из рейка") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Организаторский расход без вычета с игроков можно закрыть из рейка")
                        BulletPoint("Для этого должен быть достаточный доступный резерв")
                    }
                }
            }
        },
        KBArticle(
            title: "Как работает расчет (Settlement)",
            subtitle: "Логика итоговых переводов по сессии",
            icon: "list.number",
            color: .red,
            category: .settlement
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settlement сводит воедино покерный результат, кассу, расходы и рейкбек.")

                ArticleSection(title: "Что участвует в расчете") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Результат игрока по фишкам (buy-in/add-on/cash-out)")
                        BulletPoint("Конвертация в деньги через коэффициент сессии")
                        BulletPoint("Рейкбек игрока")
                        BulletPoint("Расходы: кто оплатил и чья доля")
                        BulletPoint("Депозиты и выдачи через кассу")
                    }
                }

                ArticleSection(title: "Какие переводы формируются") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Из кассы игроку")
                        BulletPoint("Игроку в кассу")
                        BulletPoint("Между игроками напрямую")
                        BulletPoint("Возвраты в кассу по расходам, оплаченным из кассы")
                    }
                }

                ArticleSection(title: "Перед запуском расчета") {
                    VStack(alignment: .leading, spacing: 8) {
                        CheckPoint("Все игроки завершили игру")
                        CheckPoint("Касса и расходы занесены корректно")
                        CheckPoint("Рейк/чаевые и рейкбек заданы (если использовались)")
                    }
                }
            }
        },
        KBArticle(
            title: "Статусы переводов в расчетах",
            subtitle: "Как отмечать выполненные переводы без потери учета",
            icon: "checkmark.circle.badge.questionmark",
            color: .red,
            category: .settlement
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("В экране расчетов можно отмечать переводы как выполненные. Для переводов, связанных с кассой, это синхронизируется с банковыми транзакциями.")

                ArticleSection(title: "Что происходит при отметке") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Перевод между игроками: меняется только статус выполнения")
                        BulletPoint("Перевод из/в кассу: создается связанная транзакция кассы")
                    }
                }

                ArticleSection(title: "Что происходит при снятии отметки") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Для переводов с кассой связанная транзакция удаляется")
                        BulletPoint("Статус перевода возвращается в невыполненный")
                    }
                }

                TipBlock(text: "Если данные сессии изменились после прошлого расчета, список переводов пересоздается автоматически.")
            }
        },
        KBArticle(
            title: "Таймер турнира",
            subtitle: "Запуск, пауза, переходы по уровням и уведомления",
            icon: "timer.square",
            color: .orange,
            category: .timer
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Таймер работает отдельно от сессий и использует шаблоны структуры блайндов.")

                ArticleSection(title: "Базовый сценарий") {
                    VStack(alignment: .leading, spacing: 8) {
                        NumberedPoint(number: 1, text: "Откройте вкладку \"Таймер\"")
                        NumberedPoint(number: 2, text: "Выберите встроенный шаблон")
                        NumberedPoint(number: 3, text: "Нажмите старт")
                        NumberedPoint(number: 4, text: "При необходимости используйте паузу/пропуск уровня")
                    }
                }

                ArticleSection(title: "Полезные детали") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Состояние таймера сохраняется и восстанавливается")
                        BulletPoint("При паузе уведомления пересчитываются")
                        BulletPoint("По нажатию на уведомление приложение открывает вкладку таймера")
                    }
                }

                TipBlock(text: "Перед турниром проверьте в настройках, что уведомления по смене уровня включены.")
            }
        },
        KBArticle(
            title: "Импорт и экспорт сессий",
            subtitle: "Как безопасно передавать игру между устройствами",
            icon: "square.and.arrow.up.on.square",
            color: .gray,
            category: .faq
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ArticleSection(title: "Экспорт") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("В списке сессий сделайте свайп по нужной сессии")
                        BulletPoint("Нажмите \"Поделиться\" и отправьте файл `.pokersession`")
                    }
                }

                ArticleSection(title: "Импорт") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Откройте Настройки -> \"Импортировать сессию\"")
                        BulletPoint("Выберите клуб для импорта")
                        BulletPoint("Подтвердите, каких отсутствующих участников добавить в клуб")
                    }
                }

                WarningBlock(text: "Импортируемая сессия в текущей версии создается как кеш-сессия.")
            }
        },
        KBArticle(
            title: "Ограничения текущей версии",
            subtitle: "Что уже поддерживается, а что пока в работе",
            icon: "exclamationmark.triangle.fill",
            color: .gray,
            category: .faq
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ArticleSection(title: "Сейчас стабильно работает") {
                    VStack(alignment: .leading, spacing: 8) {
                        CheckPoint("Полный кеш-сценарий: игроки, касса, расходы, рейк/рейкбек, settlement")
                        CheckPoint("Импорт/экспорт сессий через `.pokersession`")
                        CheckPoint("Таймер турнира со встроенными шаблонами и уведомлениями")
                    }
                }

                ArticleSection(title: "В разработке / частично") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Турнирный режим в деталях сессии пока неполный")
                        BulletPoint("Полная турнирная логика settlement пока не подключена")
                        BulletPoint("Пользовательские шаблоны таймера пока не сохраняются постоянно")
                    }
                }
            }
        },
        KBArticle(
            title: "Диагностика: частые проблемы",
            subtitle: "Что проверить, если расчеты или формы ведут себя неожиданно",
            icon: "stethoscope",
            color: .gray,
            category: .faq
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ArticleSection(title: "Кнопка расчета неактивна") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Проверьте, что все игроки завершили игру")
                        BulletPoint("Проверьте, что у сессии есть касса")
                    }
                }

                ArticleSection(title: "Не сходится касса") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Сверьте депозиты/выдачи по игрокам")
                        BulletPoint("Проверьте оплаты расходов и чаевых из кассы")
                        BulletPoint("Проверьте корректность коэффициента фишка/деньги")
                    }
                }

                ArticleSection(title: "Ошибка при распределении расхода") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Для обычного распределения сумма долей должна дать полную сумму расхода")
                        BulletPoint("Либо распределение должно быть нулевым (расход полностью на организаторах без вычета)")
                    }
                }

                ArticleSection(title: "Проблемы с импортом") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Убедитесь, что файл имеет формат `.pokersession`")
                        BulletPoint("Проверьте, что в приложении уже есть хотя бы один клуб")
                        BulletPoint("Если файл поврежден, запросите повторную отправку")
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

struct CheckPoint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .padding(.top, 2)
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

struct WarningBlock: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .padding(.top, 2)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.orange.opacity(0.12))
        .cornerRadius(12)
    }
}
