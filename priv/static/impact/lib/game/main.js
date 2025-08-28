ig.module(
	'game.main'
  )
  .requires(
	'impact.game',
	'impact.entity'
  )
  .defines(function(){
  
  MyGame = ig.Game.extend({
	gravity: 0, // no falling
	playerEntities: {},
	currentPlayerId: null,
  
	init: function() {
	  // WASD keys
	  ig.input.bind( ig.KEY.W, 'up' );
	  ig.input.bind( ig.KEY.A, 'left' );
	  ig.input.bind( ig.KEY.S, 'down' );
	  ig.input.bind( ig.KEY.D, 'right' );
	},
  
	setCurrentPlayer: function(id) {
	  this.currentPlayerId = id;
	},
  
	updatePlayers: function(players) {
	  // Sync from LiveView into Impact entities
	  for (const id in players) {
		let p = players[id];
		if (!this.playerEntities[id]) {
		  this.playerEntities[id] = this.spawnEntity(EntityAvatar, p.x, p.y, p);
		} else {
		  this.playerEntities[id].updateFromServer(p);
		}
	  }
	},
  
	update: function() {
	  this.parent();
	  // Send local movement to LiveView
	  let me = this.playerEntities[this.currentPlayerId];
	  if (me) {
		me.handleInput();
	  }
	},
  
	draw: function() {
	  this.parent();
	  // Chat bubble draw
	  for (let id in this.playerEntities) {
		this.playerEntities[id].drawName();
	  }
	}
  });
  
  EntityAvatar = ig.Entity.extend({
	size: {x: 32, y: 32},
	bounciness: 0.5,
	collides: ig.Entity.COLLIDES.ACTIVE,
	maxVel: {x: 200, y: 200},
  
	init: function(x, y, settings) {
	  this.parent(x, y, settings);
	  this.name = settings.name;
	  this.color = settings.color;
	  this.message = settings.message;
	  this.avatar_url = settings.avatar_url;
	},
  
	updateFromServer: function(data) {
	  this.pos.x = data.x;
	  this.pos.y = data.y;
	  this.message = data.message;
	},
  
	handleInput: function() {
	  let vx = 0, vy = 0;
	  if (ig.input.state('up')) vy = -2;
	  if (ig.input.state('down')) vy = 2;
	  if (ig.input.state('left')) vx = -2;
	  if (ig.input.state('right')) vx = 2;
  
	  if (vx || vy) {
		this.pos.x += vx;
		this.pos.y += vy;
		// Send to Phoenix
		window.liveSocket.pushEvent("move_player", {
		  x: this.pos.x, y: this.pos.y
		});
	  }
	},
  
	draw: function() {
	  // Simple avatar box
	  ig.system.context.fillStyle = this.color || "#3B82F6";
	  ig.system.context.fillRect(this.pos.x, this.pos.y, this.size.x, this.size.y);
	  this.parent();
	},
  
	drawName: function() {
	  ig.system.context.fillStyle = "#fff";
	  ig.system.context.fillText(this.name, this.pos.x, this.pos.y - 10);
  
	  if (this.message) {
		ig.system.context.fillStyle = "#ff0";
		ig.system.context.fillText(this.message, this.pos.x, this.pos.y - 25);
	  }
	}
  });
  
  });
  