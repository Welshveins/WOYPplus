//
//  BarcodeScannerRepresentable.swift
//  WOYPplus
//
//  Created by Chris Davies on 16/03/2026.
//


import SwiftUI
import AVFoundation

struct BarcodeScannerRepresentable: UIViewControllerRepresentable {

    let onFound: (String) -> Void
    let onError: (Error) -> Void

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onFound = onFound
        vc.onError = onError
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {}

    final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

        var onFound: ((String) -> Void)?
        var onError: ((Error) -> Void)?

        private let session = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            configure()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
        }

        private func configure() {
            do {
                guard let device = AVCaptureDevice.default(for: .video) else {
                    throw NSError(domain: "BarcodeScanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "No camera available"])
                }

                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) { session.addInput(input) }

                let output = AVCaptureMetadataOutput()
                if session.canAddOutput(output) { session.addOutput(output) }

                output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                output.metadataObjectTypes = [
                    .ean8, .ean13, .upce,
                    .code39, .code93, .code128,
                    .qr, .pdf417, .dataMatrix, .aztec
                ]

                let preview = AVCaptureVideoPreviewLayer(session: session)
                preview.videoGravity = .resizeAspectFill
                view.layer.addSublayer(preview)
                previewLayer = preview

                session.startRunning()

            } catch {
                onError?(error)
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let code = obj.stringValue else { return }
            onFound?(code)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if session.isRunning { session.stopRunning() }
        }
    }
}
