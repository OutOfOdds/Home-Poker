import Foundation

protocol PlayerStatsExportServiceProtocol {
    func exportReport(_ data: PlayerStatsExportReportData) throws -> URL
    func exportReportOnMain(
        _ data: PlayerStatsExportReportData,
        chunkSize: Int,
        onProgress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    )
}

struct PlayerStatsExportReportData {
    struct Metric {
        let title: String
        let value: String
        let description: String
    }

    struct SessionRow {
        let title: String
        let date: Date
        let buyIn: Int
        let cashOut: Int
        let realPnL: Int
    }

    let memberName: String
    let clubName: String
    let generatedAt: Date
    let filterDescription: String?
    let summaryMetrics: [Metric]
    let turnoverMetrics: [Metric]
    let sessions: [SessionRow]
}

enum PlayerStatsExportError: LocalizedError {
    case emptyDocument
    case failedToWrite(Error)

    var errorDescription: String? {
        switch self {
        case .emptyDocument:
            return "Не удалось сформировать CSV отчет"
        case .failedToWrite(let error):
            return "Не удалось сохранить CSV: \(error.localizedDescription)"
        }
    }
}

struct PlayerStatsExportService: PlayerStatsExportServiceProtocol {
    private let generatedAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private let sessionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    func exportReport(_ data: PlayerStatsExportReportData) throws -> URL {
        var lines = buildStaticCSVLines(data)
        if !data.sessions.isEmpty {
            lines.append(contentsOf: data.sessions.map(makeSessionCSVLine))
        }
        let csv = lines.joined(separator: "\n") + "\n"

        switch writeCSV(csv, memberName: data.memberName, generatedAt: data.generatedAt) {
        case .success(let url):
            return url
        case .failure(let error):
            throw error
        }
    }

    func exportReportOnMain(
        _ data: PlayerStatsExportReportData,
        chunkSize: Int = 200,
        onProgress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let normalizedChunkSize = max(chunkSize, 1)
        var csv = buildStaticCSVLines(data).joined(separator: "\n")
        if !csv.isEmpty {
            csv += "\n"
        }

        onProgress(0.05)
        let totalSessions = data.sessions.count

        if totalSessions == 0 {
            DispatchQueue.main.async {
                onProgress(0.98)
                let result = writeCSV(
                    csv,
                    memberName: data.memberName,
                    generatedAt: data.generatedAt
                )
                if case .success = result {
                    onProgress(1)
                }
                completion(result)
            }
            return
        }

        func processChunk(from startIndex: Int) {
            let endIndex = min(startIndex + normalizedChunkSize, totalSessions)

            for index in startIndex..<endIndex {
                csv += makeSessionCSVLine(data.sessions[index])
                csv += "\n"
            }

            let sessionsProgress = Double(endIndex) / Double(totalSessions)
            let progressValue = 0.05 + sessionsProgress * 0.9
            onProgress(min(progressValue, 0.95))

            if endIndex < totalSessions {
                DispatchQueue.main.async {
                    processChunk(from: endIndex)
                }
                return
            }

            DispatchQueue.main.async {
                onProgress(0.98)
                let result = writeCSV(
                    csv,
                    memberName: data.memberName,
                    generatedAt: data.generatedAt
                )
                if case .success = result {
                    onProgress(1)
                }
                completion(result)
            }
        }

        DispatchQueue.main.async {
            processChunk(from: 0)
        }
    }

    private func buildStaticCSVRows(_ data: PlayerStatsExportReportData) -> [[String]] {
        var rows: [[String]] = [
            [
                "section",
                "item",
                "date",
                "title",
                "value",
                "description",
                "buy_in",
                "cash_out",
                "real_pnl"
            ]
        ]

        rows.append(["meta", "member_name", "", "", data.memberName, "", "", "", ""])
        rows.append(["meta", "club_name", "", "", data.clubName, "", "", "", ""])
        rows.append([
            "meta",
            "generated_at",
            "",
            "",
            generatedAtFormatter.string(from: data.generatedAt),
            "",
            "",
            "",
            ""
        ])
        rows.append([
            "meta",
            "period",
            "",
            "",
            data.filterDescription ?? "За всё время",
            "",
            "",
            "",
            ""
        ])

        for metric in data.summaryMetrics {
            rows.append([
                "summary",
                metric.title,
                "",
                "",
                metric.value,
                metric.description,
                "",
                "",
                ""
            ])
        }

        for metric in data.turnoverMetrics {
            rows.append([
                "turnover",
                metric.title,
                "",
                "",
                metric.value,
                metric.description,
                "",
                "",
                ""
            ])
        }

        if data.sessions.isEmpty {
            rows.append([
                "session",
                "none",
                "",
                "",
                "",
                "Нет сессий за выбранный период.",
                "",
                "",
                ""
            ])
        }

        return rows
    }

    private func buildStaticCSVLines(_ data: PlayerStatsExportReportData) -> [String] {
        buildStaticCSVRows(data).map(csvLine)
    }

    private func makeSessionCSVLine(_ row: PlayerStatsExportReportData.SessionRow) -> String {
        csvLine(
            [
                "session",
                "",
                sessionDateFormatter.string(from: row.date),
                row.title,
                "",
                "",
                "\(row.buyIn)",
                "\(row.cashOut)",
                "\(row.realPnL)"
            ]
        )
    }

    private func csvLine(_ fields: [String]) -> String {
        fields.map(csvEscaped).joined(separator: ",")
    }

    private func writeCSV(
        _ csv: String,
        memberName: String,
        generatedAt: Date
    ) -> Result<URL, Error> {
        guard !csv.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(PlayerStatsExportError.emptyDocument)
        }

        let url = makeFileURL(memberName: memberName, generatedAt: generatedAt)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return .success(url)
        } catch {
            return .failure(PlayerStatsExportError.failedToWrite(error))
        }
    }

    private func csvEscaped(_ raw: String) -> String {
        if raw.contains(",") || raw.contains("\"") || raw.contains("\n") {
            let escaped = raw.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return raw
    }

    private func makeFileURL(memberName: String, generatedAt: Date) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        let stamp = formatter.string(from: generatedAt)
        let safeName = memberName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
            .lowercased()
        let filename = "player_stats_\(safeName)_\(stamp).csv"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }
}
