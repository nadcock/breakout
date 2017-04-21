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
 
 
    Things still need to do:
        - Main Menu Scene
        - Allow user to change settings:
            - Sounds On/Off
            - Accelerometer vs Tapping paddle
        - Score keeping via time took to complete
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
    
}


class GameScene: SKScene, SKPhysicsContactDelegate {
    var useAccelerometer = false
    var isFingerOnPaddle = false
    var lives = 3
    var score = 0
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
            
        }
    }
    
    var motionManager: CMMotionManager!
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
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
        
        let paddle = SKSpriteNode(imageNamed: "\(Categories.Paddle.Name).png")
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
        
        let numberOfBlocks = 12
        let numberOfRows = 7
        let blockWidth = SKSpriteNode(imageNamed: Categories.Block.Name).size.width
        let totalBlocksWidth = blockWidth * CGFloat(numberOfBlocks)
        
        let xOffset = (frame.width - totalBlocksWidth) / 2
        for x in 0..<numberOfRows{
            for i in 0..<numberOfBlocks {
                let block = SKSpriteNode(imageNamed: "\(Categories.Block.Name).png")
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
            let life = SKSpriteNode(imageNamed: "\(Categories.Ball.Name).png")
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
        
        let scoreLabel = SKLabelNode(fontNamed: "AmericanTypewriter")
        scoreLabel.text = "Hits: \(score)"
        scoreLabel.fontSize = 15
        scoreLabel.fontColor = UIColor.lightGray
        scoreLabel.name = "scoreLabel"
        scoreLabel.position = CGPoint(x: scoreLabel.frame.size.width * 1.2 / 2, y: scoreLabel.frame.size.height / 2)
        addChild(scoreLabel)
        
        gameState.enter(FirstTouch.self)
    }
    
    override func update(_ currentTime: TimeInterval) {
        gameState.update(deltaTime: currentTime)
        if useAccelerometer {
            processUserMotion(forUpdate: currentTime)
        }
        
    }
    
    func processUserMotion(forUpdate currentTime: TimeInterval) {
        if let paddle = childNode(withName: Categories.Paddle.Name) as? SKSpriteNode {
            if let accData = motionManager.accelerometerData {
                if fabs(accData.acceleration.x) > 0.2 {
                    print("Data: \(accData.acceleration.y)")
                    //paddle.physicsBody!.applyForce(CGVector(dx: 40 * CGFloat(accData.acceleration.y), dy: 0))
                    var newPaddlePosition = paddle.position.x + (CGFloat(40) * CGFloat(accData.acceleration.y)) //- (paddle.size.width / 2)
                    newPaddlePosition = max(frame.minX + (paddle.size.width / 2), newPaddlePosition)
                    newPaddlePosition = min(frame.maxX - (paddle.size.width / 2), newPaddlePosition)
                    paddle.position.x = newPaddlePosition
                }
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if (!useAccelerometer) {
            switchToNextGameState(touches: touches)
        } else {
            if (!(gameState.currentState is Playing)) {
                switchToNextGameState(touches: touches)
            }
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
        if (isFingerOnPaddle && !useAccelerometer) {
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
        }
    }
    
    func randomFloat(from: CGFloat, to: CGFloat) -> CGFloat {
        let rand: CGFloat = CGFloat(Float(arc4random()) / 0xFFFFFFFF)
        return (rand) * (to - from) + from
    }
    
    func breakBlock(node: SKNode) {
        node.removeFromParent()
        score += 1
        let scoreLabel = childNode(withName: "scoreLabel") as! SKLabelNode
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
        
        let ball = SKSpriteNode(imageNamed: "\(Categories.Ball.Name).png")
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
        ball.physicsBody!.contactTestBitMask = Categories.Bottom.Bitmask | Categories.Block.Bitmask | Categories.Border.Bitmask
        ball.zPosition = 2
        
        addChild(ball)
        isFingerOnPaddle = false
    }
    
    
}


