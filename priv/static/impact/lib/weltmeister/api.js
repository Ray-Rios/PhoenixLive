ig.module('weltmeister.api')
.requires('impact.impact')
.defines(function(){

wm.api = {
  listLevels: function(callback){
    ig.$.getJSON(wm.config.api.browse, function(resp){
      callback(resp.levels || []);
    });
  },

  loadLevel: function(name, callback, errorCallback){
    ig.$.getJSON(wm.config.api.load(name))
      .done(function(data){ callback(data); })
      .fail(function(xhr){ if(errorCallback) errorCallback(xhr); });
  },

  saveLevel: function(name, data, callback, errorCallback){
    ig.$.ajax({
      url: wm.config.api.save(name),
      type: 'POST',
      data: { data: JSON.stringify(data) },
      success: function(resp){ if(callback) callback(resp); },
      error: function(xhr){ if(errorCallback) errorCallback(xhr); }
    });
  }
};

});
