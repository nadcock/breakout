//
//  WaitingForTap.swift
//  Breakout
//
//  Created by Nick Adcock on 4/17/17.
//  Copyright © 2017 NEA. All rights reserved.
//

import SpriteKit
import GameplayKit

class WaitingForTap: GKState {
  unowned let scene: GameScene
  
  init(scene: SKScene) {
    self.scene = scene as! GameScene
    super.init()
  }
  
  override func didEnter(from previousState: GKState?) {
    scene.setBallOnPaddle()
  }
  
  override func willExit(to nextState: GKState) {
    
  }
    
  override func update(deltaTime seconds: TimeInterval) {
    scene.setBallOnPaddle()   
  }
  
  override func isValidNextState(_ stateClass: AnyClass) -> Bool {
    return stateClass is Playing.Type
    }

}
