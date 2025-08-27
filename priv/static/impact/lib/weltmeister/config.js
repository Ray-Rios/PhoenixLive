ig.module('weltmeister.config')
.requires('impact.debug.debug')
.defines(function(){

wm.config = {
  project: 'lib/game/', // Your game files
  assets: '/images/',   // Phoenix static images
  api: {
    browse: '/admin/levels',
    load: function(name) { return '/admin/levels/' + encodeURIComponent(name); },
    save: function(name) { return '/admin/levels/' + encodeURIComponent(name); }
  }
};

});
