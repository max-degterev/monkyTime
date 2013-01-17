# @require 'js/rAF.polyfill.js'
# @require 'js/hash/base64.js'
# @require 'js/hash/md5.js'


(($) ->
    if not Date.now
        Date.now = () ->
            return +new Date()

    # =========================================
    # LOAD HIGHSCORES
    # =========================================

    scoreboard = []
    highscore = 0

    $.ajax
        url: '/api/v1.1/game/score.json'
        type: 'GET'
        success: (res) ->
            if res.length
                scoreboard = res
                highscore = scoreboard[0].score

    # =========================================
    # GAME SETTINGS
    # =========================================

    options =
        debug: true
        lives: 6

        garbage: 5 * 1000

        player:
            step: 10
            accel: 1

        modes:
            time: 1000 * 20
            speeds: [5, 8, 12, 16, 23, 25]

            accelerated: 3
            randomized: 6
            vector: 2

        sudden:
            active: true
            objects: ['banana', 'banana', 'bomb', 'bomb', 'heart']
            num: 15

        transform: S.utils.supports('transform')

        objects:
            banana:
                class: 'banana'
                chance: .25
                num: 7
                points: 1
                lives: 0
                accel: 1
            bomb:
                class: 'bomb'
                chance: .005
                num: 3
                points: -5
                lives: -2
                accel: 2
            heart:
                class: 'heart'
                chance: .0001
                num: 1
                points: 30
                lives: 2
                accel: 3

    # =========================================
    # UTILITY
    # =========================================
    log = ()->
        if (options.debug && window.console?)
            if (arguments.length > 1) then console.log(Array::slice.call(arguments)) else console.log(arguments[0])

    md5 = window.md5
    btoa = window.btoa
    # `window.md5 = void 0;
    #  window.btoa = void 0;
    #  window.atob = void 0;`
    delete window.md5;
    delete window.atob;
    delete window.btoa;

    leadZeros = (num) ->
        if (num < 10)
            return '00' + num

        if (num < 100)
            return '0' + num

        return '' + num

    block = $('.p-game')
    win = $(window)

    # =========================================
    # SCREENS MANAGEMENT
    # =========================================

    screens = (()->
        els = block.find('.game-screen')
        scoreboardEl = block.find('.game-scoreboard')

        nameEl = block.find('#game-player-name')

        showIntro = () ->
            els.filter('.active').removeClass('active')
            els.filter('.game-intro').addClass('active')

            block.trigger('game::intro')
            log('game::screens::intro')

        showOver = () ->
            els.filter('.active').removeClass('active')
            els.filter('.game-over').addClass('active').find('.game-results-final').html(leadZeros(game.score))

            nameEl.off('keydown', limitNameToChars)
            block.trigger('game::over')
            log('game::screens::over')

        showHighScore = () ->
            els.filter('.active').removeClass('active')
            els.filter('.game-highscore').addClass('active').find('.game-results-final').html(leadZeros(game.score))

            nameEl.on('keydown', limitNameToChars)
            block.trigger('game::highscore')
            log('game::screens::highscore')

        showGame = () ->
            els.filter('.active').removeClass('active')
            els.filter('.game-mainscreen').addClass('active')

            block.trigger('game::started')
            log('game::screens::game')

        updateScoreboard = () ->
            results = for item in scoreboard
                '<li>' + item.name + ' ' + leadZeros(item.score) + '</li>'

            scoreboardEl.html(results)

        saveScore = () ->
            return unless (val = $.trim(nameEl.val())).length and game.score > highscore

            result = 
                name: val
                score: game.score

            scoreboard.unshift(result)
            scoreboard.length = 10 unless scoreboard.length <= 10
            highscore = game.score

            json = JSON.stringify(result)

            $.ajax
                url: '/api/v1.1/game/score.json'
                data:
                    signature: md5(json)
                    data: btoa(json)
                type: 'POST'
                success: (res) ->
                    scoreboard = res
                    highscore = scoreboard[0].score

            updateScoreboard()
            showOver()

        limitNameToChars = (e) ->
            if (e.keyCode == 13)
                saveScore()
            else
                if (!/^[a-zA-Z]*$/.test(String.fromCharCode(e.keyCode)) and e.keyCode != 8 and e.keyCode != 46)
                    e.preventDefault()


        updateScoreboard()

        block.find('#game-start').on('click', showGame)
        block.find('#game-retry').on('click', showGame)
        block.find('#game-savescore').on('click', saveScore)

        {
            intro: showIntro
            over: showOver
            highscore: showHighScore
            game: showGame
        }
        )()

    # =========================================
    # GAME STATUS
    # =========================================

    game = (() ->
        defaults =
            active: false

            score: 0
            lives: options.lives

            mode: 0

            objects: []
            activeObjects: {}

            player: null

            time: Date.now()

            width: block.width()
            height: block.height()

            offset: {}

        defaults.reset = () ->
            game.active = false

            game.score = 0
            game.lives = options.lives
            
            game.mode = 0

        calculateOffset = () ->
            pos = block.offset()
            defaults.offset.x = pos.left
            defaults.offset.y = pos.top

        calculateOffset()
        win.on('resize', calculateOffset)

        return defaults
        )()

    # =========================================
    # GAME OBJECTS
    # =========================================
    class Entity
        constructor: (type, settings) ->
            @type = type
            @options = settings       

            @points = @options.points
            @lives = @options.lives
            @chance = @options.chance

            @velocity = 0
            @accelerated = 0

            @vector = 0
            @randomized = 0

            @x = 0
            @y = 0

            @width = 0
            @height = 0

            @remove = false

            @active = false

            @el = $('<span class="game-object ' + @options.class + '"></span>')

        getSizes: () ->
            @width = @el.width()
            @height = @el.height()

        activate: () ->
            @active = true

            @el.addClass('active')
            game.activeObjects[@type]++ unless @remove

            @getSizes() unless @width and @height

            @x = Math.random() * (game.width - @width)
            @y = -Math.random() * game.height

        deactivate: () ->
            @x = 0
            @y = 0

            @active = false

            @el.removeClass('active')
            game.activeObjects[@type]-- unless @remove

            @velocity = 0
            @vector = 0

        _randomVector: () ->
            return (if Math.random() < .5 then @options.accel else -@options.accel) * (Math.random() + 1)

        move: () ->
            if (game.mode >= options.modes.accelerated - 1 and game.time - @accelerated > 150)
                @velocity += @options.accel
                @accelerated = game.time

            if (game.mode >= options.modes.vector - 1 and game.mode < options.modes.randomized - 1 and not @vector)
                @vector = @_randomVector()

            if (game.mode >= options.modes.randomized - 1 and game.time - @randomized > 300)
                @vector += @_randomVector() * 3
                @randomized = game.time

            @y += options.modes.speeds[game.mode] + @velocity
            @x += @vector          

            if (@y >= game.height)
                @deactivate()

        render: () ->
            if not @active and not @remove
                if (game.activeObjects[@type] >= options.objects[@type].num)
                    return false
                
                if (Math.random() < @chance or @chance == 1)
                    @activate()
                else 
                    return false

            @move()

            if options.transform
                props = {}
                props[options.transform] = 'translate3d(' + @x + 'px, ' + @y + 'px, 0)'        
            else
                props =
                    left: @x
                    top: @y

            @el.css(props)
            
    # =========================================
    # PLAYER OBJECT
    # =========================================
    class Player
        constructor: () ->
            @x = 0
            @y = 0

            @el = block.find('.player')

            @width = 0
            @height = 0

            @velocity = 0
            @moved = 0

            @offset = parseInt($(@el).css('margin-top'))

        reset: () ->
            @width = @el.width()
            @height = @el.height()

            @x = (game.width / 2) - (@el.width() / 2)
            @y = 0

            @move(0, 0)

        move: (x, keyb) ->
            if x?
                if (keyb)
                    if (game.time - @moved < 100)
                        @velocity += if (x > 0) then options.player.accel else -options.player.accel
                    else 
                        @velocity = 0
                else
                    @velocity = 0

                @x = Math.min(Math.max(0, @x + x + @velocity), game.width - @width)
                @moved = game.time

            # if y?
            #     @y = Math.min(Math.max(0, @y + y), game.height - @height)

        render: () ->
            if options.transform
                props = {}
                props[options.transform] = 'translate3d(' + @x + 'px, ' + @y + 'px, 0)' 
            else
                props =
                    left: @x
                    top: @y

            @el.css(props)


    # =========================================
    # GAME ENGINE
    # =========================================
    engine = (()->
        doc = $(document)
        el = block.find('.game-mainscreen')

        livesEl = block.find('.game-lives')
        scoreEl = block.find('.game-score')
        pauseEl = block.find('.game-paused')

        modeStarted = Date.now()
        modesNum = options.modes.speeds.length - 1

        garbageCollected = Date.now()

        frame = null

    # --------------------------
    # INITIALIZING
    # --------------------------
        initObjects = () ->
            for type, obj of options.objects
                game.activeObjects[type] = 0
                for [1..obj.num]
                    ent = new Entity(type, obj)

                    el.append(ent.el)

                    game.objects.push(ent)

            game.player = new Player()

        initSudden = () ->
            for [1..options.sudden.num]
                ent = new Entity(options.sudden.objects[game.mode], options.objects[options.sudden.objects[game.mode]])

                ent.remove = true               
                el.append(ent.el)
                ent.activate()

                game.objects.push(ent)

        initEngine = () ->
            initObjects()

            block.on('game::started', startEngine)
            # block.on('game::intro', stopEngine)
            # block.on('game::over', stopEngine)

            pauseEl.on('click', togglePause)

            log('game::engine::initialized')

        resetObjects = () ->
            for obj in game.objects
                obj.deactivate()

    # --------------------------
    # GAME LOOP
    # --------------------------
        collision = (obj) ->
            if obj.points
                game.score = Math.max(game.score + obj.points, 0)
                scoreEl.html(leadZeros(game.score))

            if obj.lives
                game.lives = Math.min(game.lives + obj.lives, options.lives)
                livesEl.attr('data-lives', game.lives)
                if game.lives <= 0
                    gameOver()

            # collided, remove to avoid consecutive calls
            obj.deactivate()

        checkCollisions = (obj) ->
            if ((obj.y + obj.height >= game.player.y + game.player.offset) and (obj.y <= game.player.y + game.player.offset)) or
            ((obj.y >= game.player.y + game.player.offset) and (obj.y <= game.player.y + game.player.offset + game.player.height))
            # Collided by Y

                if ((obj.x <= game.player.x) and (obj.x + obj.width >= game.player.x)) or
                ((obj.x >= game.player.x) and (obj.x <= game.player.x + game.player.width))
                # Collided by both X and Y
                    collision(obj)

        changeMode = () ->
            modeStarted = game.time

            initSudden() unless not options.sudden.active

            game.mode++
            log('game::engine::mode ' + (game.mode + 1))

        garbageCollector = () ->
            garbageCollected = game.time
            gameObjects = []
            collected = 0

            for ent in game.objects
                if (ent.remove and not ent.active)
                    ent.el.remove()
                    collected++
                else
                    gameObjects.push(ent)

            game.objects = gameObjects

            log('game::engine::gc collected: ' + collected)

        render = () ->
            game.player.render()

            for ent in game.objects
                checkCollisions(ent) unless not ent.active
                ent.render()

        gameLoop = () ->
            if game.active
                frame = requestAnimationFrame(gameLoop)

                game.time = Date.now()
                if (game.time - modeStarted > options.modes.time and modesNum > game.mode) then changeMode()

                render()

            if (game.time - garbageCollected > options.garbage) then garbageCollector()

        stopLoop = () ->
            cancelAnimationFrame(frame)

    # --------------------------
    # CONTROLS
    # --------------------------
        handleKeys = (e) ->
            switch e.keyCode
                when 27
                    # ESC
                    togglePause()                  

                when 37
                    # LEFT
                    game.player.move(-options.player.step, true)

                # when 38
                #     # UP
                #     game.player.move(-options.player.step)

                when 39
                    # RIGHT
                    game.player.move(options.player.step, true)

                # when 0
                    # SPACEBAR

        handleMouse = (e) ->
            game.player.move(e.pageX - game.player.x - game.player.width / 2 - game.offset.x)

    # --------------------------
    # LOGIC
    # --------------------------
        gameOver = () ->
            stopEngine()

            if (game.score > highscore)
                screens.highscore()
            else
                screens.over()

        togglePause = () ->
            if game.active
                pauseEngine()
            else
                resumeEngine()

        startEngine = () ->
            doc.on('keydown', handleKeys)
            doc.on('mousemove', handleMouse)
            win.on('blur', pauseEngine)

            livesEl.attr('data-lives', game.lives)
            scoreEl.html(leadZeros(game.score))

            modeStarted = Date.now()

            resetObjects()
            game.reset()
            game.player.reset()

            game.active = true
            
            gameLoop()

            log('game::engine::started')

        stopEngine = () ->
            doc.off('keydown', handleKeys)
            doc.off('mousemove', handleMouse)
            win.off('blur', pauseEngine)

            game.active = false

            stopLoop()

            log('game::engine::stopped')

        pauseEngine = () ->
            el.addClass('paused')

            game.active = false

            stopLoop()

            log('game::engine::paused')

        resumeEngine = () ->
            el.removeClass('paused')

            game.active = true

            gameLoop()

            log('game::engine::resumed')

        {
            init: initEngine
            start: startEngine
            stop: stopEngine
            pause: startEngine
            resume: startEngine
        }
        )()

    # =========================================
    # ALL DONE
    # =========================================
    engine.init()
)(jQuery)
