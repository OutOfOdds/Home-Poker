import Foundation
import UIKit

protocol PlayerStatsPDFExportServiceProtocol {
    func exportReport(_ data: PlayerStatsPDFReportData) throws -> URL
}

struct PlayerStatsPDFReportData {
    enum MetricTone {
        case neutral
        case positive
        case negative
        case accent
    }

    struct Metric {
        let title: String
        let value: String
        let description: String
        let tone: MetricTone
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
    let summaryMetrics: [Metric]
    let turnoverMetrics: [Metric]
    let sessions: [SessionRow]
}

enum PlayerStatsPDFExportError: LocalizedError {
    case emptyDocument
    case failedToWrite(Error)

    var errorDescription: String? {
        switch self {
        case .emptyDocument:
            return "Не удалось сформировать PDF отчет"
        case .failedToWrite(let error):
            return "Не удалось сохранить PDF: \(error.localizedDescription)"
        }
    }
}

struct PlayerStatsPDFExportService: PlayerStatsPDFExportServiceProtocol {
    private let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 @72dpi
    private let horizontalPadding: CGFloat = 32
    private let topPadding: CGFloat = 24
    private let bottomPadding: CGFloat = 28
    private let sectionSpacing: CGFloat = 20
    private let cardGap: CGFloat = 12
    private let cardHeight: CGFloat = 96
    private let tableRowHeight: CGFloat = 26

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    func exportReport(_ data: PlayerStatsPDFReportData) throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let pdfData = renderer.pdfData { context in
            var nextRowIndex = 0
            var isFirstPage = true

            repeat {
                context.beginPage()
                let cgContext = context.cgContext
                var y = drawHeader(data: data, context: cgContext)

                if isFirstPage {
                    y = drawMetricsSection(
                        title: "Сводка",
                        metrics: data.summaryMetrics,
                        startY: y,
                        context: cgContext
                    )
                    y = drawMetricsSection(
                        title: "Оборот",
                        metrics: data.turnoverMetrics,
                        startY: y,
                        context: cgContext
                    )
                }

                nextRowIndex = drawSessionsTable(
                    rows: data.sessions,
                    startIndex: nextRowIndex,
                    startY: y,
                    isContinuation: !isFirstPage,
                    context: cgContext
                )
                isFirstPage = false
            } while nextRowIndex < data.sessions.count
        }

        guard !pdfData.isEmpty else { throw PlayerStatsPDFExportError.emptyDocument }

        let url = makeFileURL(memberName: data.memberName, generatedAt: data.generatedAt)
        do {
            try pdfData.write(to: url, options: .atomic)
            return url
        } catch {
            throw PlayerStatsPDFExportError.failedToWrite(error)
        }
    }

