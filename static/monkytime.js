/* Author:
    Max Degterev <me@maxdegterev.name> @suprMax
*/

// ======================================================================================
// Polyfills
// ======================================================================================
// requestAnimationFrame polyfill
(function() {
    var lastTime = 0;
    var vendors = ['ms', 'moz', 'webkit', 'o'];
    for(var x = 0; x < vendors.length && !window.requestAnimationFrame; ++x) {
        window.requestAnimationFrame = window[vendors[x]+'RequestAnimationFrame'];
        window.cancelAnimationFrame = window[vendors[x]+'CancelAnimationFrame']
                                   || window[vendors[x]+'CancelRequestAnimationFrame'];
    }
 
    if (!window.requestAnimationFrame)
        window.requestAnimationFrame = function(callback, element) {
            var currTime = new Date().getTime();
            var timeToCall = Math.max(0, 16 - (currTime - lastTime));
            var id = window.setTimeout(function() { callback(currTime + timeToCall); },
              timeToCall);
            lastTime = currTime + timeToCall;
            return id;
        };
 
    if (!window.cancelAnimationFrame)
        window.cancelAnimationFrame = function(id) {
            clearTimeout(id);
        };
}());

var monkyTime = function(settings) {
// ======================================================================================
// Options
// ======================================================================================
    var options = $.extend({
        debug: true,
        lives: 6,
        accelmx: 3.5,
        objects: {
            banana: {
                chance: 1,
                num: 2,
                points: 10,
                lives: 0
            },
            bomb: {
                chance: .005,
                num: 1,
                points: -10,
                lives: -1
            },
            heart: {
                chance: .001,
                num: 1,
                points: 20,
                lives: 1
            }
        } 
    }, settings);
    
// ======================================================================================
// Utility
// ======================================================================================
    var debug = function() {
        if (options.debug && 'console' in window) {
            (arguments.length > 1) ? console.log(Array.prototype.slice.call(arguments)) : console.log(arguments[0]);
        }
    };
    
    var supports = (function() {
        var div = document.createElement('div'),
            vendors = 'Ms O Moz Webkit'.split(' '),
            len = vendors.length,
            succeeded,
            memo = {};

        return function(prop) {
            var key = prop;

            if (typeof memo[key] !== 'undefined') {
                return memo[key];
            }

            if (typeof div.style[prop] !== 'undefined') {
                memo[key] = prop;
                return memo[key];
            } 

            prop = prop.replace(/^[a-z]/, function(val) {
                return val.toUpperCase();
            });

            for (var i = len - 1; i >= 0; i--) {
                if (typeof div.style[vendors[i] + prop] !== 'undefined') {
                    succeeded = '-' + vendors[i] + '-' + prop;
                    memo[key] = succeeded.toLowerCase();
                    return memo[key];
                }
            }

            return false;
        };
    })();
    
// ======================================================================================
// Running selectors
// ======================================================================================
    var mt = $('#monkytime'),
        mtScreens = mt.find('.mt-screen'),
        
        // Basic
        gameScreen = mt.find('#mt-game-screen'),
        gameObjects = gameScreen.find('.mt-game-object'),
        gameLives = gameScreen.find('#mt-game-lives'),
        gameScore = gameScreen.find('#mt-game-lives'),
        gamePlayer = gameScreen.find('#mt-game-player'),
        
        // Screens
        introScreen = mtScreens.filter('.mt-introduction-screen'),
        startScreen = mtScreens.filter('.mt-start-screen'),
        endScreen = mtScreens.filter('.mt-end-screen'),
        
        // Buttons
        buttonStartGame = startScreen.find('#sm-game-start'),
        buttonRestartGame = endScreen.find('#sm-game-restart'),
        buttonEndGame = endScreen.find('#sm-game-quit'),
        
        // Game objects
        gameObjBanana = gameObjects.filter('.mt-banana'),
        gameObjBomb = gameObjects.filter('.mt-bomb'),
        gameObjHeart = gameObjects.filter('.mt-heart');

    debug('[MonkyTime]: game initialized');
        
// ======================================================================================
// Setting vars
// ======================================================================================
    var game = {
        id: 0,
        active: false,

        score: 0,
        lives: options.lives,

        transform: supports('transform'),

        objects: [],
        activeObjects: {},
        
        width: mt.width(),
        height: mt.height()
    },
    i, l;

// ======================================================================================
// Initializing game objects
// ======================================================================================
    var GameObject = function(type, settings) {
        this.type = type;
        this.options = settings;
        
        this.points = this.options.points;
        this.lives = this.options.lives;
        this.chance = this.options.chance;
    
        this.velocity = 0;
        this.accelerated = false;

        this.x = 0;
        this.y = 0;

        this.active = false;
        
        this.elem = $('<span class="mt-' + this.type + ' mt-game-object" />');
        
        gameScreen.append(this.elem);
    };
    GameObject.prototype.activate = function() {
        this.active = true;
        game.activeObjects[this.type]++;
        
        this.elem.css({
            display: 'block'
        });

        if (!this.width || !this.height) {
            this.width = this.elem.width();
            this.height = this.elem.height();
        }
        
        this.x = (Math.random() * (game.width - this.width)) | 0;
        this.y = -(Math.random() * game.height) | 0;
        
        //debug('[MonkyTime]: game object "' + this.type + '" activated');        
    };
    GameObject.prototype.deactivate = function() {
        this.x = 0;
        this.y = 0;
        this.active = false;
        game.activeObjects[this.type]--;

        this.elem.css({
            display: 'none'
        });
        //debug('[MonkyTime]: game object "' + this.type + '" deactivated');
    };
    GameObject.prototype.move = function() {
        if (this.accelerated) {
            this.velocity++;
            this.y += options.accelmx + this.velocity / 2;
        }
        else {
            this.y += options.accelmx;
        }

        if (this.y >= game.height) {
            this.velocity = 0;
            this.deactivate();
        }
    };
    GameObject.prototype.render = function() {
        if (!this.active) {
            if (game.activeObjects[this.type] >= options.objects[this.type].num) {
                return false;
            }
            
            if (Math.random() < this.chance || this.chance === 1) {
                this.activate();
            }
            else {
                return false;
            }
        }

        this.move();
        
        if (game.transform) {
            var props = {};
            props[game.transform] = 'translate3d(' + this.x + 'px, ' + this.y + 'px, 0)';
            this.elem.css(props);
        }
        else {
            this.elem.css({
                left: this.x,
                top: this.y
            });
        }
    };

    for (object in options.objects) {
        for (i = 0; i < options.objects[object].num; i++) {
            game.objects.push(new GameObject(object, options.objects[object], i));
            debug('[MonkyTime]: game object "' + object + '" initialized');
        }
        game.activeObjects[object] = 0;
    }
// ======================================================================================
// Player logic
// ======================================================================================
    var player = {
        x: 0,
        y: 0,
        
        elem: gamePlayer,
        
        width: 0,
        height: 0,
        
        score: 0,
        lives: options.lives
    };
    player.collision = function() {
        
    };
    player.check = function() {
        
    };
    player.move = function(x, y) {
        x && (this.x = Math.min(Math.max(0, this.x + x), game.width - this.width));
        y && (this.y = Math.min(Math.max(0, this.y + y), game.height - this.height));
    };
    player.render = function() {
        this.check();
        
        if (game.transform) {
            var props = {};
            props[game.transform] = 'translate3d(' + this.x + 'px, 0, 0)';
            console.log(props);
            this.elem.css(props);
        }
        else {
            this.elem.css({
                left: this.x
            });
        }
    };

// ======================================================================================
// Game loop
// ======================================================================================
    var handleDeviceMotion = function(e) {
        console.log('kalld')
        player.move(e.accelerationIncludingGravity.x * options.accelmx);
    };
    var handleMouseMove = function(e) {
        player.move(e.pageX - player.x);
    };
    var gameInit = function() {
        if (!player.width || !player.height) {
            player.width = player.elem.width();
            player.height = player.elem.height();
        }
        
        if (game.transform) {
            player.elem.css({ left: 0 });
        }
        
        window.addEventListener('devicemotion', handleDeviceMotion, false);
        document.addEventListener('mousemove', handleMouseMove, false);

        game.active = true;
        gameLoop();
    };

    var gameStop = function() {
        window.removeEventListener('devicemotion', handleDeviceMotion, false);
        document.removeEventListener('mousemove', handleMouseMove, false);

        game.active = false;
    };

    var gameLoop = function(timestamp) {
        var i = 0,
            l = game.objects.length;
            
        if (!game.active) {// Stop tha game
            return false;
        }
        
        player.render();

        for (; i < l; i++) {
            game.objects[i].render();
        }
        
        game.active && (game.id = requestAnimationFrame(gameLoop));
    };

// ======================================================================================
// Handling screens
// ======================================================================================
    var inviteToPlay = function() {
        debug('[MonkyTime]: inviting to the game');
        introScreen.removeClass('active');
        startScreen.addClass('active');
    };
    
    var startGame = function() {
        debug('[MonkyTime]: starting the game');
        startScreen.removeClass('active');
        gameScreen.addClass('active');

        gameInit();
    };
    
    var resetGame = function() {
        debug('[MonkyTime]: resetting the game');
        resetObjects();
        
        score = 0;
        renderedScore = 0;
        lives = options.lives;
        
        gameStop();
        
        gameScreen.removeClass('active');
        startScreen.addClass('active');
    };
    
    var endGame = function() {
        debug('[MonkyTime]: quitting the game');

        gameStop();
        
        gameScreen.removeClass('active');
        endScreen.addClass('active');
    };
    
    
    var quitGame = function() {
        debug('[MonkyTime]: quitting the game');
        
        endScreen.removeClass('active');
        introScreen.addClass('active');
    };
    
    var pauseGame = function() {
        if (isPaused) {
            debug('[MonkyTime]: unpausing the game');
        
            gameScreen.addClass('paused');
        }
        else {
            debug('[MonkyTime]: pausing the game');
        
            gameScreen.addClass('paused');
        }
    };
    
    buttonStartGame.onpress(startGame);
    buttonRestartGame.onpress(resetGame);
    buttonEndGame.onpress(quitGame);

// ======================================================================================
// Game logic
// ======================================================================================

    var resetObjects = function() {
        var i = 0,
            l = game.objects.length;

        for (; i < l; i++) {
            game.objects[i].deactivate();
        }

        debug('[MonkyTime]: resetting objects');
    };
// ======================================================================================
// Rendering screen
// ======================================================================================


// ======================================================================================
// Returning game controls
// ======================================================================================
    return {
        ready: inviteToPlay,
        start: startGame,
        reset: resetGame,
        end: quitGame,
        pause: pauseGame,
        status: game
    };
};
