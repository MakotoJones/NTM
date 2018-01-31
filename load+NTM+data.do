clear
set more off
cd "P:\ORD_Jones_201309030D\Scripts\NLM abstract STATA"
*Calculate the nubmer of NTM infections from ICD-9 codes
*--------------------------------------------------------*

*clean inpaitent ICD-9 data
clear
#delimit ;
odbc load, exec ("
SELECT * FROM study.inpatientNTM
")
conn("DRIVER={SQL Server}; 
	  SERVER=[ServerName]; 
	  DATABASE=ORD_Jones_201309030D; 
	  Trusted_Connection=True") 
noquote clear
;
#delimit cr
drop FacilityID InpatientID EncounterID OrdinalNumber DiagnosisText
rename (ICDCode ICDDescription) (inptICDCode inptICDDescription)
capture drop AdmitDateTime2
gen double AdmitDateTime2 = clock(AdmitDateTime, "YMDhms")
format AdmitDateTime2 %tc
sort patientID AdmitDateTime2 //sort by first diagnosis per unique patient
capture drop inptcase
gen inptcase = 1 if AdmitDateTime2 > 1546387201000
replace inptcase=0 if inptcase==.
sort patientID AdmitDateTime2
collapse (first) inptICDCode-inptcase, by(patientID) //remove duclicates
display "Inpatient ICD-9 codes (first diagnosis)"
tab inptcase, missing
save inpatientNTM.dta, replace

*clean outpaitent ICD-9 data
clear
#delimit ;
odbc load, exec ("
SELECT * FROM study.outpatientNTM
")
conn("DRIVER={SQL Server}; 
	  SERVER=[ServerName]; 
	  DATABASE=ORD_Jones_201309030D; 
	  Trusted_Connection=True") 
noquote clear
;
#delimit cr
drop FacilityID OutPtEncounterID OutPtEncounterDiagnosisID ICDdictionaryID DiagnosisText
rename ICDCode outptICDCode
rename ICDDescription outptICDDescription
sort patientID DiagnosisDateTime //sort by first diagnosis per unique patient
capture drop outptcase
gen outptcase = 1 if DiagnosisDateTime > 1546387201000
replace outptcase=0 if outptcase==.
lab var outptcase "Case from outpatient"
sort patientID DiagnosisDateTime
collapse (first) DiagnosisDateTime-outptcase, by(patientID) //remove duplicates
tab outptcase,missing
display "Outpatient ICD-9 codes (first diagnosis)"
tab outptICDCode if outptcase ==1, missing
save outpatientNTM.dta, replace

*Merge the inpatient and outpatient ICD-9 datasets
use outpatientNTM.dta, clear
merge 1:1 patientID using inpatientNTM.dta, noreport // perform the merge, matching on patientID
tab _merge
drop _merge
replace inptcase=0 if inptcase==. 
replace outptcase=0 if outptcase==.
tab outptcase inptcase, missing
count if outptcase ==1 | inptcase ==1
capture drop IDICD9
gen IDICD9 = 0 if outptcase ==0 & inptcase ==0
replace IDICD9 = 1 if IDICD9 ==.
lab var IDICD9 "ICD-9"
tab IDICD9, missing
save mergedICD9NTM, replace

*Calculate the nubmer of NTM infections from mico/lab data
*--------------------------------------------------------*

*clean the cohort
clear
#delimit ;
odbc load, exec ("
SELECT * FROM Src.[Cohort]
")
conn("DRIVER={SQL Server}; 
	  SERVER=[ServerName]; 
	  DATABASE=ORD_Jones_201309030D; 
	  Trusted_Connection=True") 
noquote clear
;
#delimit cr
drop PatientGlobalUniqueID ScrGlobalUniqueID LocalUniqueID FacilityID
rename BestGlobalUniquePatientID BestGlobalUniquePatientID
sort BestGlobalUniquePatientID
quietly by BestGlobalUniquePatientID: gen dup = cond(_N==1,0,_n) //remove duplicates
drop if dup>1
drop dup
save cohort.dta, replace

*clean micro/lab data
clear
#delimit ;
odbc load, exec ("
SELECT * FROM temp.nlp_mycobacterial_criteria
")
conn("DRIVER={SQL Server}; 
	  SERVER=[ServerName]; 
	  DATABASE=ORD_Jones_201309030D; 
	  Trusted_Connection=True") 
noquote clear
;
#delimit cr
sort BestGlobalUniquePatientID
tab preferredterm
drop if preferredterm == "Mycobacterium tuberculosis" | ///
preferredterm == "Mycobacterium tuberculosis complex" // remove TB
drop if preferredterm == "Mycobacterium gordonae" // remove gordonae as it does not cause infections
*convert times to stata times
capture drop mindt2
gen double mindt2 = clock(mindt, "YMDhms")
format mindt2 %tc
drop mindt
capture drop unspecified_mindt2
gen double unspecified_mindt2 = clock(unspecified_mindt, "YMDhms")
format unspecified_mindt2 %tc
drop unspecified_mindt
capture drop sputum2
gen sputum2 = sputum + unspecified_sputum
capture drop bronch2
gen bronch2 = bronch + unspecified_bronch
capture drop lung2
gen lung2 = lung + unspecified_lung
capture drop other2
gen other2 = other + unspecified_other
capture drop firstdxdate
gen firstdxdate = min(mindt2, unspecified_mindt2)
capture drop microcase
gen microcase = 1 if firstdxdate > 1546387201000
replace microcase=0 if microcase==.
sort BestGlobalUniquePatientID firstdxdate
collapse (first) firstdxdate microcase (sum) sputum2 bronch2 lung2 other2 ,by(BestGlobalUniquePatientID) // remove duplicates
*ATS/IDSA guidelines for microbiological criteria of NTM are
// isolated from one bronchoscopy specimen OR
// at least 2 sputum samples OR
// extrapulmonary disease defined by NTM isolation from a sterile site
capture drop microcase2
gen microcase2 = 1 if (bronch2 >=1 | sputum2 >=2 | lung2 >=1 | other >=1) & microcase ==1
replace microcase2=0 if microcase2==.
lab var microcase2 "Case from micro/lab"
capture drop patientID
gen patientID = . // for linking to other data sets
tab microcase2,missing
sort BestGlobalUniquePatientID
save NLPNTM.dta, replace

*link patients patientID to NLP data
use NLPNTM.dta, clear
merge 1:1 BestGlobalUniquePatientID using cohortSID.dta, update noreport // perform the merge, matching on patientID
tab _merge
drop if _merge ==2
drop _merge
save NTM_data1.dta, replace

*Merge the datasets
use NTM_data1.dta, clear
merge 1:1 patientID using mergedICD9NTM, noreport
tab _merge
drop _merge
replace microcase2=0 if microcase2==.
replace outptcase=0 if outptcase==.
replace inptcase=0 if inptcase==.
replace IDICD9=0 if IDICD9==.
tab microcase2, missing
tab outptcase, missing
tab inptcase, missing
tab IDICD9,missing
save NTM_combine.dta, replace

*NTM identification results
*--------------------------------------------
use NTM_combine.dta, clear
display "Total number of NTM infections identified"
count if IDICD9 ==1 | microcase2 ==1
tab inptcase outptcase, missing
display "number of NTM infections identified by ICD-9 code in outpatient vist"
count if outptcase ==1
display "number of NTM infections identified by ICD-9 code in inpatient stay"
count if inptcase ==1
display "total number of NTM infections identified by ICD-9 code"
count if IDICD9 == 1
display "number of NTM infections identified by micro/lab data (ATS/IDSA guidelines)"
count if microcase2 ==1
display "number of NTM infections identified by both ICD-9 and micro/lab data"
count if IDICD9 == 1 & microcase2 ==1
tab IDICD9 microcase2, missing col
tab IDICD9 microcase2, missing row
tab IDICD9 microcase2, missing cell
count if IDICD9 ==1 | microcase2 ==1
