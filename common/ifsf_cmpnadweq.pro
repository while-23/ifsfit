; docformat = 'rst'
;
;+
;
; Compute absorption and emission-line equivalent widths for NaD. Note: the 
; default boxcar kernel for automatic feature detection is optimized for the 
; GMOS B600 grating.
;
; :Categories:
;    IFSFIT
;
; :Returns: 
;    Array of equivalent widths and their errors. If AUTOWAVELIM is
;    selected, also returns the indices into the input arrays that
;    give the lower and upper boundaries of the absorption and
;    emission lines.
;
; :Params:
;    wave: in, required, type=dblarr(N)
;      Wavelengths.
;    flux: in, required, type=dblarr(N)
;      Normalized fluxes.
;    err: in, required, type=dblarr(N)
;      Flux errors.
;
; :Keywords:
;    wavelim: in, optional, type=dblarr(4)
;      Limits of integration for equivalent widths. First two elements are 
;      wavelength ranges of absorption, second two are for emission.
;    autowavelim: in, optional, type=byte
;      Same as wavelim, except now the ranges are for finding the actual
;      absorption and emission limits using the automatic algorithm. If this 
;      keyword is selected, the output array has a second dimension
;      containing the indices into the input arrays that give the
;      lower and upper boundaries of the absorption and emission lines.
;    smoothkernel: in, optional, type=long, default=5
;      Kernel size for boxcar smoothing the spectrum to look for features. The
;      default is optimized for the GMOS B600 grating, which has a spectral 
;      resolution element of ~5 pixels at 6000 A (based on 0.46 A dispersion 
;      and interpolating blaze resolutions of 1688 and 3744 at 461 and 926 nm, 
;      respectively).
; 
; :Author:
;    David S. N. Rupke::
;      Rhodes College
;      Department of Physics
;      2000 N. Parkway
;      Memphis, TN 38104
;      drupke@gmail.com
;
; :History:
;    ChangeHistory::
;      2014may14, DSNR, created
;    
; :Copyright:
;    Copyright (C) 2014 David S. N. Rupke
;
;    This program is free software: you can redistribute it and/or
;    modify it under the terms of the GNU General Public License as
;    published by the Free Software Foundation, either version 3 of
;    the License or any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;    General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see
;    http://www.gnu.org/licenses/.
;
;-
function ifsf_cmpnadweq,wave,flux,err,wavelim=wavelim,$
                        autowavelim=autowavelim,$
                        smoothkernel=smoothkernel,$
                        snflux=snflux,unerr=unerr,emflux=emflux
   
   
   if ~ keyword_set(smoothkernel) then smoothkernel=5l
   
;  If wavelength limits not set, then integration defaults to entire wavelength 
;  range and absorption only.
   if ~ keyword_set(wavelim) then begin
      iabslo = 1l
      iabsup = n_elements(wave)-1l
      iemlo = -1l
      iemup = -1l
;  If wavelength limits are set manually for absorption and emission line 
;  integrations
   endif else if ~ keyword_set(autowavelim) then begin
      iabslo = value_locate(wave,wavelim[0])
      iabsup = value_locate(wave,wavelim[1])
      iemlo = value_locate(wave,wavelim[2])
      iemup = value_locate(wave,wavelim[3])
   endif

;  Algorithm for automatically finding wavelength ranges for absorption and 
;  emission line integration. The algorithm boxcar smooths the spectrum and 
;  error using a kernel equal to the size of a spectral resolution element. This
;  is akin to averaging 5 adjacent points. If this average yields a point with
;  SNR > 1, then 
   if keyword_set(autowavelim) then begin
;     subtract/add 2 pixels to avoid edge effects
      i1abs = value_locate(wave,autowavelim[0])-2l
      i2abs = value_locate(wave,autowavelim[1])+2l
      i1em = value_locate(wave,autowavelim[2])-2l
      i2em = value_locate(wave,autowavelim[3])+2l
      sflux = smooth(flux,smoothkernel,/edge_truncate)
      serr = sqrt(smooth(err^2d,smoothkernel,/edge_truncate))
;     1 minus flux, since we care about features above/below the continuum
      snr = (1d -sflux)/serr
;     truncate smoothed arrays for easier bookkeeping
      sflux_abs=sflux[i1abs:i2abs]
      serr_abs=serr[i1abs:i2abs]
      snr_abs=snr[i1abs:i2abs]
      sflux_em=sflux[i1em:i2em]
      serr_em=serr[i1em:i2em]
      snr_em=snr[i1em:i2em]
;     find significant absorption/emission features
      iabs = where(snr_abs ge 1d,ctabs)
      iem = where(snr_em le -1d,ctem)
;     Make sure more than one point is found, and then assign lower and upper
;     indices of range based on lowest wavelength and highest wavelength points
;     found. The extra bit of logic makes sure that the indices don't stray
;     outside the ranges of the truncated arrays.
      if ctabs gt 1 then begin
         iabslo = iabs[0]-2l lt 1 ? 1 : iabs[0]-2l
         iabsup = $
            iabs[ctabs-1]+2l gt i2abs-i1abs ? i2abs-i1abs : iabs[ctabs-1]+2l
         iabslo += i1abs
         iabsup += i1abs
      endif else begin
         iabslo=-1l
         iabsup=-1l
      endelse
;     Same for emission.
      if ctem gt 1 then begin
         iemlo=iem[0]-2l lt 1 ? 1 : iem[0]-2l
         iemup = iem[ctem-1]+2l gt i2em-i1em ? i2em-i1em : iem[ctem-1]+2l
         iemlo += i1em
         iemup += i1em
      endif else begin
         iemlo=-1l
         iemup=-1l
      endelse
   endif
      
;  Compute equivalent widths.
   if iabslo ne -1l AND iabsup ne -1l then begin
      weq_abs = total((1d -flux[iabslo:iabsup])*$
                      (wave[iabslo:iabsup]-$
                       wave[iabslo-1:iabsup-1]))
      weq_abs_e = sqrt(total(err[iabslo:iabsup]^2*$
                             (wave[iabslo:iabsup]-$
                              wave[iabslo-1:iabsup-1])))
   endif else begin
      weq_abs = 0d
      weq_abs_e = 0d
   endelse
   if iemlo ne -1l AND iemup ne -1l then begin
      weq_em = total((1d -flux[iemlo:iemup])*$
                     (wave[iemlo:iemup]-wave[iemlo-1:iemup-1]))
      weq_em_e = sqrt(total(err[iemlo:iemup]^2*$
                            (wave[iemlo:iemup]-wave[iemlo-1:iemup-1])))
      if keyword_set(snflux) AND keyword_set(emflux) then begin
         fl_em = total(snflux[iemlo:iemup]*$
                       (wave[iemlo:iemup]-wave[iemlo-1:iemup-1]))
         if keyword_set(unerr) then $
            fl_em_e = sqrt(total(unerr[iemlo:iemup]^2*$
                                 (wave[iemlo:iemup]-wave[iemlo-1:iemup-1]))) $
         else fl_em_e = 0d
         emflux = [fl_em,fl_em_e]
      endif
   endif else begin
      weq_em = 0d
      weq_em_e = 0d
   endelse

   out = [weq_abs,weq_abs_e,weq_em,weq_em_e]
;  indices into original arrays of auto-detect regions
   if keyword_set(autowavelim) then begin
      autoindices=[iabslo,iabsup,iemlo,iemup]
      out=[[out],[autoindices]]
   endif

   return,out
  
end
