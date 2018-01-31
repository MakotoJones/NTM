*** PLEASE NOTE THAT CONNECTION INFORMATION AND NAMES OF NATIVE DATA TABLES AND FIELD NAMES HAVE BEEN CHANGED
*** FOR SECURITY REASONS


capture log close
log using "P:\ORD_Jones_201309030D\Scripts\NLM abstract STATA\ntm.smcl", replace

quietly {
noisily di _n(2)
noisily di in smcl "{hline}"
noisily di _n(2)
noisily di "{title: Load data from SQL database and save for later merging}"
}

clear
#delimit ;
odbc load, exec ("
SELECT * FROM [FacilityInfoTable]
")
conn("DRIVER={SQL Server}; 
	  SERVER=[ServerName]; 
	  DATABASE=[db]; 
	  Trusted_Connection=True") 
noquote clear
;
#delimit cr
quietly { //housekeeping
 rename facilityID facilityID
 sort facilityID
 cd "P:\ORD_Jones_201309030D\data"
}
save "facilityID.dta",replace


clear
#delimit ;
odbc load, exec ("
SELECT * FROM study.patientlivesntm
")
conn("DRIVER={SQL Server}; 
	  SERVER=[ServerName]; 
	  DATABASE=ORD_Jones_201309030D; 
	  Trusted_Connection=True") 
noquote clear
;
#delimit cr
quietly { //housekeeping
rename EncounterYear y
rename PatientLives py
rename facilityID facilityID
sort facilityID y
}
save "py.dta",replace

clear
#delimit ;
odbc load, exec ("
SELECT * FROM study.patientlivesntm_zip3
")
conn("DRIVER={SQL Server}; 
	  SERVER=[ServerName]; 
	  DATABASE=ORD_Jones_201309030D; 
	  Trusted_Connection=True") 
noquote clear
;
#delimit cr
quietly { //housekeeping
rename EncounterYear y
rename PatientLives py
rename facilityID facilityID
sort facilityID y
}
save "py_zip3.dta",replace


clear
#delimit ;
odbc load, exec ("
SELECT a.*,substring(b.zip,1,3) zip3
FROM study.cases a
LEFT JOIN src.PatientDetails b ON a.patientID=b.patientID
")
conn("DRIVER={SQL Server}; 
	  SERVER=[ServerName]; 
	  DATABASE=ORD_Jones_201309030D; 
	  Trusted_Connection=True") 
noquote clear
;
#delimit cr
save "casepatients.dta",replace


clear
#delimit ;
odbc load, exec ("
SELECT DISTINCT patientID, 1 pulmdx
  FROM [ORD_Jones_201309030D].temp.ntmdiagnosis
  WHERE icdcode='031.0' AND encounterdate BETWEEN '2008-01-01' AND '2012-12-31'
UNION
SELECT DISTINCT patientID, 1 pulmdx
  FROM [ORD_Jones_201309030D].study.samplingstudyntmdiagnoses
  WHERE icdcode='031.0' AND coalesce(visitdatetime,admissiondatetime) BETWEEN '2008-01-01' AND '2012-12-31'
")
conn("DRIVER={SQL Server}; 
	  SERVER=[ServerName]; 
	  DATABASE=ORD_Jones_201309030D; 
	  Trusted_Connection=True") 
noquote clear
;
#delimit cr
quietly { //housekeeping
sort patientID pulmdx
}
save "pulmdx.dta",replace


clear
#delimit ;
odbc load, exec ("
SELECT DISTINCT
      b.patientID
      ,[DOD]
	  ,DOB
  FROM [Src].[DeathRecords] a
  INNER JOIN [Src].[PatientDetails] b ON a.PatientIdentifier=b.PatientIdentifier
  WHERE b.patientID IN (SELECT case_patientID FROM study.controls) OR b.patientID IN (SELECT patientID FROM study.controls)

")
conn("DRIVER={SQL Server}; 
	  SERVER=[ServerName]; 
	  DATABASE=ORD_Jones_201309030D; 
	  Trusted_Connection=True") 
noquote clear
;
#delimit cr
quietly { //housekeeping
gen dod=date(DOD,"YMD")
format dod %td

drop DOD
gen dob=date(DOB,"YMD")
format dob %td
drop DOB
sort patientID dod
}
save "death.dta",replace

clear
#delimit ;
odbc load, exec ("
SELECT facilityID, [case_patientID] case_patientIDs
      ,patientID patientIDS
	  ,'' preferredterm
	  ,NULL extrapulm
	  ,setting typeflag
	  ,encountertime typedateS
      ,null pulmdx
	  ,null micro
	  ,null dx
      ,null tbmed
	  ,null infxn
	  ,copd
	  ,bronchiectasis
	  ,cancer
	  ,otherpulm
	  ,dmard
	  ,hiv
	  ,male_gender
	  ,encountertime
	  ,specialty
	  ,agediff
  FROM [ORD_Jones_201309030D].[Study].[controls]
")
conn("DRIVER={SQL Server}; 
	  SERVER=[ServerName]; 
	  DATABASE=ORD_Jones_201309030D; 
	  Trusted_Connection=True") 
noquote clear
;
#delimit cr
quietly { //housekeeping
gen patientID=real(patientIDS)
gen double case_patientID=real(case_patientIDs)
gen typedate=date(typedateS,"YMD")
format typedate %td

keep case_patientID facilityID patientID preferredterm extrapulm typeflag typedate pulmdx micro dx tbmed infxn copd bronchiectasis cancer otherpulm dmard hiv male_gender
sort patientID
}
save "controls.dta",replace

*grab everything with any NTM diagnosis or any case meeting NTM micro criteria
clear
#delimit ;
odbc load, exec ("
  WITH a as
(SELECT GlobalPatientIdentifier,patientID,facilityID,preferredterm,mindt,maxdt,sputum,bronch,lung,other
,unspecified_sputum,unspecified_bronch,unspecified_lung,unspecified_other,unspecified_mindt,unspecified_maxdt 
,CASE WHEN bronch+lung+other>0 OR (sputum>=2) OR (sputum>0 AND unspecified_sputum>0) THEN 1 ELSE 0 END NTM
,CASE WHEN other>0 AND bronch+lung+sputum=0 THEN 1 ELSE 0 END extrapulm
FROM [Temp].[nlp_mycobacterial_criteria] 
),
b as
(
SELECT GlobalPatientIdentifier,patientID,facilityID,preferredterm,mindt,extrapulm FROM a WHERE ntm=1 
) ,
ca as
(
SELECT GlobalPatientIdentifier,patientID,facilityID,typeflag,typedate,row_number() OVER(PARTITION BY GlobalPatientIdentifier ORDER BY typedate) rn FROM [Temp].[NtmDiagPatients] WHERE NTMFlag is not null  AND typedate BETWEEN '2008-01-01' AND '2012-12-31'
),
c as
(
SELECT * FROM ca WHERE rn=1
),
d as
(
SELECT GlobalPatientIdentifier,b.patientID,a.facilityID,cast(ct as varchar) ct,mindt, row_numbeR() OVER(PARTITION BY GlobalPatientIdentifier ORDER BY mindt) rn FROM temp.tb_drugs_filled a LEFT OUTER JOIN src.PatientDetails b ON a.patientID=b.patientID
) ,
dd as
(SELECT * FROM d WHERE rn=1),
e as
(
SELECT 
CASE WHEN b.GlobalPatientIdentifier is not null THEN b.GlobalPatientIdentifier ELSE c.GlobalPatientIdentifier END GlobalPatientIdentifier,
CASE WHEN b.patientID is not null THEN b.patientID ELSE c.patientID END patientID,
CASE WHEN b.facilityID is not null THEN b.facilityID ELSE c.facilityID END facilityID,
b.preferredterm,b.mindt micromindt,b.extrapulm,
c.typeflag,c.typedate
FROM b
FULL OUTER JOIN c ON b.GlobalPatientIdentifier=c.GlobalPatientIdentifier
) ,
f as
(
SELECT e.*,dd.ct ct_drugs,dd.mindt drug_mindt
FROM e
LEFT OUTER JOIN dd ON e.GlobalPatientIdentifier=dd.GlobalPatientIdentifier
)
SELECT f.GlobalPatientIdentifier,f.patientID,f.facilityID,f.preferredterm,f.micromindt,f.extrapulm,
CASE WHEN max(CASE WHEN f.typeflag='I' THEN 1
     WHEN g.datevalue is not null THEN 1
	 WHEN f.typeflag='O' THEN 0
	 END)=1 THEN 'I' ELSE 'O' END typeflag,f.typedate,f.ct_drugs,f.drug_mindt
FROM f
LEFT OUTER JOIN (SELECT * FROM [ADT].[AdtCensus] WHERE spansmidnight=1) g ON f.patientID=g.patientID AND g.datevalue=f.micromindt
GROUP BY  f.GlobalPatientIdentifier,f.patientID,f.facilityID,f.preferredterm,f.micromindt,f.extrapulm,f.typedate,f.ct_drugs,f.drug_mindt
;

")
conn("DRIVER={SQL Server}; 
	  SERVER=[ServerName]; 
	  DATABASE=ORD_Jones_201309030D; 
	  Trusted_Connection=True") 
noquote clear
;
#delimit cr

save "P:\ORD_Jones_201309030D\Scripts\NLM abstract STATA\ntm_mj1.dta", replace
use "P:\ORD_Jones_201309030D\Scripts\NLM abstract STATA\ntm_mj1.dta", clear

quietly {
set more off
capture drop microdt dxdt drugdt
gen microdt=date(micromindt,"YMDhms")
format microdt %td
gen dxdt=date(typedate,"YMD")
format dxdt %td
gen drugdt=date(drug_mindt,"YMDhms")
format drugdt %td
}

quietly {
noisily di in smcl _n(2) "{hline}" _n(1) "{title:Population}" "{p} Data used in this study were extracted from the Veterans Informatics and Computing Infrastructure (VINCI) from January 2008 through December 2012 to identify NTM. Natural language processing was used to identify the presence of mycobacterial from free-text microbiology record data. Data were coded to the most granular SNOMED CT concept (version __). In addition, mycobacterial identification in laboratory chemistry data were also extracted and coded to LOINC. The combined set was used to identify the presence of mycobacteria."
noisily di in smcl _n(2) "{hline}" _n(1) "{title:Microbiological identification}" "{p} We defined microbiological criteria for pulmonary NTM isolation as species identification in sputum followed either by isolation of the same species or a separate isolate identifying acid-fast bacteria within a lifetime. A single bronchoscopy specimen was also allowed. A single isolation of NTM was allowed for extrapulmonary NTM. {it:M. gordonae} was excluded no matter the number of positives."
noisily di in smcl _n(2) "{hline}" _n(1) "{title:Identification of {it:Mycobacteria} as they appeared in microbiology and laboratory data}" "{p} The following data represent species that were coded to the most granular level possible. Note that, for example, {it:M. avium}, {it:M. avium} complex, etc appear on separate lines. The table is ordered by frequency."
noisily tab preferredterm, sort

replace preferredterm="Mycobacterium abscessus-chelonae group" if preferredterm=="Mycobacterium abscessus" | preferredterm=="Mycobacterium chelonae"
replace preferredterm="Mycobacterium, avium-intracellulare group" if preferredterm=="Mycobacterium avium" | preferredterm=="Mycobacterium intracellulare"
replace preferredterm="Mycobacterium fortuitum complex" if preferredterm=="Mycobacterium fortuitum"
replace preferredterm="Mycobacterium terrae complex" if preferredterm=="Mycobacterium terrae" | preferredterm=="Mycobacterium nonchromogenicum" | preferredterm =="Mycobacterium triviale"

collapse (first) GlobalPatientIdentifier facilityID micromindt extrapulm typeflag typedate ct_drugs drug_mindt microdt dxdt drugdt, by(patientID preferredterm)
noisily di in smcl _n(2) "{p} In the following table, {it:Mycobacterium avium} complex, {it:M. chelonae} and {it:M.abscessus}, {it:M. fortuitum}, and {it:M. terrae} complexes are grouped together."
noisily tab preferredterm,sort

drop if preferredterm=="Rapid growing mycobacteria" | preferredterm=="Scotochromogenic mycobacteria" | preferredterm=="Mycobacterium, non-TB"
noisily di in smcl _n(2) "{p} Finally, we will group one more time as {it:Mycobacterium avium} complex, {it:M. chelonae} and {it:M.abscessus}, {it:M. kansasii} and other groups are specified."
replace preferredterm="Other Mycobacteria" if preferredterm~="Mycobacterium abscessus-chelonae group" & preferredterm~="Mycobacterium, avium-intracellulare group" & preferredterm ~="Mycobacterium kansasii" & preferredterm~=""
collapse (first) GlobalPatientIdentifier facilityID micromindt extrapulm typeflag typedate ct_drugs drug_mindt microdt dxdt drugdt, by(patientID preferredterm)
noisily tab preferredterm,sort

noisily di in smcl _n(2) "{p} We can stratify this list by whether the microbiological tests meet pulmonary or extra-pulmonary criteria"
noisily di _n "{bf:Pulmonary}"
noisily tab preferredterm if extrapulm==0, sort
noisily di _n(2) "{bf:Extra-pulmonary}"
noisily tab preferredterm if extrapulm==1, sort

*marks whether there was a micro diagnosis
gen micro=cond(preferredterm~="",1,0)
*marks in or outpatient dx code
gen dx=cond(typedate~="",1,0)
*marks whether an ntm med was given
gen tbmed=cond(ct_drugs~="",1,0)

count if micro==0 & dx==1
local x=r(N)
count if micro==1
noisily di in smcl _n(2) "{p} Besides " r(N) " microbiology cases, " `x' " cases were identified only by ICD-9-CM codes. The following table demonstrates the overlap between the two."
noisily tab micro dx


* get ICD diagnoses of pulmonary diseases and mark
* at least one pulmonary diagnoses among mycobacterial diagnoses
merge m:1 patientID using "pulmdx.dta"
drop if _merge==2
replace pulmdx=0 if pulmdx==.

capture drop x
quietly gen x=cond(typeflag=="O",1,0)
quietly sum x

noisily di in smcl _n(2) "{p} Most diagnoses or microbiology (" r(mean) ") occurs in the outpatient setting. When we examine microbiology and ICD-9-CM diagnoses separately by setting, we see that when diagnoses codes are used alone, we predominantly have an initial outpatient diagnoses. The majority of micro-only diagnoses are actually made in the inpatient setting. When both microbiology and diagnosis codes are present the split is fairly even." _n

replace typeflag="O" if typeflag=="" //happened in an outpt setting if micro dx and I cant find an inpt setting

capture drop x
gen x="micro" if micro==1 & dx==0
replace x="micro&dx" if micro==1 & dx==1
replace x="dx" if micro==0 & dx==1
noisily tab typeflag  x,co

noisily di _n in smcl "{hline}"
noisily display in smcl  _n(2) as text "{title:Pulmonary versus Extra-pulmonary.}"

count if dx==1
local x=r(N)
count if pulmdx==1
local x=r(N)/`x'
noisily di in smcl _n(2) "{p} Among mycobacterial infections with diagnosis codes, " `x' " also document a pulmonary code."

gen pulmmicro=1 if extrapulm==0 & micro==1
replace pulmmicro=0 if pulmmicro==.
count if micro==1
local x=r(N)
count if pulmmicro==1
local x=r(N)/`x'
noisily di in smcl  " Among mycobacterial infections with microbiology, " `x' " meet pulmonary microbiology criteria."

noisily di in smcl  " Whereas there were a number of NTM diagnoses without microbiology, when we restrict to pulmonary cases, we find that there are more cases that meet microbiology criteria without a diagnosis." 
noisily di _n(2)
noisily tab pulmdx pulmmicro


capture drop x
gen x="pulmdx" if pulmdx==1 & pulmmicro==0
replace x="pulmdx&micro" if pulmdx==1 & pulmmicro==1
replace x="micro" if pulmdx==0 & pulmmicro==1
noisily di in smcl _n(2) "When we stratify the way in which pulmonary NTM is diagnosed by whether it was first documented in or outpatient, we see similar patterns as before."
noisily tab typeflag x

gen extrapulmmicro=1 if extrapulm==1 & micro==1
replace extrapulmmicro=0 if extrapulmmicro==.
gen extrapulmdx=1 if pulmdx==0 & dx==1
replace extrapulmdx=0 if extrapulmdx==.

capture drop x
gen x="xpulmdx" if extrapulmdx==1 & extrapulmmicro==0
replace x="xpulmdx&micro" if extrapulmdx==1 & extrapulmmicro==1
replace x="xpulmmicro" if extrapulmdx==0 & extrapulmmicro==1
noisily di in smcl _n(2) "{p} When we stratify the way in which {it:extra}pulmonary NTM is diagnosed by whether it was first documented in or outpatient, we see similar patterns as before."
noisily tab typeflag x

noisily di in smcl _n(2) "{p} A close examination of the previous tables reveals that there must be overlap between pulmonary micriobiology and non-pulmonary diagnoses. The following tables demonstrate this."
noisily tab pulmmicro extrapulmdx
noisily tab pulmdx extrapulmmicro

noisily di in smcl _n(2) "{p} For analyses below, we therefore defined a pulmonary NTM diagnosis as the presence of microbiological or ICD9-CM criteria for pulmonary NTM infection."
gen pulmcase=cond(pulmdx==1 | pulmmicro==1,1,0)
sum pulmcase
noisily di in smcl "The resulting proportion of pulmonary cases was " r(mean) "."

noisily di in smcl "Finally, looking at pulmonary cases diagnosed inpatient and outpatient, we find that the majority of cases diagnosed as inpatient are pulmonary and the majority of cases diagnosed as outpatient are not pulmonary."
noisily tab pulmcase typeflag




* count for Euler's diagram

noisily di "{p}The following are necessary to create the Euler diagram showing overlap of microbiology, diagnoses and possible NTM medications."

noisily di _n "NTM micro+, dx+, meds+."
noisily count if micro==1 & dx==1 & tbmed==1
noisily di "NTM micro+, dx+, meds-."
noisily count if micro==1 & dx==1 & tbmed==0
noisily di "NTM micro+, dx-, meds-."
noisily count if micro==1 & dx==0 & tbmed==0
noisily di "NTM micro+, dx-, meds+."
noisily count if micro==1 & dx==0 & tbmed==1
noisily di "NTM micro-, dx-, meds+."
noisily count if micro==0 & dx==0 & tbmed==1
noisily di "NTM micro-, dx+, meds+."
noisily count if micro==0 & dx==1 & tbmed==1
noisily di "NTM micro-, dx+, meds-."
noisily count if micro==0 & dx==1 & tbmed==0


noisily di in smcl _n(2) "{p} Before moving on to examine the epidemiology of NTM, we examined whether diagnoses came after microbiology."
*Create a histogram and table showing whether diagnosis predates micro (negative)
* or micro predates diagnosis (positive values)
gen dd=dxdt-microdt
hist(dd) if dd>-2000, xtitle("Diagnosis date - micro date")
graph export "dx_b4_micro.emf",replace
noisily di in smcl _n(2) "{p} The histogram shown demonstrates the distribution of times between microbiology and diagnosis. Negative numbers reflect diagnoses documented before microbiology. [Insert dx_b4_micro.emf]"
noisily di in smcl "Although we did not find that microbiology always preceded diagnosis, we defined the case to occur at the time of the earliest of when microbiological criteria were met. "

* call NTM infection with either micro or ICD9 criteria. Take the earliest of the two
gen earliestdt=cond(microdt<dxdt,microdt,dxdt)
gen y=year(earliestdt)
gen infxn=cond(pulmmicro==1 | pulmdx==1,1,0) //pulm
gen extrapulminfxn=cond((extrapulmmicro==1 | extrapulmdx==1) & infxn==0,1,0)
gen anyinfxn=cond(pulmmicro==1 | pulmdx==1 | extrapulmmicro==1 | extrapulmdx==1,1,0)

gen pulmmicrodx=cond(pulmmicro==1 & pulmdx==1,1,0)
gen extrapulmmicrodx=cond(extrapulmmicro==1 & extrapulmdx==1,1,0)
gen anypulmmicrodx=cond((pulmmicro==1 & pulmdx==1) | (extrapulmmicro==1 & extrapulmdx==1),1,0)


noisily di in smcl _n(2) "{p} We surmised that a substantial proportion of real pulmonary NTM cases would be treated. Therefore, we also examined the use of possible NTM medications, which we defined as the systemic, outpatient administration of fluoroquinolones, tetracyclines, macrolides, linezolid, trimethoprim/sulfamethoxazole, cefoxitin, aminoglycosides, isoniazid, ethambutol, rifampin, or carbapenems given for at least 30 days."
label var tbmed NTMmed
noisily tab tbmed pulmcase

label var tbmed NTMmed
noisily tab tbmed extrapulminfxn

**** EXAMINE THE TRENDS OF THE RAW DATA COMPONENTS
graph bar (sum) pulmmicro pulmdx infxn pulmmicrodx if y>2008 & y<2013, over(y) legend(label(1 "micro") label(2 "dx") label(3 "micro OR dx") label(4 "micro AND dx")) title("Count for pulmonary")
graph save a,replace
graph bar (sum) extrapulmmicro extrapulmdx extrapulminfxn extrapulmmicrodx if y>2008 & y<2013, over(y) legend(label(1 "micro") label(2 "dx") label(3 "micro OR dx") label(4 "micro AND dx")) title("Count in extra-pulmonary")
graph save b,replace
graph bar (sum) micro dx anyinfxn anypulmmicrodx if y>2008 & y<2013, over(y) legend(label(1 "micro") label(2 "dx") label(3 "micro OR dx") label(4 "micro AND dx")) title("Count overall")
graph save c,replace

graph combine "a.gph" "b.gph" "c.gph", ro(1)
graph export "ntm dx mod by type.emf", replace



noisily di in smcl "{hline}"
noisily di in smcl _n(2) "{title: Epidemiology}"




*generate a graph of overall pulmonary NTM incidence in the population by regions
save "P:\ORD_Jones_201309030D\Scripts\NLM abstract STATA\ntm_pulmANDextra.dta", replace
use "P:\ORD_Jones_201309030D\Scripts\NLM abstract STATA\ntm_pulmANDextra.dta", clear
cd "P:\ORD_Jones_201309030D\data"
*keep if infxn==1
//generate a file for maps
{
preserve
tab  preferredterm if extrapulm==0, gen(ntm_spec)
tab  preferredterm if extrapulm==1, gen(ntm_spece)
collapse (count) ct=patientID (sum) ntm_spec1 ntm_spec2 ntm_spec3 ntm_spec4 ntm_spece1 ntm_spece2 ntm_spece3 ntm_spece4  (sum) infxn extrapulminfxn, by(facilityID y)
merge 1:1 facilityID y using "py.dta"
keep if y>=2008 & y<=2012
capture drop _merge
merge m:1 facilityID using "facilityID.dta"
gen region="Gulf" if NetworkID==8 | NetworkID==16 | NetworkID==17
replace region="Atlantic" if NetworkID==7 | NetworkID==6 | NetworkID==5 | NetworkID==3 | NetworkID==1 | NetworkID==2 | NetworkID==4
replace region="Midwest" if NetworkID==10 | NetworkID==9 | NetworkID==11 |NetworkID==12| NetworkID==15 | NetworkID==23
replace region="Mountain" if NetworkID==18 | NetworkID==19
replace region="Pacific" if NetworkID==20 | NetworkID==21 | NetworkID==22
keep if NetworkID>0 & NetworkID~=14
collapse (sum) ct ntm_spec1 ntm_spec2 ntm_spec3 ntm_spec4 ntm_spece1 ntm_spece2 ntm_spece3 ntm_spece4 extrapulminfxn infxn py, by(NetworkID region)
save "P:\ORD_Jones_201309030D\ntm_spec2.dta", replace
restore
}



{
preserve
keep if infxn==1
set more off
tab  preferredterm if extrapulm==0, gen(ntm_spec)
tab  preferredterm if extrapulm==1, gen(ntm_spec_e)
collapse (sum) infxn, by(facilityID y)
merge 1:1 facilityID y using "py.dta"
keep if y>=2008 & y<=2012
gen x=infxn/py
capture drop _merge
merge m:1 facilityID using "facilityID.dta"
gen region="Gulf" if NetworkID==8 | NetworkID==16 | NetworkID==17
replace region="Atlantic" if NetworkID==7 | NetworkID==6 | NetworkID==5 | NetworkID==3 | NetworkID==1 | NetworkID==2 | NetworkID==4
replace region="Midwest" if NetworkID==10 | NetworkID==9 | NetworkID==11 |NetworkID==12| NetworkID==15 | NetworkID==23
replace region="Mountain" if NetworkID==18 | NetworkID==19
replace region="Pacific" if NetworkID==20 | NetworkID==21 | NetworkID==22
keep if NetworkID>0 & NetworkID~=14

collapse (sum) infxn py, by(region y)
gen x=100000*infxn/py
drop if y==2008
twoway (line x y if region=="Gulf", sort lpattern(solid)) (line x y if region=="Atlantic", sort lpattern(dash)) (line x y if region=="Midwest", sort lpattern(dash_dot)) (line x y if region=="Mountain", sort lpattern(longdash)) (line x y if region=="Pacific", sort lpattern(longdash_dot)), ytitle("per 100k pt-yr")  title("Pulmonary NTM cases") legend(label(1 "Gulf") label(2 "Atlantic") label(3 "Midwest") label(4 "Mountain") label(5 "Pacific")) xtitle(year) scheme(s1mono) ylab(0(4)24)
graph export "pulmonaryntm.emf", replace

noisily poisson infxn y if region=="Gulf", exposure(py) irr 
noisily poisson infxn y if region=="Atlantic", exposure(py) irr
noisily poisson infxn y if region=="Midwest", exposure(py) irr
noisily poisson infxn y if region=="Mountain", exposure(py) irr
noisily poisson infxn y if region=="Pacific", exposure(py) irr

collapse (sum) infxn py, by(region)
gen rate=100000*infxn/py
gsort -rate
noisily di in smcl _n(2) "{p}The nations NetworkIDs were divided into 5 regions: Gulf (8, 16, 17), Atlantic (1,2,3,4,5,6,7), Midwest (9,10,11,12,15,23), Mountain (18,19), and Pacific (20,21,22)."
noisily di in smcl _n(2) "Patient years were counted as the number of unique patients at a VA station with one or more in- or outpatient visits during a calendar year. Patients could only count for the first station that they visited in a year. The following table represents all pulmonary NTM."


gen lb=.
gen ub=.
gen irr=.
gen p=.

sort region
local x0=infxn[1]
local y0=py[1]

forvalues i = 1/5{
 local x=infxn[`i']
 local y=py[`i']
 cii means `y' `x',poisson
 replace lb=100000*r(lb) in `i'/`i'
 replace ub=100000*r(ub) in `i'/`i'
 iri `x' `x0' `y' `y0'
 replace irr=r(irr) in `i'/`i'
 replace p=2*r(p) in `i'/`i'
}

noisily di "Incidence rates of pulmonary NTM per 100k patient-years"
noisily list
noisily di in smcl _n(2) "The accompanying figure demonstrates time trends. [insert pulmonaryntm.eff]"
gen x=100000*infxn/py
egen g=group(region)
noisily oneway x g [fweight=py],tab
//noisily robvar x [fweight=py], by(g) //cant weight robvar.. equal variances violated

restore
}

*extrapulm
{
preserve
keep if extrapulminfxn==1
set more off
collapse (sum) extrapulminfxn, by(facilityID y)
merge 1:1 facilityID y using "py.dta"
keep if y>=2008 & y<=2012
gen x=extrapulminfxn/py
capture drop _merge
merge m:1 facilityID using "facilityID.dta"
gen region="Gulf" if NetworkID==8 | NetworkID==16 | NetworkID==17
replace region="Atlantic" if NetworkID==7 | NetworkID==6 | NetworkID==5 | NetworkID==3 | NetworkID==1 | NetworkID==2 | NetworkID==4
replace region="Midwest" if NetworkID==10 | NetworkID==9 | NetworkID==11 |NetworkID==12| NetworkID==15 | NetworkID==23
replace region="Mountain" if NetworkID==18 | NetworkID==19
replace region="Pacific" if NetworkID==20 | NetworkID==21 | NetworkID==22
keep if NetworkID>0 & NetworkID~=14

collapse (sum) extrapulminfxn py, by(region y)
gen x=100000*extrapulminfxn/py
drop if y==2008
twoway (line x y if region=="Gulf", sort lpattern(solid)) (line x y if region=="Atlantic", sort lpattern(dash)) (line x y if region=="Midwest", sort lpattern(dash_dot)) (line x y if region=="Mountain", sort lpattern(longdash)) (line x y if region=="Pacific", sort lpattern(longdash_dot)), ytitle("per 100k pt-yr")  title("Extra-pulmonary NTM cases") legend(label(1 "Gulf") label(2 "Atlantic") label(3 "Midwest") label(4 "Mountain") label(5 "Pacific")) xtitle(year) scheme(s1mono) ylab(0(4)24)
graph export "extrapulmonaryntm.emf", replace

noisily poisson extrapulminfxn y if region=="Gulf", exposure(py) irr 
noisily poisson extrapulminfxn y if region=="Atlantic", exposure(py) irr
noisily poisson extrapulminfxn y if region=="Midwest", exposure(py) irr
noisily poisson extrapulminfxn y if region=="Mountain", exposure(py) irr
noisily poisson extrapulminfxn y if region=="Pacific", exposure(py) irr

collapse (sum) extrapulminfxn py, by(region)
gen rate=100000*extrapulminfxn/py
gsort -rate
noisily di in smcl _n(2) "{p}The nations NetworkIDs were divided into 5 regions: Gulf (8, 16, 17), Atlantic (1,2,3,4,5,6,7), Midwest (9,10,11,12,15,23), Mountain (18,19), and Pacific (20,21,22)."
noisily di in smcl _n(2) "Patient years were counted as the number of unique patients at a VA station with one or more in- or outpatient visits during a calendar year. Patients could only count for the first station that they visited in a year. The following table represents all extrapulmonary NTM."


gen lb=.
gen ub=.
gen irr=.
gen p=.

sort region
local x0=extrapulminfxn[1]
local y0=py[1]

forvalues i = 1/5{
 local x=extrapulminfxn[`i']
 local y=py[`i']
 cii means `y' `x',poisson
 replace lb=100000*r(lb) in `i'/`i'
 replace ub=100000*r(ub) in `i'/`i'
 iri `x' `x0' `y' `y0'
 replace irr=r(irr) in `i'/`i'
 replace p=2*r(p) in `i'/`i'
}

noisily di "Incidence rates of extrapulmonary NTM per 100k patient-years"
noisily list
noisily di in smcl _n(2) "The accompanying figure demonstrates time trends. [insert extrapulmonaryntm.eff]"
gen x=100000*extrapulminfxn/py
egen g=group(region)
noisily oneway x g [fweight=py],tab
//noisily robvar x [fweight=py], by(g) //cant weight robvar.. equal variances violated

restore
}



{
preserve
keep if infxn==1
collapse (sum) infxn, by(facilityID y)
merge 1:1 facilityID y using "py.dta"
keep if y>=2008 & y<=2012
collapse (sum) infxn py, by(y)
gen x=100000*infxn/py
drop if y==2008
noisily di "overall trend in PNTM"
noisily poisson infxn y, exposure(py) irr
restore
}

{
preserve
keep if infxn==1
tab preferredterm,gen(org)
rename org1 chelonae
rename org2 kansasii
rename org3 mac
rename org4 Other
capture drop _merge
merge m:1 facilityID using "facilityID.dta"
gen region="Gulf" if NetworkID==8 | NetworkID==16 | NetworkID==17
replace region="Atlantic" if NetworkID==7 | NetworkID==6 | NetworkID==5 | NetworkID==3 | NetworkID==1 | NetworkID==2 | NetworkID==4
replace region="Midwest" if NetworkID==10 | NetworkID==9 | NetworkID==11 |NetworkID==12| NetworkID==15 | NetworkID==23
replace region="Mountain" if NetworkID==18 | NetworkID==19
replace region="Pacific" if NetworkID==20 | NetworkID==21 | NetworkID==22
keep if NetworkID>0 & NetworkID~=14
noisily di in smcl _n(2) "{p} We can also examine the distribution of isolated pulmonary NTM species by region. [insert pulmonaryntm_region_species.emf]"
graph bar (sum) chelonae (sum) kansasii (sum) mac (sum) Other, stack over(region) legend(label(1 "{it:M. chelonae-abscessus}") label(2 "{it:M. kansasii}") label(3 "{it:M. avium complex}") label(4 "Other {it:Mycobacteria}")) title("Count of pulmonary cases")
graph export "pulmonaryntm_region_species.emf",replace
restore
}

*do the same with avium
{
preserve
keep if infxn==1
keep if preferredterm=="Mycobacterium, avium-intracellulare group"
collapse (sum) infxn, by(facilityID y)
merge 1:1 facilityID y using "py.dta"
keep if y>=2008 & y<=2012
gen x=infxn/py
capture drop _merge
merge m:1 facilityID using "facilityID.dta"
gen region="Gulf" if NetworkID==8 | NetworkID==16 | NetworkID==17
replace region="Atlantic" if NetworkID==7 | NetworkID==6 | NetworkID==5 | NetworkID==3 | NetworkID==1 | NetworkID==2 | NetworkID==4
replace region="Midwest" if NetworkID==10 | NetworkID==9 | NetworkID==11 |NetworkID==12| NetworkID==15 | NetworkID==23
replace region="Mountain" if NetworkID==18 | NetworkID==19
replace region="Pacific" if NetworkID==20 | NetworkID==21 | NetworkID==22
keep if NetworkID>0 & NetworkID~=14
collapse (sum) infxn py, by(region y)
gen x=100000*infxn/py
drop if y==2008
twoway (line x y if region=="Gulf", sort) (line x y if region=="Atlantic", sort) (line x y if region=="Midwest", sort) (line x y if region=="Mountain", sort) (line x y if region=="Pacific", sort), ytitle("per 100k pt-yr")  title("Pulmonary {it:M. avium complex} cases") legend(label(1 "Gulf") label(2 "Atlantic") label(3 "Midwest") label(4 "Mountain") label(5 "Pacific"))
graph export "pulmonaryMAC.emf", replace
collapse (sum) infxn py, by(region)
gen rate=100000*infxn/py
gsort -rate
noisily di in smcl _n(2) "The following table represents {it:M. avium-intracellulare} group."

gen lb=.
gen ub=.
forvalues i = 1/5{
 local x=infxn[`i']
 local y=py[`i']
 cii means `y' `x',poisson
 replace lb=100000*r(lb) in `i'/`i'
 replace ub=100000*r(ub) in `i'/`i'
}

noisily list
noisily di in smcl _n(2) "The accompanying figure demonstrates time trends. [insert pulmonaryMAC.eff]"
restore
}

*do the same with chelonae-abscessus
{
preserve
keep if infxn==1
keep if preferredterm=="Mycobacterium abscessus-chelonae group"
collapse (sum) infxn, by(facilityID y)
merge 1:1 facilityID y using "py.dta"
keep if y>=2008 & y<=2012
gen x=infxn/py
capture drop _merge
merge m:1 facilityID using "facilityID.dta"
gen region="Gulf" if NetworkID==8 | NetworkID==16 | NetworkID==17
replace region="Atlantic" if NetworkID==7 | NetworkID==6 | NetworkID==5 | NetworkID==3 | NetworkID==1 | NetworkID==2 | NetworkID==4
replace region="Midwest" if NetworkID==10 | NetworkID==9 | NetworkID==11 |NetworkID==12| NetworkID==15 | NetworkID==23
replace region="Mountain" if NetworkID==18 | NetworkID==19
replace region="Pacific" if NetworkID==20 | NetworkID==21 | NetworkID==22
keep if NetworkID>0 & NetworkID~=14
collapse (sum) infxn py, by(region y)
gen x=100000*infxn/py
drop if y==2008
twoway (line x y if region=="Gulf", sort) (line x y if region=="Atlantic", sort) (line x y if region=="Midwest", sort) (line x y if region=="Mountain", sort) (line x y if region=="Pacific", sort), ytitle("per 100k pt-yr")  title("Pulmonary {it:M.abscessus/chelonae} cases") legend(label(1 "Gulf") label(2 "Atlantic") label(3 "Midwest") label(4 "Mountain") label(5 "Pacific"))
graph export "pulmonaryabscessus.emf", replace
collapse (sum) infxn py, by(region)
gen rate=100000*infxn/py
gsort -rate
noisily di in smcl _n(2) "The following table represents {it:M. abscessus} and {it:M. chelonae}."

gen lb=.
gen ub=.
forvalues i = 1/5{
 local x=infxn[`i']
 local y=py[`i']
 cii means `y' `x',poisson
 replace lb=100000*r(lb) in `i'/`i'
 replace ub=100000*r(ub) in `i'/`i'
}

noisily list
noisily di in smcl _n(2) "The accompanying figure demonstrates time trends. [insert pulmonaryabscessus.eff]"
restore
}

*do the same with chelonae-abscessus
{
preserve
keep if infxn==1
keep if preferredterm=="Mycobacterium kansasii"
collapse (sum) infxn, by(facilityID y)
merge 1:1 facilityID y using "py.dta"
keep if y>=2008 & y<=2012
gen x=infxn/py
capture drop _merge
merge m:1 facilityID using "facilityID.dta"
gen region="Gulf" if NetworkID==8 | NetworkID==16 | NetworkID==17
replace region="Atlantic" if NetworkID==7 | NetworkID==6 | NetworkID==5 | NetworkID==3 | NetworkID==1 | NetworkID==2 | NetworkID==4
replace region="Midwest" if NetworkID==10 | NetworkID==9 | NetworkID==11 |NetworkID==12| NetworkID==15 | NetworkID==23
replace region="Mountain" if NetworkID==18 | NetworkID==19
replace region="Pacific" if NetworkID==20 | NetworkID==21 | NetworkID==22
keep if NetworkID>0 & NetworkID~=14
collapse (sum) infxn py, by(region y)
gen x=100000*infxn/py
drop if y==2008
twoway (line x y if region=="Gulf", sort) (line x y if region=="Atlantic", sort) (line x y if region=="Midwest", sort) (line x y if region=="Mountain", sort) (line x y if region=="Pacific", sort), ytitle("per 100k pt-yr")  title("Pulmonary {it:M. kansasii} cases") legend(label(1 "Gulf") label(2 "Atlantic") label(3 "Midwest") label(4 "Mountain") label(5 "Pacific"))
graph export "pulmonarykansasii.emf", replace
collapse (sum) infxn py, by(region)
gen rate=100000*infxn/py
gsort -rate
noisily di in smcl _n(2) "The following table represents {it:M. kansasii}."

gen lb=.
gen ub=.
forvalues i = 1/5{
 local x=infxn[`i']
 local y=py[`i']
 cii means `y' `x',poisson
 replace lb=100000*r(lb) in `i'/`i'
 replace ub=100000*r(ub) in `i'/`i'
}

noisily list
noisily di in smcl _n(2) "The accompanying figure demonstrates time trends. [insert pulmonarykansasii.eff]"
restore
}

*do the same with other
{
preserve
keep if infxn==1
keep if preferredterm=="Other Mycobacteria"
collapse (sum) infxn, by(facilityID y)
merge 1:1 facilityID y using "py.dta"
keep if y>=2008 & y<=2012
gen x=infxn/py
capture drop _merge
merge m:1 facilityID using "facilityID.dta"
gen region="Gulf" if NetworkID==8 | NetworkID==16 | NetworkID==17
replace region="Atlantic" if NetworkID==7 | NetworkID==6 | NetworkID==5 | NetworkID==3 | NetworkID==1 | NetworkID==2 | NetworkID==4
replace region="Midwest" if NetworkID==10 | NetworkID==9 | NetworkID==11 |NetworkID==12| NetworkID==15 | NetworkID==23
replace region="Mountain" if NetworkID==18 | NetworkID==19
replace region="Pacific" if NetworkID==20 | NetworkID==21 | NetworkID==22
keep if NetworkID>0 & NetworkID~=14
collapse (sum) infxn py, by(region y)
gen x=100000*infxn/py
drop if y==2008
twoway (line x y if region=="Gulf", sort) (line x y if region=="Atlantic", sort) (line x y if region=="Midwest", sort) (line x y if region=="Mountain", sort) (line x y if region=="Pacific", sort), ytitle("per 100k pt-yr")  title("Pulmonary Other NTM cases") legend(label(1 "Gulf") label(2 "Atlantic") label(3 "Midwest") label(4 "Mountain") label(5 "Pacific"))
graph export "pulmonaryother.emf", replace
collapse (sum) infxn py, by(region)
gen rate=100000*infxn/py
gsort -rate
noisily di in smcl _n(2) "The following table represents other {it:Mycobacteria}."

gen lb=.
gen ub=.
forvalues i = 1/5{
 local x=infxn[`i']
 local y=py[`i']
 cii means `y' `x',poisson
 replace lb=100000*r(lb) in `i'/`i'
 replace ub=100000*r(ub) in `i'/`i'
}

noisily list
noisily di in smcl _n(2) "The accompanying figure demonstrates time trends. [insert pulmonaryother.eff]"
restore
}

noisily di in smcl _n(2) "{hline}"
noisily di in smcl _n(2) "{title: Regression models}"


*add in the controls and keep everyone from 2009 onward (so that everyone has a year history)

noisily di in smcl _n "{p} To allow each case or control in the cohort to have one year of history prior to inclusion, regression models start from 2009. Follow-up time ends the 12/31/2012."
capture drop typedate
rename earliestdt typedate
format typedate %td
keep if typedate>=date("2009-01-01","YMD")
keep facilityID patientID preferredterm extrapulm typeflag typedate pulmdx micro dx tbmed infxn extrapulminfxn
gen double case_patientID=patientID

capture drop _merge
merge m:1 patientID using "casepatients.dta", force keepusing(loc COPD male_gender mindt bronchiectasis cancer otherpulm dmard hiv)
drop if _merge==2
rename COPD copd
append using "controls.dta"

*get the death data
capture drop _merge
merge m:1 patientID using "death.dta"
drop if _merge==2


****CALCULATE PREVALENCE IN 2012
preserve
drop if dod<date("2012-01-01","YMD")
capture drop y
gen y=2012
collapse (sum) infxn, by(facilityID y)
merge 1:1 facilityID y using "py.dta"
keep if y==2012
collapse (sum) infxn py
noisily list

restore

preserve
capture drop dt
capture drop y
gen dt = date(mindt,"YMDhms")
format dt %td
gen y=yofd(dt)

drop if dod<date("2009-01-01","YMD")
collapse (sum) infxn, by(facilityID y)
merge 1:1 facilityID y using "py.dta"

collapse (sum) infxn py
noisily list

restore



set matsize 10000
gen d=cond(dod~=.,1,0)
replace dod=date("2012-12-31","YMD") if dod==. //set the study stop
replace d=0 if dod>date("2012-12-31","YMD") //censor death past follow up
capture drop t
gen t=(dod-typedate)/365 //time of death

set more off
drop if t<=0 //drop erroneous death dates AND very early deaths
replace t=4 if t>4
gen case=cond(patientID==case_patientID,1,0) //set the case marker

count if case==1 //count cases
noisily di in smcl _n " After cases with erroneous death times have been dropped, we have " r(N) " cases during the study period."

* matched 4:1 so the group should have 5--including the case
gsort case_patientID -case
capture drop controlcount
egen controlcount=count(case), by(case_patientID)
drop if controlcount<5

count if case==1
noisily di in smcl _n "{p} We matched cases 4:1. There were " r(N) " cases remaining that matched to 4 controls on age within one year without having the diagnosis; sex; COPD, bronchiectasis, cancer, and other pulmonary diagnosis; receipt of a diseaes modifying antirheumatic drug; same station, and the closest time to visit."

capture drop mindate
gen mindate=date(mindt,"YMDhms")
format mindate %td
capture drop age
gen age=(mindate-dob)/365

gsort  case_patientID -case
capture drop xp
gen xp=extrapulminfxn if case==1
replace xp=xp[_n-1] if case_patientID==case_patientID[_n-1] in 2/l

forvalues i = 0/1{
noisily di in smcl _n "Characteristics of cases"
noisily tab male_gender case if xp==`i', co chi
noisily tab copd case if xp==`i', co chi
noisily tab bronchiectasis case if xp==`i', co chi
noisily tab cancer case if xp==`i', co chi
noisily tab otherpulm case if xp==`i', co chi
noisily tab dmard case if xp==`i', co chi
noisily tab loc case if xp==`i', co chi
noisily sum age if case==1 & xp==`i', detail
//noisily sum age if case==0 & xp==`i', detail
//noisily ttest age  if xp==`i',by(case)
noisily tab hiv case if xp==`i', co chi
}


stset t, failure(d==1)

stphplot, by(case)
stcoxkm, by(case)

stphplot, strata(case) adj(cancer)
stphplot, strata(case) adj(hiv)


* hazard ratio of death
capture drop baselin
stset t, failure(d==1)
noisily stcox case copd male_gender bronchiectasis cancer otherpulm dmard hiv, strata(case_patientID) 

estat phtest, detail
noisily di in smcl _n(2) "A survival curve of the cases is found below. [insert survival_after_ntm.emf]"

noisily stcox case male_gender bronchiectasis cancer otherpulm dmard hiv if copd==1, strata(case_patientID) 
estat phtest, detail

noisily stcox case male_gender bronchiectasis cancer otherpulm dmard hiv if _t<.5, strata(case_patientID) 
estat phtest, detail

noisily stcox case male_gender bronchiectasis cancer otherpulm dmard hiv if _t>.5, strata(case_patientID) 
estat phtest, detail


gen NoCOPD=1 if cond(copd==0,1,0)
gen NotMale=1 if cond(male_gender==0,1,0)

sts graph if xp==0, by(case)  xtitle(years) title(Survivor function for pulm. NTM)  scheme(s1mono)
graph save "pulmsurvraw.gph",replace
sts graph if xp==1, by(case)  xtitle(years) title(Survivor function for extra-pulm. NTM)  scheme(s1mono)
graph save "xpulmsurvraw.gph",replace

graph combine "pulmsurvraw.gph" "xpulmsurvraw.gph", row(1) scheme(s1mono) note(no adjustment)
graph export "survivalraw.tif",replace width(1600) height(1200)



sts graph if xp==0, strata(case) adjustfor(NoCOPD male_gender bronchiectasis cancer otherpulm dmard hiv) xtitle(years) title(Survivor function for pulm. NTM)  scheme(s1mono)
graph save "pulmsurv.gph",replace
sts graph if xp==1, strata(case) adjustfor(NoCOPD male_gender bronchiectasis cancer otherpulm dmard hiv) xtitle(years) title(Survivor function for extra-pulm. NTM)  scheme(s1mono)
graph save "xpulmsurv.gph",replace

graph combine "pulmsurv.gph" "xpulmsurv.gph", row(1) scheme(s1mono) note(adjusted to men with COPD and without the other studied covariates)
graph export "survival.tif",replace width(1600) height(1200)

clear
#delimit ;
odbc load, exec ("
SELECT * FROM temp.visitcounts
")
conn("DRIVER={SQL Server}; 
	  SERVER=[ServerName]; 
	  DATABASE=ORD_Jones_201309030D; 
	  Trusted_Connection=True") 
noquote clear
;
#delimit cr

gen case=cond(patientID==case_patientID,1,0)
egen g=group(case_patientID)

gen double case_patientID2=real(case_patientID)
drop case_patientID
rename case_patientID2 case_patientID
gen double patientID2=real(patientID)
drop patientID
rename patientID2 patientID

merge m:1 patientID using "cases.dta"

egen m=min(cs),by(case_patientID)
sort case_patientID cs
keep if m==1
*relative rate of outpt visits

noisily di in smcl _n(2) "{p} The same cases and controls were used to determine the ratio of visits within the first year of pulmonary NTM diagnosis."
noisily xtpoisson ct case  male_gender copd bronchiectasis cancer otherpulm dmard hiv, i(g) irr



}








log close
