
function renderDataTexture(width, height, renderer) {
    // Generate random noise texture
    var size = width * height;
    var data = new Uint8Array( 3 * size );

    function to8bit(f) {
        return Math.round(Math.max(0, Math.min(f, 1.0))*255);
    }

    var i = 0;
    for (var y=0; y<height; y++) {
        for (var x=0; x<width; x++) {
            var col = renderer(x/width,y/height);
            data[i++] = to8bit(col.r);
            data[i++] = to8bit(col.g);
            data[i++] = to8bit(col.b);
        }
    }

    var dt = new THREE.DataTexture( data, width, height, THREE.RGBFormat);
    dt.magFilter = THREE.LinearFilter;
    dt.minFilter = THREE.LinearFilter;
    dt.needsUpdate = true;

    return dt;
}

ProceduralTextures = {

  beachBall: function() {

      var colors = [
        { r: 1, g: 0, b: 0 },
        { r: 1, g: 1, b: 1 },
        { r: 0, g: 0.5, b: 0 },
        { r: 1, g: 1, b: 1 },
        { r: 0, g: 0, b: 1 },
        { r: 1, g: 1, b: 1 }
      ];

      var dt = renderDataTexture(colors.length, 1, function(x,y) {
          return colors[Math.floor(x*colors.length)];
      });
      dt.magFilter = THREE.NearestFilter;
      dt.minFilter = THREE.NearestFilter;
      return dt;
  },

  accretionDisk: function() {

      var TEX_RES = 2048;

      return renderDataTexture(TEX_RES, TEX_RES/4, function(x,y) {
          var s = x*Math.exp(-x*4.0)*(1.0-x) * Math.pow((Math.sin(x*Math.PI*20)+1.0)*0.5,0.1) * 20.0;
          if (Math.ceil(y*50)%2 === 0) s *= 0.7;
          return { r: s, g: s*0.8, b: s*0.5 };
      });
  },

  starBackground: function() {

      var TEX_RES = 2*1024;

      return renderDataTexture(TEX_RES*2, TEX_RES, function(x,y) {

          var prob = 5.0 / TEX_RES;
          prob *= Math.cos((y-0.5)*Math.PI);

          var s = Math.random();

          if (s < prob) {
              s /= prob;
              return { r: s, g: s, b: s };
          }

          return { r: 0, g: 0, b: 0 };
      });
  }
};
