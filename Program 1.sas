%macro import(infile,outname,sheet);
	proc import out=&outname
		datafile="&sharedrive/Data/&infile"
		dbms=xlsx replace;
		sheet="&sheet";
		getnames=yes;
	run;
%mend import;

%import(bmi.xlsx,info,info);
%import(bmi.xlsx,bmi,bmi);
%import(bmi.xlsx,drink,Drink);

proc format;
	value genderfmt 0 ="Male"
					1="Female";
	value yesno 0="No"
		  		1="Yes";
	value trtfmt 1="Control"
		  	     2="LAGB"
		  	     3="RYGB";
run;
/*merge all data together*/
data all;
	merge info(in=in_f)
		  bmi(in=in_b)
		  drink(in=in_d);
	by id;
	if in_f=in_b=in_d=1;
	label id ="ID"
		  Gender = "Gender"
		  Diabetes = "Diabetes status at baseline"
		  Hypertension = "Hypertension status at baseline"
		  TRT = "Treatment";	
	format gender genderfmt. diabetes yesno. hypertension yesno. TRT trtfmt.;
run;

proc sort data=all;	
	by id Gender Diabetes Hypertension TRT;
run;
proc transpose data=all out=long_bmi (rename=(col1=bmi) drop=_name_);
	by id Gender Diabetes Hypertension TRT;
	var BMI0-BMI4 ;
run;

proc transpose data=all out=long_drink (rename=(col1=drink) drop=_name_);
	by id Gender Diabetes Hypertension TRT ;
	var DRINK0-DRINK4;
run;

data long_raw;
	merge long_bmi long_drink;
	by id Gender Diabetes Hypertension TRT;
	if bmi="NA" then bmi=.;
	if drink="NA" then drink=.;
	if _LABEL_="DRINK0" then time=0;
	else if _LABEL_="DRINK1" then time=6;
	else if _LABEL_="DRINK2" then time=12;
	else if _LABEL_="DRINK3" then time=18;
	else time=24;
	drop _LABEL_;
	if drink not=. then do;
		if gender=1 then do;
			if drink<=8 then drink_cat="Normal";
			else drink_cat="Heavy Drinking";
		end;
		else if gender=0 then do;
			if drink<=15 then drink_cat="Normal";
			else drink_cat="Heavy Drinking";
		end;
	end;
run;

proc sort data=long;
	by id;
run;

data long;
set long_raw;
by id;
retain prev_BMI first_BMI total_drink;
if first.id then do;
	weight_change=.;
	prev_BMI=BMI;
	first_BMI=BMI;
	total_drink=drink;
end;
else do;
	weight_change=BMI-prev_BMI;
	total_drink=total_drink+drink;
	prev_BMI=BMI;
end;
if last.id then do;
    last_BMI = BMI;
    total_weight_change = last_BMI - first_BMI;
end;
weight_loss=-weight_change;
BMI_num = input(BMI, best.);
DRINK_num = input(DRINK, best.);
total_drink_num=input(total_drink,best.);
drop BMI DRINK total_drink prev_BMI first_BMI last_BMI;
rename BMI_num=BMI DRINK_num=DRINK total_drink_num=total_drink;
run;

proc print data=long (obs=10) label;
	id id;
run;

%Qtitle(Missing value investigation);
proc tabulate data=long out=summary_table;
  class ID Gender Diabetes Hypertension TRT time;
  var BMI DRINK ;
  table (Gender Diabetes Hypertension TRT ALL),
        (BMI="BMI & Drink")*(time ALL) *( n*f=8.  nmiss*f=8.);
  keylabel n='Count' nmiss='Missing' ALL="Total";
run;


%Qtitle(visualize changes in weight loss or trends in substance abuse over time);
proc tabulate data=long;
  class ID Gender Diabetes Hypertension TRT time;
  var BMI;
  table (Gender Diabetes Hypertension TRT ALL),
        (BMI="BMI")*(time ALL) *(mean median);
  keylabel ALL="Total";
run;
proc tabulate data=long;
  class ID Gender Diabetes Hypertension TRT time;
  var DRINK ;
  table (Gender Diabetes Hypertension TRT ALL),
        (drink="Drink")*(time ALL) *(mean median);
  keylabel ALL="Total";
run;

proc sgplot data=long;
	pbspline x=time y=bmi/group=TRT;
	xaxis label="Time (month)";
	yaxis label="BMI";
run;

proc sgplot data=long;
	pbspline x=time y=Drink/group=TRT;
	xaxis label="Time (month)";
	yaxis label="Number of drinks per week consumed";
run;


%Qtitle(BMI at baseline);
proc tabulate data=long;
  class ID Gender Diabetes Hypertension TRT time;
  var bmi ;
  table (Gender*Diabetes*Hypertension ALL),
        bmi*TRT*(n mean median);
  keylabel ALL="Total";
  where time=0;
run;


