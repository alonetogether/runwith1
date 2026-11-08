import GLTFKit2
import SceneKit
import simd

/// The Haru Urara bust: a skinned glTF with named clips, played through
/// SceneKit animation players and crossfaded on tap.
///
/// Clips are looked up by name. The Blender export script names them
/// `idle` (loops while she is up) and `hide` (ducking with hands over her
/// ears; loops if the clip is a cowering loop, otherwise holds its last
/// frame). Anything else in the file is ignored.
final class HaruCompanion {
    let scene: SCNScene
    let cameraPosition: simd_float3
    let cameraTarget: simd_float3
    /// Head-joint-to-crown distance; framing offsets are expressed in it.
    let unit: Float

    private(set) var isHiding = false

    private let head: SCNNode
    private let headTop: SCNNode
    private let restHeadCenter: simd_float3
    private var players: [String: SCNAnimationPlayer] = [:]

    /// Camera orbit around her. Negative puts the camera on her right, so her
    /// face turns toward the screen's content instead of straight out.
    static let cameraYaw: Float = -0.38

    static func load() -> HaruCompanion? {
        guard let url = Bundle.main.url(forResource: "HaruUrara", withExtension: "glb"),
              let asset = try? GLTFAsset(url: url, options: [:]) else { return nil }
        let source = GLTFSCNSceneSource(asset: asset)
        guard let scene = source.defaultScene else { return nil }
        return HaruCompanion(scene: scene, animations: source.animations)
    }

    init?(scene: SCNScene, animations: [GLTFSCNAnimation]) {
        guard let head = Self.bone("mixamorig:Head", in: scene),
              let headTop = Self.bone("mixamorig:HeadTop_End", in: scene),
              let armL = Self.bone("mixamorig:LeftArm", in: scene),
              let armR = Self.bone("mixamorig:RightArm", in: scene) else { return nil }
        self.scene = scene
        self.head = head
        self.headTop = headTop

        // Flat anime shading: the textures are baked, so no PBR highlights.
        scene.rootNode.enumerateHierarchy { node, _ in
            for material in node.geometry?.materials ?? [] {
                material.lightingModel = .lambert
                material.roughness.contents = 1
                material.metalness.contents = 0
            }
        }

        // Frame her as a bust from a three-quarter angle, in her own axes.
        let h = head.simdWorldPosition
        let up = simd_float3(0, 1, 0)
        let left = simd_normalize(armL.simdWorldPosition - armR.simdWorldPosition)
        let forward = simd_normalize(simd_cross(up, -left))
        unit = simd_length(headTop.simdWorldPosition - h)
        restHeadCenter = (h + headTop.simdWorldPosition) * 0.5
        cameraTarget = h - 0.15 * unit * left + 0.30 * unit * up
        let distance = 5.6 * unit
        cameraPosition = cameraTarget
            + distance * (sin(Self.cameraYaw) * left + cos(Self.cameraYaw) * forward)
            + 0.10 * unit * up

        for clip in animations {
            let player = clip.animationPlayer
            player.animation.isRemovedOnCompletion = false
            player.animation.fillsForward = true
            player.animation.blendInDuration = 0.25
            player.animation.blendOutDuration = 0.25
            players[clip.name] = player
            scene.rootNode.addAnimationPlayer(player, forKey: clip.name)
            player.stop()
        }
        if let idle = players["idle"] {
            idle.animation.repeatCount = .greatestFiniteMagnitude
            idle.play()
        } else if let any = players.values.first {
            any.animation.repeatCount = .greatestFiniteMagnitude
            any.play()
        }
        if let hide = players["hide"] {
            // One-shot duck. When it lands she settles into the quivering hold.
            hide.animation.repeatCount = 1
            hide.animation.animationDidStop = { [weak self] _, _, finished in
                guard let self, finished, self.isHiding else { return }
                self.crossfade(to: "cower", duration: 0.3)
            }
        }
        if let cower = players["cower"] {
            cower.animation.repeatCount = .greatestFiniteMagnitude
        }
    }

    var clipNames: [String] { players.keys.sorted() }

    /// Centre and radius of the head for screen-space tap tests; follows the animation.
    var headCenter: simd_float3 {
        (head.presentation.simdWorldPosition + headTop.presentation.simdWorldPosition) * 0.5
    }
    var headRadius: Float { 0.75 * unit }

    // MARK: Control

    func setHiding(_ hiding: Bool) {
        isHiding = hiding
        crossfade(to: hiding ? "hide" : "idle", duration: hiding ? 0.18 : 0.35)
    }

    private func crossfade(to name: String, duration: TimeInterval) {
        guard let next = players[name] else { return }
        // Every other player, including a finished one-shot still filling
        // forward; otherwise its last frame keeps leaking under the next clip.
        for (other, player) in players where other != name {
            player.stop(withBlendOutDuration: duration)
        }
        next.animation.blendInDuration = duration
        next.play()
    }

    /// How far the camera rig should shift this frame so the bust framing
    /// follows her head while she hides; zero when she is up, so the idle's
    /// sway is not chased. Smoothed by the caller.
    var desiredFollowOffset: simd_float3 {
        isHiding ? headCenter - restHeadCenter : .zero
    }

    // MARK: Lookup

    /// Finds a joint by its Mixamo name. Some exporters suffix names
    /// (`mixamorig:Head_06`), so a prefix match is accepted when the exact
    /// name is absent.
    private static func bone(_ name: String, in scene: SCNScene) -> SCNNode? {
        if let exact = scene.rootNode.childNode(withName: name, recursively: true) { return exact }
        var found: SCNNode?
        scene.rootNode.enumerateHierarchy { node, stop in
            if let n = node.name, n.hasPrefix(name + "_"),
               !n.dropFirst(name.count + 1).contains(where: { !$0.isNumber }) {
                found = node
                stop.pointee = true
            }
        }
        return found
    }
}
