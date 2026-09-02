import AVFoundation
import SwiftUI
import UIKit

/// SwiftUI wrapper that *hosts* the capture session's one shared preview layer.
///
/// SwiftUI has no native camera view, so anything involving AVFoundation goes
/// through `UIViewRepresentable` -- the bridge that lets you drop a UIKit view
/// into a SwiftUI hierarchy. `makeUIView` builds it once; `updateUIView` runs
/// whenever SwiftUI re-renders.
///
/// This view deliberately does **not** own an `AVCaptureVideoPreviewLayer` and
/// never assigns `.session`. Assigning a session to a layer once the session is
/// already running blocks the calling thread while AVFoundation rebuilds the
/// connection graph -- 9.0 s, measured on an iPhone 15 Pro. SwiftUI creates a
/// replacement view *before* dismantling the old one, so a per-screen layer meant
/// two layers briefly shared one running session and the main thread froze on
/// every framing -> recording transition and every dim -> undim.
///
/// `CaptureController` therefore owns the layer and binds it to the session once,
/// while the session is still stopped. Moving it between screens is then just a
/// layer re-parent, which is free.
struct CameraPreview: UIViewRepresentable {

    let previewLayer: AVCaptureVideoPreviewLayer

    final class PreviewView: UIView {
        /// The shared layer this view is currently displaying.
        var hosted: AVCaptureVideoPreviewLayer?

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let hosted, hosted.superlayer === layer else { return }
            // A plain frame assignment on a CALayer animates over 0.25 s by
            // default, which reads as the viewfinder sliding into place.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            hosted.frame = bounds
            CATransaction.commit()
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.adopt(previewLayer)
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.adopt(previewLayer)
    }
}

private extension CameraPreview.PreviewView {
    /// Re-parents the shared layer onto this view. `addSublayer` detaches it from
    /// its previous superlayer automatically, so the outgoing screen's view is
    /// left empty and its later teardown is a no-op.
    func adopt(_ incoming: AVCaptureVideoPreviewLayer) {
        guard incoming.superlayer !== layer else { return }
        hosted = incoming
        layer.addSublayer(incoming)
        setNeedsLayout()
    }
}
