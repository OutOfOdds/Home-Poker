import SwiftUI
import TipKit

struct AddPlayerTip: Tip {
    var title: Text {
        Text("Добавьте первого игрока")
    }

    var message: Text? {
        Text("Нажмите здесь, чтобы добавить игрока в сессию и начать игру")
    }

    var image: Image? {
        Image(systemName: "person.badge.plus")
    }
}
