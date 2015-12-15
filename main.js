
if ( ! Detector.webgl ) Detector.addGetWebGLMessage();

var container, stats;
var camera, scene, renderer, cameraControls, shader = null;
var uniforms;

var TEX_RES = 2*1024;

function Shader(mustacheTemplate) {
    // Compile-time shader parameters
    this.parameters = {
        accretion_disk: true,
        planet: true,
        planet_distance: 8.0,
        planet_radius: 0.4,
        gravitational_time_dilation: true,
        light_travel_time: true,
        time_scale: 1.0,
    };
    var that = this;
    this.needsUpdate = false;

    this.hasMovingParts = function() {
        return this.parameters.planet;
    };

    this.compile = function() {
        return Mustache.render(mustacheTemplate, that.parameters);
    };
}

function degToRad(a) { return Math.PI * a / 180.0; }

(function(){
    var textures = {
        galaxy: null,
        accretion_disk: null,
        stars: null,
        moon: null
    };

    function whenLoaded() {
        init(textures);
        $('#loader').hide();
        animate();
    }

    function checkLoaded() {
        if (shader === null) return;
        for (var key in textures) if (textures[key] === null) return;
        whenLoaded();
    }

    SHADER_LOADER.load(function(shaders) {
        shader = new Shader(shaders.raytracer.fragment);
        checkLoaded();
    });

    var texLoader = new THREE.TextureLoader();
    texLoader.load('img/milkyway.jpg', function(tex) {
        tex.magFilter = THREE.NearestFilter;
        tex.minFilter = THREE.NearestFilter;
        textures.galaxy = tex;
        checkLoaded();
    });

    texLoader.load('img/moon_1024.jpg', function(tex) {
        textures.moon = tex;
        checkLoaded();
    });

    textures.accretion_disk = renderDataTexture(TEX_RES, TEX_RES/4, accretionDiskTexture1D);
    textures.stars = renderDataTexture(TEX_RES*2, TEX_RES, starBackgroundTexture);

    checkLoaded();
})();

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

function init(textures) {

    container = document.createElement( 'div' );
    document.body.appendChild( container );

    scene = new THREE.Scene();

    var geometry = new THREE.PlaneBufferGeometry( 2, 2 );

    uniforms = {
        time: { type: "f", value: 1.0 },
        resolution: { type: "v2", value: new THREE.Vector2() },
        cam_pos: { type: "v3", value: new THREE.Vector3(0,0,-0.5) },
        cam_x: { type: "v3", value: new THREE.Vector3(1,0,0) },
        cam_y: { type: "v3", value: new THREE.Vector3(0,1,0) },
        cam_z: { type: "v3", value: new THREE.Vector3(0,0,1) },

        planet_distance: { type: "f" },
        planet_radius: { type: "f" },

        star_texture: { type: "t", value: textures.stars },
        accretion_disk_texture: { type: "t",  value: textures.accretion_disk },
        galaxy_texture: { type: "t", value: textures.galaxy },
        planet_texture: { type: "t", value: textures.moon },
    };

    updateUniforms();

    var material = new THREE.ShaderMaterial( {

        uniforms: uniforms,
        vertexShader: $('#vertex-shader').text(),
    } );

    scene.updateShader = function() {
        material.fragmentShader = shader.compile();
        material.needsUpdate = true;
        shader.needsUpdate = true;
    };

    scene.updateShader();

    var mesh = new THREE.Mesh( geometry, material );
    scene.add( mesh );

    renderer = new THREE.WebGLRenderer();
    renderer.setPixelRatio( window.devicePixelRatio );
    container.appendChild( renderer.domElement );

    stats = new Stats();
    stats.domElement.style.position = 'absolute';
    stats.domElement.style.top = '0px';
    container.appendChild( stats.domElement );

    // Orbit camera from three.js
    camera = new THREE.PerspectiveCamera( 45, window.innerWidth / window.innerHeight, 1, 80000 );
    initializeCamera(camera);

    cameraControls = new THREE.OrbitControls( camera, renderer.domElement );
    cameraControls.target.set( 0, 0, 0 );
    cameraControls.addEventListener( 'change', updateCamera );
    updateCamera();

    onWindowResize();

    window.addEventListener( 'resize', onWindowResize, false );

    setupGUI();
}