%Qsection(Hypothesis 1);
ods text="Hypothesis 1: is there a difference in mean BMI between males and females at baseline?";
ods text="H0:mu_male=mu_female H1: mu_male =/=mu_female";
ods text="Normality check: Given the qqplot and Shapiro-Wilk score for both male and female, the distribution of bmi is generally normally distributed in both male and female group. Therefore normality assumption is appropriate.";
ods text="Equal variance check: p-value = 0.6869>0.05  Fail to reject H0 (variances are the same)";
ods text= "%bold(Two-sample t-test (pooled variance):) p =0.0697>0.05, so we fail to reject H0.";

proc univariate data=long normal;
	class gender;
	var bmi;
	where time=0;
	qqplot bmi;
run;

proc ttest data=long;
	class gender;
	var bmi;
	where time=0;
	ods select Equality TTests;
run;

ods text= "There was no evidence to support that the mean bmi between male and female were different.";


%Qsection(Hypothesis 2);
ods text="Hypothesis 2: is there a difference in mean BMI between Diabetes status (Yes/No) at baseline?";
ods text="H0:mu_yes_diabete=mu_no_diabete H1: mu_yes_diabete =/= mu_no_diabete";
ods text="Normality check: Given the qqplot and Shapiro-Wilk score for both with diabetes and without diabetes, the distribution of bmi is generally normally distributed in both with diabetes and without diabetes group. Therefore normality assumption is appropriate.";
ods text="Equal variance check: p-value = 0.7196>0.05  Fail to reject H0 (variances are the same)";
ods text= "%bold(Two-sample t-test (pooled variance):) p =0.6931>0.05, so we fail to reject H0.";

proc univariate data=long normal;
	class diabetes;
	var bmi;
	where time=0;
	qqplot bmi;
run;

proc ttest data=long;
	class diabetes;
	var bmi;
	where time=0;
	ods select Equality TTests;
run;

ods text= "There was no evidence to support that the mean bmi between with diabetes and without diabetes groups were different.";

%Qsection(Hypothesis 3);
ods text="Hypothesis 3: is there a difference in mean BMI between hypertension status (Yes/No) at baseline?";
ods text="H0:mu_yes_hypertension=mu_no_hypertension H1: mu_yes_hypertension =/= mu_no_hypertension";
ods text="Normality check: Given the qqplot and Shapiro-Wilk score for both with hypertension and without hypertension, the distribution of bmi is generally normally distributed in both with hypertension and without hypertension group. Therefore normality assumption is appropriate.";
ods text="Equal variance check: p-value = 0.8463>0.05  Fail to reject H0 (variances are the same)";
ods text= "%bold(Two-sample t-test (pooled variance):) p =0.7133>0.05, so we fail to reject H0.";

proc univariate data=long normal;
	class hypertension;
	var bmi;
	where time=0;
	qqplot bmi;
run;

proc ttest data=long;
	class hypertension;
	var bmi;
	where time=0;
	ods select Equality TTests;
run;

ods text= "There was no evidence to support that the mean bmi between with hypertension and without hypertension groups were different.";

%Qsection(Hypothesis 4);
ods text="Hypothesis 4: is there a difference in mean BMI between treatments and control at baseline?";
ods text="H0:mu_control=mu_LAGB=mu_RYGB H1:at least one mean difference exists";
ods text="Normality check: Given the qqplot and Shapiro-Wilk score for control and 2 treatment groups, the distribution of BMI is generally normally distributed in all three groups. Therefore normality assumption is appropriate.";
ods text="check heteroskedasticity:(HOV Test:) p = 0.41>0.05 so we fail to reject null hypothesis and conclude that equal variance assumption is appropriate).";
ods text= "%bold(ANOVA:) p = 0.3075>0.05 so we fail to Reject null hypothesis and conclude that the BMI is same among two treatments and control group at baseline  ";
proc univariate data=long normal;
	class TRT;
	var bmi;
	where time=0;
	qqplot bmi;
run;
proc anova data=long;
	class trt;
	where time=0;
	model bmi = trt;
	means trt / hovtest=bf; 
run; quit;
ods text= "There was no evidence to support that the mean BMI were generally different among all treatment and control groups.";

%Qsection(Hypothesis 5);
ods text="Hypothesis 5: Is the Pearson's correlation coefficient of BMI and alcohol consumption at baseline equal to 0?";
ods text="H0: rho equal to 0 vs. H1: rho not equal to 0";
ods text="Pearson correlation coefficient test: p-value = 0.3490>0.05, so we fail to reject the null hypothesis.";
proc corr data=long plots=scatter;
	var bmi drink;
	where time=0;
run;
proc sgplot data=long;
	vbox bmi /group=drink grouporder=ascending;
	where time=0;
run;
ods text="The p-value associated with this correlation coefficient is 0.3490. The p-value tests the null hypothesis that the true correlation is zero which means no association.";


%Qtitle(Test for differences in weight loss over time);
proc sgplot data=long;
	vbox bmi / category=trt group=time;
run;

