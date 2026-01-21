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
        Text("Это учет")
    }

    var message: Text? {
        Text("Все транзакции наличных фиксируются здесь")
    }

    var image: Image? {
        Image(systemName: "pencil.and.list.clipboard")
    }

    var rules: [Rule] {
        [
            // Показывать только после добавления первого игрока
            #Rule(Self.$hasAddedFirstPlayer) { $0 == true }
        ]
    }
}


struct TestTip: Tip {
    var title: Text {
        Text("Добавь сессию!")
    }
    
    var message: Text? {
        Text("Они будут храняться в этом списке")
    }
    
    var image: Image? {
        Image(systemName: "plus")
    }
}
