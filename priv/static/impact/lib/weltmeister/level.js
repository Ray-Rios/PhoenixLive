// Save current level
wm.api.saveLevel(this.name, this.data, function(resp){
    console.log("Level saved:", resp);
  });
  
  // Load a level
  wm.api.loadLevel(levelName, function(levelData){
    this.loadLevel(levelData);
  }.bind(this));
  