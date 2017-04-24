//
//  GameScene.swift
//  Breakout
//
//  Created by Nick Adcock on 4/17/17.
//  Copyright © 2017 NEA. All rights reserved.
//

/*  Things changed:
        - Turned catagories into struct
        - Added Game State to allow for multiple lives
        - Started ball on paddle instead of in air
        - Moved node creation to code instead of Scene Editor
        - Allow for gameplay via accelerometer
        - Reskin graphics
        - Allow user to change settings:
            - Sounds On/Off
            - Accelerometer vs Tapping paddle
        - Settins above persist through UserDefaults
        - Keep score by how many blocks broken
        - Ability to pause game
 
 
    Things still need to do:
        - Main Menu Scene
        - Level creation via tile map for blocks
        - Level tracking
 */

import SpriteKit
import GameplayKit
import CoreMotion

struct Categories {
    struct Ball {
        static let Name = "ball"
        static let Bitmask: UInt32 = 0x1 << 0
    }
    
    struct Bottom {
        static let Bitmask: UInt32 = 0x1 << 1
    }
    
    struct Block {
        static let Name = "block"
        static let Bitmask: UInt32 = 0x1 << 2
    }
    
    struct Paddle {
        static let Name = "paddle"
        static let Bitmask: UInt32 = 0x1 << 3
    }
    
    struct Border {
        static let Bitmask: UInt32 = 0x1 << 4
    }
    
    struct GameMessage {
        static let Name = "gameMessage"
    }
    
    struct Pause {
        static let Name = "pause"
    }
    
    struct ScoreLabel {
        static let Name = "scoreLabel"
    }
    
}


class GameScene: SKScene, SKPhysicsContactDelegate {
    var useAccelerometer: Bool?
    var soundsOn: Bool?
    var isFingerOnPaddle = false
    var lives = 3
    var score = 0
    
    let blipSound = SKAction.playSoundFileNamed("pongblip", waitForCompletion: false)
    let blipPaddleSound = SKAction.playSoundFileNamed("paddleBlip", waitForCompletion: false)
    let gameWonSound = SKAction.playSoundFileNamed("game-won", waitForCompletion: false)
    let gameOverSound = SKAction.playSoundFileNamed("game-over", waitForCompletion: false)
    
    let prefs = UserDefaults.standard
    
    lazy var gameState: GKStateMachine = GKStateMachine(states: [
        FirstTouch(scene: self),
        WaitingForTap(scene: self),
        Playing(scene: self),
        GameOver(scene: self)])
    let colors: [UIColor] = [UIColor.red, UIColor.orange, UIColor.yellow, UIColor.green, UIColor.cyan, UIColor.blue, UIColor.purple]
    
    var levelWon: Bool = false {
        didSet {
            let levelOver = childNode(withName: Categories.GameMessage.Name) as! SKSpriteNode
            let textureName = levelWon ? "YouWon" : "GameOver"
            let texture = SKTexture(imageNamed: textureName)
            let actionSequence = SKAction.sequence([SKAction.setTexture(texture), SKAction.scale(to: 1.0, duration: 0.25)])
            levelOver.run(actionSequence)
            setBallOnPaddle()
            if (soundsOn!) {
                run(levelWon ? gameWonSound : gameOverSound)
            }
        }
    }
    
    var motionManager: CMMotionManager!
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        if isKeyPresentInUserDefaults(key: "useAccelerometer") {
            useAccelerometer = prefs.bool(forKey: "useAccelerometer")
        } else {
            useAccelerometer = true
            prefs.set(useAccelerometer!, forKey: "useAccelerometer")
        }
        
        if isKeyPresentInUserDefaults(key: "soundsOn") {
            soundsOn = prefs.bool(forKey: "soundsOn")
        } else {
            soundsOn = true
            prefs.set(soundsOn!, forKey: "useAccelerometer")
        }
        
        
        motionManager = CMMotionManager()
        motionManager.startAccelerometerUpdates()
        
        physicsWorld.gravity = CGVector(dx: 0.0, dy: 0.0)
        physicsWorld.contactDelegate = self
        
