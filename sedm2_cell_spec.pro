
PRO SEDM2_CELL_SPEC, dir_in, dir_out, tauv,mu_d, cell_x_offset, cell_y_offset,cell_size,$
                snap = snap_in, model_str=model_str, $
                models_dir=dir_models

;;------------------------------------------------------------------
;; Parameters
;;------------------------------------------------------------------
;  ll_min = 3700.                ;min wavelength
;  ll_max = 9100.                ;max wavelength

;;------------------------------------------------------------------
;; Input and output files
;;------------------------------------------------------------------


  cell = 'cell'
  ; cell = 'tracked_cell'
  ;; style = ''
  style = '_star_age'
  ; for i=0, 4 do print, cell, style
  print, "x_offset | y_offset | cell_size"
  print, cell_x_offset, cell_y_offset,cell_size

;;-- set up plotting file
  cell_str = 'cell_'+string(cell_x_offset, form='(I+03)')+string(cell_y_offset, form='(I+03)')
  cell_str = cell_str+'_size_'+string(cell_size, form='(F0.1)' )
  outstr = '_tauv'+string(tauv,form='(F0.1)')
  outstr = outstr+'_mu'+string(mu_d,form='(F0.1)')

  if n_elements(snap_in) gt 0 then psfile = dir_out+cell_str+'_spectra'+outstr+'_'+string(snap_in,form='(I3.3)')+string(style)+'.ps' $
  else psfile = dir_out+string(cell)+'_spectra'+outstr+string(style)+'.ps'

;;-- find snapshot filenames from gadget simulation files
  filename = file_search(dir_in+'/*.hdf5',count=nsnap)
  filename0 = filename[0]

  if n_elements(snap_in) gt 0 then begin

     SEDM2_READSNAP, filename[0], stars=stars, /getstars ;need to get minID of old stars from first file
     oldstars_minid = min(stars.id) ;minimum ID number of old stars. New stars will have ID < this value.
     if style eq '_star_age' then oldstars_minid=-1

     tmp = where(strmatch(filename, '*'+string(snap_in,form='(I3.3)')+'.hdf5') eq 1)
     if tmp[0] eq -1 then message, 'Something wrong with identifying snapshot file: ', snap_in
     filename = filename[tmp]

  endif


  nsnap = n_elements(filename)

  print, 'SEDM2_SDSSIMAGE: number of snapshots to process',nsnap

;;------------------------------------------------------------------
;; Pre-computations
;;------------------------------------------------------------------

;;-- read SSPs !!!! NEED TO ADD DIFFERENT METALLICITIES
  ssps = SEDM2_GETSSPS(dir_models, model_str,'62')
  age_ssp = ssps.age
  nssps = n_elements(age_ssp)
;  ind = where(ssps.lambda ge ll_min and ssps.lambda le ll_max,nlambda)
  lambda = ssps.lambda;[ind]
  ssps_lum = ssps.seds;[ind,*]
  ssps = 0
  nlambda = n_elements(lambda)
;;------------------------------------------------------------------
;;-- dust attenuation
;;------------------------------------------------------------------
  tau_young = mu_d*tauv*( (5500./lambda)^0.7) + (1-mu_d)*tauv*( (5500./lambda)^1.3)
  tau_old = mu_d*tauv*( (5500./lambda)^0.7)

;;------------------------------------------------------------------
;;-- Loop over all snapshots
;;------------------------------------------------------------------

  ps1c, psfile
  time = systime(1)

  mass_young = dblarr(nsnap)

  for i=0, nsnap-1 do begin ;Nsnap-1 do begin

     tmp = (strsplit(filename[i],'/',/extract,count=n))[n-1]
     filename_short = (strsplit(tmp,'.',/extract))[0]
     str_snap = (strsplit(filename_short,'_',/extract))[1] ;don't use i as could be only doing a single snapshot

     print, 'SEDM2_SPEC building spectrum for snapshot:'+str_snap

;;-- outfile (single snapshot, all components, all orientations)
     outfile_fits = dir_out+ cell_str+'_spec'+outstr+'_'+str_snap+string(style)+'.fits'

;;-- output arrays for each component of the final image
     spec_g_old = (spec_g_young = (spec_ns_old = (spec_ns_young = (spec_os_old = (spec_os_young = fltarr(nlambda))))))