%Qsection(Hypothesis 6);
ods text="Hypothesis 6: is there a difference in mean weight loss over time?";
ods text="H0:mu_6_months=mu_12_months=mu_18_months=mu_24_months H1:at least one mean difference exists";
ods text="Normality check: Given the qqplot and Shapiro-Wilk score for time=6 months(Pr < W=0.2164), time=12 months(Pr < W=0.1852), time=18 months(Pr < W=	0.6722), time=24 months(Pr < W=0.5291), the distribution of weight loss is generally normally distributed in all times. Therefore normality assumption is appropriate.";
ods text="check heteroskedasticity:(HOV Test:) p = <.0001<0.05 so we reject null hypothesis and conclude that equal variance assumption isn't appropriate).";
ods text= "%bold(ANOVA:) p = <.0001< 0.05 so we can reject null hypothesis and conclude that the weight loss is different among each time";

data long_diff;
	set long;
	where time>0;
	weight_loss=-1*weIght_change;
run;

proc univariate data=long_diff normal;
	class time;
	var weight_loss;
	qqplot weight_loss;
run;

proc anova data=long_diff;
	class time;
	model weight_loss = time;
	means time / hovtest=bf dunnett("6"); 
run; quit;

ods text= "There was strong evidence to support that the mean weight loss were different at each time point. Moreover, additional analyses showed evidence that there is a statistically significant decrease in weight loss at 12, 18, and 24 months compared to 6 months, with the amount of weight loss increasing as time goes on.";


%Qsection(Hypothesis 7);
ods text="Hypothesis 7: is there a difference in mean total weight change among different treatments and control group?";
ods text="H0:mu_control=mu_LAGB=mu_RYGB H1:at least one mean difference exists";
ods text="Normality check: Given the qqplot and Shapiro-Wilk score for control(0.5422),LAGB(0.2981),RYGB(0.8745) groups, the distribution of total weight change is generally normally distributed in all three groups. Therefore normality assumption is appropriate.";
ods text="check heteroskedasticity:(HOV Test:) p = 0.7768>0.05 so we fail to reject null hypothesis and conclude that equal variance assumption is appropriate).";
ods text= "%bold(ANOVA:) p = <.0001<0.05 so we can reject null hypothesis and conclude that the total weight change is different among two treatments and control group.";


proc univariate data=long normal;
	class trt;
	var total_weight_change;
	qqplot total_weight_change;
run;
proc anova data=long;
	class trt;
	model total_weight_change = trt;
	means trt / hovtest=bf; 
run; quit;
ods text= "There was strong evidence to support that the mean total weight change were different among treatments and control groups.";

%Qsection(Mixed effect regression models);
/*random intercept without interaction*/
proc mixed data=long ;
	class trt(ref="Control") gender(ref="Male") diabetes(ref="No") hypertension(ref="No") drink_cat(ref="Normal");
	model weight_change = gender diabetes hypertension trt time drink_cat/ solution;
	random intercept / subject=id type=un;
run;
/*random intercept with interaction between trt and time*/
proc mixed data=long;
	class trt(ref="Control") gender(ref="Male") diabetes(ref="No") hypertension(ref="No") drink_cat(ref="Normal");
	model weight_change = gender diabetes hypertension trt|time drink_cat/ solution;
	random intercept / subject=id type=un;
run;
/*random intercept and random slope by trt */
proc mixed data=long ;
	class trt(ref="Control") gender(ref="Male") diabetes(ref="No") hypertension(ref="No") drink_cat(ref="Normal");
	model weight_change = gender diabetes hypertension trt time drink_cat / solution ;
	random trt / subject=id type=un;
run;
/*random intercept and random slope by trt with interaction between trt and time*/
proc mixed data=long ;
	class trt(ref="Control") gender(ref="Male") diabetes(ref="No") hypertension(ref="No") drink_cat(ref="Normal");
	model weight_change = gender diabetes hypertension trt|time drink_cat / solution;
	random trt / subject=id type=un;
run;
ods text="Given the comparison of AIC, the first model was selected because of smaller AIC value.";
ods text="There is a risk of bias due to incomplete follow-up or drop out of study participants";

%Qsection(GEE);

proc genmod data=long;
	class id trt(ref="Control") gender(ref="Male") diabetes(ref="No") hypertension(ref="No") drink_cat(ref="Normal");
	model weight_change = gender diabetes hypertension trt time drink_cat;
	repeated subject=id / type=un covb corrw;
run;

%Qtitle(final weight measurement related to any of your exposures of interest, Is there any relevant interaction among your exposures?);

proc sort data=long;
	by id;
run;
data final_long;
	set long;
	by id;
	if last.id then output;
run;

proc sgplot data=final_long;
	histogram bmi;
run;/*normally distributed*/
proc sgplot data=final_long;
	histogram total_weight_change;
run;/*normally distributed*/

/*fit full model*/
proc glm data=final_long;
    class gender(ref="Male") diabetes(ref="No") hypertension(ref="No");
    model bmi = gender diabetes hypertension total_drink/solution;
run; quit;

proc corr data=final_long plots=matrix;
	var bmi gender diabetes hypertension total_drink;
run;

ods rtf close;
