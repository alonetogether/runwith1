import SceneKit
import SwiftUI

/// A bust of Haru Urara in the corner of the gear check. Tap her head and she
/// covers her ears and ducks; tap her again and she pops back up. The clips
/// and crossfades live in `HaruCompanion`; this file is the SceneKit plumbing.
struct HaruUraraView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PassthroughSCNView {
        let view = PassthroughSCNView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = true
        view.preferredFramesPerSecond = 60

        guard let companion = HaruCompanion.load() else { return view }
        let scene = companion.scene
        scene.background.contents = UIColor.clear
        context.coordinator.companion = companion
        context.coordinator.view = view
        view.claimsTouch = { [weak coordinator = context.coordinator] point in
            (coordinator?.region(at: point) ?? .outside) != .outside
        }

        let camera = SCNCamera()
        camera.fieldOfView = 26
        camera.zNear = Double(companion.unit) * 0.2
        camera.zFar = Double(companion.unit) * 200
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.simdPosition = companion.cameraPosition
        cameraNode.simdLook(at: companion.cameraTarget)
        scene.rootNode.addChildNode(cameraNode)
        context.coordinator.cameraNode = cameraNode
        view.delegate = context.coordinator

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 350
        scene.rootNode.addChildNode(ambient)

        view.scene = scene
        view.isPlaying = true

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: PassthroughSCNView, context: Context) {}

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        var companion: HaruCompanion?
        weak var view: PassthroughSCNView?
        var cameraNode: SCNNode?
        private var followOffset = simd_float3.zero

        enum Region { case head, body, outside }

        /// Once per frame on SceneKit's render thread: ease the camera down
        /// and back up with her head so the bust stays framed while she ducks.
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let companion, let cameraNode else { return }
            // Full vertical follow, partial sideways, so the camera stays a
            // little in front of her instead of ending up over her crown.
            let wanted = companion.desiredFollowOffset * simd_float3(0.6, 1.0, 0.6)
            followOffset += (wanted - followOffset) * 0.1
            cameraNode.simdPosition = companion.cameraPosition + followOffset
            cameraNode.simdLook(at: companion.cameraTarget + followOffset)
        }

        /// Screen-space test against the animated skeleton. SceneKit's geometry
        /// hit test ignores skinning for this asset, so we project the head
        /// joint instead: a circle for the head, a column below it for the body.
        func region(at point: CGPoint) -> Region {
            guard let view, let companion else { return .outside }
            let c = companion.headCenter
            let cp = view.projectPoint(SCNVector3(c))
            let ep = view.projectPoint(SCNVector3(c + simd_float3(companion.headRadius, 0, 0)))
            let center = CGPoint(x: CGFloat(cp.x), y: CGFloat(cp.y))
            let radius = max(28, CGFloat(hypot(ep.x - cp.x, ep.y - cp.y)))
            if hypot(point.x - center.x, point.y - center.y) <= radius { return .head }
            if point.y > center.y, abs(point.x - center.x) <= radius * 1.4 { return .body }
            return .outside
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let companion, let view else { return }
            let point = gesture.location(in: view)
            switch region(at: point) {
            case .outside: return
            case .body where !companion.isHiding: return   // sitting up: only the head toggles
            default: break                                 // hiding: any tap on her brings her back
            }
            companion.setHiding(!companion.isHiding)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }
}

/// Only claims touches that land on her, so the list beneath stays tappable
/// around her.
final class PassthroughSCNView: SCNView {
    var claimsTouch: ((CGPoint) -> Bool)?

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard super.point(inside: point, with: event) else { return false }
        return claimsTouch?(point) ?? false
    }
}
