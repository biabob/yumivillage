//
//  ContentView.swift
//  Yumi village Watch App
//
//  Весь игровой код на первой итерации — один файл,
//  чтобы Xcode подхватил без правки project.pbxproj.
//  Следующий шаг: разбить на модули.
//

import SwiftUI
import SpriteKit

// MARK: - GameState

final class GameState: ObservableObject {
    @Published var coins: Int = 0
    @Published var flour: Int = 0
    @Published var bread: Int = 0

    // 0 — заброшена, 1 — восстановлена
    @Published var bakeryLevel: Int = 0

    // Какой диалог открыт сейчас
    @Published var activeBuilding: BuildingKind? = nil

    enum BuildingKind: String, Identifiable {
        case bakery
        var id: String { rawValue }
    }

    func tap(_ kind: BuildingKind) { activeBuilding = kind }
    func closeDialog()            { activeBuilding = nil  }
}

// MARK: - YumiNode

final class YumiNode: SKNode {

    private let body: SKShapeNode

    override init() {
        body = SKShapeNode(circleOfRadius: 9)
        body.fillColor  = SKColor(red: 0.95, green: 0.62, blue: 0.22, alpha: 1)
        body.strokeColor = .clear
        body.zPosition  = 10

        super.init()

        // Ушки
        for side: CGFloat in [-1, 1] {
            let ear = SKShapeNode()
            let p = CGMutablePath()
            p.move(to: CGPoint(x: side * 5, y: 7))
            p.addLine(to: CGPoint(x: side * 9, y: 15))
            p.addLine(to: CGPoint(x: side * 2, y: 9))
            p.closeSubpath()
            ear.path = p
            ear.fillColor = body.fillColor
            ear.strokeColor = .clear
            body.addChild(ear)
        }

        // Имя
        let name = SKLabelNode(text: "Юми")
        name.fontSize  = 7
        name.fontColor = .white
        name.fontName  = "Helvetica-Bold"
        name.position  = CGPoint(x: 0, y: -18)
        name.zPosition = 10

        addChild(body)
        addChild(name)

        // Дыхание в покое
        let breathe = SKAction.repeatForever(.sequence([
            .scale(to: 1.06, duration: 0.9),
            .scale(to: 1.00, duration: 0.9)
        ]))
        body.run(breathe, withKey: "idle")
    }

    required init?(coder: NSCoder) { fatalError() }

    func walk(to dest: CGPoint) {
        let dist     = hypot(dest.x - position.x, dest.y - position.y)
        let duration = max(0.3, TimeInterval(dist / 55))

        // Разворот
        body.xScale = dest.x < position.x ? -1 : 1

        removeAction(forKey: "walk")
        run(.sequence([
            .move(to: dest, duration: duration),
        ]), withKey: "walk")
    }
}

// MARK: - BuildingNode

final class BuildingNode: SKNode {

    let kind: GameState.BuildingKind
    private(set) var isAbandoned: Bool

    private let facade: SKShapeNode
    private let signLabel: SKLabelNode

    // Насколько далеко засчитывается касание
    let tapRadius: CGFloat = 34

