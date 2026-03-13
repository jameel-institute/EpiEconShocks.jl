#TO DO:
#parametrisation
#sectoral disaggregation
#avoidant behaviour

#PACKAGES USED
using CSV
using DataFrames
using Dates
using StatsBase
using Trapz

#READ IN DATA
df_tsdp = CSV.read(raw"../tsdp.csv", DataFrame);
df_tsdw = CSV.read(raw"../tsdw.csv", DataFrame);
df_tsdc = CSV.read(raw"../tsdc.csv", DataFrame);

SIM_END = Date(2025,11,25);#end of exercise
SIM_BEG = SIM_END - Day(90);

df_tsdp = df_tsdp[(df_tsdp.date .> SIM_BEG) .& (df_tsdp.date .<= SIM_END), :];
df_tsdw = df_tsdw[(df_tsdw.date .> SIM_BEG) .& (df_tsdw.date .<= SIM_END), :];
df_tsdc = df_tsdc[(df_tsdc.date .> SIM_BEG) .& (df_tsdc.date .<= SIM_END), :];

#PARAMETERS
N_TOT   = 67000000;#total population
N_WORK  = 30000000;#total workforce
N_NESS  = 20000000;#non-essential workforce
N_SCHC  = 0.172 * 67000000;#total school-children
EMP_POP = 0.75;#ratio of workforce to adult-population
A_MILD  = 0.50;#relative productivity of mildly symptomatic
A_CAR   = 0.50;#relative productivity of caregiving adults
PHI_ECO = 0.01 * 19216182 / N_TOT;#fitted value from Pangollo but rescaled from NY Metro to UK population

#DEFINE DAILY SHOCKS
l_notill = (N_WORK .- ((1 .- A_MILD) .* df_tsdw.prev_mldi .+ df_tsdw.prev_sevi .+ df_tsdw.occupancy_hosp .+ df_tsdw.deaths)) ./ N_WORK;
l_notcar = (N_WORK .- (1 .- A_CAR) .* EMP_POP .* (df_tsdc.prev_mldi .+ df_tsdc.prev_sevi .+ df_tsdc.occupancy_hosp)) ./ N_WORK;
l_notecl = (N_WORK .- N_NESS .* ((df_tsdw.date .≥ Date(2025,10,31)) .- (df_tsdw.date .≥ Date(2025,11,25)))) ./ N_WORK;
l_notscl = (N_WORK .- (1 .- A_CAR) .* EMP_POP .* N_SCHC .* ((df_tsdc.date .≥ Date(2025,10,10)) .- (df_tsdc.date .≥ Date(2025,11,25)))) ./ N_WORK;
l_avl    = l_notill .* l_notcar .* l_notecl .* l_notscl;
l_shock  = 1 .- l_avl;

c_shock  = 1 .- exp.(-PHI_ECO .* [0; diff(df_tsdp.deaths)]);

df_shocks = DataFrame(date = Dates.value.(df_tsdp.date), l_shock = l_shock, c_shock = c_shock);

#CALCULATE OUTPUT
vec_shocks = [trapz(df_shocks.date, df_shocks.l_shock), trapz(df_shocks.date, df_shocks.c_shock)] ./ (df_shocks.date[end] - (df_shocks.date[1] - 1));