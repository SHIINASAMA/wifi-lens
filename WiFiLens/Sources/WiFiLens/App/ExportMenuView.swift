import SwiftUI
import UniformTypeIdentifiers

struct ExportMenuView: View {
    let seriesData: [ChartSeriesData]
    let band: ChannelBand
    let chartView: AnyView

    @State private var showSavePanel = false
    @State private var exportType: ExportType = .png

    enum ExportType {
        case png, csv
    }

    var body: some View {
        Menu {
            Button(String(localized: "Export as PNG")) {
                exportType = .png
                showSavePanel = true
            }
            Button(String(localized: "Export as CSV")) {
                exportType = .csv
                showSavePanel = true
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .fileExporter(
            isPresented: $showSavePanel,
            document: ExportDocument(type: exportType, data: exportData),
            contentType: exportType == .png ? .png : .commaSeparatedText,
            defaultFilename: "\(band.displayName.lowercased().replacingOccurrences(of: " ", with: "-"))_wifi"
        ) { _ in }
    }

    var exportData: Data {
        switch exportType {
        case .csv: return csvData()
        case .png: return pngData()
        }
    }

    private func csvData() -> Data {
        var csv = "channel,rssi,ssid,bssid\n"
        for s in seriesData {
            let escapedSSID = s.ssid.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\(s.channel),\(s.rssi),\"\(escapedSSID)\",\(s.bssid)\n"
        }
        return csv.data(using: .utf8) ?? Data()
    }

    @MainActor
    private func pngData() -> Data {
        let renderer = ImageRenderer(content: chartView)
        renderer.scale = 2.0
        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return Data() }
        return png
    }
}

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png, .commaSeparatedText] }

    let type: ExportMenuView.ExportType
    let data: Data

    init(type: ExportMenuView.ExportType, data: Data) {
        self.type = type
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.type = .png
        self.data = Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