    private func drawHeader(data: PlayerStatsPDFReportData, context: CGContext) -> CGFloat {
        let bannerRect = CGRect(
            x: horizontalPadding,
            y: topPadding,
            width: pageRect.width - horizontalPadding * 2,
            height: 112
        )

        context.saveGState()
        UIBezierPath(roundedRect: bannerRect, cornerRadius: 16).addClip()
        let colors = [UIColor(red: 0.09, green: 0.35, blue: 0.87, alpha: 1).cgColor, UIColor(red: 0.14, green: 0.17, blue: 0.41, alpha: 1).cgColor]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0.0, 1.0]) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: bannerRect.minX, y: bannerRect.minY),
                end: CGPoint(x: bannerRect.maxX, y: bannerRect.maxY),
                options: []
            )
        } else {
            UIColor.systemBlue.setFill()
            UIBezierPath(rect: bannerRect).fill()
        }
        context.restoreGState()

        drawText(
            "Отчет по статистике игрока",
            in: CGRect(x: bannerRect.minX + 18, y: bannerRect.minY + 16, width: bannerRect.width - 36, height: 30),
            attributes: [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.white
            ]
        )

        drawText(
            "\(data.memberName) · \(data.clubName)",
            in: CGRect(x: bannerRect.minX + 18, y: bannerRect.minY + 50, width: bannerRect.width - 36, height: 24),
            attributes: [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
        )

        let generatedAt = "Сформировано: \(dateFormatter.string(from: data.generatedAt))"
        drawText(
            generatedAt,
            in: CGRect(x: bannerRect.minX + 18, y: bannerRect.minY + 76, width: bannerRect.width - 36, height: 20),
            attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ]
        )

        return bannerRect.maxY + sectionSpacing
    }

    private func drawMetricsSection(
        title: String,
        metrics: [PlayerStatsPDFReportData.Metric],
        startY: CGFloat,
        context: CGContext
    ) -> CGFloat {
        guard !metrics.isEmpty else { return startY }

        drawSectionTitle(title, y: startY, context: context)
        let sectionTopY = startY + 30
        let contentWidth = pageRect.width - horizontalPadding * 2
        let cardWidth = (contentWidth - cardGap) / 2

        for (index, metric) in metrics.enumerated() {
            let row = index / 2
            let col = index % 2
            let x = horizontalPadding + CGFloat(col) * (cardWidth + cardGap)
            let y = sectionTopY + CGFloat(row) * (cardHeight + cardGap)
            let rect = CGRect(x: x, y: y, width: cardWidth, height: cardHeight)
            drawMetricCard(metric, rect: rect, context: context)
        }

        let rowCount = Int(ceil(Double(metrics.count) / 2.0))
        let metricsHeight = CGFloat(rowCount) * cardHeight + CGFloat(max(rowCount - 1, 0)) * cardGap
        return sectionTopY + metricsHeight + sectionSpacing
    }

    private func drawMetricCard(
        _ metric: PlayerStatsPDFReportData.Metric,
        rect: CGRect,
        context: CGContext
    ) {
        let toneColor = color(for: metric.tone)

        let cardPath = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        UIColor(white: 0.97, alpha: 1).setFill()
        cardPath.fill()
        UIColor(white: 0.88, alpha: 1).setStroke()
        cardPath.lineWidth = 1
        cardPath.stroke()

        let markerRect = CGRect(x: rect.minX, y: rect.minY, width: 5, height: rect.height)
        let markerPath = UIBezierPath(roundedRect: markerRect, byRoundingCorners: [.topLeft, .bottomLeft], cornerRadii: CGSize(width: 12, height: 12))
        toneColor.withAlphaComponent(0.9).setFill()
        markerPath.fill()

        drawText(
            metric.title,
            in: CGRect(x: rect.minX + 14, y: rect.minY + 10, width: rect.width - 22, height: 18),
            attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )

        drawText(
            metric.value,
            in: CGRect(x: rect.minX + 14, y: rect.minY + 32, width: rect.width - 22, height: 24),
            attributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .bold),
                .foregroundColor: toneColor
            ]
        )

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.minimumLineHeight = 13
        paragraph.maximumLineHeight = 13
        drawText(
            metric.description,
            in: CGRect(x: rect.minX + 14, y: rect.minY + 60, width: rect.width - 22, height: 30),
            attributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraph
            ]
        )
    }

    private func drawSessionsTable(
        rows: [PlayerStatsPDFReportData.SessionRow],
        startIndex: Int,
        startY: CGFloat,
        isContinuation: Bool,
        context: CGContext
    ) -> Int {
        let title = isContinuation ? "Сессии (продолжение)" : "Сессии"
        drawSectionTitle(title, y: startY, context: context)
        var y = startY + 30

        let tableRect = CGRect(
            x: horizontalPadding,
            y: y,
            width: pageRect.width - horizontalPadding * 2,
            height: tableRowHeight
        )
        UIColor(white: 0.92, alpha: 1).setFill()
        UIBezierPath(roundedRect: tableRect, cornerRadius: 8).fill()

        let columnX = tableColumnsX(tableRect: tableRect)
        drawText("Дата", in: CGRect(x: columnX.date, y: y + 6, width: 70, height: 14), attributes: tableHeaderAttributes)
        drawText("Сессия", in: CGRect(x: columnX.title, y: y + 6, width: 180, height: 14), attributes: tableHeaderAttributes)
        drawText("Buy-in", in: CGRect(x: columnX.buyIn, y: y + 6, width: 70, height: 14), attributes: tableHeaderAttributes)
        drawText("Cash-out", in: CGRect(x: columnX.cashOut, y: y + 6, width: 75, height: 14), attributes: tableHeaderAttributes)
        drawText("PnL", in: CGRect(x: columnX.pnl, y: y + 6, width: 60, height: 14), attributes: tableHeaderAttributes)
        y += tableRowHeight + 4

        if rows.isEmpty {
            drawText(
                "Нет сыгранных сессий",
                in: CGRect(x: horizontalPadding, y: y + 8, width: pageRect.width - horizontalPadding * 2, height: 16),
                attributes: [
                    .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: UIColor.secondaryLabel
                ]
            )
            return startIndex
        }

        let bottomLimit = pageRect.height - bottomPadding
        var index = startIndex

        while index < rows.count && (y + tableRowHeight) <= bottomLimit {
            let row = rows[index]
            let rowRect = CGRect(
                x: horizontalPadding,
                y: y,
                width: pageRect.width - horizontalPadding * 2,
                height: tableRowHeight
            )

            if index % 2 == 0 {
                UIColor(white: 0.98, alpha: 1).setFill()
                UIBezierPath(rect: rowRect).fill()
            }

            let day = row.date.formatted(date: .abbreviated, time: .omitted)
            drawText(day, in: CGRect(x: columnX.date, y: y + 6, width: 70, height: 14), attributes: tableCellAttributes)
            drawText(row.title, in: CGRect(x: columnX.title, y: y + 6, width: 180, height: 14), attributes: tableCellAttributes)
            drawText(row.buyIn.asCurrency(), in: CGRect(x: columnX.buyIn, y: y + 6, width: 70, height: 14), attributes: tableCellAttributes)
            drawText(row.cashOut.asCurrency(), in: CGRect(x: columnX.cashOut, y: y + 6, width: 75, height: 14), attributes: tableCellAttributes)
            drawText(
                row.realPnL.asCurrency(showSign: true),
                in: CGRect(x: columnX.pnl, y: y + 6, width: 60, height: 14),
                attributes: [
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: color(for: tone(for: row.realPnL))
                ]
            )

            UIColor(white: 0.9, alpha: 1).setStroke()
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: rowRect.minX, y: rowRect.maxY))
            context.addLine(to: CGPoint(x: rowRect.maxX, y: rowRect.maxY))
            context.strokePath()

            y += tableRowHeight
            index += 1
        }

        return index
    }

    private func drawSectionTitle(_ text: String, y: CGFloat, context: CGContext) {
        drawText(
            text,
            in: CGRect(x: horizontalPadding, y: y, width: pageRect.width - horizontalPadding * 2, height: 24),
            attributes: [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: UIColor.label
            ]
        )
    }

    private func drawText(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(in: rect, withAttributes: attributes)
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
        let filename = "player_stats_\(safeName)_\(stamp).pdf"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }

    private func tableColumnsX(tableRect: CGRect) -> (date: CGFloat, title: CGFloat, buyIn: CGFloat, cashOut: CGFloat, pnl: CGFloat) {
        (
            date: tableRect.minX + 8,
            title: tableRect.minX + 84,
            buyIn: tableRect.minX + 270,
            cashOut: tableRect.minX + 345,
            pnl: tableRect.minX + 428
        )
    }

    private var tableHeaderAttributes: [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel
        ]
    }

    private var tableCellAttributes: [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.label
        ]
    }

    private func tone(for value: Int) -> PlayerStatsPDFReportData.MetricTone {
        if value > 0 { return .positive }
        if value < 0 { return .negative }
        return .neutral
    }

    private func color(for tone: PlayerStatsPDFReportData.MetricTone) -> UIColor {
        switch tone {
        case .neutral:
            return .label
        case .positive:
            return .systemGreen
        case .negative:
            return .systemRed
        case .accent:
            return .systemBlue
        }
    }
}
