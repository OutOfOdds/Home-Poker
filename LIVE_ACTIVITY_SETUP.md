# 🚀 Настройка Live Activities - Финальные шаги

Все файлы созданы! Осталось только добавить их в правильные targets в Xcode.

## ❗️ Обязательная настройка Target Membership

### Шаг 1: Добавить Domain файлы в оба target

Эти файлы должны быть доступны **и в главном app, и в widget extension**:

#### 1.1 TimerActivityAttributes.swift

1. Найди в Project Navigator: `Home Poker → Domain → Models → LiveActivity → TimerActivityAttributes.swift`
2. Выбери файл (кликни один раз)
3. Открой **File Inspector** справа (иконка документа 📄)
4. В разделе **Target Membership** поставь галочки:
   - ✅ **Home Poker**
   - ✅ **PokerTimerWidgetExtension**

#### 1.2 BlindModels.swift

1. Файл: `Home Poker → Domain → Models → Tournament → BlindModels.swift`
2. File Inspector → Target Membership:
   - ✅ **Home Poker**
   - ✅ **PokerTimerWidgetExtension**

#### 1.3 TournamentTemplate.swift (если используется)

1. Файл: `Home Poker → Domain → Models → Tournament → TournamentTemplate.swift`
2. File Inspector → Target Membership:
   - ✅ **Home Poker**
   - ✅ **PokerTimerWidgetExtension**

---

### Шаг 2: Добавить Info.plist в главный app

#### Вариант А: Через Info.plist файл

1. Найди файл `Info.plist` в главном target
2. Добавь новый ключ:
   - **Key:** `NSSupportsLiveActivities`
   - **Type:** `Boolean`
   - **Value:** `YES`

#### Вариант Б: Через Build Settings

1. Выбери target **Home Poker**
2. Вкладка **Build Settings**
3. В поиске набери: `Supports Live Activities`
4. Поставь **YES**

---

### Шаг 3: Удалить файлы из Xcode (если остались шаблонные)

Если в Project Navigator видишь эти файлы - удали их:
- ❌ `PokerTimerWidget/PokerTimerWidget.swift` (красной кнопкой Delete)
- ❌ `PokerTimerWidget/PokerTimerWidgetLiveActivity.swift` (шаблонный)

**Оставь только:**
- ✅ `PokerTimerWidget/PokerTimerWidgetBundle.swift`
- ✅ `PokerTimerWidget/PokerTimerLiveActivity.swift`
- ✅ `PokerTimerWidget/Views/LockScreenTimerView.swift`
- ✅ `PokerTimerWidget/Views/DynamicIslandViews.swift`

---

### Шаг 4: Проверка структуры в Xcode

Должна быть такая структура:

```
Home Poker (проект)
├── Home Poker/
│   ├── Domain/
│   │   ├── Models/
│   │   │   ├── LiveActivity/
│   │   │   │   └── TimerActivityAttributes.swift  ✅ 2 галочки
│   │   │   └── Tournament/
│   │   │       ├── BlindModels.swift              ✅ 2 галочки
│   │   │       └── TournamentTemplate.swift       ✅ 2 галочки
│   │   └── Services/
│   │       └── LiveActivityService.swift          ✅ только Home Poker
│
├── PokerTimerWidget/
│   ├── PokerTimerWidgetBundle.swift               ✅ только Widget
│   ├── PokerTimerLiveActivity.swift               ✅ только Widget
│   ├── Views/
│   │   ├── LockScreenTimerView.swift              ✅ только Widget
│   │   └── DynamicIslandViews.swift               ✅ только Widget
│   ├── Assets.xcassets
│   └── Info.plist
```

---

## 🔨 Попробуй собрать проект

1. Выбери схему **Home Poker** (не PokerTimerWidget)
2. **Product → Build** (⌘B)

### Возможные ошибки:

#### ❌ "Cannot find type 'TimerActivityAttributes' in scope"

**Решение:**
- Проверь Target Membership для `TimerActivityAttributes.swift`
- Должны быть галочки на обоих targets

#### ❌ "Cannot find type 'LevelItem' in scope"

**Решение:**
- Проверь Target Membership для `BlindModels.swift`
- Добавь галочку **PokerTimerWidgetExtension**

#### ❌ "Module 'ActivityKit' not found"

**Решение:**
1. Выбери target **PokerTimerWidgetExtension**
2. **General** → **Frameworks and Libraries**
3. Нажми **"+"** → добавь `ActivityKit.framework`

---

## ✅ После успешной сборки

Проект должен собраться без ошибок!

### Что дальше?

1. **Запусти приложение** на симуляторе или устройстве
2. **Перейди в Timer Manager**
3. **Запусти таймер**
4. **Заблокируй экран** (⌘L в симуляторе)
5. **Увидишь Live Activity** на Lock Screen! 🎉

---

## 🎨 Что получишь:

### Lock Screen
- Название турнира
- Текущий уровень (Level X/Total)
- SB/BB/Ante
- Оставшееся время (большими цифрами)
- Progress bar
- Общее время турнира

### Dynamic Island (iPhone 14 Pro+)
- **Compact:** Уровень + время
- **Expanded:** Полная информация с блайндами
- **Minimal:** Иконка таймера

---

## 🐛 Если что-то не работает

Напиши мне список ошибок компиляции, и я помогу их исправить!

---

*Создано с помощью Claude Code* 🤖
