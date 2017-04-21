//
//  Block.swift
//  Breakout
//
//  Created by Nick Adcock on 4/18/17.
//  Copyright © 2017 NEA. All rights reserved.
//

import SpriteKit

enum BlockType: Int, CustomStringConvertible {
    case unknown = 0, brick
    
    var spriteName: String {
        let spriteNames = [
            "block"]
        return spriteNames[rawValue - 1]
    }
    
    var description: String {
        return spriteName
    }
}

class Block: CustomStringConvertible {
    var column: Int
    var row: Int
    let blockType: BlockType
    var blockColor: UIColor?
    var sprite: SKSpriteNode?
    var description: String {
        return "type: \(blockType) location: (\(column),\(row))"
    }
    
    init(column: Int, row: Int, blockType: BlockType) {
        self.column = column
        self.row = row
        self.blockType = blockType
    }
}
