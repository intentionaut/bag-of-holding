import Foundation
import PDFKit
import Vision

/// Text for search, worked out on this Mac: Vision for images, PDFKit for PDFs.
public enum Indexer {
    public static func text(at url: URL, kind: Kind) -> String {
        switch kind {
        case .text:
            var encoding = String.Encoding.utf8
            return (try? String(contentsOf: url, usedEncoding: &encoding)) ?? ""
        case .pdf:
            return PDFDocument(url: url)?.string ?? ""
        case .image:
            return recognise(url)
        }
    }

    static func recognise(_ url: URL) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try? VNImageRequestHandler(url: url).perform([request])
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}
