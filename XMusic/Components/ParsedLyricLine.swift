import Foundation

struct ParsedLyricLine: Identifiable, Equatable {
    let id: String
    let time: Int
    let text: String
    var extendedLyrics: [String]
}
