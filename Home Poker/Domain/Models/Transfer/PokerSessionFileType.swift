//
//  PokerSessionFileType.swift
//  Home Poker
//
//  Defines custom file type for poker session transfer files
//

import UniformTypeIdentifiers

extension UTType {
    /// Тип файла для экспорта/импорта сессий покера
    /// Расширение: .pokersession
    /// MIME type: application/json
    static var pokerSession: UTType {
        UTType(exportedAs: "com.homepoker.pokersession")
    }
}
