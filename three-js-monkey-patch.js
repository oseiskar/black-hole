/* why is this not there in the first place :( */
THREE.Matrix3.prototype.multiply = function(another_matrix) {
    var b = another_matrix.elements;
    var a = this.elements;
    this.set(
        a[0]*b[0] + a[3]*b[1] + a[6]*b[2],
        a[0]*b[3] + a[3]*b[4] + a[6]*b[5],
        a[0]*b[6] + a[3]*b[7] + a[6]*b[8],
        a[1]*b[0] + a[4]*b[1] + a[7]*b[2],
        a[1]*b[3] + a[4]*b[4] + a[7]*b[5],
        a[1]*b[6] + a[4]*b[7] + a[7]*b[8],
        a[2]*b[0] + a[5]*b[1] + a[8]*b[2],
        a[2]*b[3] + a[5]*b[4] + a[8]*b[5],
        a[2]*b[6] + a[5]*b[7] + a[8]*b[8]
    );
    return this;
};

THREE.Matrix4.prototype.linearPart = function() {
    var m = new THREE.Matrix3();
    var te = this.elements;
    m.set(
        te[0], te[4], te[8],
        te[1], te[5], te[9],
        te[2], te[6], te[10]
    );
    return m;
};
