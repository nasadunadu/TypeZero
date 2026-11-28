import Foundation
import CoreGraphics
import AppKit

// MARK: - Future-Ready Species Rig Tag (Phase 1: Cat 100%; Phase 2+: Dog / Reptile / Beetle / Fish)

public enum PetSpeciesKind: String, Codable, CaseIterable, Sendable {
    case cat = "cat"
}

// MARK: - Artist-Grade Procedural Cat Coat Compiler (`CatPhotoDNA` -> `.kurocat` formatVersion 2)

public enum CatCoatCompiler {

    static func compileSkinSpec(from rawDNA: CatPhotoDNA, previewPNG: Data? = nil) throws -> SkinSpec {
        let data = try compileJSONData(from: rawDNA, previewPNG: previewPNG)
        return try SkinSpec.parse(data)
    }

    public static func compileJSONData(from rawDNA: CatPhotoDNA, previewPNG: Data? = nil) throws -> Data {
        var dna = rawDNA
        dna.sanitize()

        let milk = "#F5F1E8"
        let pHex = dna.primaryFurHex
        let sHex = dna.secondaryFurHex
        let tHex = dna.tertiaryFurHex
        let pLum = luminance(of: pHex)

        var palette: [String: Any] = [
            "nose": dna.noseHex,
            "earInner": dna.earInnerHex,
            "iris": dna.irisLeftHex,
            "irisLeft": dna.irisLeftHex,
            "irisRight": dna.heterochromia ? dna.irisRightHex : dna.irisLeftHex
        ]

        // Subtle adorable `:3` kitty mouth line tuned to muzzle contrast
        let hasLightMuzzle: Bool = {
            switch dna.patternFamily {
            case .calico, .ragdollBicolor, .shaded, .van:
                return true
            case .tuxedoBicolor, .tabbyBicolor:
                return dna.faceBlaze != .none
            case .tabby:
                return dna.faceBlaze == .whiteMuzzle || dna.faceBlaze == .noseBridgeBlaze || dna.faceBlaze == .invertedV
            case .solid:
                return pLum > 0.55 || dna.faceBlaze != .none
            case .colorpoint, .tortoiseshell:
                return false
            }
        }()
        let paletteMouth: String = {
            if dna.patternFamily == .tortoiseshell || (pLum < 0.24 && !hasLightMuzzle) {
                return "#DFCCBACC"
            }
            return hasLightMuzzle ? "#7A685BC4" : "#6D5B4EB0"
        }()
        palette["mouth"] = paletteMouth
        if pLum < 0.42 && (dna.patternFamily == .tabby || dna.patternFamily == .tabbyBicolor || dna.patternFamily == .tuxedoBicolor) {
            // Crisp bright white whiskers standing out against dark tabby/tuxedo cheeks & background (like real 花椒!)
            palette["whiskers"] = "#F6F3ECE2"
        } else if pLum > 0.70 || hasLightMuzzle {
            palette["whiskers"] = "#857C70B8"
        }

        var partGradients: [String: Any] = [:]
        var regions: [[String: Any]] = []
        var marks: [[String: Any]] = []
        var idleLegs = "legs"

        // Helper builders for Bezier regions & marks
        func smoothRegion(space: String, fill: String, alpha: Double = 1.0, points: [(Double, Double)], tension: Double = 0.28) -> [String: Any] {
            let n = points.count
            var anchors: [[String: Any]] = []
            anchors.reserveCapacity(n)
            for i in 0..<n {
                let prev = points[(i - 1 + n) % n]
                let curr = points[i]
                let next = points[(i + 1) % n]
                let dx = (next.0 - prev.0) * tension * 0.5
                let dy = (next.1 - prev.1) * tension * 0.5
                anchors.append([
                    "x": round2(curr.0),
                    "y": round2(curr.1),
                    "inX": round2(curr.0 - dx),
                    "inY": round2(curr.1 - dy),
                    "outX": round2(curr.0 + dx),
                    "outY": round2(curr.1 + dy)
                ])
            }
            return [
                "space": space,
                "fill": fill,
                "alpha": round2(alpha),
                "anchors": anchors
            ]
        }

        func polygonMark(space: String, color: String, alpha: Double = 1.0, clipToBib: Bool = false, points: [(Double, Double)]) -> [String: Any] {
            [
                "space": space,
                "kind": "polygon",
                "color": color,
                "alpha": round2(alpha),
                "clipToBib": clipToBib,
                "points": points.map { [round2($0.0), round2($0.1)] }
            ]
        }

        func strokeMark(space: String, color: String, width: Double, alpha: Double = 0.85, brush: String = "round", points: [(Double, Double)]) -> [String: Any] {
            [
                "space": space,
                "kind": "stroke",
                "color": color,
                "width": round2(width),
                "alpha": round2(alpha),
                "brush": brush,
                "points": points.map { [round2($0.0), round2($0.1)] }
            ]
        }

        // Deterministic seeded jitter for organic spots
        let seedAngle = Double(dna.patchSeed % 97) * 0.6180339
        let shiftSpot = sin(seedAngle * 6.28) * 5.0

        // Reusable anatomical artwork generators (rich multi-stroke tiger / mackerel tabby geometry!)
        func appendForeheadM(color: String, alpha: Double = 0.88) {
            // Dark dorsal crown shadow between ears (signature real-tabby dark crown!)
            marks.append(polygonMark(space: "head", color: color, alpha: alpha * 0.62, points: [
                (-24.0, -40.0), (24.0, -40.0), (16.0, -29.0), (0.0, -27.5), (-16.0, -29.0)
            ]))
            // Bold 5-band M emblem
            marks.append(strokeMark(space: "head", color: color, width: 3.6, alpha: alpha, points: [
                (-13.0, -33.0), (-11.2, -24.0), (-7.8, -16.2)
            ]))
            marks.append(strokeMark(space: "head", color: color, width: 3.8, alpha: alpha, points: [
                (-3.0, -34.0), (-2.0, -23.5), (0.0, -13.2), (2.0, -23.5), (3.0, -34.0)
            ]))
            marks.append(strokeMark(space: "head", color: color, width: 3.6, alpha: alpha, points: [
                (13.0, -33.0), (11.2, -24.0), (7.8, -16.2)
            ]))
            marks.append(strokeMark(space: "head", color: color, width: 3.0, alpha: alpha * 0.92, points: [
                (-22.5, -29.5), (-20.0, -22.0), (-16.8, -15.5)
            ]))
            marks.append(strokeMark(space: "head", color: color, width: 3.0, alpha: alpha * 0.92, points: [
                (22.5, -29.5), (20.0, -22.0), (16.8, -15.5)
            ]))
        }

        func appendCheekStripes(color: String, alpha: Double = 0.86) {
            // Upper outer-eye Cleopatra eyeliner sweep + lower cheek tabby stripe on both sides
            marks.append(strokeMark(space: "head", color: color, width: 3.2, alpha: alpha, points: [
                (-45.0, 0.5), (-36.5, 2.2), (-28.5, 1.2)
            ]))
            marks.append(strokeMark(space: "head", color: color, width: 3.0, alpha: alpha * 0.94, points: [
                (-44.0, 10.5), (-35.5, 11.8), (-28.0, 9.8)
            ]))
            marks.append(strokeMark(space: "head", color: color, width: 3.2, alpha: alpha, points: [
                (45.0, 0.5), (36.5, 2.2), (28.5, 1.2)
            ]))
            marks.append(strokeMark(space: "head", color: color, width: 3.0, alpha: alpha * 0.94, points: [
                (44.0, 10.5), (35.5, 11.8), (28.0, 9.8)
            ]))
        }

        func appendRibStripes(color: String, alpha: Double = 0.86) {
            // 1) Two classic Tabby "Lord's Necklace" curved chest bands across upper torso!
            marks.append(strokeMark(space: "body", color: color, width: 4.0, alpha: alpha * 0.92, points: [
                (-44.0, -52.0), (-26.0, -40.0), (0.0, -34.0), (26.0, -40.0), (44.0, -52.0)
            ]))
            marks.append(strokeMark(space: "body", color: color, width: 4.2, alpha: alpha, points: [
                (-48.0, -38.0), (-28.0, -27.0), (0.0, -22.0), (28.0, -27.0), (48.0, -38.0)
            ]))
            // 2) Dense curved mackerel tiger stripes wrapping from flanks across ribs & belly!
            for (yOut, yIn) in [(-24.0, -13.0), (-10.0, -1.0), (4.0, 11.0)] {
                marks.append(strokeMark(space: "body", color: color, width: 4.4, alpha: alpha, points: [
                    (-52.0, yOut), (-34.0, (yOut + yIn) * 0.5 + 1.5), (-11.0, yIn)
                ]))
                marks.append(strokeMark(space: "body", color: color, width: 4.4, alpha: alpha, points: [
                    (52.0, yOut), (34.0, (yOut + yIn) * 0.5 + 1.5), (11.0, yIn)
                ]))
            }
        }

        func appendArmTabbyBracelets(color: String, alpha: Double = 0.86) {
            // 5 crisp tiger bracelet rings along BOTH front legs (sitting & reaching!) + hind leg!
            for space in ["leftArm", "rightArm", "hindLeg"] {
                for xPct in [20.0, 36.0, 52.0, 68.0, 83.0] {
                    marks.append(strokeMark(space: space, color: color, width: 4.0, alpha: alpha, points: [
                        (xPct, -10.5), (xPct + 2.0, 0.0), (xPct, 10.5)
                    ]))
                }
            }
        }

        func appendTailRings(color: String, alpha: Double = 0.88) {
            for xPos in [16.0, 32.0, 48.0, 64.0, 78.0] {
                marks.append(strokeMark(space: "tail", color: color, width: 5.6, alpha: alpha, points: [
                    (xPos, 10.5), (xPos, -10.5)
                ]))
            }
        }

        func appendTailTip(color: String) {
            marks.append(polygonMark(space: "tail", color: color, alpha: 0.96, points: [
                (80.0, -11.5), (103.0, -11.5), (105.0, 0.0), (103.0, 11.5), (80.0, 11.5)
            ]))
        }

        // Drawn as `polygonMark` AFTER body stripes so the fluffy white throat kerchief / bib sits cleanly OVER the stripes!
        func appendChestBibOverlayMark(style: CatChestBibStyle, bibColor: String, includeBellyWisp: Bool = false) {
            switch style {
            case .none:
                break
            case .locket:
                marks.append(polygonMark(space: "body", color: bibColor, points: [
                    (0.0, -65.0), (14.0, -56.0), (11.0, -40.0), (0.0, -33.0), (-11.0, -40.0), (-14.0, -56.0)
                ]))
            case .triangleCollar:
                // Authentic V-shaped white throat kerchief (like 花椒!) — leaves chest necklaces & rib stripes 100% visible below y = -34!
                marks.append(polygonMark(space: "body", color: bibColor, points: [
                    (0.0, -78.0), (26.0, -68.0), (28.0, -54.0), (17.0, -43.0),
                    (0.0, -31.0), (-17.0, -43.0), (-28.0, -54.0), (-26.0, -68.0)
                ]))
                if includeBellyWisp {
                    // Subtle narrow vertical white belly tuft lower down between the striped front legs!
                    marks.append(polygonMark(space: "body", color: bibColor, alpha: 0.94, points: [
                        (0.0, -14.0), (6.5, -3.0), (5.5, 16.0), (0.0, 22.0), (-5.5, 16.0), (-6.5, -3.0)
                    ]))
                }
            case .fullBib:
                marks.append(polygonMark(space: "body", color: bibColor, points: [
                    (0.0, -78.0), (22.0, -68.0), (26.0, -34.0), (24.0, 10.0),
                    (15.0, 36.0), (0.0, 42.0), (-15.0, 36.0), (-24.0, 10.0),
                    (-26.0, -34.0), (-22.0, -68.0)
                ]))
            }
        }

        // Paint colored cap over a light head on the 3D spherical `.head` dome (NO flat `.skull` rect that would block the eyes!)
        func appendColoredCapForBlaze(_ blaze: CatFaceBlaze, capColor: String, muzzleWhiteColor: String, width: Double) {
            let w = min(0.90, max(0.25, width))
            switch blaze {
            case .none:
                break
            case .invertedV:
                let cheekOpenX = 18.0 + w * 24.0
                let bridgeHalfX = 2.0 + w * 4.5
                let apexY = -24.0 + (1.0 - w) * 8.0
                regions.append(smoothRegion(space: "head", fill: capColor, points: [
                    (0.5, -42.0), (-34.0, -42.0), (-50.0, -22.0), (-50.0, 11.0),
                    (-cheekOpenX, 13.0), (-bridgeHalfX - 6.0, -4.0), (-0.5, apexY)
                ], tension: 0.22))
                regions.append(smoothRegion(space: "head", fill: capColor, points: [
                    (-0.5, -42.0), (0.5, apexY), (bridgeHalfX + 6.0, -4.0), (cheekOpenX, 13.0),
                    (50.0, 11.0), (50.0, -22.0), (34.0, -42.0)
                ], tension: 0.22))
            case .skewLeft:
                regions.append(smoothRegion(space: "head", fill: capColor, points: [
                    (-48.0, -42.0), (36.0, -42.0), (48.0, -20.0), (46.0, -4.0),
                    (20.0, -12.0), (-2.0, -18.0), (-14.0, 8.0), (-48.0, 16.0)
                ], tension: 0.22))
            case .skewRight:
                regions.append(smoothRegion(space: "head", fill: capColor, points: [
                    (-36.0, -42.0), (48.0, -42.0), (48.0, 16.0), (14.0, 8.0),
                    (2.0, -18.0), (-20.0, -12.0), (-46.0, -4.0), (-48.0, -20.0)
                ], tension: 0.22))
            case .helmetCap:
                regions.append(smoothRegion(space: "head", fill: capColor, points: [
                    (-50.0, -42.0), (50.0, -42.0), (50.0, -12.0), (22.0, -14.0),
                    (0.0, -11.5), (-22.0, -14.0), (-50.0, -12.0)
                ], tension: 0.20))
            case .splitHalf:
                regions.append(smoothRegion(space: "head", fill: capColor, points: [
                    (0.0, -44.0), (-52.0, -42.0), (-52.0, 26.0), (-2.0, 28.0), (1.0, -4.0)
                ], tension: 0.18))
            case .eyePatchLeft:
                regions.append(smoothRegion(space: "head", fill: capColor, points: [
                    (-8.0, -34.0), (-36.0, -34.0), (-44.0, -8.0), (-34.0, 12.0), (-10.0, 8.0), (-5.0, -10.0)
                ], tension: 0.30))
            case .eyePatchRight:
                regions.append(smoothRegion(space: "head", fill: capColor, points: [
                    (8.0, -34.0), (5.0, -10.0), (10.0, 8.0), (34.0, 12.0), (44.0, -8.0), (36.0, -34.0)
                ], tension: 0.30))
            case .noseBridgeBlaze:
                // Authentic Tabby-Bicolor narrow nasal-bridge white flame:
                // Eyes stay 100% surrounded by tabby fur while a crisp white wedge rises up the nose bridge & flares across whisker pads!
                marks.append(polygonMark(space: "head", color: muzzleWhiteColor, points: [
                    (0.0, -6.5), (3.8, -1.0), (6.5, 5.5), (15.0, 11.5),
                    (31.0, 16.5), (34.0, 23.0), (24.0, 33.5), (0.0, 36.0),
                    (-24.0, 33.5), (-34.0, 23.0), (-31.0, 16.5), (-15.0, 11.5),
                    (-6.5, 5.5), (-3.8, -1.0)
                ]))
            case .whiteMuzzle:
                marks.append(polygonMark(space: "head", color: muzzleWhiteColor, points: [
                    (0.0, 3.0), (16.0, 9.5), (29.0, 20.0), (22.0, 34.0),
                    (0.0, 36.0), (-22.0, 34.0), (-29.0, 20.0), (-16.0, 9.5)
                ]))
            case .sealMask:
                break
            }
        }

        // Configure socks on front/hind limbs
        func applyLimbSocks(baseLegHex: String, sockWhiteHex: String) {
            let leftHasSock = dna.frontLeftSock != .none
            let rightHasSock = dna.frontRightSock != .none

            if leftHasSock && rightHasSock {
                palette["paws"] = sockWhiteHex
            } else if !leftHasSock && !rightHasSock {
                palette["paws"] = baseLegHex
            } else {
                palette["paws"] = leftHasSock ? sockWhiteHex : baseLegHex
            }

            if leftHasSock {
                let stop = dna.frontLeftSock == .highSock ? 0.35 : 0.68
                partGradients["leftArm"] = ["from": baseLegHex, "to": sockWhiteHex, "stop": stop]
            } else {
                // Explicit uniform arm gradient prevents CatRenderer from auto-bleeding `pal.belly` white onto dark shoulders!
                partGradients["leftArm"] = ["from": baseLegHex, "to": baseLegHex, "stop": 0.5]
            }

            if rightHasSock {
                let stop = dna.frontRightSock == .highSock ? 0.35 : 0.68
                partGradients["rightArm"] = ["from": baseLegHex, "to": sockWhiteHex, "stop": stop]
            } else {
                partGradients["rightArm"] = ["from": baseLegHex, "to": baseLegHex, "stop": 0.5]
            }

            palette["hindLeg"] = baseLegHex
            palette["hindPaw"] = dna.hindSocks ? sockWhiteHex : baseLegHex
        }

        // MARK: - Coat Family Synthesis

        switch dna.patternFamily {
        case .solid:
            palette["body"] = pHex
            palette["headBody"] = pHex
            palette["legs"] = pHex
            palette["earOuter"] = pHex
            palette["tail"] = pHex
            if pLum > 0.16 {
                palette["bodyShade"] = darkenHex(pHex, amount: 0.07)
            }
            if pLum > 0.72 {
                palette["outline"] = "#8C857CB8"
                palette["crease"] = "#948C8299"
            }
            if dna.faceBlaze == .whiteMuzzle || dna.faceBlaze == .noseBridgeBlaze {
                appendColoredCapForBlaze(dna.faceBlaze, capColor: pHex, muzzleWhiteColor: milk, width: dna.blazeWidth)
            } else if dna.faceBlaze != .none && dna.faceBlaze != .sealMask {
                palette["headBody"] = sHex
                appendColoredCapForBlaze(dna.faceBlaze, capColor: pHex, muzzleWhiteColor: sHex, width: dna.blazeWidth)
            }
            appendChestBibOverlayMark(style: dna.chestBib, bibColor: milk)
            applyLimbSocks(baseLegHex: pHex, sockWhiteHex: milk)
            if dna.foreheadM { appendForeheadM(color: darkenHex(pHex, amount: 0.22), alpha: 0.55) }
            if dna.tailTipDip { appendTailTip(color: sHex) }
            idleLegs = (dna.frontLeftSock == .none && dna.frontRightSock == .none) ? "chest" : "legs"

        case .tuxedoBicolor:
            let whiteHex = luminance(of: sHex) > 0.45 ? sHex : milk
            let darkHex = pHex
            let useWhiteBaseHead = (dna.faceBlaze != .none && dna.faceBlaze != .whiteMuzzle && dna.faceBlaze != .noseBridgeBlaze && dna.faceBlaze != .sealMask)

            // Keep torso & sleeves in dark coat (`darkHex`) with crisp white chest bib & white mittens (never ghostly all-white arms!)
            palette["body"] = darkHex
            palette["legs"] = darkHex
            if dna.chestBib != .none {
                palette["belly"] = whiteHex
            }
            appendChestBibOverlayMark(style: dna.chestBib, bibColor: whiteHex)
            applyLimbSocks(baseLegHex: darkHex, sockWhiteHex: whiteHex)
            idleLegs = "legs"

            palette["earOuter"] = (dna.faceBlaze == .eyePatchRight) ? whiteHex : darkHex
            if dna.faceBlaze == .splitHalf || dna.faceBlaze == .eyePatchLeft {
                marks.append(polygonMark(space: "rightEar", color: whiteHex, points: [(-60, 10), (60, 10), (0, -110)]))
            } else if dna.faceBlaze == .eyePatchRight {
                marks.append(polygonMark(space: "rightEar", color: darkHex, points: [(-60, 10), (60, 10), (0, -110)]))
            }

            palette["tail"] = darkHex
            if useWhiteBaseHead {
                palette["headBody"] = whiteHex
                appendColoredCapForBlaze(dna.faceBlaze, capColor: darkHex, muzzleWhiteColor: whiteHex, width: dna.blazeWidth)
            } else {
                palette["headBody"] = darkHex
                if dna.faceBlaze == .whiteMuzzle || dna.faceBlaze == .noseBridgeBlaze {
                    appendColoredCapForBlaze(dna.faceBlaze, capColor: darkHex, muzzleWhiteColor: whiteHex, width: dna.blazeWidth)
                }
            }
            if dna.chinSpot {
                regions.append(smoothRegion(space: "head", fill: darkHex, points: [
                    (-1.5, 27.5), (5.5, 27.2), (6.0, 31.8), (1.8, 33.2), (-2.2, 31.5)
                ], tension: 0.30))
            }
            if dna.tailTipDip { appendTailTip(color: whiteHex) }

        case .ragdollBicolor:
            let creamHex = "#F7F3EB"
            let pointHex = pHex
            palette["body"] = creamHex
            palette["bodyShade"] = "#ECE3D5"
            palette["headBody"] = creamHex
            palette["belly"] = "#FFFFFF"
            palette["legs"] = creamHex
            palette["paws"] = "#FFFFFF"
            palette["hindLeg"] = creamHex
            palette["hindPaw"] = "#FFFFFF"
            palette["earOuter"] = pointHex
            palette["tail"] = pointHex
            palette["outline"] = "#9B8E8088"
            let ragdollBlaze: CatFaceBlaze = (dna.faceBlaze == .none || dna.faceBlaze == .sealMask) ? .invertedV : dna.faceBlaze
            appendColoredCapForBlaze(ragdollBlaze, capColor: pointHex, muzzleWhiteColor: creamHex, width: dna.blazeWidth)
            idleLegs = "chest"

        case .colorpoint:
            let creamBody = luminance(of: pHex) > 0.55 ? pHex : "#F4EBD9"
            let darkPoint = luminance(of: pHex) > 0.55 ? sHex : pHex
            palette["body"] = creamBody
            palette["bodyShade"] = darkenHex(creamBody, amount: 0.08)
            palette["points"] = darkPoint
            palette["pointsMid"] = blendHex(darkPoint, creamBody, t: 0.48)
            palette["legs"] = darkPoint
            palette["paws"] = dna.frontLeftSock != .none ? milk : darkPoint
            palette["earOuter"] = darkPoint
            palette["tail"] = darkPoint
            palette["outline"] = "#AD98826B"
            idleLegs = "chest"

        case .calico:
            let baseWhite = luminance(of: pHex) > 0.60 ? pHex : milk
            let gingerPatch = sHex
            let inkPatch = tHex
            palette["body"] = baseWhite
            palette["headBody"] = baseWhite
            palette["belly"] = baseWhite
            palette["legs"] = baseWhite
            palette["paws"] = baseWhite
            palette["hindLeg"] = baseWhite
            palette["hindPaw"] = baseWhite
            palette["earOuter"] = gingerPatch
            palette["outline"] = "#B8B0A468"

            // Asymmetric calico ears: left ginger, right charcoal ink!
            regions.append(smoothRegion(space: "rightEar", fill: inkPatch, points: [
                (-56.0, 6.0), (56.0, 6.0), (4.0, -104.0), (-4.0, -104.0)
            ], tension: 0.12))

            // Calico head patches (ginger left brow/cheek + charcoal right crown/temple, preserving sweet white face blaze!)
            let spread = 12.0 + dna.blazeWidth * 24.0
            regions.append(smoothRegion(space: "head", fill: gingerPatch, points: [
                (0.0, -42.0), (-36.0, -42.0), (-50.0, -18.0), (-48.0, 10.0),
                (-spread, 11.0), (-spread * 0.45, -5.0), (-2.0, -20.0)
            ], tension: 0.28))
            regions.append(smoothRegion(space: "head", fill: inkPatch, points: [
                (-2.0, -42.0), (2.0, -21.0), (spread * 0.52, -6.0), (spread + 4.0, 8.0),
                (50.0, 6.0), (50.0, -20.0), (34.0, -42.0)
            ], tension: 0.28))
            // Subtle ginger tabby M inside the ginger patch if requested
            if dna.foreheadM {
                marks.append(strokeMark(space: "head", color: darkenHex(gingerPatch, amount: 0.22), width: 2.3, alpha: 0.65, points: [
                    (-18.0, -29.0), (-15.0, -21.0), (-11.0, -16.0)
                ]))
            }

            // Calico body patches (ginger left hip + charcoal right upper shoulder + small ginger spot)
            regions.append(smoothRegion(space: "body", fill: gingerPatch, points: [
                (-54.0, -52.0 + shiftSpot), (-26.0, -42.0 + shiftSpot), (-22.0, -8.0),
                (-34.0, 18.0), (-56.0, 14.0), (-58.0, -24.0)
            ], tension: 0.30))
            regions.append(smoothRegion(space: "body", fill: inkPatch, points: [
                (54.0, -72.0), (58.0, -34.0), (50.0, -4.0 - shiftSpot),
                (28.0, -10.0 - shiftSpot), (26.0, -48.0), (34.0, -70.0)
            ], tension: 0.30))
            regions.append(smoothRegion(space: "body", fill: gingerPatch, points: [
                (34.0, 2.0), (54.0, -2.0), (54.0, 20.0), (32.0, 20.0)
            ], tension: 0.28))

            // Calico two-tone tail (ginger base + ink tip!)
            palette["tail"] = gingerPatch
            appendTailTip(color: inkPatch)
            if dna.chinSpot {
                regions.append(smoothRegion(space: "head", fill: gingerPatch, points: [
                    (-6.0, 23.0), (6.0, 23.0), (6.5, 30.0), (-6.5, 30.0)
                ], tension: 0.30))
            }
            idleLegs = "chest"

        case .tortoiseshell:
            let darkBase = pHex
            let amberPatch = sHex
            let creamGold = tHex
            palette["body"] = darkBase
            palette["headBody"] = darkBase
            palette["legs"] = darkBase
            palette["paws"] = dna.frontLeftSock != .none ? creamGold : darkBase
            palette["earOuter"] = darkBase
            palette["tail"] = darkBase
            if luminance(of: dna.noseHex) < 0.28 {
                palette["nose"] = "#CA7F7A"
            }

            regions.append(smoothRegion(space: "leftEar", fill: amberPatch, alpha: 0.88, points: [
                (-8.0, -22.0), (42.0, -10.0), (6.0, -94.0), (-20.0, -54.0)
            ], tension: 0.25))
            regions.append(smoothRegion(space: "rightEar", fill: creamGold, alpha: 0.72, points: [
                (-30.0, -18.0), (14.0, -28.0), (-2.0, -82.0), (-36.0, -46.0)
            ], tension: 0.25))
            regions.append(smoothRegion(space: "head", fill: amberPatch, alpha: 0.85, points: [
                (-28.0, -34.0), (-6.0, -32.0), (-3.0, -14.0), (-24.0, -12.0), (-34.0, -24.0)
            ], tension: 0.34))
            regions.append(smoothRegion(space: "head", fill: creamGold, alpha: 0.78, points: [
                (2.0, -24.0), (16.0, -26.0), (12.0, -8.0), (1.0, -4.0)
            ], tension: 0.32))
            regions.append(smoothRegion(space: "head", fill: amberPatch, alpha: 0.80, points: [
                (22.0, 2.0), (42.0, 0.0), (40.0, 18.0), (20.0, 16.0)
            ], tension: 0.34))
            regions.append(smoothRegion(space: "head", fill: creamGold, alpha: 0.70, points: [
                (-38.0, 6.0), (-22.0, 8.0), (-24.0, 20.0), (-40.0, 18.0)
            ], tension: 0.34))
            regions.append(smoothRegion(space: "body", fill: amberPatch, alpha: 0.82, points: [
                (-46.0, -54.0), (-22.0, -48.0), (-20.0, -28.0), (-44.0, -24.0)
            ], tension: 0.34))
            regions.append(smoothRegion(space: "body", fill: creamGold, alpha: 0.74, points: [
                (-8.0, -44.0), (14.0, -42.0), (10.0, -22.0), (-12.0, -24.0)
            ], tension: 0.34))
            regions.append(smoothRegion(space: "body", fill: amberPatch, alpha: 0.80, points: [
                (22.0, -38.0), (48.0, -42.0), (50.0, -16.0), (26.0, -14.0)
            ], tension: 0.34))
            regions.append(smoothRegion(space: "body", fill: creamGold, alpha: 0.72, points: [
                (-36.0, -8.0), (-12.0, -6.0), (-16.0, 14.0), (-40.0, 12.0)
            ], tension: 0.34))
            appendTailTip(color: amberPatch)
            appendChestBibOverlayMark(style: dna.chestBib, bibColor: creamGold)

        case .tabby, .tabbyBicolor:
            let baseFur = pHex
            let bibCol = luminance(of: sHex) > 0.50 ? sHex : milk
            let stripeHex = luminance(of: tHex) < luminance(of: baseFur) ? tHex : darkenHex(baseFur, amount: 0.45)
            let isBicolor = (dna.patternFamily == .tabbyBicolor || dna.chestBib != .none)

            palette["body"] = baseFur
            palette["headBody"] = baseFur
            palette["stripes"] = stripeHex
            palette["earOuter"] = darkenHex(baseFur, amount: 0.22)
            // Natural warm tawny-brown inner ear fluff on dark brown/charcoal tabbies instead of neon pink
            if luminance(of: baseFur) < 0.42 && dna.earInnerHex == "#E4A6A8" {
                palette["earInner"] = "#78624F"
            }
            palette["tail"] = baseFur
            // CRITICAL: Keep legs in rich dark tabby `baseFur` (NEVER chalk-white sleeves!), with 5 tiger bracelet rings!
            palette["legs"] = baseFur
            if pLum < 0.48 {
                // Natural deep charcoal-umber leg creases & contour instead of chalky light-grey default creases
                palette["crease"] = darkenHex(baseFur, amount: 0.34)
                palette["outline"] = darkenHex(baseFur, amount: 0.38)
            }
            idleLegs = "legs"

            // Subtle darker dorsal crown & upper-back gradient for rich 2.5D agouti coat depth
            partGradients["head"] = ["from": darkenHex(baseFur, amount: 0.22), "to": baseFur, "stop": 0.55]
            partGradients["body"] = ["from": darkenHex(baseFur, amount: 0.14), "to": baseFur, "stop": 0.55]

            applyLimbSocks(baseLegHex: baseFur, sockWhiteHex: bibCol)

            // 1. Draw full-body tiger rib stripes, chest necklaces, arm bracelets, forehead M & cheek eyeliners FIRST
            if dna.foreheadM { appendForeheadM(color: stripeHex, alpha: 0.90) }
            if dna.cheekStripes { appendCheekStripes(color: stripeHex, alpha: 0.88) }
            appendRibStripes(color: stripeHex, alpha: 0.88)
            appendArmTabbyBracelets(color: stripeHex, alpha: 0.88)
            if dna.tailRings { appendTailRings(color: stripeHex, alpha: 0.90) }
            // Tabby tail tips are always rich dark `stripeHex` (never white!)
            appendTailTip(color: stripeHex)

            // 2. Layer white muzzle / nose-bridge flame & V-collar kerchief ON TOP so white stays snowy crisp while stripes surround it!
            let effectiveBlaze: CatFaceBlaze = (dna.faceBlaze == .none && isBicolor) ? .noseBridgeBlaze : dna.faceBlaze
            if effectiveBlaze == .invertedV || effectiveBlaze == .skewLeft || effectiveBlaze == .skewRight {
                palette["headBody"] = bibCol
                appendColoredCapForBlaze(effectiveBlaze, capColor: baseFur, muzzleWhiteColor: bibCol, width: dna.blazeWidth)
            } else if effectiveBlaze == .noseBridgeBlaze || effectiveBlaze == .whiteMuzzle {
                appendColoredCapForBlaze(effectiveBlaze, capColor: baseFur, muzzleWhiteColor: bibCol, width: dna.blazeWidth)
            }

            let effectiveBib: CatChestBibStyle = (dna.chestBib == .none && dna.patternFamily == .tabbyBicolor) ? .triangleCollar : dna.chestBib
            if effectiveBib != .none {
                palette["belly"] = bibCol
                appendChestBibOverlayMark(
                    style: effectiveBib,
                    bibColor: bibCol,
                    includeBellyWisp: (effectiveBib == .triangleCollar && dna.patternFamily == .tabbyBicolor)
                )
            }

        case .shaded:
            let dorsalHex = pHex
            let creamUnder = luminance(of: sHex) > 0.65 ? sHex : "#F8F4EC"
            let tipDark = tHex
            palette["body"] = creamUnder
            palette["headBody"] = dorsalHex
            palette["belly"] = creamUnder
            palette["legs"] = creamUnder
            palette["paws"] = creamUnder
            palette["hindLeg"] = creamUnder
            palette["hindPaw"] = creamUnder
            palette["earOuter"] = dorsalHex
            palette["tail"] = dorsalHex
            palette["outline"] = "#B8AA9668"

            partGradients["head"] = ["from": dorsalHex, "to": creamUnder, "stop": 0.64]
            partGradients["body"] = ["from": blendHex(dorsalHex, creamUnder, t: 0.35), "to": creamUnder, "stop": 0.62]
            appendColoredCapForBlaze(.whiteMuzzle, capColor: dorsalHex, muzzleWhiteColor: creamUnder, width: 0.60)
            if dna.foreheadM {
                appendForeheadM(color: tipDark, alpha: 0.38)
            }
            if dna.cheekStripes {
                appendCheekStripes(color: tipDark, alpha: 0.34)
            }
            appendTailTip(color: tipDark)
            idleLegs = "chest"

        case .van:
            let snowHex = luminance(of: pHex) > 0.70 ? pHex : "#F7F5EF"
            let patchHex = sHex
            palette["body"] = snowHex
            palette["headBody"] = snowHex
            palette["belly"] = snowHex
            palette["legs"] = snowHex
            palette["paws"] = snowHex
            palette["hindLeg"] = snowHex
            palette["hindPaw"] = snowHex
            palette["earOuter"] = patchHex
            palette["tail"] = patchHex
            palette["outline"] = "#BCBAAC70"

            // Classic Van head crown spots near ear bases
            regions.append(smoothRegion(space: "head", fill: patchHex, points: [
                (-38.0, -38.0), (-12.0, -38.0), (-14.0, -20.0), (-36.0, -18.0)
            ], tension: 0.30))
            regions.append(smoothRegion(space: "head", fill: patchHex, points: [
                (14.0, -38.0), (38.0, -38.0), (36.0, -20.0), (16.0, -22.0)
            ], tension: 0.30))
            if dna.tailRings {
                appendTailRings(color: darkenHex(patchHex, amount: 0.22), alpha: 0.55)
            }
            idleLegs = "chest"
        }

        let shape: [String: Any] = [
            "build": dna.isSleekBuild ? "sleek" : "standard",
            "cheekFullness": round2(dna.cheekFullness),
            "earSize": round2(dna.earSize),
            "pawStagger": 0
        ]

        let dnaData = try JSONEncoder().encode(dna)
        let dnaDict = (try JSONSerialization.jsonObject(with: dnaData) as? [String: Any]) ?? [:]

        var root: [String: Any] = [
            "formatVersion": 2,
            "name": dna.name,
            "author": "TypeZero Photo Studio",
            "species": PetSpeciesKind.cat.rawValue,
            "headSurface": "dome",
            "idleLegs": idleLegs,
            "palette": palette,
            "shape": shape,
            "typezeroCatDNA": dnaDict
        ]
        if !partGradients.isEmpty { root["partGradients"] = partGradients }
        if !regions.isEmpty { root["regions"] = regions }
        if !marks.isEmpty { root["marks"] = marks }
        if let png = previewPNG, !png.isEmpty, png.count <= 500 * 1024 {
            root["preview"] = "data:image/png;base64," + png.base64EncodedString()
        }

        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Color Math Helpers

    public static func rgbComponents(_ hex: String) -> (r: Double, g: Double, b: Double) {
        let clean = CatPhotoDNA.normalizeHex(hex, fallback: "#232328").dropFirst()
        let scanner = Scanner(string: String(clean))
        var val: UInt64 = 0
        scanner.scanHexInt64(&val)
        return (
            r: Double((val >> 16) & 0xFF) / 255.0,
            g: Double((val >> 8) & 0xFF) / 255.0,
            b: Double(val & 0xFF) / 255.0
        )
    }

    public static func hexString(from nsColor: NSColor) -> String {
        let c = nsColor.usingColorSpace(.sRGB) ?? nsColor
        let r = max(0, min(255, Int((c.redComponent * 255.0).rounded())))
        let g = max(0, min(255, Int((c.greenComponent * 255.0).rounded())))
        let b = max(0, min(255, Int((c.blueComponent * 255.0).rounded())))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    public static func swiftUIColor(_ hex: String) -> NSColor {
        let c = rgbComponents(hex)
        return NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: 1.0)
    }

    static func luminance(of hex: String) -> Double {
        let c = rgbComponents(hex)
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }

    private static func darkenHex(_ hex: String, amount: Double) -> String {
        let c = rgbComponents(hex)
        let k = max(0.0, 1.0 - amount)
        return String(
            format: "#%02X%02X%02X",
            max(0, min(255, Int((c.r * k * 255.0).rounded()))),
            max(0, min(255, Int((c.g * k * 255.0).rounded()))),
            max(0, min(255, Int((c.b * k * 255.0).rounded())))
        )
    }

    private static func blendHex(_ a: String, _ b: String, t: Double) -> String {
        let ca = rgbComponents(a)
        let cb = rgbComponents(b)
        let u = min(1.0, max(0.0, t))
        let r = ca.r + (cb.r - ca.r) * u
        let g = ca.g + (cb.g - ca.g) * u
        let bl = ca.b + (cb.b - ca.b) * u
        return String(
            format: "#%02X%02X%02X",
            max(0, min(255, Int((r * 255.0).rounded()))),
            max(0, min(255, Int((g * 255.0).rounded()))),
            max(0, min(255, Int((bl * 255.0).rounded())))
        )
    }

    private static func round2(_ v: Double) -> Double {
        (v * 100.0).rounded() / 100.0
    }
}
