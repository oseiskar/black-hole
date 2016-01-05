# spectrum.py from my raytracer
# https://github.com/oseiskar/raytracer

import numpy as np

def interp1d(x, data_x, data_y):
    if len(data_y.shape) == 1:
        data_y = data_y[np.newaxis, :]
    
    # TODO: scipy.interp1d ?
    return np.array([np.interp(x, data_x, data_y[i, :]) \
        for i in range(data_y.shape[0])])

class Spectrum:
    """
    Helper for generating representations of emission, absorption etc.
    spectra of light and converting wavelengths of photons on these spectra
    to RGB colors
    """

    def __init__(self, wavelength_range_nm = None, resolution = None):
        
        if wavelength_range_nm is None:
            wavelength_range_nm = (360, 830)
        
        if resolution is None:
            resolution = wavelength_range_nm[1] - wavelength_range_nm[0] + 1
        
        self.resolution = resolution
        self.wavelength_range = wavelength_range_nm
        self.wavelengths = np.linspace( *wavelength_range_nm, num=resolution )
    
    def map_left(self, wavelengths, y ):
        return interp1d(self.wavelengths, wavelengths, y)
    
    def map_right(self, wavelengths, y ):
        return interp1d(wavelengths, self.wavelengths, y)
    
    def cie_1931_xyz(self):
        if not hasattr(self, 'cie_xyz'):
            # Google for "CIE 1931 data" to find an XLS with this data
            cie_data = np.genfromtxt('data/cie-1931.csv', delimiter=',')
            self.cie_xyz = self.map_left( cie_data[:, 0], cie_data[:, 1:].T )
        return self.cie_xyz
    
    def cie_1931_rgb(self):
        # matrix copy-pasted from Wikipedia
        cie_xyz_matrix = 1.0 / 0.17697 * np.array([ \
                [0.49, 0.31, 0.20],
                [0.17697, 0.81240, 0.01063],
                [0.00, 0.01, 0.99]
            ])
        
        return np.linalg.solve(cie_xyz_matrix, self.cie_1931_xyz())
    
    def visible_intensity(self):
        intensity = np.sqrt(np.sum(self.cie_1931_rgb()**2, axis=0))
        return intensity / np.sum(intensity)
    
    def black_body(self, T, normalized=True, doppler_factor=1.0):
        # Planck's law, the formula from the "Science. It works, bitches" xkcd
        # strip. T is the (color) temperature in kelvins.
        
        from scipy.constants import h, c, k
        
        l = self.wavelengths * 1e-9 * doppler_factor
        energy_density = 2*h*c**2 / l**5 * 1.0 / (np.exp(h*c / (l*k*T)) - 1.0)
        
        if normalized:
            energy_density /= np.max(energy_density)
        
        return energy_density
    
    def wavelength_index(self, nm):
        rng = self.wavelength_range
        return (nm-rng[0])/float(rng[1]-rng[0])*self.wavelengths.size
    
    def single_wavelength(self, nm):
        y = np.zeros(self.wavelengths.size)
        idx = round(self.wavelength_index(nm))
        if idx >= 0 and idx < self.wavelengths.size: y[idx] = 1.0
        return y
    
    def gaussian(self, mean, stdev):
        # Gaussian, normalized to a value one at the maximum
        return np.exp( -0.5 * ((self.wavelengths - mean) / stdev)**2 )  
    
    def get_color(self, density, brightness = None):
        c = np.dot( self.cie_1931_rgb(), np.ravel(density).T )
        if brightness is not None:
            c = c / np.max(c) * brightness
            if isinstance(brightness, int):
                c = c.astype(int)
        return tuple(c)
