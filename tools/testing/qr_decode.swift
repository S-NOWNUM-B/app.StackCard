import Foundation
import Vision
import ImageIO

// Независимый decoder screenshot: это не проверка физической камеры.
let handler = VNImageRequestHandler(url: URL(fileURLWithPath: CommandLine.arguments[1]), options: [:])
let request = VNDetectBarcodesRequest()
request.symbologies = [.qr]
try handler.perform([request])
let payloads = (request.results ?? []).compactMap { $0.payloadStringValue }
for payload in payloads { print(payload) }
if payloads != [CommandLine.arguments[2]] { exit(1) }
