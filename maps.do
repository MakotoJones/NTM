capture program drop genmsp

program genmsp, sortpreserve
version 12.1
syntax varname, Weights(name) [Pvalue(real 0.05)]

unab Y : `varlist'
tempname W
matrix `W' = `weights'
tempvar Z
qui summarize `Y'
qui generate `Z' = (`Y' - r(mean)) / sqrt( r(Var) * ( (r(N)-1) / r(N) ) )
qui cap drop std_`Y'
qui generate std_`Y' = `Z'
tempname z Wz
qui mkmat `Z', matrix(`z')
matrix `Wz' = `W'*`z'
matrix colnames `Wz' = Wstd_`Y'
qui cap drop Wstd_`Y'
qui svmat `Wz', names(col)
qui spatlsa `Y', w(`W') moran
tempname M
matrix `M' = r(Moran)
matrix colnames `M' = __c1 __c2 __c3 zval_`Y' pval_`Y'
qui cap drop __c1 __c2 __c3
qui cap drop zval_`Y'
qui cap drop pval_`Y'
qui svmat `M', names(col)
qui cap drop __c1 __c2 __c3
qui cap drop msp_`Y'
qui generate msp_`Y' = .
qui replace msp_`Y' = 1 if std_`Y'<0 & Wstd_`Y'<0 & pval_`Y'<`pvalue'
qui replace msp_`Y' = 2 if std_`Y'<0 & Wstd_`Y'>0 & pval_`Y'<`pvalue'
qui replace msp_`Y' = 3 if std_`Y'>0 & Wstd_`Y'<0 & pval_`Y'<`pvalue'
qui replace msp_`Y' = 4 if std_`Y'>0 & Wstd_`Y'>0 & pval_`Y'<`pvalue'
lab def __msp 1 "Low-Low" 2 "Low-High" 3 "High-Low" 4 "High-High", modify
lab val msp_`Y' __msp
end
exit





//cd "\\tsclient\P\ORD_Jones_201309030D"
cd "P:\ORD_Jones_201309030D"
shp2dta using "P:\ORD_Jones_201309030D\VA_Shapefiles\VISNS", database(VISN) coordinates(VISNcoordinates) genid(id)


*NTM1 Mycobacterium chelonae-abscessus comple 
*NTM2 Mycobacterium kansasii 
*NTM3 Mycobacterium, avium-intracellulare gro 
*NTM4 Other Mycobacteria 


use VISNcoordinates, clear
collapse (min) minx=_X miny=_Y (max) maxx=_X maxy=_Y  ,by(_ID)
gen x=minx+(maxx-minx)/2
gen y=miny+(maxy-miny)/2
gen id=_ID
save "VISNxy.dta",replace


use VISN, clear
gen visn=real(VISN)
capture drop VISN
rename visn VISN
recast int VISN
merge 1:1 VISN using "P:\ORD_Jones_201309030D\ntm_spec2.dta"

egen Infxn=sum(infxn),by(region)
egen Extrapulminfxn=sum(extrapulminfxn),by(region)
egen PY=sum(py),by(region)
gen i=10000*Infxn/PY
gen e=10000*Extrapulminfxn/PY

egen chelonae=sum(ntm_spec1),by(region)
egen kansasii=sum(ntm_spec2),by(region)
egen mac=sum(ntm_spec3),by(region)
egen other=sum(ntm_spec4),by(region)

gen t=(chelonae+kansasii+mac+other)
replace chelonae=chelonae/t
replace kansasii=kansasii/t
replace mac=mac/t
replace other=other/t

egen chelonaee=sum(ntm_spece1),by(region)
egen kansasiie=sum(ntm_spece2),by(region)
egen mace=sum(ntm_spece3),by(region)
egen othere=sum(ntm_spece4),by(region)

gen te=(chelonaee+kansasiie+mace+othere)
replace chelonaee=chelonaee/te
replace kansasiie=kansasiie/te
replace mace=mace/te
replace othere=othere/te

capture drop _merge
merge 1:1 id using "VISNxy.dta"

sort region VISN
gen m=1 if VISN==11 | VISN==19 | VISN==22 | VISN==16 | VISN==6
replace chelonae=. if m==.
replace kansasii=. if m==.
replace mac=. if m==.
replace other=. if m==.
replace chelonaee=. if m==.
replace kansasiie=. if m==.
replace mace=. if m==.
replace othere=. if m==.


label var chelonae "{it:M. chelonae-abscessus} group"
label var kansasii "{it:M. kansasii}"
label var mac "{it:M. avium} complex"
label var other "Other {it:Mycobacteria}"

label var chelonaee "Extra-pulm {it:M. chelonae-abscessus} group"
label var kansasiie "Extra-pulm {it:M. kansasii}"
label var mace "Extra-pulm {it:M. avium} complex"
label var othere "Extra-pulm Other {it:Mycobacteria}"

spmap i using VISNcoordinates, id(id) diagram(var(chelonae kansasii mac other) x(x) y(y) prop(t) legenda(on)) osize(vvthin)
graph export "VISNmap_pulm.tif",replace width(1600) height(1200)

spmap e using VISNcoordinates, id(id) diagram(var(chelonaee kansasiie mace othere) x(x) y(y) prop(te) legenda(on)) osize(vvthin)
graph export "VISNmap_extrapulm.tif",replace width(1600) height(1200)





shp2dta using "P:\ORD_Jones_201309030D\zip3\zip3", database(zip3) coordinates(zip3coordinates) genid(id)
use zip3, clear
spmap using zip3coordinates, id(id)

use zip3coordinates, clear
collapse (min) minx=_X miny=_Y (max) maxx=_X maxy=_Y  ,by(_ID)
gen x=minx+(maxx-minx)/2
gen y=miny+(maxy-miny)/2
gen id=_ID
save "zip3xy.dta",replace

use "casepatients.dta", clear
collapse (count) ct=sta3n,by(zip3)
save zip3dta,replace


clear
#delimit ;
odbc load, exec ("
SELECT * FROM study.patientlivesntmzip3
")
conn("DRIVER={SQL Server}; 
	  SERVER=[ServerName]; 
	  DATABASE=ord_jones_201309030D; 
	  Trusted_Connection=True") 
noquote clear
;
#delimit cr
keep if EncounterYear>=2009 & EncounterYear<2013
collapse (sum) PatientLives,by(zip3)
save zip3lives, replace

use zip3,clear
*rename ZIP3 zip3
merge 1:1 zip3 using zip3dta
drop if _merge==2
capture drop _merge

merge 1:1 zip3 using zip3lives
capture drop x
gen x=100000*ct/PatientLives
drop if STATE=="AK"
drop if STATE=="HI"
drop if STATE=="PR"
drop if STATE==""
drop if STATE=="US"
spmap x using zip3coordinates, id(id) fcolor(Blues) osize(vvthin)

graph save Graph "P:\ORD_Jones_201309030D\NTM_rates.gph"
*graph export "NTM_rates.tif",replace width(1600) height(1200)

capture drop _merge
save zip3,replace

sysdir set PERSONAL "P:\ORD_Jones_201309030D\Upload\plus\plus"

insheet using "P:\ORD_Jones_201309030D\zip3\zip3_swm.csv", comma clear
drop zip3_shapefile state
gen zip3=cond(zip_prefix<100,"0","")+string(zip_prefix)

foreach v in v4 v5 v6 v7 v8 v9 v10 v11 v12 v13 v14 v15 v16 v17 v18 v19 v20 v21 v22 v23 v24 v25 v26 v27 v28 v29 v30 v31 v32 v33 v34 v35 v36 v37 v38 v39 v40 v41 v42 v43 v44 v45 v46 v47 v48 v49 v50 v51 v52 v53 v54 v55 v56 v57 v58 v59 v60 v61 v62 v63 v64 v65 v66 v67 v68 v69 v70 v71 v72 v73 v74 v75 v76 v77 v78 v79 v80 v81 v82 v83 v84 v85 v86 v87 v88 v89 v90 v91 v92 v93 v94 v95 v96 v97 v98 v99 v100 v101 v102 v103 v104 v105 v106 v107 v108 v109 v110 v111 v112 v113 v114 v115 v116 v117 v118 v119 v120 v121 v122 v123 v124 v125 v126 v127 v128 v129 v130 v131 v132 v133 v134 v135 v136 v137 v138 v139 v140 v141 v142 v143 v144 v145 v146 v147 v148 v149 v150 v151 v152 v153 v154 v155 v156 v157 v158 v159 v160 v161 v162 v163 v164 v165 v166 v167 v168 v169 v170 v171 v172 v173 v174 v175 v176 v177 v178 v179 v180 v181 v182 v183 v184 v185 v186 v187 v188 v189 v190 v191 v192 v193 v194 v195 v196 v197 v198 v199 v200 v201 v202 v203 v204 v205 v206 v207 v208 v209 v210 v211 v212 v213 v214 v215 v216 v217 v218 v219 v220 v221 v222 v223 v224 v225 v226 v227 v228 v229 v230 v231 v232 v233 v234 v235 v236 v237 v238 v239 v240 v241 v242 v243 v244 v245 v246 v247 v248 v249 v250 v251 v252 v253 v254 v255 v256 v257 v258 v259 v260 v261 v262 v263 v264 v265 v266 v267 v268 v269 v270 v271 v272 v273 v274 v275 v276 v277 v278 v279 v280 v281 v282 v283 v284 v285 v286 v287 v288 v289 v290 v291 v292 v293 v294 v295 v296 v297 v298 v299 v300 v301 v302 v303 v304 v305 v306 v307 v308 v309 v310 v311 v312 v313 v314 v315 v316 v317 v318 v319 v320 v321 v322 v323 v324 v325 v326 v327 v328 v329 v330 v331 v332 v333 v334 v335 v336 v337 v338 v339 v340 v341 v342 v343 v344 v345 v346 v347 v348 v349 v350 v351 v352 v353 v354 v355 v356 v357 v358 v359 v360 v361 v362 v363 v364 v365 v366 v367 v368 v369 v370 v371 v372 v373 v374 v375 v376 v377 v378 v379 v380 v381 v382 v383 v384 v385 v386 v387 v388 v389 v390 v391 v392 v393 v394 v395 v396 v397 v398 v399 v400 v401 v402 v403 v404 v405 v406 v407 v408 v409 v410 v411 v412 v413 v414 v415 v416 v417 v418 v419 v420 v421 v422 v423 v424 v425 v426 v427 v428 v429 v430 v431 v432 v433 v434 v435 v436 v437 v438 v439 v440 v441 v442 v443 v444 v445 v446 v447 v448 v449 v450 v451 v452 v453 v454 v455 v456 v457 v458 v459 v460 v461 v462 v463 v464 v465 v466 v467 v468 v469 v470 v471 v472 v473 v474 v475 v476 v477 v478 v479 v480 v481 v482 v483 v484 v485 v486 v487 v488 v489 v490 v491 v492 v493 v494 v495 v496 v497 v498 v499 v500 v501 v502 v503 v504 v505 v506 v507 v508 v509 v510 v511 v512 v513 v514 v515 v516 v517 v518 v519 v520 v521 v522 v523 v524 v525 v526 v527 v528 v529 v530 v531 v532 v533 v534 v535 v536 v537 v538 v539 v540 v541 v542 v543 v544 v545 v546 v547 v548 v549 v550 v551 v552 v553 v554 v555 v556 v557 v558 v559 v560 v561 v562 v563 v564 v565 v566 v567 v568 v569 v570 v571 v572 v573 v574 v575 v576 v577 v578 v579 v580 v581 v582 v583 v584 v585 v586 v587 v588 v589 v590 v591 v592 v593 v594 v595 v596 v597 v598 v599 v600 v601 v602 v603 v604 v605 v606 v607 v608 v609 v610 v611 v612 v613 v614 v615 v616 v617 v618 v619 v620 v621 v622 v623 v624 v625 v626 v627 v628 v629 v630 v631 v632 v633 v634 v635 v636 v637 v638 v639 v640 v641 v642 v643 v644 v645 v646 v647 v648 v649 v650 v651 v652 v653 v654 v655 v656 v657 v658 v659 v660 v661 v662 v663 v664 v665 v666 v667 v668 v669 v670 v671 v672 v673 v674 v675 v676 v677 v678 v679 v680 v681 v682 v683 v684 v685 v686 v687 v688 v689 v690 v691 v692 v693 v694 v695 v696 v697 v698 v699 v700 v701 v702 v703 v704 v705 v706 v707 v708 v709 v710 v711 v712 v713 v714 v715 v716 v717 v718 v719 v720 v721 v722 v723 v724 v725 v726 v727 v728 v729 v730 v731 v732 v733 v734 v735 v736 v737 v738 v739 v740 v741 v742 v743 v744 v745 v746 v747 v748 v749 v750 v751 v752 v753 v754 v755 v756 v757 v758 v759 v760 v761 v762 v763 v764 v765 v766 v767 v768 v769 v770 v771 v772 v773 v774 v775 v776 v777 v778 v779 v780 v781 v782 v783 v784 v785 v786 v787 v788 v789 v790 v791 v792 v793 v794 v795 v796 v797 v798 v799 v800 v801 v802 v803 v804 v805 v806 v807 v808 v809 v810 v811 v812 v813 v814 v815 v816 v817 v818 v819 v820 v821 v822 v823 v824 v825 v826 v827 v828 v829 v830 v831 v832 v833 v834 v835 v836 v837 v838 v839 v840 v841 v842 v843 v844 v845 v846 v847 v848 v849 v850 v851 v852 v853 v854 v855 v856 v857 v858 v859 v860 v861 v862 v863 v864 v865 v866 v867 v868 v869 v870 v871 v872 v873 v874 v875 v876 v877 v878 v879 v880 v881 v882 v883 v884 v885 v886 v887 v888 v889{
 local `v'l "`:var lab `v''"
 local `v'l = string(``v'l')
 local zro=cond(real("``v'l'")<100,"z0","z")
 local vl ="`zro'"+"``v'l'"
 gen `vl'=cond(`v'=="TRUE",1,0)
 recast byte `vl'
 drop `v'
}
drop zip_prefix

