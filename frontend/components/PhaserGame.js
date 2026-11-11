import { useEffect, useRef } from 'react'
import Phaser from 'phaser'

class MainScene extends Phaser.Scene {
  constructor() {
    super('MainScene')
  }

  preload() {
    // Nothing to preload. All textures are generated at runtime for fast loading.
  }

  create() {
    this.gameOver = false
    this.score = 0
    this.level = 1
    this.bombSpeed = 140
    this.controlState = { left: false, right: false, jump: false }

    this.createTextures()
    this.createBackground()
    this.createPlayer()
    this.createPlatforms()
    this.createStars()
    this.createBombs()
    this.createParticles()
    this.createUI()
    this.createInputHandlers()
  }

  createTextures() {
    const graphics = this.make.graphics({ x: 0, y: 0, add: false })

    graphics.fillStyle(0x44d1ff, 1)
    graphics.fillCircle(24, 24, 24)
    graphics.generateTexture('player', 48, 48)
    graphics.clear()

    graphics.fillStyle(0xffff00, 1)
    graphics.fillCircle(10, 10, 10)
    graphics.generateTexture('star', 20, 20)
    graphics.clear()

    graphics.fillStyle(0xff4d4f, 1)
    graphics.fillCircle(16, 16, 16)
    graphics.generateTexture('bomb', 32, 32)
    graphics.clear()

    graphics.fillStyle(0x3b82f6, 1)
    graphics.fillRoundedRect(0, 0, 180, 28, 10)
    graphics.generateTexture('platform', 180, 28)
    graphics.clear()

    graphics.fillStyle(0xffffff, 0.35)
    graphics.fillCircle(12, 12, 12)
    graphics.generateTexture('cloud', 24, 24)
    graphics.clear()
  }

  createBackground() {
    this.cameras.main.setBackgroundColor('#0b1732')

    this.starfield = this.add.particles('star', {
      x: { min: 0, max: 800 },
      y: 0,
      lifespan: { min: 2000, max: 5000 },
      speedY: { min: 20, max: 40 },
      scale: { start: 0.05, end: 0 },
      alpha: { start: 0.5, end: 0 },
      quantity: 1,
      blendMode: 'ADD'
    })

    this.clouds = this.add.group()
    for (let i = 0; i < 6; i++) {
      const cloud = this.add.image(Phaser.Math.Between(50, 750), Phaser.Math.Between(80, 220), 'cloud')
      cloud.setAlpha(0.12)
      cloud.speed = Phaser.Math.Between(8, 20)
      this.clouds.add(cloud)
    }

    this.lighting = this.add.rectangle(400, 300, 800, 600, 0x155c82, 0.08)
  }

  createPlayer() {
    this.player = this.physics.add.sprite(400, 450, 'player')
      .setBounce(0.2)
      .setCollideWorldBounds(true)
      .setDepth(2)

    this.player.body.setSize(40, 40).setOffset(4, 4)
    this.player.setMaxVelocity(320, 800)
    this.player.setDragX(700)

    this.cursors = this.input.keyboard.createCursorKeys()
  }

  createPlatforms() {
    this.platforms = this.physics.add.staticGroup()
    this.platforms.create(400, 568, 'platform').setScale(1).refreshBody()
    this.platforms.create(600, 400, 'platform').refreshBody()
    this.platforms.create(50, 250, 'platform').refreshBody()
    this.platforms.create(750, 220, 'platform').refreshBody()

    this.movingPlatform = this.physics.add.image(240, 320, 'platform')
      .setImmovable(true)
      .setVelocityX(100)
      .setCollideWorldBounds(true)
      .setBounce(1, 0)
      .setDepth(1)
    this.movingPlatform.body.allowGravity = false

    this.physics.add.collider(this.player, this.platforms)
    this.physics.add.collider(this.player, this.movingPlatform)
    this.physics.add.collider(this.movingPlatform, this.platforms)
  }

  createStars() {
    this.stars = this.physics.add.group({
      key: 'star',
      repeat: 11,
      setXY: { x: 12, y: 0, stepX: 70 }
    })

    this.stars.getChildren().forEach((child) => {
      child.setBounceY(Phaser.Math.FloatBetween(0.4, 0.8))
      child.setCircle(10)
    })

    this.physics.add.collider(this.stars, this.platforms)
    this.physics.add.collider(this.stars, this.movingPlatform)
    this.physics.add.overlap(this.player, this.stars, this.collectStar, null, this)
  }

  createBombs() {
    this.bombs = this.physics.add.group()
    this.physics.add.collider(this.bombs, this.platforms)
    this.physics.add.collider(this.bombs, this.movingPlatform)
    this.physics.add.collider(this.player, this.bombs, this.hitBomb, null, this)
  }

  createParticles() {
    this.explosionParticles = this.add.particles('star', {
      speed: { min: -100, max: 100 },
      scale: { start: 0.4, end: 0 },
      alpha: { start: 0.8, end: 0 },
      lifespan: 700,
      quantity: 8,
      on: false
    })
  }

