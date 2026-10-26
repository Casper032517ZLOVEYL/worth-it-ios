import AVFoundation
import Foundation
// Usage: swift scripts/prepare-lottery-audio.swift SOURCE.mp3 OUTPUT.m4a
// Source and CC0 license: see docs/Content-Provenance.md.
guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: prepare-lottery-audio.swift SOURCE.mp3 OUTPUT.m4a")
}
let input = try AVAudioFile(forReading: URL(fileURLWithPath: CommandLine.arguments[1]))
let format = input.processingFormat
let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(input.length))!
try input.read(into: buffer)
let rate = format.sampleRate
// A short uninterrupted sequence of actual stick rattles, with soft edges.
let start = Int(rate * 5.0)
let length = Int(rate * 1.35)
let clip = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(length))!
clip.frameLength = AVAudioFrameCount(length)
var peak: Float = 0
for ch in 0..<Int(format.channelCount) {
    for i in 0..<length { peak = max(peak, abs(buffer.floatChannelData![ch][start+i])) }
}
let gain: Float = min(4, 0.65 / max(peak,0.001))
for ch in 0..<Int(format.channelCount) {
    for i in 0..<length {
        let fade = min(1, min(Double(i)/(rate * 0.012), Double(length-1-i)/(rate * 0.09)))
        clip.floatChannelData![ch][i] = buffer.floatChannelData![ch][start+i] * gain * Float(fade)
    }
}
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: rate, AVNumberOfChannelsKey: format.channelCount, AVEncoderBitRateKey: 128000]
func writeClip() throws {
    let output = try AVAudioFile(forWriting: outputURL, settings: settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
    try output.write(from: clip)
}
try writeClip()
print("Saved",outputURL.path,"source peak",peak,"gain",gain)