preserve
keep zip3
save "zip3_swm_zip3.dta", replace
restore

drop zip3
save zip3_swm, replace
use zip3_swm, clear
set matsize 11000

spatwmat using "P:\ORD_Jones_201309030D\zip3_swm.dta", name(W) standardize
use zip3,clear
//rename ZIP3 zip3
drop if STATE=="AK"
drop if STATE=="HI"
merge 1:1 zip3 using zip3dta
drop if _merge==2
drop _merge
merge 1:1 zip3 using zip3_swm_zip3
drop if _merge==1
replace x=0 if x==.
//spatlsa x, w(W) id(zip3) sort moran


genmsp x, w(W)


spmap x using zip3coordinates, id(id) fcolor(Reds) osize(vvthin) cln(8)
graph save Graph "P:\ORD_Jones_201309030D\morani.gph"

graph export "autocorrellation.tif",replace width(1600) height(1200)

/*

preserve
insheet using "P:\ORD_Jones_201309030D\autocorrelation.csv", comma clear
gen zip=cond(zip3<100,"0","")+string(zip3)
capture drop zip3
rename zip zip3
save "P:\ORD_Jones_201309030D\autocorrelation.dta",replace
restore
capture drop _merge
capture drop g1i eg1i sdg1i z pvalue ii ci
merge 1:1 zip3 using "P:\ORD_Jones_201309030D\autocorrelation.dta"
spmap ci using zip3coordinates, id(id) fcolor(Reds) osize(vvthin) cln(8)
graph export "autocorrellation.tif",replace width(1600) height(1200)

drop _merge
merge 1:1 id using zip3xy
drop if _merge==2
spatwmat, xcoord(x) ycoord(y) name(W) binary band(0 10)
spatlsa x, w(W) id(zip3) sort go1
preserve
insheet using "P:\ORD_Jones_201309030D\autocorrelation.csv", comma clear
gen zip=cond(zip3<100,"0","")+string(zip3)
capture drop zip3
rename zip zip3
save "P:\ORD_Jones_201309030D\autocorrelation.dta",replace
restore
capture drop _merge
capture drop g1i eg1i sdg1i z pvalue
merge 1:1 zip3 using "P:\ORD_Jones_201309030D\autocorrelation.dta"
spmap g1i using zip3coordinates, id(id) fcolor(Rainbow) osize(vvthin)
graph export "autocorrellation_dist.tif",replace width(1600) height(1200)


spmap x using zip3coordinates, id(id) fcolor(Blues) osize(vvthin)
graph export "NTM_rates.tif",replace width(1600) height(1200)
*/