function updateUniforms() {
    uniforms.planet_distance.value = shader.parameters.planet_distance;
    uniforms.planet_radius.value = shader.parameters.planet_radius;
}

function setupGUI() {

    function updateShader() { scene.updateShader(); }

    var gui = new dat.GUI();
    gui.add(shader.parameters, 'accretion_disk').onChange(updateShader);


    gui.add(shader.parameters, 'planet').onChange(updateShader);
    gui.add(shader.parameters, 'planet_distance').min(1.5).onChange(updateUniforms);
    gui.add(shader.parameters, 'planet_radius').min(0.01).max(2.0).onChange(updateUniforms);

    gui.add(shader.parameters, 'gravitational_time_dilation').onChange(updateShader);
    gui.add(shader.parameters, 'light_travel_time').onChange(updateShader);
    gui.add(shader.parameters, 'time_scale').min(0);
}

function starBackgroundTexture(x,y) {

    var prob = 5.0 / TEX_RES;
    prob *= Math.cos((y-0.5)*Math.PI);

    var s = Math.random();

    if (s < prob) {
        s /= prob;
        return { r: s, g: s, b: s };
    }

    return { r: 0, g: 0, b: 0 };
}

function accretionDiskTexture1D(x, y) {
    var s = x*Math.exp(-x*4.0)*(1.0-x) * Math.pow((Math.sin(x*Math.PI*20)+1.0)*0.5,0.1) * 20.0;
    if (Math.ceil(y*50)%2 === 0) s *= 0.7;
    return { r: s, g: s*0.8, b: s*0.5 };
}

function onWindowResize( event ) {

    renderer.setSize( window.innerWidth, window.innerHeight );

    uniforms.resolution.value.x = renderer.domElement.width;
    uniforms.resolution.value.y = renderer.domElement.height;

}

function initializeCamera(camera) {

    var pitchAngle = 10.0, yawAngle = 115.0;
    var dist = 20.0;

    // there are nicely named methods such as "lookAt" in the camera object
    // but there do not do a thing to the projection matrix due to an internal
    // representation of the camera coordinates using a quaternion (nice)
    camera.matrixWorldInverse.makeRotationX(degToRad(-pitchAngle));
    camera.matrixWorldInverse.multiply(new THREE.Matrix4().makeRotationY(degToRad(-yawAngle)));

    var m = camera.matrixWorldInverse.elements;

    camera.position.set(m[2]*dist, m[6]*dist, m[10]*dist);
}

function updateCamera( event ) {

    var dist = camera.position.length();
    var m = camera.matrixWorldInverse.elements;

    // y and z swapped for a nicer coordinate system
    uniforms.cam_x.value.set(m[0], m[8], m[4]);
    uniforms.cam_y.value.set(m[1], m[9], m[5]);
    uniforms.cam_z.value.set(m[2], m[10], m[6]);

    var p = uniforms.cam_z.value;

    uniforms.cam_pos.value.set(-p.x*dist, -p.y*dist, -p.z*dist);
}

function frobeniusDistance(matrix1, matrix2) {
    var sum = 0.0;
    for (var i in matrix1.elements) {
        var diff = matrix1.elements[i] - matrix2.elements[i];
        sum += diff*diff;
    }
    return Math.sqrt(sum);
}

function animate() {
    requestAnimationFrame( animate );

    camera.updateMatrixWorld();
    camera.matrixWorldInverse.getInverse( camera.matrixWorld );

    if (shader.needsUpdate || shader.hasMovingParts() ||
        frobeniusDistance(camera.matrixWorldInverse, lastCameraMat) > 1e-10) {

        shader.needsUpdate = false;
        render();
        lastCameraMat = camera.matrixWorldInverse.clone();
    }
    stats.update();
}

var lastCameraMat = new THREE.Matrix4().identity();

var getFrameDuration = (function() {
    var lastTimestamp = new Date().getTime();
    return function() {
        timestamp = new Date().getTime();
        var diff = (timestamp - lastTimestamp) / 1000.0;
        lastTimestamp = timestamp;
        return diff;
    };
})();

function render() {

    dt = getFrameDuration() * shader.parameters.time_scale;

    if (shader.parameters.gravitational_time_dilation) {
        var observer_r = camera.position.length();
        dt = dt * 1.0 / Math.sqrt(1-1.0/observer_r);
    }

    uniforms.time.value += dt;
    renderer.render( scene, camera );
}
