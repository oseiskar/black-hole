
if ( ! Detector.webgl ) Detector.addGetWebGLMessage();

var container, stats;
var camera, scene, renderer, cameraControls;
var uniforms;

var TEX_RES = 2*1024;

function degToRad(a) { return Math.PI * a / 180.0; }

SHADER_LOADER.load(function(shaders) {
    init(shaders);
    animate();
});

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
    dt.needsUpdate = true;
    
    return dt;
}

function init(shaders) {

    var FOV_ANGLE_DEG = 60;

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
        fov_mult: { type: "f", value: 1.0 / Math.tan(degToRad(FOV_ANGLE_DEG*0.5)) },
        bg_texture: {
            type: "t",
            value: renderDataTexture(TEX_RES*2, TEX_RES, starBackgroundTexture)
        },
        
        accretion_disk_texture: {
            type: "t",
            value: renderDataTexture(TEX_RES, TEX_RES/4, accretionDiskTexture1D)
        }
    };

    var material = new THREE.ShaderMaterial( {

        uniforms: uniforms,
        vertexShader: $('#vertex-shader').text(),
        fragmentShader: shaders.raytracer.fragment

    } );

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
    initializeCamera(camera, 20.0, 15.0);
    
    cameraControls = new THREE.OrbitControls( camera, renderer.domElement );
    cameraControls.target.set( 0, 0, 0 );
    cameraControls.addEventListener( 'change', updateCamera );
    updateCamera();

    onWindowResize();

    window.addEventListener( 'resize', onWindowResize, false );

}

function starBackgroundTexture(x,y) {
            
    var prob = 5.0 / TEX_RES;
    prob *= Math.cos((y-0.5)*Math.PI);
    
    var s = Math.random()
    
    if (s < prob) {
        s /= prob;
        return { r: s, g: s, b: s };
    }
    
    return { r: 0, g: 0, b: 0 };
}

function accretionDiskTexture1D(x, y) {
    var s = x*Math.exp(-x*4.0)*(1.0-x) * Math.pow((Math.sin(x*Math.PI*20)+1.0)*0.5,0.1) * 10.0;
    if (Math.ceil(y*50)%2 == 0) s *= 0.7;
    return { r: s, g: s*0.8, b: s*0.5 };
}

function onWindowResize( event ) {

    renderer.setSize( window.innerWidth, window.innerHeight );

    uniforms.resolution.value.x = renderer.domElement.width;
    uniforms.resolution.value.y = renderer.domElement.height;

}

function initializeCamera(camera, angle, dist) {
    
    // there are nicely named methods such as "lookAt" in the camera object
    // but there do not do a thing to the projection matrix due to an internal
    // representation of the camera coordinates using a quaternion (nice)
    var a = degToRad(-angle);
    camera.matrixWorldInverse.makeRotationX(a);
    
    camera.position.set(0,Math.sin(a)*dist,Math.cos(a)*dist);
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

function animate() {
    requestAnimationFrame( animate );

    render();
    stats.update();
}

function render() {
    uniforms.time.value += 0.05;
    renderer.render( scene, camera );
}