;;-- read simulation files  - 9 secs
     SEDM2_READSNAP, filename[i], stars=stars, gas=gas, sfr=sfr, snap_time=snap_time,/getstars,/getgas




     if n_elements(oldstars_minid) eq 0 and i eq 0 then oldstars_minid = min(stars.id) ;minimum ID number of old stars. New stars will have ID < this value.
     if style eq '_star_age' then oldstars_minid=-1
 ;;-- select particles in the center part
      temp =  file_search(dir_in+'*_???.hdf5',count=tot_nsnap)
      centerlist = fltarr(6, tot_nsnap)
      ;;read the centers
      openr, centertxt, dir_in+'centers.txt', /get_lun
      readf, centertxt, centerlist
      free_lun, centertxt
      two_center = centerlist[*,uint(str_snap)]
      center = two_center[0:2]
      ; print, center
      center[0] += cell_x_offset
      center[1] += cell_y_offset
      ; print, center
      print, 'oldstars_minid', oldstars_minid

      print,"cell_size", cell_size
      ;print, stars[0]
      ind_newstars = where(stars.id lt oldstars_minid, nnewstars,compl=ind_oldstars)
      newstars = stars[ind_newstars]
      print, "Check newstars:"
      get_center_ind, newstars, cen_part_ind, center=center, box_size=cell_size
      newstar_cen_ind = cen_part_ind
      ; print, n_elements(newstar_cen_ind)
      ; print, total(newstar_cen_ind)
      ; print, n_elements(stars)
      print, "Check stars:"
      get_center_ind, stars, cen_part_ind, center=center, box_size=cell_size
      ;print, cen_part_ind
      stars = stars[cen_part_ind]
      ; print, n_elements(stars)
      ; print, n_elements(gas)
      print, "Check gas:"
      get_center_ind, gas, cen_part_ind, center=center, box_size=cell_size
      gas_cen_ind = cen_part_ind
      gas = gas[gas_cen_ind]
      ; print, n_elements(gas)



      if size(stars,/type) eq 8 then nstars = n_elements(stars) else nstars=0
      if size(gas,/type)   eq 8 then ngas   = n_elements(gas)   else ngas=0

     ind_newstars = where(stars.id lt oldstars_minid, nnewstars)
     ind_oldstars = where(stars.id ge oldstars_minID,compl=ind_newstars, noldstars) ;ID the old stars
     if ind_newstars[0] ne -1 then nnewstars = n_elements(ind_newstars) else nnewstars = 0
     if nnewstars+noldstars ne nstars then stop
     print, 'starnum', nnewstars, noldstars, nstars
     print, 'gasnum', ngas
     print, 'gasnum', ngas
     print, 'gasnum', ngas
     print, 'gasnum', ngas

;;-- fill up ind_ssp star structures
     if i eq 0 then plot=1 else plot=0
     if noldstars gt 0 then SEDM2_BUILDSED, age_ssp, stars, oldstars_minid, sfr, snap_time,plot=plot

;;-- read gas particle and new star particle SFHs for this snapshot - 0.5 secs
     restore,  dir_in+'gassfh_uniform_Z_5_March/'+filename_short+'_gassfh.sav'

     gassfh=gassfh[gas_cen_ind,*]

     newstarsfh=newstarsfh[newstar_cen_ind, *]


;;-- loop over SSPs to build integrated spectra
     for j=0,nssps-1 do begin

       if style ne "_star_age" then begin
          ;;-- gas
          if ngas gt 0 then begin
             if age_ssp[j] le 0.01 then spec_g_young = spec_g_young+total(gassfh[*,j])*ssps_lum[*,j] $
             else spec_g_old = spec_g_old+total(gassfh[*,j])*ssps_lum[*,j]
          endif

          ;;-- new stars
          if nnewstars gt 0 then begin
             if age_ssp[j] le 0.01 then spec_ns_young = spec_ns_young+total(newstarsfh[*,j])*ssps_lum[*,j] $
             else spec_ns_old = spec_ns_old+total(newstarsfh[*,j])*ssps_lum[*,j]
          endif
        endif ;;style

        ;;-- old stars
        if noldstars gt 0 then begin
           ind = where(stars[ind_oldstars].ind_ssp eq j,nn2)
           if ind[0] ne -1 then begin
              if age_ssp[j] le 0.01 then spec_os_young = spec_os_young+total(stars[ind_oldstars[ind]].mass)*ssps_lum[*,j] $
              else spec_os_old = spec_os_old+total(stars[ind_oldstars[ind]].mass)*ssps_lum[*,j]
           endif
        endif


     endfor


;;-- sum components and add dust
     spec_ns = spec_ns_young+spec_ns_old
     spec_ns_dust = spec_ns_young*exp(-tau_young)+spec_ns_old*exp(-tau_old)
     spec_g = spec_g_young+spec_g_old
     spec_g_dust = spec_g_young*exp(-tau_young)+spec_g_old*exp(-tau_old)
     spec_os = spec_os_young+spec_os_old
     spec_os_dust = spec_os_young*exp(-tau_young)+spec_os_old*exp(-tau_old)

     spec_notau = spec_ns+spec_g+spec_os
     spec_tau = spec_ns_dust+spec_g_dust+spec_os_dust