    init(kind: GameState.BuildingKind, abandoned: Bool) {
        self.kind       = kind
        self.isAbandoned = abandoned

        let wallColor = abandoned
            ? SKColor(white: 0.22, alpha: 1)
            : SKColor(red: 0.72, green: 0.50, blue: 0.26, alpha: 1)
        let roofColor = abandoned
            ? SKColor(white: 0.17, alpha: 1)
            : SKColor(red: 0.60, green: 0.17, blue: 0.12, alpha: 1)

        // Стены
        facade = SKShapeNode(rectOf: CGSize(width: 46, height: 32), cornerRadius: 3)
        facade.fillColor   = wallColor
        facade.strokeColor = abandoned
            ? SKColor(white: 0.30, alpha: 1)
            : SKColor(red: 0.48, green: 0.30, blue: 0.12, alpha: 1)
        facade.lineWidth  = 1.5
        facade.zPosition  = 5

        // Крыша
        let roof = SKShapeNode()
        let rp = CGMutablePath()
        rp.move(to: CGPoint(x: -28, y: 16))
        rp.addLine(to: CGPoint(x:   0, y: 34))
        rp.addLine(to: CGPoint(x:  28, y: 16))
        rp.closeSubpath()
        roof.path        = rp
        roof.fillColor   = roofColor
        roof.strokeColor = .clear
        roof.zPosition   = 6
        facade.addChild(roof)

        // Иконка
        let icon = SKLabelNode(text: abandoned ? "🏚" : "🏠")
        icon.fontSize = 18
        icon.position = CGPoint(x: 0, y: -9)
        icon.zPosition = 7
        facade.addChild(icon)

        // Табличка
        signLabel = SKLabelNode(text: "ПЕКАРНЯ")
        signLabel.fontSize   = 6
        signLabel.fontColor  = abandoned
            ? SKColor(white: 0.45, alpha: 1)
            : SKColor(red: 1.0, green: 0.88, blue: 0.65, alpha: 1)
        signLabel.fontName  = "Helvetica-Bold"
        signLabel.position  = CGPoint(x: 0, y: -30)
        signLabel.zPosition = 5

        super.init()

        addChild(facade)
        addChild(signLabel)

        // Мягкое покачивание — подсказка, что это тапабельно
        run(.repeatForever(.sequence([
            .scale(to: 1.025, duration: 1.4),
            .scale(to: 1.000, duration: 1.4)
        ])))
    }

    required init?(coder: NSCoder) { fatalError() }

    func feedbackTap() {
        facade.run(.sequence([
            .scale(to: 1.10, duration: 0.08),
            .scale(to: 1.00, duration: 0.12)
        ]))
    }

    func refresh(abandoned: Bool) {
        // Перерисовать после восстановления — удалить и создать заново не нужно:
        // сцена сама пересоздаётся через onAppear/onChange
        isAbandoned = abandoned
    }
}

// MARK: - GameScene

final class GameScene: SKScene {

    private let game: GameState
    private var yumi: YumiNode!
    private var bakery: BuildingNode!

    // Определение длинного нажатия
    private var touchStart: (t: TimeInterval, pt: CGPoint)?
    private let longPressMin: TimeInterval = 0.32
    private let tapMaxDelta:  CGFloat      = 9

    init(game: GameState, size: CGSize) {
        self.game = game
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        buildWorld()
    }

    // MARK: World setup

    private func buildWorld() {
        removeAllChildren()

        let w = size.width, h = size.height

        // Небо (верхняя четверть)
        let sky = SKSpriteNode(
            color: SKColor(red: 0.45, green: 0.60, blue: 0.75, alpha: 1),
            size:  CGSize(width: w, height: h * 0.28))
        sky.position  = CGPoint(x: w/2, y: h * 0.86)
        sky.zPosition = 0
        addChild(sky)

        // Трава
        let grass = SKSpriteNode(
            color: SKColor(red: 0.20, green: 0.38, blue: 0.17, alpha: 1),
            size:  CGSize(width: w, height: h * 0.72))
        grass.position  = CGPoint(x: w/2, y: h * 0.36)
        grass.zPosition = 0
        addChild(grass)

        // Грунтовая дорожка
        let road = SKShapeNode(rectOf: CGSize(width: 16, height: h * 0.55))
        road.fillColor   = SKColor(red: 0.55, green: 0.43, blue: 0.28, alpha: 1)
        road.strokeColor = .clear
        road.position    = CGPoint(x: w/2, y: h * 0.37)
        road.zPosition   = 1
        addChild(road)

        // Деревья
        placeTree(at: CGPoint(x: w * 0.14, y: h * 0.56))
        placeTree(at: CGPoint(x: w * 0.83, y: h * 0.60))
        placeTree(at: CGPoint(x: w * 0.08, y: h * 0.36))
        placeTree(at: CGPoint(x: w * 0.90, y: h * 0.38))

        // Пекарня
        bakery = BuildingNode(kind: .bakery, abandoned: game.bakeryLevel == 0)
        bakery.position = CGPoint(x: w/2, y: h * 0.66)
        addChild(bakery)

        // Юми
        yumi = YumiNode()
        yumi.position = CGPoint(x: w/2, y: h * 0.22)
        addChild(yumi)
    }