  createUI() {
    this.add.text(400, 30, 'FopCam Arcade', {
      fontSize: '30px',
      color: '#ffffff',
      fontFamily: 'Arial'
    }).setOrigin(0.5)

    this.scoreText = this.add.text(18, 18, 'Score: 0', {
      fontSize: '20px',
      color: '#ffffff'
    }).setDepth(5)

    this.levelText = this.add.text(18, 44, 'Niveau: 1', {
      fontSize: '18px',
      color: '#d0e8ff'
    }).setDepth(5)

    this.hintText = this.add.text(400, 568, 'Keyboard or touch zones: left / right / jump', {
      fontSize: '16px',
      color: '#bbbbff'
    }).setOrigin(0.5).setAlpha(0.85)
  }

  createInputHandlers() {
    this.input.on('pointerdown', this.handlePointerInput, this)
    this.input.on('pointerup', this.handlePointerRelease, this)
    this.input.on('pointermove', (pointer) => {
      if (pointer.isDown) {
        this.handlePointerInput(pointer)
      }
    }, this)

    this.input.keyboard.on('keydown-R', () => {
      if (this.gameOver) {
        this.restartGame()
      }
    })
  }

  handlePointerInput(pointer) {
    if (this.gameOver) {
      return
    }

    const width = this.scale.width
    const height = this.scale.height
    const x = pointer.x
    const y = pointer.y

    const edge = width * 0.2
    const center = width * 0.5

    this.controlState.left = x < edge || (x < center && y > height * 0.6)
    this.controlState.right = x > width - edge || (x > center && y > height * 0.6)
    this.controlState.jump = y < height * 0.35 || (x >= edge && x <= width - edge && y > height * 0.6)
  }

  handlePointerRelease() {
    this.controlState.left = false
    this.controlState.right = false
    this.controlState.jump = false
  }

  update() {
    if (this.gameOver) {
      return
    }

    this.clouds.getChildren().forEach((cloud) => {
      cloud.x += cloud.speed * 0.03
      if (cloud.x > 850) {
        cloud.x = -50
      }
    })

    const speed = 260
    const onGround = this.player.body.blocked.down || this.player.body.touching.down
    const leftDown = this.cursors.left.isDown || this.controlState.left
    const rightDown = this.cursors.right.isDown || this.controlState.right
    const jumpDown = this.cursors.up.isDown || this.cursors.space.isDown || this.controlState.jump

    if (leftDown) {
      this.player.setVelocityX(-speed)
    } else if (rightDown) {
      this.player.setVelocityX(speed)
    }

    if (!leftDown && !rightDown && onGround) {
      this.player.setVelocityX(0)
    }

    if (jumpDown && onGround) {
      this.player.setVelocityY(-520)
      this.controlState.jump = false
    }
  }

  collectStar(player, star) {
    star.disableBody(true, true)
    this.score += 10
    this.scoreText.setText(`Score: ${this.score}`)
    this.explosionParticles.emitParticleAt(star.x, star.y)

    if (this.stars.countActive(true) === 0) {
      this.level++
      this.levelText.setText(`Niveau: ${this.level}`)
      this.bombSpeed += 30

      this.stars.getChildren().forEach((child) => {
        child.enableBody(true, child.x, 0, true, true)
      })

      const x = player.x < 400 ? Phaser.Math.Between(400, 760) : Phaser.Math.Between(40, 400)
      this.spawnBomb(x)
    }
  }

  spawnBomb(x) {
    const bomb = this.bombs.create(x, 16, 'bomb')
    bomb.setBounce(1)
    bomb.setCollideWorldBounds(true)
    bomb.setVelocity(Phaser.Math.Between(-this.bombSpeed, this.bombSpeed), Phaser.Math.Between(150, 280))
    bomb.body.setCircle(16)
    bomb.setGravityY(100)
    bomb.setTint(0xff7a7a)
    bomb.setDepth(2)
  }

  hitBomb(player) {
    this.physics.pause()
    player.setTint(0xff0000)
    this.gameOver = true
    this.add.text(400, 300, 'Game Over', {
      fontSize: '42px',
      color: '#ffdddd'
    }).setOrigin(0.5)
    this.add.text(400, 340, 'Appuyez sur R pour recommencer', {
      fontSize: '18px',
      color: '#ffffff'
    }).setOrigin(0.5)
  }

  restartGame() {
    this.scene.restart()
  }
}

export default function PhaserGame() {
  const containerRef = useRef(null)
  const gameRef = useRef(null)

  useEffect(() => {
    if (typeof window === 'undefined' || !containerRef.current) return

    const config = {
      type: Phaser.AUTO,
      parent: containerRef.current,
      width: 800,
      height: 600,
      scale: {
        mode: Phaser.Scale.FIT,
        autoCenter: Phaser.Scale.CENTER_BOTH,
        width: 800,
        height: 600
      },
      backgroundColor: '#0b1732',
      physics: {
        default: 'arcade',
        arcade: {
          gravity: { y: 550 },
          debug: false
        }
      },
      scene: [MainScene]
    }

    gameRef.current = new Phaser.Game(config)

    return () => {
      if (gameRef.current) {
        gameRef.current.destroy(true)
        gameRef.current = null
      }
    }
  }, [])

  return (
    <div className="w-full max-w-5xl mx-auto p-2">
      <div className="bg-slate-900 rounded-3xl shadow-2xl overflow-hidden border border-slate-700 relative">
        <div ref={containerRef} />
      </div>
    </div>
  )
}