;;-- PCA components


;;-- save output file
     struc = {wave:lambda, spec_tau:spec_tau,spec_notau:spec_notau,spec_stars:spec_ns, spec_ns_dust:spec_ns_dust, spec_bulge:spec_os, spec_os_dust:spec_os_dust, spec_gas:spec_g, spec_g_dust:spec_g_dust}
     mwrfits, struc, outfile_fits,/create


;;------------------------------------------------------------------
;;-- some figures
;;------------------------------------------------------------------

     plot, lambda,spec_notau[*,0],/xlog,/ylog,/xs,xtitle='Wavelength [A]',ytitle=textoidl('Luminosity [L_\odot/A]'),title='Orien 0: Snapshot '+str_snap;+' N*='+string(nstars,form='(I0)')
     oplot, lambda,spec_os[*,0],color=cgcolor('red')
     oplot, lambda,spec_ns[*,0],color=cgcolor('cyan')
     oplot, lambda,spec_g[*,0],color=cgcolor('purple')

     xyouts, 0.8,0.9,'Total',/normal
     xyouts, 0.8,0.85,'Old stars',/normal,color=cgcolor('blue')
     xyouts, 0.8,0.75,'New Stars',/normal,color=cgcolor('cyan')
     xyouts, 0.8,0.7,'Gas',/normal,color=cgcolor('purple')

     plot, lambda,spec_tau[*,0],/xlog,/ylog,/xs,xtitle='Wavelength [A]',ytitle=textoidl('Luminosity [L_\odot/A]'),title='Orien 0: Snapshot '+str_snap+' with dust'+' (cell region)';+' N*='+string(nstars,form='(I0)')
     oplot, lambda,spec_os_dust[*,0],color=cgcolor('red')
     oplot, lambda,spec_ns_dust[*,0],color=cgcolor('cyan')
     oplot, lambda,spec_g_dust[*,0],color=cgcolor('purple')

     plot, lambda, -alog(spec_tau[*,0]/spec_notau[*,0]),/xlog,/xs,ytitle=textoidl('\tau_\lambda'),xtitle='Wavelength [A]'
     oplot, lambda, -alog(spec_g_dust[*,0]/spec_g[*,0]),color=cgcolor('purple')
     oplot, lambda, -alog(spec_ns_dust[*,0]/spec_ns[*,0]),color=cgcolor('cyan')
     oplot, lambda, -alog(spec_os_dust[*,0]/spec_os[*,0]),color=cgcolor('red')

     ;; shorteer wavelength range
     plot, lambda,spec_notau[*,0],/xs,xr=[3000,9000],title='Orien 0: Snapshot '+str_snap+' N*='+string(nstars,form='(I0)')+' (cell region)'
     oplot, lambda,spec_os[*,0],color=cgcolor('red')
     oplot, lambda,spec_ns[*,0],color=cgcolor('cyan')
     oplot, lambda,spec_g[*,0],color=cgcolor('purple')

     plot, lambda,spec_tau[*,0],/xs,xr=[3000,9000],title='Orien 0: Snapshot '+str_snap+' with dust'+' N*='+string(nstars,form='(I0)')+' (cell region)'
     oplot, lambda,spec_os_dust[*,0],color=cgcolor('red')
     oplot, lambda,spec_ns_dust[*,0],color=cgcolor('cyan')
     oplot, lambda,spec_g_dust[*,0],color=cgcolor('purple')
     print, 'gas_max',max(spec_g_dust[*,0])
     print, 'newstar_max',max(spec_ns_dust[*,0])
     ;print, spec_ns_dust[*,0]
     xyouts, 0.8,0.9,'Total',/normal
     xyouts, 0.8,0.85,'Old stars',/normal,color=cgcolor('red')
     xyouts, 0.8,0.75,'New Stars',/normal,color=cgcolor('cyan')
     xyouts, 0.8,0.7,'Gas',/normal,color=cgcolor('purple')

     plot, lambda, -alog(spec_tau[*,0]/spec_notau[*,0]),/xs,xr=[3000,9000],ytitle=textoidl('\tau_\lambda')
     oplot, [5500,5500],[0,5],linestyle=2
     oplot, lambda, -alog(spec_g_dust[*,0]/spec_g[*,0]),color=cgcolor('purple')
     oplot, lambda, -alog(spec_ns_dust[*,0]/spec_ns[*,0]),color=cgcolor('cyan')
     oplot, lambda, -alog(spec_os_dust[*,0]/spec_os[*,0]),color=cgcolor('red')


  endfor


END