import SwiftUI
import TipKit

struct AddPlayerTip: Tip {
    var title: Text {
        Text("Нажмите, чтобы добавить игрока")
    }
}

struct SessionBankTip: Tip {
    // Parameter для отслеживания добавления первого игрока
    @Parameter
    static var hasAddedFirstPlayer: Bool = false

    var title: Text {
        Text("Это Банк Сессии")
    }

    var message: Text? {
        Text("Все транзакции наличных фиксируются здесь")
    }

    var image: Image? {
        Image(systemName: "building.columns")
    }

    var rules: [Rule] {
        [
            // Показывать только после добавления первого игрока
            #Rule(Self.$hasAddedFirstPlayer) { $0 == true }
        ]
    }
}