        let borderBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: self.frame.minX, y: self.frame.minY - 50, width: self.frame.maxX, height: self.frame.maxY + 50))

        borderBody.friction = 0
        borderBody.categoryBitMask = Categories.Border.Bitmask
        self.physicsBody = borderBody
        
        let bottomRect = CGRect(x: frame.origin.x, y: frame.origin.y - 49, width: frame.size.width, height: 1)
        let bottom = SKNode()
        bottom.physicsBody = SKPhysicsBody(edgeLoopFrom: bottomRect)
        bottom.physicsBody!.categoryBitMask = Categories.Bottom.Bitmask
        addChild(bottom)
        
        let paddle = SKSpriteNode(imageNamed: Categories.Paddle.Name)
        paddle.position = CGPoint(x: frame.width / 2, y: frame.height * 0.1)
        paddle.physicsBody = SKPhysicsBody(rectangleOf: paddle.frame.size)
        paddle.physicsBody!.categoryBitMask = Categories.Paddle.Bitmask
        paddle.physicsBody!.allowsRotation = false
        paddle.physicsBody!.friction = 0.0
        paddle.physicsBody!.restitution = 1.0
        paddle.physicsBody!.linearDamping = 0.0
        paddle.physicsBody!.angularDamping = 0.0
        paddle.physicsBody!.affectedByGravity = false
        paddle.physicsBody!.isDynamic = false
        paddle.name = Categories.Paddle.Name
        paddle.physicsBody!.categoryBitMask = Categories.Paddle.Bitmask
        paddle.physicsBody!.contactTestBitMask = Categories.Border.Bitmask
        paddle.zPosition = 3
        addChild(paddle)
        
        
        let numberOfRows = 7
        let nodeScaleFactor: CGFloat = 0.65
        let blockWidth = SKSpriteNode(imageNamed: Categories.Block.Name).size.width * nodeScaleFactor
        let numberOfBlocks = floor(frame.width / blockWidth)
        
        let totalBlocksWidth = blockWidth * CGFloat(numberOfBlocks)
        
        let xOffset = (frame.width - totalBlocksWidth) / 2
        for x in 0..<numberOfRows{
            for i in 0..<Int(numberOfBlocks) {
                let block = SKSpriteNode(imageNamed: Categories.Block.Name)
                block.setScale(nodeScaleFactor)
                block.position = CGPoint(x: xOffset + CGFloat(CGFloat(i) + 0.5) * blockWidth, y: (frame.height * 0.85) - (block.size.height * CGFloat(x)))
                block.physicsBody = SKPhysicsBody(rectangleOf: block.frame.size)
                block.color = colors[x]
                block.colorBlendFactor = 1.0
                block.physicsBody!.allowsRotation = false
                block.physicsBody!.friction = 0.0
                block.physicsBody!.affectedByGravity = false
                block.physicsBody!.isDynamic = false
                block.name = Categories.Block.Name
                block.physicsBody!.categoryBitMask = Categories.Block.Bitmask
                block.zPosition = 2
                addChild(block)
            }
        }
        
        for i in 0..<lives {
            let life = SKSpriteNode(imageNamed: Categories.Ball.Name)
            life.name = "remainingLife\(i + 1)"
            life.position = CGPoint(x: frame.width - ((life.frame.width * 2.0 * (CGFloat(i) + 1.0))), y: life.frame.height)
            life.alpha = 0.50
            addChild(life)
        }
        
        let gameMessage = SKSpriteNode(imageNamed: "TapToPlay")
        gameMessage.name = Categories.GameMessage.Name
        gameMessage.position = CGPoint(x: frame.midX, y: frame.midY)
        gameMessage.zPosition = 4
        gameMessage.setScale(0.0)
        addChild(gameMessage)
        
        let pause = SKSpriteNode(imageNamed: Categories.Pause.Name)
        pause.name = Categories.Pause.Name
        pause.setScale(0.2)
        pause.position = CGPoint(x: pause.size.width * 1.5 / 2, y: pause.size.height / 2)
        addChild(pause)
        
        let scoreLabel = SKLabelNode(fontNamed: "8BIT WONDER")
        scoreLabel.text = "Hits: \(score)"
        scoreLabel.fontSize = 15
        scoreLabel.fontColor = UIColor.lightGray
        scoreLabel.name = Categories.ScoreLabel.Name
        scoreLabel.position = CGPoint(x: (pause.size.width * 1.5) + scoreLabel.frame.size.width * 1.2 / 2, y: scoreLabel.frame.size.height / 2)
        addChild(scoreLabel)
        
        gameState.enter(FirstTouch.self)
    }
    
    override func update(_ currentTime: TimeInterval) {
        gameState.update(deltaTime: currentTime)
        if (useAccelerometer! && !(gameState.currentState is GameOver)) {
            processUserMotion(forUpdate: currentTime)
        }
        
    }
    
    func processUserMotion(forUpdate currentTime: TimeInterval) {
        if let paddle = childNode(withName: Categories.Paddle.Name) as? SKSpriteNode {
            if let accData = motionManager.accelerometerData {
                if fabs(accData.acceleration.x) > 0.2 {
                    var newPaddlePosition = paddle.position.x + (CGFloat(40) * CGFloat(accData.acceleration.y))
                    newPaddlePosition = max(frame.minX + (paddle.size.width / 2), newPaddlePosition)
                    newPaddlePosition = min(frame.maxX - (paddle.size.width / 2), newPaddlePosition)
                    paddle.position.x = newPaddlePosition
                }
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first!
        if let _ = self.childNode(withName: "pauseBackground") {
            detectPauseScreenTaps(touches: touches)
        } else {
            let pause = childNode(withName: Categories.Pause.Name) as! SKSpriteNode
            if (pause.contains(touch.location(in: self)))  {
                scene!.isPaused = !scene!.view!.isPaused
                presentPausedMenu()
            } else if (!useAccelerometer!) {
                switchToNextGameState(touches: touches)
            } else {
                if (!(gameState.currentState is Playing)) {
                    switchToNextGameState(touches: touches)
                }
            }
        }
    }
    
    func presentPausedMenu() {
        let backgroundRect = SKShapeNode(rect: CGRect(x: 0.0, y: 0.0, width: frame.size.width, height: frame.size.height))
        backgroundRect.fillColor = SKColor(colorLiteralRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.5)
        backgroundRect.lineWidth = 0.0
        backgroundRect.zPosition = 10
        backgroundRect.name = "pauseBackground"
        addChild(backgroundRect)
        
        let greySquare = SKShapeNode(rect: CGRect(x: frame.size.width * 0.2, y: frame.size.height * 0.15, width: frame.size.width - (frame.size.width * 0.2 * 2), height: frame.size.height - (frame.size.height * 0.15 * 2)))
        greySquare.fillColor = SKColor.darkGray
        greySquare.lineWidth = 0.0
        greySquare.zPosition = backgroundRect.zPosition + 1
        greySquare.name = "pauseBackgroundSquare"
        backgroundRect.addChild(greySquare)
        
        let settingsLabel = SKLabelNode(fontNamed: "Heavy Weight Gamer")
        settingsLabel.text = "Settings:"
        settingsLabel.fontSize = 36
        settingsLabel.fontColor = SKColor.white
        settingsLabel.name = "settingsLabel"
        settingsLabel.position = CGPoint(x: ((frame.size.width * 0.25) + (settingsLabel.frame.size.width / 2)) , y: (frame.size.height * 0.65) + (settingsLabel.frame.size.height / 2))
        settingsLabel.zPosition = greySquare.zPosition + 1
        backgroundRect.addChild(settingsLabel)
        
        let useAccLabel = SKLabelNode(fontNamed: "Heavy Weight Gamer")
        useAccLabel.text = "Accelerometer"
        useAccLabel.fontSize = 27
        useAccLabel.fontColor = SKColor.white
        useAccLabel.name = "useAccLabel"
        useAccLabel.position = CGPoint(x: ((frame.size.width * 0.29) + (useAccLabel.frame.size.width / 2)) , y: (frame.size.height * 0.50) + (useAccLabel.frame.size.height / 2))
        useAccLabel.zPosition = greySquare.zPosition + 1
        backgroundRect.addChild(useAccLabel)
        
        let soundFXLabel = SKLabelNode(fontNamed: "Heavy Weight Gamer")
        soundFXLabel.text = "Sound FX"
        soundFXLabel.fontSize = 27
        soundFXLabel.fontColor = SKColor.white
        soundFXLabel.name = "soundFXLabel"
        soundFXLabel.position = CGPoint(x: ((frame.size.width * 0.29) + (soundFXLabel.frame.size.width / 2)) , y: (frame.size.height * 0.38) + (soundFXLabel.frame.size.height / 2))
        soundFXLabel.zPosition = greySquare.zPosition + 1
        backgroundRect.addChild(soundFXLabel)
        
        let resumePlayLabel = SKLabelNode(fontNamed: "Heavy Weight Gamer")
        resumePlayLabel.text = "Resume Play"
        resumePlayLabel.fontSize = 36
        resumePlayLabel.fontColor = SKColor.green
        resumePlayLabel.name = "resumePlayLabel"
        resumePlayLabel.position = CGPoint(x: (frame.size.width * 0.5) , y: (frame.size.height * 0.18) + (resumePlayLabel.frame.size.height / 2))
        resumePlayLabel.zPosition = greySquare.zPosition + 1
        backgroundRect.addChild(resumePlayLabel)
        
        let accSettingsButton = SKSpriteNode(imageNamed: "SettingsButtonOff")
        if (useAccelerometer!) {
            accSettingsButton.texture = SKTexture(imageNamed: "SettingsButtonOn")
        }
        accSettingsButton.zPosition = greySquare.zPosition + 1
        accSettingsButton.name = "accSettingsButton"
        accSettingsButton.position = CGPoint(x: useAccLabel.position.x + (useAccLabel.frame.size.width / 2) + frame.size.width * 0.075, y: (useAccLabel.position.y +  (accSettingsButton.size.height / 2)))
        backgroundRect.addChild(accSettingsButton)
        
        let fxSettingsButton = SKSpriteNode(imageNamed: "SettingsButtonOff")
        if (soundsOn!) {
            fxSettingsButton.texture = SKTexture(imageNamed: "SettingsButtonOn")
        }
        fxSettingsButton.zPosition = greySquare.zPosition + 1
        fxSettingsButton.name = "fxSettingsButton"
        fxSettingsButton.position = CGPoint(x: accSettingsButton.position.x, y: (soundFXLabel.position.y +  (fxSettingsButton.size.height / 2)))
        backgroundRect.addChild(fxSettingsButton)
        
    }
    
    func detectPauseScreenTaps(touches: Set<UITouch>) {
        let pauseBackground = childNode(withName: "pauseBackground") as! SKShapeNode
        let accSettingsButton = pauseBackground.childNode(withName: "accSettingsButton") as! SKSpriteNode
        let fxSettingsButton = pauseBackground.childNode(withName: "fxSettingsButton") as! SKSpriteNode
        let resumePlayLabel = pauseBackground.childNode(withName: "resumePlayLabel") as! SKLabelNode
        
        let touch = touches.first!
        if (accSettingsButton.contains(touch.location(in: self))) {
            useAccelerometer! = !useAccelerometer!
            prefs.set(useAccelerometer!, forKey: "useAccelerometer")
            if (useAccelerometer!) {
                accSettingsButton.texture = SKTexture(imageNamed: "SettingsButtonOn")
            } else {
                accSettingsButton.texture = SKTexture(imageNamed: "SettingsButtonOff")
            }
        }
        
        if (fxSettingsButton.contains(touch.location(in: self))) {
            soundsOn! = !soundsOn!
            prefs.set(soundsOn!, forKey: "soundsOn")
            if (soundsOn!) {
                fxSettingsButton.texture = SKTexture(imageNamed: "SettingsButtonOn")
            } else {
                fxSettingsButton.texture = SKTexture(imageNamed: "SettingsButtonOff")
            }
        }
        
        if (resumePlayLabel.contains(touch.location(in: self))) {
            pauseBackground.removeFromParent()
            scene?.isPaused = false
        }
        
    }
    
    func switchToNextGameState(touches: Set<UITouch>) {
        switch gameState.currentState {
        case is FirstTouch:
            gameState.enter(Playing.self)
            isFingerOnPaddle = true
            
        case is WaitingForTap:
            gameState.enter(Playing.self)
            isFingerOnPaddle = true
            
        case is Playing:
            let touch = touches.first
            let touchLocation = touch!.location(in: self)
            
            if let body = physicsWorld.body(at: touchLocation) {
                if body.node!.name == Categories.Paddle.Name {
                    isFingerOnPaddle = true
                }
            }
            
        case is GameOver:
            let newScene = GameScene(fileNamed:"GameScene")
            newScene!.scaleMode = .aspectFit
            let reveal = SKTransition.flipHorizontal(withDuration: 0.5)
            self.view?.presentScene(newScene!, transition: reveal)
            
        default:
            break
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if (isFingerOnPaddle && !useAccelerometer!) {
            let touch = touches.first
            let touchLocation = touch!.location(in: self)
            let previousLocation = touch!.previousLocation(in: self)
            let paddle = childNode(withName: Categories.Paddle.Name) as! SKSpriteNode
            var paddleX = paddle.position.x + (touchLocation.x - previousLocation.x)
            
            paddleX = max(paddleX, paddle.size.width / 2)
            paddleX = min(paddleX, size.width - paddle.size.width / 2)
            
            paddle.position = CGPoint(x: paddleX, y: paddle.position.y)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            isFingerOnPaddle = false
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        if gameState.currentState is Playing {
            var firstBody: SKPhysicsBody
            var secondBody: SKPhysicsBody
            
            if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
                firstBody = contact.bodyA
                secondBody = contact.bodyB
            } else {
                firstBody = contact.bodyB
                secondBody = contact.bodyA
            }
            
            if firstBody.categoryBitMask == Categories.Ball.Bitmask && secondBody.categoryBitMask == Categories.Bottom.Bitmask {
                if lives <= 0 {
                    gameState.enter(GameOver.self)
                    levelWon = false
                } else {
                    self.enumerateChildNodes(withName: "remainingLife\(lives)") {
                        node, stop in
                        node.removeFromParent()
                    }
                    lives -= 1
                    setBallOnPaddle()
                    isFingerOnPaddle = false
                    gameState.enter(WaitingForTap.self)
                }
            }
            
            if firstBody.categoryBitMask == Categories.Ball.Bitmask && secondBody.categoryBitMask == Categories.Block.Bitmask {
                breakBlock(node: secondBody.node!)
                if isLevelWon() {
                    gameState.enter(GameOver.self)
                    levelWon = true
                }
            }
            
            if firstBody.categoryBitMask == Categories.Ball.Bitmask && secondBody.categoryBitMask == Categories.Border.Bitmask {
                if (soundsOn!) {
                    run(blipSound)
                }
                
            }
            
            
            if firstBody.categoryBitMask == Categories.Ball.Bitmask && secondBody.categoryBitMask == Categories.Paddle.Bitmask {
                if (soundsOn!) {
                    run(blipPaddleSound)
                }
                
            }
        }
    }
    
    func randomFloat(from: CGFloat, to: CGFloat) -> CGFloat {
        let rand: CGFloat = CGFloat(Float(arc4random()) / 0xFFFFFFFF)
        return (rand) * (to - from) + from
    }
    
    func breakBlock(node: SKNode) {
        node.removeFromParent()
        if (soundsOn!) {
           run(blipSound)
        }
        score += 1
        let scoreLabel = childNode(withName: Categories.ScoreLabel.Name) as! SKLabelNode
        scoreLabel.text = "Hits: \(score)"
    }
    
    func isLevelWon() -> Bool {
        var numberOfBricks = 0
        self.enumerateChildNodes(withName: Categories.Block.Name) {
            node, stop in
            numberOfBricks = numberOfBricks + 1
        }
        
        return numberOfBricks == 0
    }
    
    func setBallOnPaddle() {
        let paddle = childNode(withName: Categories.Paddle.Name) as! SKSpriteNode
        
        if let ball = childNode(withName: Categories.Ball.Name) as? SKSpriteNode {
            ball.removeFromParent()
        }
        
        let ball = SKSpriteNode(imageNamed: Categories.Ball.Name)
        //ball.setScale(nodeScaleFactor)
        ball.position = CGPoint(x: paddle.position.x, y: paddle.position.y + (paddle.size.height / 2) + ball.size.height / 2)
        ball.physicsBody = SKPhysicsBody(circleOfRadius: ball.frame.size.width / 2)
        ball.physicsBody!.allowsRotation = false
        ball.physicsBody!.friction = 0.0
        ball.physicsBody!.restitution = 1.0
        ball.physicsBody!.linearDamping = 0.0
        ball.physicsBody!.angularDamping = 0.0
        ball.physicsBody!.affectedByGravity = true
        ball.physicsBody!.isDynamic = true
        ball.name = Categories.Ball.Name
        ball.physicsBody!.categoryBitMask = Categories.Ball.Bitmask
        ball.physicsBody!.contactTestBitMask = Categories.Bottom.Bitmask | Categories.Block.Bitmask | Categories.Border.Bitmask | Categories.Paddle.Bitmask
        ball.zPosition = 2
        addChild(ball)
        
        isFingerOnPaddle = false
    }
    
    func isKeyPresentInUserDefaults(key: String) -> Bool {
        return UserDefaults.standard.object(forKey: key) != nil
    }
    
    
}


