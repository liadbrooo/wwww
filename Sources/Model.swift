import Foundation
import CoreGraphics

enum ClipKind: String, Codable, CaseIterable { case video, audio, title }
enum Look: String, Codable, CaseIterable { case original, monochrome, warm, cool, vivid, vintage }
enum Motion: String, Codable, CaseIterable { case none, zoomIn, zoomOut, slideLeft, slideRight }
enum Canvas: String, Codable, CaseIterable {
    case landscape = "16:9", portrait = "9:16", square = "1:1"
    var size: CGSize {
        switch self { case .landscape: return CGSize(width:1920,height:1080)
        case .portrait: return CGSize(width:1080,height:1920)
        case .square: return CGSize(width:1080,height:1080) }
    }
}
struct Media: Identifiable, Codable, Equatable {
    var id = UUID()
    var path: String
    var name: String
    var duration: Double
    var kind: ClipKind
}
struct Clip: Identifiable, Codable, Equatable {
    var id = UUID()
    var mediaID: UUID? = nil
    var name: String
    var kind: ClipKind
    var start: Double = 0
    var sourceIn: Double = 0
    var length: Double = 5
    var speed: Double = 1
    var lane: Int = 0
    var volume: Double = 1
    var opacity: Double = 1
    var scale: Double = 1
    var x: Double = 0
    var y: Double = 0
    var rotation: Double = 0
    var brightness: Double = 0
    var contrast: Double = 1
    var saturation: Double = 1
    var look: Look = .original
    var motion: Motion = .none
    var fadeIn: Double = 0
    var fadeOut: Double = 0
    var title: String = "Dein Text"
    var fontSize: Double = 80
    var end: Double { start + length }
}
struct Project: Codable, Equatable {
    var name = "Unbenannt"
    var canvas: Canvas = .landscape
    var fps: Int = 30
    var media: [Media] = []
    var clips: [Clip] = []
    var duration: Double { clips.map(\.end).max() ?? 0 }
    func asset(_ clip: Clip) -> Media? { media.first { $0.id == clip.mediaID } }
    mutating func split(_ id: UUID, at time: Double) -> UUID? {
        guard let index = clips.firstIndex(where: {$0.id == id}) else { return nil }
        var right = clips[index]
        let offset = time - right.start
        guard offset > 0.04, offset < right.length - 0.04 else { return nil }
        right.id = UUID()
        right.start = time
        right.sourceIn += offset * right.speed
        right.length -= offset
        right.fadeIn = 0
        clips[index].length = offset
        clips[index].fadeOut = 0
        clips.append(right)
        return right.id
    }
}
