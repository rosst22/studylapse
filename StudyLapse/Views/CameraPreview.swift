import AVFoundation
import SwiftUI
import UIKit

/// SwiftUI wrapper around `AVCaptureVideoPreviewLayer`.
///
/// SwiftUI has no native camera view, so anything involving AVFoundation goes
/// through `UIViewRepresentable` -- the bridge that lets you drop a UIKit view
/// into a SwiftUI hierarchy. `makeUIView` builds it once; `updateUIView` runs
/// whenever SwiftUI re-renders.
///
/// The layer is set as the view's *backing* layer via `layerClass` rather than
/// added as a sublayer, so it resizes with the view automatically instead of
/// needing manual frame maths in `layoutSubviews`.
struct CameraPreview: UIViewRepresentable {

    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        if view.previewLayer.session !== session {
            view.previewLayer.session = session
        }
    }
}
