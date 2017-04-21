//
//  BeginPlaying.swift
//  Breakout
//
//  Created by Nick Adcock on 4/18/17.
//  Copyright © 2017 NEA. All rights reserved.
//

import SpriteKit
import GameplayKit

class FirstTouch: GKState {
    unowned let scene: GameScene
    
    init(scene: SKScene) {
        self.scene = scene as! GameScene
        super.init()
    }
    
    override func didEnter(from previousState: GKState?) {
        let initialScale = SKAction.scale(to: 1.1, duration: 1.0)
        let scaleToLarger = SKAction.scale(to: 1.1, duration: 1.0)
        let scaleSmaller = SKAction.scale(to: 0.9, duration: 1.0)
        let pulse = SKAction.repeatForever(SKAction.sequence([scaleSmaller,scaleToLarger]))
        scene.childNode(withName: Categories.GameMessage.Name)!.run(SKAction.sequence([initialScale,pulse]))
        scene.setBallOnPaddle()
        
    }
    
    override func update(deltaTime seconds: TimeInterval) {
        scene.setBallOnPaddle()
    }
    
    override func willExit(to nextState: GKState) {
        if nextState is Playing {
            let scale = SKAction.scale(to: 0, duration: 0.4)
            scene.childNode(withName: Categories.GameMessage.Name)!.removeAllActions()
            scene.childNode(withName: Categories.GameMessage.Name)!.run(scale)
        }
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass is Playing.Type
    }
    
}
