### Ray-traced simulation of a black hole

_see **[COPYRIGHT.md](https://github.com/oseiskar/black-hole/blob/master/COPYRIGHT.md)** for license and copyright info_

In this simulation, the light ray paths are computed by integrating an ODE describing the Schwarzschild geodesics (see [this page the maths](https://github.com/oseiskar/black-hole/blob/numeric-notebooks/physics.ipynb)) using GLSL on the GPU, leveraging WebGL and [three.js](http://threejs.org). This should result to a fairly physically accurate gravitational lensing effect. The colors of the accretion disk are (obviously?) fake, and it can hidden from the GUI.

There are some numerical artefacts related to the low step count required for real-time raytracing. First, the light paths bend a bit more than they should (see [numeric tests](https://github.com/oseiskar/black-hole/blob/numeric-notebooks/numeric_tests.ipynb)) with higher step sizes, but this seems to happen in a systematic way so that the image looks very similar in comparison to a more accurate simulation. The step sizes are also changed when toggling "gravitational time dilation", resulting to noticeable changes in the numerical artefacts. The "real" Shapiro delay effect is noticeable as apparent shearing of the planet when moving it very close to the black hole and viewing it from above.