    private func placeTree(at pt: CGPoint) {
        let trunk = SKShapeNode(rectOf: CGSize(width: 5, height: 11))
        trunk.fillColor   = SKColor(red: 0.36, green: 0.22, blue: 0.09, alpha: 1)
        trunk.strokeColor = .clear
        trunk.position    = pt
        trunk.zPosition   = 2

        let crown = SKShapeNode(circleOfRadius: 9)
        crown.fillColor   = SKColor(red: 0.17, green: 0.44, blue: 0.16, alpha: 1)
        crown.strokeColor = .clear
        crown.position    = CGPoint(x: 0, y: 11)
        crown.zPosition   = 3
        trunk.addChild(crown)

        addChild(trunk)
    }

    // MARK: Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        touchStart = (t.timestamp, t.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let start = touchStart else { return }
        touchStart = nil

        let loc      = t.location(in: self)
        let duration = t.timestamp - start.t
        let delta    = hypot(loc.x - start.pt.x, loc.y - start.pt.y)

        if duration >= longPressMin {
            // Длинное нажатие — идти туда
            yumi.walk(to: start.pt)
        } else if delta < tapMaxDelta {
            // Обычный тап — проверяем здания
            checkTap(at: loc)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = nil
    }

    private func checkTap(at pt: CGPoint) {
        let d = hypot(pt.x - bakery.position.x, pt.y - bakery.position.y)
        if d < bakery.tapRadius {
            bakery.feedbackTap()
            game.tap(.bakery)
        }
    }
}

// MARK: - Dialogs

struct BakerySheet: View {
    @ObservedObject var game: GameState

    var body: some View {
        ScrollView {
            VStack(spacing: 7) {
                Text(game.bakeryLevel == 0 ? "🏚" : "🏠")
                    .font(.system(size: 34))

                Text("Пекарня")
                    .font(.system(.headline, design: .rounded))

                if game.bakeryLevel == 0 {
                    Text("Здесь пекла бабушка. Юми хочет её восстановить.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        game.bakeryLevel = 1
                        game.closeDialog()
                    } label: {
                        Label("Восстановить", systemImage: "hammer.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                } else {
                    Label("Пекарня работает", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)

                    Button("Закрыть") { game.closeDialog() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Root View

struct ContentView: View {
    @StateObject private var game  = GameState()
    @State private var scene: GameScene? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Игровая сцена
                if let scene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                }

                // Минимальный HUD — монеты
                Label("\(game.coins)", systemImage: "coloncurrencysign.circle.fill")
                    .font(.system(.caption2, design: .rounded).bold())
                    .foregroundStyle(.yellow)
                    .shadow(color: .black.opacity(0.65), radius: 1, x: 0, y: 1)
                    .padding(.leading, 6)
                    .padding(.top, 3)
            }
            .onAppear {
                guard scene == nil else { return }
                scene = GameScene(game: game, size: geo.size)
            }
            // Пересоздать сцену при смене уровня (пекарня восстановлена)
            .onChange(of: game.bakeryLevel) { _ in
                guard let s = scene else { return }
                s.game.bakeryLevel == 0
                    ? nil
                    : s.run(.wait(forDuration: 0)) // triggers didMove через SKView, не нужно
                // Простой способ: пересоздать
                let fresh = GameScene(game: game, size: geo.size)
                scene = fresh
            }
        }
        .sheet(item: $game.activeBuilding) { kind in
            switch kind {
            case .bakery: BakerySheet(game: game)
            }
        }
    }
}
