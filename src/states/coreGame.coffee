class window.CoreGame
  # He has to feel fast, not sluggish. Fighting skill is big in this game.
  PLAYER_MOVE_SPEED = 256
  PLAYER_FRAME_RATE = 6
  
  TILE_SIZE = window.Model.MapGenerator.TILE_SIZE

  create: () ->
    # TODO: map is only as big as your screen. Make it bigger.   
    ## Debugging only ##
    #@game.time.advancedTiming = true
    #window.setInterval(() =>
    #  console.log("#{@game.time.fps} FPS") unless @game.time.fps == 0
    #, 5000)
    ## End Debugging ##
    
    @_showMap(@game.data.world.currentMap)
          
    @game.physics.startSystem(Phaser.Physics.ARCADE) # needed for velocity
    
    startX = @currentMap.startX || @game.world.centerX # default on new game
    startY = @currentMap.startY || @game.world.centerY # default on new game
    
    @player = @game.add.sprite(startX, startY, 'hero 1')
    @player.animations.add('down', [0, 1, 2], PLAYER_FRAME_RATE, true)
    @player.animations.add('left', [3, 4, 5], PLAYER_FRAME_RATE, true)
    @player.animations.add('right', [6, 7, 8], PLAYER_FRAME_RATE, true)
    @player.animations.add('up', [9, 10, 11], PLAYER_FRAME_RATE, true)
    @game.physics.enable(@player, Phaser.Physics.ARCADE)
    
    # Fade out and in
    @blackout = @game.add.sprite(0, 0, 'blackout')
    
    @fadeOutTween = @game.add.tween(@blackout)
    @fadeOutTween.to({ alpha: 1 }, 1000, null)
    @fadeOutTween.onComplete.add(() ->
      @game.state.start('coreGame')
    , this)    
    
    fadeInTween = @game.add.tween(@blackout)
    fadeInTween.to({ alpha: 0 }, 1000, null)
    fadeInTween.start()
    fadeInTween.onComplete.add(() ->
      @transitioning = false
    , this)
    
    @game.camera.follow(@player)
    @cursors = @game.input.keyboard.createCursorKeys()
    
  update: () ->
    if @blackout.alpha > 0
      @player.body.velocity.x = @player.body.velocity.y = 0
      return
    
    if @cursors.left.isDown
      @player.body.velocity.x = -1 * PLAYER_MOVE_SPEED;
      @player.animations.play('left')
    else if @cursors.right.isDown
      @player.body.velocity.x = PLAYER_MOVE_SPEED;
      @player.animations.play('right')
    else
      @player.body.velocity.x = 0

    if @cursors.up.isDown
      @player.body.velocity.y = -1 * PLAYER_MOVE_SPEED;
      @player.animations.play('up')
    else if @cursors.down.isDown
      @player.body.velocity.y = PLAYER_MOVE_SPEED;
      @player.animations.play('down')
    else
      @player.body.velocity.y = 0
      
    @player.animations.stop() unless @cursors.up.isDown || @cursors.down.isDown ||
      @cursors.left.isDown || @cursors.right.isDown
      
    @game.physics.arcade.collide(@player, @collideTiles)
    @game.physics.arcade.collide(@player, @objects)
    
    @game.physics.arcade.overlap(@player, @transitionTiles, @_checkAndTransitionPlayer, null, this)
    
  _showMap: (map) ->
    @currentMap = map
    
    @transitionTiles.destroy if @transitionTiles?
    @collideTiles.destroy if @collideTiles?
    @tiles.destroy if @tiles?
    
    @collideTiles = @game.add.group()
    @collideTiles.enableBody = true
    
    # Everything not in collideTiles    
    @tiles = @game.add.group()
    
    # stuff that has a transition on it
    @transitionTiles = @game.add.group()
    
    ## setup tiles
    
    for y in [0 ... map.height]
      for x in [0 ... map.width]
          tile = @game.add.sprite(game.world.centerX, game.world.centerY, 'top outside tiles')
          tile.x = x * TILE_SIZE.width
          tile.y = y * TILE_SIZE.height
          tile.frame = map.get(x, y)
          if (tile.frame > 0)
            tile.frame = 1
            @game.physics.enable(tile, Phaser.Physics.ARCADE)
            @collideTiles.add(tile)
            tile.body.immovable = true
          else
            # non-collidables
            @tiles.add(tile)
    
    ## setup transitions    
    # For each transition, set up collision/overlap on the tile at that position
    for t in map.transitions
    
      # tile X/Y are in tile indicies, while sprites are in pixels.      
      tiles = @tiles.filter((sprite, index, @tiles) -> return sprite.x == t.x * TILE_SIZE.width && sprite.y == t.y * TILE_SIZE.height)
      
      # It's not in @tiles. Maybe it's already in @collideTiles?
      if tiles.total == 0
        tiles = @transitionTiles.filter((sprite, index, @transitionTiles) -> return sprite.x == t.x * TILE_SIZE.width && sprite.y == t.y * TILE_SIZE.height)
      # Nope, there's a problem.
      if tiles.total == 0
        throw "Found no tiles at #{t.x}, #{t.y} although there's a transition there."
        
      tile = tiles.first # guaranteed to be just one matching tile. More than one won't break anything since coordinates line up.
      @game.physics.enable(tile, Phaser.Physics.ARCADE)
      @transitionTiles.add(tile)
      tile.body.immovable = true
      
    ## create objects
    @objects = @game.add.group()
    @objects.enableBody = true
    
    for o in map.objects
      o = @objects.create(o.x * TILE_SIZE.width, o.y * TILE_SIZE.height, o.image)
      o.body.immovable = true
      
  _checkAndTransitionPlayer: (player, tile) ->
      return if @transitioning == true
      t = @currentMap.transitionAt(tile.x / TILE_SIZE.width, tile.y / TILE_SIZE.height)
      throw "Can't find transition at #{tile.x / TILE_SIZE.width}, #{tile.y / TILE_SIZE.height}" if !t?
      throw 'Transition from map to itself' if t.destination == @currentMap
      @game.data.world.currentMap = t.destination
      @transitioning = true
      
      # Offset by one tile in the specified direction.
      playerX = t.destX * TILE_SIZE.width
      playerX += TILE_SIZE.width if t.direction == 'right'
      playerX -= TILE_SIZE.width if t.direction == 'left'
      
      playerY = t.destY * TILE_SIZE.height
      playerY += TILE_SIZE.height if t.direction == 'down'
      playerY -= TILE_SIZE.height if t.direction == 'up'
      
      # Set starting location on the new map
      t.destination.startX = playerX
      t.destination.startY = playerY
     
      @fadeOutTween.start() # leads to: @game.state.start('coreGame')
      
